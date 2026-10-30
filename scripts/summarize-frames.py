#!/usr/bin/env python3
"""Summarize xctrace App Updates, not FPS. No performance PASS is inferred."""
import argparse
import json
import math
from pathlib import Path
import re
import xml.etree.ElementTree as ET


def distribution(values):
    if not values:
        return dict(count=0, p50_ms=None, p95_ms=None, max_ms=None, total_ms=0)
    values = sorted(values)
    return dict(count=len(values), p50_ms=values[math.ceil(len(values)*.5)-1],
                p95_ms=values[math.ceil(len(values)*.95)-1], max_ms=values[-1],
                total_ms=sum(values))


def summarize(toc_path, events_path, run=1, process='StreamLab', start=0, end=None):
    if not math.isfinite(start) or start < 0 or (end is not None and
            (not math.isfinite(end) or end <= start)):
        raise ValueError('Expected finite window: 0 <= start < end')
    toc = ET.parse(toc_path).getroot()
    selected = next((r for r in toc.findall('run') if r.get('number') == str(run)), None)
    if selected is None:
        raise ValueError('Requested run missing from TOC')
    target = selected.find('info/target/process')
    if target is None or target.get('name') != process or not target.get('pid'):
        raise ValueError('Requested process does not match the recorded target')
    target_pid = target.get('pid')
    tables = selected.findall('data/table')
    root = ET.parse(events_path).getroot()
    ids = {e.get('id'): e for e in root.iter() if e.get('id')}

    def resolve(e):
        if e.get('ref'):
            if e.get('ref') not in ids:
                raise ValueError('Unresolved XML reference')
            return ids[e.get('ref')]
        return e

    def number(e):
        value = float(resolve(e).text or '')
        if not math.isfinite(value) or value < 0:
            raise ValueError('Invalid numeric data')
        return value

    def belongs(e):
        p = resolve(e)
        pid = p.find('pid')
        return pid is not None and (resolve(pid).text or '') == target_pid

    kinds = {'hitches-updates': [], 'hitches': []}
    exported = set()
    seen = set()
    for node in root.findall('node'):
        path = node.get('xpath', '')
        match = re.search(r'/run\[(\d+)\].*/table\[(\d+)\]', path)
        if not match:
            raise ValueError('Unsupported export XPath')
        if int(match[1]) != run:
            continue
        index = int(match[2]) - 1
        if not 0 <= index < len(tables):
            raise ValueError('Export table index does not match TOC')
        schema = tables[index].get('schema')
        if schema not in kinds:
            continue
        declared = node.find('schema')
        if declared is not None and declared.get('name') != schema:
            raise ValueError('Export schema does not match TOC')
        exported.add(schema)
        for row in node.findall('row'):
            fields = list(row)
            if len(fields) < (8 if schema == 'hitches-updates' else 5):
                raise ValueError('Incomplete frame row')
            if not belongs(fields[2]):
                continue
            if schema == 'hitches-updates' and number(fields[7]) != 0:
                continue  # nested updates must not be counted twice
            t = number(fields[0]) / 1e9
            ms = number(fields[1]) / 1e6
            if t < start or (end is not None and t >= end):
                continue
            key = (schema, t, ms, number(fields[4]))
            if key in seen:
                continue
            seen.add(key)
            kinds[schema].append(ms)
    missing = sorted(set(kinds) - exported)
    return dict(run=run, process=process, window_seconds=dict(start=start, end=end),
                window_policy='event start in [start,end); durations are not clipped',
                percentile_method='nearest-rank',
                capture_status=('missing_tables' if missing else
                                'no_app_updates_in_window' if not kinds['hitches-updates'] else 'available'),
                missing_tables=missing,
                app_updates=distribution(kinds['hitches-updates']),
                hitches=distribution(kinds['hitches']),
                limitations=['App Update durations are not FPS or display-frame intervals.',
                             'No hitches recorded does not prove no main-thread delay.',
                             'No automatic performance PASS; compare equivalent windows and conditions.'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--toc', required=True, type=Path)
    parser.add_argument('--events', required=True, type=Path)
    parser.add_argument('--run', type=int, default=1)
    parser.add_argument('--process', default='StreamLab')
    parser.add_argument('--start', type=float, default=0)
    parser.add_argument('--end', type=float)
    args = parser.parse_args()
    try:
        result = summarize(args.toc, args.events, args.run, args.process, args.start, args.end)
    except (ValueError, OSError, ET.ParseError) as error:
        parser.exit(2, f'Cannot summarize: {error}\n')
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['capture_status'] == 'available' else 1


if __name__ == '__main__':
    raise SystemExit(main())
