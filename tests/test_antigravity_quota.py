import runpy
import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch

COLLECTOR = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'configs/bin/omarchy-agent-usage-antigravity'))


def payload():
    return {
        'status': 'SUCCESS',
        'command': {'name': 'usage', 'data': {'groups': [
            {'name': 'Gemini Models', 'buckets': [
                {'id': 'gemini-weekly', 'remaining_fraction': 0.83, 'reset_time': '2026-09-12T10:58:02Z'},
                {'id': 'gemini-5h', 'remaining_fraction': 0, 'reset_time': '2026-09-05T15:58:02Z'},
            ]},
            {'name': 'Claude and GPT models', 'buckets': [
                {'id': '3p-weekly', 'remaining_fraction': 1, 'reset_time': '2026-09-12T14:04:46Z'},
                {'id': '3p-5h', 'remaining_fraction': 1, 'reset_time': '2026-09-05T19:04:46Z'},
            ]},
        ]}},
    }


class QuotaTests(unittest.TestCase):
    def test_remaining_is_converted_to_used_per_bucket(self):
        limits = COLLECTOR['parse_quota'](payload())
        self.assertEqual([x['title'] for x in limits], ['Gemini · 5h', 'Gemini · Weekly', 'Claude / GPT · 5h', 'Claude / GPT · Weekly'])
        self.assertEqual(limits[0]['percent'], 1)
        self.assertAlmostEqual(limits[1]['percent'], 0.17)
        self.assertEqual([x['percent'] for x in limits[2:]], [0, 0])
        self.assertEqual(limits[0]['resetsAt'], '2026-09-05T15:58:02Z')

    def test_invalid_fraction_is_unknown_not_zero(self):
        for value in [None, '0.5', True, -0.1, 1.1, float('nan'), float('inf')]:
            with self.subTest(value=value):
                data = payload()
                data['command']['data']['groups'][0]['buckets'][1]['remaining_fraction'] = value
                self.assertTrue(COLLECTOR['parse_quota'](data)[0]['unknown'])

    def test_missing_group_and_bad_reset_are_unknown(self):
        data = payload()
        data['command']['data']['groups'].pop()
        data['command']['data']['groups'][0]['buckets'][0]['reset_time'] = 'bad'
        limits = COLLECTOR['parse_quota'](data)
        self.assertEqual([x['unknown'] for x in limits], [False, True, True, True])

    def test_wrong_command_or_failed_response_rejected(self):
        for key, value in [('status', 'ERROR'), ('command', {'name': 'chat'})]:
            data = payload()
            data[key] = value
            with self.assertRaises(ValueError):
                COLLECTOR['parse_quota'](data)

    def test_timeout_or_invalid_json_clears_quotas(self):
        for failure in [subprocess.TimeoutExpired('agy', 45), ValueError('bad json')]:
            with patch('shutil.which', return_value='/bin/agy'), patch('subprocess.run', side_effect=failure):
                limits, status, help_text = COLLECTOR['fetch_quota']()
                self.assertTrue(all(x['unknown'] for x in limits))
                self.assertEqual(status, 'Quota unavailable')
                self.assertTrue(help_text)

    def test_get_user_email_returns_latest_auth_account(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmpdir:
            log_dir = Path(tmpdir) / "log"
            log_dir.mkdir(parents=True)
            log_file = log_dir / "cli-20260905_120000.log"
            log_file.write_text(
                "2026-09-05T12:00:00Z [auth] applyAuthResult: email=old_user@gmail.com, authMethod=consumer, quotaProject=\n"
                "2026-09-05T12:30:00Z [info] some other log message\n"
                "2026-09-05T13:00:00Z [auth] applyAuthResult: email=new_user@gmail.com, authMethod=consumer, quotaProject=\n"
                "2026-09-05T13:05:00Z [info] completed\n"
            )
            email = COLLECTOR['get_user_email'](candidate_dirs=[log_dir])
            self.assertEqual(email, "new_user@gmail.com")

    def test_get_user_email_picks_newest_log_file(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmpdir:
            log_dir = Path(tmpdir) / "log"
            log_dir.mkdir(parents=True)
            log1 = log_dir / "cli-20260905_100000.log"
            log1.write_text("applyAuthResult: email=user1@gmail.com, authMethod=consumer\n")
            log2 = log_dir / "cli-20260905_110000.log"
            log2.write_text("applyAuthResult: email=user2@gmail.com, authMethod=consumer\n")
            email = COLLECTOR['get_user_email'](candidate_dirs=[log_dir])
            self.assertEqual(email, "user2@gmail.com")


if __name__ == '__main__':
    unittest.main()

