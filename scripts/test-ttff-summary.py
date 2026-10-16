import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('ttff', Path(__file__).with_name('summarize-ttff.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class SummaryTests(unittest.TestCase):
    def test_nearest_rank(self):
        self.assertEqual(module.percentile(list(range(1, 21)), .5), 10)
        self.assertEqual(module.percentile(list(range(1, 21)), .95), 19)
        self.assertIsNone(module.percentile([], .95))

    def test_duplicates_failures_missing_and_source_isolation(self):
        end = 'summary attempt=a source=hls first_frame_ready_seconds=1.5 failures=0 invalid_transitions=0'
        text = '\n'.join(['attempt_started attempt=a source=hls', end, end,
            'attempt_started attempt=b source=hls',
            'summary attempt=c source=hls first_frame_ready_seconds=not-observed failures=1 invalid_transitions=0',
            'summary attempt=d source=local first_frame_ready_seconds=0.1 failures=0 invalid_transitions=0'])
        starts, rows = module.collect(text, 'hls')
        self.assertEqual(starts - rows.keys(), {'b'})
        self.assertEqual(set(rows), {'a', 'c'})
        self.assertIsNone(rows['c']['seconds'])
        self.assertEqual(rows['c']['failures'], 1)
        with self.assertRaises(ValueError):
            module.collect(text + '\n' + end.replace('1.5', '2.0'), 'hls')

    def test_invalid_or_empty(self):
        for value in ['NaN', 'inf', '-1']:
            with self.assertRaises(ValueError):
                module.collect(f'summary attempt=a source=hls first_frame_ready_seconds={value} failures=0 invalid_transitions=0', 'hls')
        with self.assertRaises(ValueError):
            module.collect('summary attempt=a first_frame_ready_seconds=1', 'hls')

if __name__ == '__main__':
    unittest.main()
