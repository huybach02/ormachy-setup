import runpy
import unittest
from pathlib import Path

STATUSLINE = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'configs/bin/agy-statusline'))

class StatuslineTests(unittest.TestCase):
    def test_strip_ansi(self):
        colored = "\x1b[1;37m5h:\x1b[0m \x1b[36mGemini\x1b[0m"
        self.assertEqual(STATUSLINE['strip_ansi'](colored), "5h: Gemini")

    def test_truncate_ansi(self):
        colored = "\x1b[1;36mGemini\x1b[0m [████░░░░░░] 40%"
        trunc = STATUSLINE['truncate_ansi'](colored, 10)
        self.assertLessEqual(len(STATUSLINE['strip_ansi'](trunc)), 10)
        self.assertTrue(trunc.endswith("\x1b[0m"))

    def test_format_tokens(self):
        self.assertEqual(STATUSLINE['format_tokens'](500), "500")
        self.assertEqual(STATUSLINE['format_tokens'](90812), "90.8k")
        self.assertEqual(STATUSLINE['format_tokens'](1048576), "1.0M")

    def test_format_reset_time(self):
        self.assertEqual(STATUSLINE['format_reset_time'](None), "--")
        self.assertEqual(STATUSLINE['format_reset_time'](0), "now")
        self.assertEqual(STATUSLINE['format_reset_time'](-10), "now")
        self.assertEqual(STATUSLINE['format_reset_time'](45), "45s")
        self.assertEqual(STATUSLINE['format_reset_time'](120), "2m")
        self.assertEqual(STATUSLINE['format_reset_time'](5400), "1h30m")
        self.assertEqual(STATUSLINE['format_reset_time'](3600 * 5), "5h")
        self.assertEqual(STATUSLINE['format_reset_time'](86400 * 3 + 3600 * 12), "3d12h")
        self.assertEqual(STATUSLINE['format_reset_time'](86400 * 4), "4d")

    def test_render_bar(self):
        plain_bar = STATUSLINE['strip_ansi'](STATUSLINE['render_bar'](20, 10))
        self.assertEqual(plain_bar, "██░░░░░░░░")
        plain_bar_50 = STATUSLINE['strip_ansi'](STATUSLINE['render_bar'](50, 6))
        self.assertEqual(plain_bar_50, "███░░░")
        self.assertEqual(STATUSLINE['render_bar'](20, 0), "")

    def test_responsive_widths_never_overflow(self):
        for w in range(25, 160):
            line_5h = STATUSLINE['format_quota_line']("5h", 20, "2h30m", 30, "1h20m", w)
            plain_5h = STATUSLINE['strip_ansi'](line_5h)
            self.assertLessEqual(len(plain_5h), w, f"5h line overflowed at width {w}: {len(plain_5h)} > {w}")

            line_wk = STATUSLINE['format_quota_line']("Weekly", 5, "3d18h", 2, "3d17h", w)
            plain_wk = STATUSLINE['strip_ansi'](line_wk)
            self.assertLessEqual(len(plain_wk), w, f"Weekly line overflowed at width {w}: {len(plain_wk)} > {w}")

            line_ctx = STATUSLINE['format_context_line'](90812, 1048576, w)
            plain_ctx = STATUSLINE['strip_ansi'](line_ctx)
            self.assertLessEqual(len(plain_ctx), w, f"Context line overflowed at width {w}: {len(plain_ctx)} > {w}")

    def test_get_quotas(self):
        payload = {
            "quota": {
                "gemini-5h": {"remaining_fraction": 0.8, "reset_in_seconds": 9000},
                "3p-5h": {"remaining_fraction": 0.7, "reset_in_seconds": 4800},
                "gemini-weekly": {"remaining_fraction": 0.95, "reset_in_seconds": 300000},
                "3p-weekly": {"remaining_fraction": 0.99, "reset_in_seconds": 290000},
            }
        }
        res = STATUSLINE['get_quotas'](payload)
        self.assertEqual(res["5h"]["gemini"], (20, "2h30m"))
        self.assertEqual(res["5h"]["claude"], (30, "1h20m"))
        self.assertEqual(res["weekly"]["gemini"][0], 5)
        self.assertEqual(res["weekly"]["claude"][0], 1)

if __name__ == '__main__':
    unittest.main()
