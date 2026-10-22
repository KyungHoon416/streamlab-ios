import importlib.util
from pathlib import Path
import unittest
import csv
import hashlib
import subprocess
import sys
import tempfile

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

    def test_rebuffer_validation_and_conflicts(self):
        base = 'summary attempt=a source=hls first_frame_ready_seconds=1 failures=0 invalid_transitions=0'
        valid = base + ' rebuffer_count=2 rebuffer_seconds=3.5'
        _, rows = module.collect(valid + '\n' + valid, 'hls')
        self.assertEqual(rows['a']['rebuffer_seconds'], 3.5)
        for suffix in ['rebuffer_count=1', 'rebuffer_seconds=1',
                       'rebuffer_count=-1 rebuffer_seconds=0',
                       'rebuffer_count=0 rebuffer_seconds=1',
                       'rebuffer_count=1 rebuffer_seconds=NaN',
                       'rebuffer_count=1 rebuffer_seconds=inf',
                       'rebuffer_count=1 rebuffer_seconds=-1']:
            with self.subTest(suffix=suffix), self.assertRaises(ValueError):
                module.collect(base + ' ' + suffix, 'hls')
        with self.assertRaises(ValueError):
            module.collect(valid + '\n' + valid.replace('3.5', '4.5'), 'hls')
        with self.assertRaises(ValueError):
            module.collect(valid.replace(' failures=0', ''), 'hls')

    def run_report(self, root, text):
        log = root / 'synthetic.log'
        log.write_text(text)
        output = root / 'report'
        result = subprocess.run([sys.executable, str(Path(module.__file__)),
            '--log', str(log), '--source', 'hls', '--device', 'SYNTHETIC',
            '--os', 'fixture', '--configuration', 'test', '--scenario', 'synthetic only',
            '--commit', 'fixture', '--output-dir', str(output), '--require-complete'],
            capture_output=True, text=True)
        return result, output

    def test_complete_report_csv_percentiles_hash_and_overwrite(self):
        text = '\n'.join(
            f'attempt_started attempt=a{i} source=hls\n'
            f'summary attempt=a{i} source=hls first_frame_ready_seconds={i} '
            f'failures={int(i == 20)} invalid_transitions=0 '
            f'rebuffer_count={int(i > 10)} rebuffer_seconds={i if i > 10 else 0}'
            for i in range(1, 21))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            result, output = self.run_report(root, text)
            self.assertEqual(result.returncode, 0, result.stderr)
            report = (output / 'REPORT.md').read_text()
            for expected in ['| p50 · nearest rank | 10.000 s |',
                             '| p95 · nearest rank | 19.000 s |',
                             '| 재버퍼링 총 대기 시간 | 155.000 s |',
                             '| 재버퍼링 총 횟수 | 10 |',
                             '| 재버퍼링 발생 시도 비율 | 10/20 (50.0%) |',
                             '| 요약이 있는 시도 중 실패 비율 | 1/20 (5.0%) |',
                             '| 시도별 재버퍼링 대기 시간 p50 | 0.000 s |',
                             '| 시도별 재버퍼링 대기 시간 p95 | 19.000 s |',
                             '| 20개 관측·로그 완전성 | PASS |',
                             '| 성능 목표 판정 | NOT TESTED',
                             hashlib.sha256(text.encode()).hexdigest()]:
                self.assertIn(expected, report)
            with (output / 'samples.csv').open(encoding='utf-8-sig') as handle:
                rows = list(csv.DictReader(handle))
            self.assertEqual(len(rows), 20)
            self.assertTrue(all(r['record_status'] == 'summary' for r in rows))
            again, _ = self.run_report(root, text)
            self.assertNotEqual(again.returncode, 0)
            self.assertEqual((output / 'REPORT.md').read_text(), report)

    def test_incomplete_report_preserves_unknowns_and_returns_nonzero(self):
        text = ('attempt_started attempt=a source=hls\n'
                'summary attempt=a source=hls first_frame_ready_seconds=1 failures=0 invalid_transitions=0\n'
                'attempt_started attempt=b source=hls\n'
                'summary attempt=c source=hls first_frame_ready_seconds=not-observed failures=1 invalid_transitions=0')
        with tempfile.TemporaryDirectory() as directory:
            result, output = self.run_report(Path(directory), text)
            self.assertEqual(result.returncode, 2, result.stderr)
            with (output / 'samples.csv').open(encoding='utf-8-sig') as handle:
                rows = list(csv.DictReader(handle))
            self.assertEqual([r['record_status'] for r in rows],
                             ['missing-rebuffer-metrics', 'missing-summary', 'orphan-summary'])
            self.assertTrue(all(r['rebuffer_seconds'] == '' for r in rows))
            report = (output / 'REPORT.md').read_text()
            self.assertIn('| 재버퍼링 총 횟수 | NOT TESTED |', report)
            self.assertIn('| 20개 관측·로그 완전성 | FAIL |', report)

if __name__ == '__main__':
    unittest.main()
