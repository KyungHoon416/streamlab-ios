#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('frames', Path(__file__).with_name('summarize-frames.py'))
frames = importlib.util.module_from_spec(spec)
spec.loader.exec_module(frames)

class FrameSummaryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.toc = Path(self.temp.name)/'toc.xml'
        self.events = Path(self.temp.name)/'events.xml'
        self.toc.write_text('<trace-toc><run number="1"><info><target><process name="StreamLab" pid="42"/></target></info><data><table schema="hitches-updates"/><table schema="hitches"/></data></run></trace-toc>')

    def run_summary(self, rows='', hitch=True, **kwargs):
        self.events.write_text('<trace-query-result><node xpath="/run[1]/data[1]/table[1]">'+rows+'</node>'+ ('<node xpath="/run[1]/data[1]/table[2]"/>' if hitch else '')+'</trace-query-result>')
        return frames.summarize(self.toc, self.events, **kwargs)

    def row(self, time=1, duration=10, pid=42, depth=0):
        return f'<row><start>{int(time*1e9)}</start><duration>{int(duration*1e6)}</duration><process><pid>{pid}</pid></process><display>1</display><id>10</id><surface>1</surface><color/><depth>{depth}</depth></row>'

    def test_nearest_rank_and_empty_are_not_zero_percentiles(self):
        self.assertEqual(frames.distribution(range(1,21))['p95_ms'],19)
        self.assertIsNone(frames.distribution([])['p95_ms'])

    def test_other_process_nested_rows_and_duplicates_excluded(self):
        rows=self.row()+self.row()+self.row(pid=7)+self.row(depth=1)
        result=self.run_summary(rows)
        self.assertEqual(result['app_updates']['count'],1)
        self.assertEqual(result['hitches']['count'],0)
        self.assertEqual(result['capture_status'],'available')

    def test_missing_and_empty_tables_are_distinct(self):
        self.assertEqual(self.run_summary(hitch=False)['capture_status'],'missing_tables')
        self.assertEqual(self.run_summary()['capture_status'],'no_app_updates_in_window')

    def test_window_uses_start_and_does_not_clip(self):
        result=self.run_summary(self.row(time=.9)+self.row(time=1,duration=2000)+self.row(time=2),start=1,end=2)
        self.assertEqual(result['app_updates']['count'],1)
        self.assertEqual(result['app_updates']['max_ms'],2000)

    def test_references_resolve(self):
        rows=self.row().replace('<process><pid>42</pid></process>','<process id="p"><pid>42</pid></process>')
        rows+=self.row(time=2).replace('<process><pid>42</pid></process>','<process ref="p"/>')
        self.assertEqual(self.run_summary(rows)['app_updates']['count'],2)

    def test_bad_reference_and_bounds_fail(self):
        with self.assertRaises(ValueError):self.run_summary(self.row().replace('<duration>10000000</duration>','<duration ref="absent"/>'))
        with self.assertRaises(ValueError):self.run_summary(start=2,end=1)
        with self.assertRaises(ValueError):self.run_summary(run=2)

if __name__=='__main__':unittest.main()
