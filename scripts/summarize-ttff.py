#!/usr/bin/env python3
"""Summarize one real-device/source/scenario log; never infer performance PASS."""
import argparse
import csv
import math
from pathlib import Path
import re


def collect(text, source):
    starts, summaries = set(), {}
    for line in text.splitlines():
        if 'attempt_started ' not in line and 'summary attempt=' not in line:
            continue
        fields = dict(re.findall(r'([a-z_]+)=([^\s]+)', line))
        if fields.get('source') != source:
            continue
        attempt = fields.get('attempt')
        if not attempt:
            raise ValueError('Missing attempt ID')
        if 'attempt_started ' in line:
            starts.add(attempt)
            continue
        value = fields.get('first_frame_ready_seconds')
        seconds = None if value == 'not-observed' else float(value)
        if seconds is not None and (not math.isfinite(seconds) or seconds < 0):
            raise ValueError('Invalid first-frame time')
        row = {'attempt': attempt, 'source': source, 'seconds': seconds,
               'failures': int(fields['failures']),
               'invalid_transitions': int(fields['invalid_transitions'])}
        if row['failures'] < 0 or row['invalid_transitions'] < 0:
            raise ValueError('Negative event count')
        if attempt in summaries and summaries[attempt] != row:
            raise ValueError('Conflicting duplicate summary: ' + attempt)
        summaries[attempt] = row
    if not starts and not summaries:
        raise ValueError('No matching source-tagged records. Update app and capture unfiltered logs.')
    return starts, summaries


def percentile(values, fraction):
    """Nearest rank; for n=20 p50 is item 10 and p95 is item 19."""
    return sorted(values)[math.ceil(len(values) * fraction) - 1] if values else None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('log', 'source', 'device', 'os', 'configuration', 'scenario', 'commit', 'output-dir'):
        parser.add_argument('--' + name, required=True)
    args = parser.parse_args()
    starts, summaries = collect(Path(args.log).read_text(encoding='utf-8'), args.source)
    values = [r['seconds'] for r in summaries.values() if r['seconds'] is not None]
    incomplete = starts - summaries.keys()
    orphaned = summaries.keys() - starts
    no_frame = sum(r['seconds'] is None for r in summaries.values())
    failures = sum(r['failures'] > 0 for r in summaries.values())
    invalid = sum(r['invalid_transitions'] for r in summaries.values())
    output = Path(args.output_dir)
    output.mkdir(parents=True, exist_ok=True)
    if any((output / n).exists() for n in ('samples.csv', 'REPORT.md')):
        raise ValueError('Output already exists; use a new directory to preserve previous results')
    with (output / 'samples.csv').open('w', newline='', encoding='utf-8-sig') as handle:
        writer = csv.writer(handle)
        writer.writerow(['attempt', 'source', 'first_frame_ready_seconds', 'failures', 'invalid_transitions', 'record_status'])
        for attempt in sorted(starts | summaries.keys()):
            row = summaries.get(attempt)
            writer.writerow([attempt, args.source, row['seconds'] if row else '',
                             row['failures'] if row else '', row['invalid_transitions'] if row else '',
                             'summary' if row else 'missing-summary'])
    def seconds(value):
        return 'NOT TESTED' if value is None else f'{value:.3f} s'
    capture = 'PASS' if len(values) >= 20 and not incomplete and not orphaned else 'FAIL'
    def cell(value):
        return str(value).replace('|', '\\|').replace('\n', ' ')
    rows = [('기기', args.device), ('OS', args.os), ('빌드', args.configuration),
            ('커밋', args.commit), ('조건', args.scenario), ('소스 ID', args.source),
            ('로그', args.log), ('관측된 시도 수', len(starts | summaries.keys())),
            ('첫 프레임 관측 수', len(values)), ('종료 요약 없는 시도', len(incomplete)),
            ('시작 기록 없는 요약', len(orphaned)), ('첫 프레임 미관측 종료', no_frame),
            ('실패 이벤트가 있는 시도', failures), ('무효 상태 전이 수', invalid),
            ('p50 · nearest rank', seconds(percentile(values, .50))),
            ('p95 · nearest rank', seconds(percentile(values, .95))),
            ('최소 / 최대', f'{seconds(min(values) if values else None)} / {seconds(max(values) if values else None)}'),
            ('20개 관측·로그 완전성', capture), ('성능 목표 판정', 'NOT TESTED — 합의한 기준과 별도 비교 필요')]
    report = '# 실기기 첫 프레임 준비 시간 보고서\n\n| 항목 | 결과 |\n|---|---|\n'
    report += '\n'.join(f'| {cell(k)} | {cell(v)} |' for k, v in rows)
    report += '''\n\n## 측정 정의와 한계

- PlaybackModel.load()의 진단 시작부터 AVPlayerLayer.isReadyForDisplay 최초 관측까지.
- 실제 디스플레이 표시 시각이나 터치부터의 전체 지연, 첫 오디오 출력 시각이 아니다.
- 약 250ms polling에 스케줄링 지연이 더해질 수 있다. 기기/네트워크/캐시/빌드 조건을 함께 비교한다.
- p50/p95는 첫 프레임이 관측된 시도만 계산한다. 이후 실패한 시도도 시간 표본에는 포함한다.
- 미관측·실패·요약 누락을 0초로 대체하거나 숨기지 않는다. 재시도는 별도 attempt다.
- 동일 attempt의 같은 요약은 중복 제거한다. 로그에 전혀 남지 않은 시도는 발견할 수 없다.
- 20회는 초기 측정이며 p95의 안정성을 보장하지 않는다. 필요 시 같은 조건으로 표본을 늘린다.
- 로그 완전성 PASS는 성능/무오류 PASS가 아니다. 실패/미관측이 있으면 별도 조사한다.

## 결론 및 후속 조치

- 성능 목표: 미입력. 원본 과제 또는 합의한 p50/p95 기준을 기재할 것.
- 실패/누락 원인: 미작성.
- 재측정 및 개선 사항: 미작성.
'''
    (output / 'REPORT.md').write_text(report, encoding='utf-8')
    print('Report:', output / 'REPORT.md')
    print('Samples:', output / 'samples.csv')


if __name__ == '__main__':
    main()
