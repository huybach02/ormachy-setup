import runpy
import sqlite3
import tempfile
import unittest
from contextlib import closing
from datetime import datetime
from pathlib import Path

M = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'configs/bin/omarchy-agent-usage-antigravity'))


def varint(n):
    out = bytearray()
    while n > 127:
        out.append((n & 127) | 128)
        n >>= 7
    return bytes(out) + bytes([n])


def proto(**fields):
    out = b''
    for key, value in fields.items():
        tag = int(key[1:])
        if isinstance(value, bytes):
            out += varint(tag * 8 + 2) + varint(len(value)) + value
        else:
            out += varint(tag * 8) + varint(value)
    return out


class TokenTests(unittest.TestCase):
    def test_real_counts_model_day_and_deduplication(self):
        stamp = int(datetime(2026, 9, 5, 12).timestamp())
        usage = proto(f2=100, f3=30, f5=200, f4=10, f9=20, f10=10, f7=b'unique-response')
        generation = proto(f2=varint(1), f1=proto(f4=usage, f19=b'actual-model'))
        with tempfile.TemporaryDirectory() as directory:
            for name in ['original.db', 'copied.db']:
                with closing(sqlite3.connect(Path(directory) / name)) as conn:
                    conn.execute('CREATE TABLE steps(idx INTEGER, metadata BLOB)')
                    conn.execute('CREATE TABLE gen_metadata(idx INTEGER, data BLOB)')
                    conn.execute('INSERT INTO steps VALUES (?, ?)', (1, proto(f1=proto(f1=stamp), f9=usage)))
                    conn.execute('INSERT INTO gen_metadata VALUES (?, ?)', (0, generation))
                    conn.commit()
            days, models, today, skipped = M['token_stats'](Path(directory), ['2026-09-04', '2026-09-05'], '2026-09-05')
        self.assertEqual(days, {'2026-09-04': 0, '2026-09-05': 340})
        self.assertEqual(models['actual-model']['totalTokens'], 340)
        self.assertEqual(today, {'actual-model': 340})
        self.assertEqual(skipped, 0)

    def test_truncated_protobuf_rejected(self):
        with self.assertRaises(ValueError):
            list(M['proto_fields'](b'\x0a\x10abc'))


if __name__ == '__main__':
    unittest.main()
