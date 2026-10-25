# 실기기 재생 품질 측정 절차 (TTFF 대리지표·재버퍼링)

## 정의

이 프로젝트의 first_frame_ready_seconds는 PlaybackModel.load() 진단 시작부터
AVPlayerLayer.isReadyForDisplay 최초 관측까지의 시간이다. 버튼 터치부터의 전체 지연,
첫 소리 시각, 실제 디스플레이 표시 시각과 구분한다. 약 250ms polling에 스케줄링 지연이
추가될 수 있다. 보고서 명칭은 '첫 프레임 준비 시간(TTFF 대리지표)'으로 쓴다.
Apple 정의: https://developer.apple.com/documentation/avfoundation/avplayerlayer/isreadyfordisplay

## 준비

1. 최신 main을 받고 실기기에 빌드한다. 측정 커밋, 아이폰 모델, iOS 버전을 기록한다.
2. 제출용 비교는 Release 구성에서 Instruments 없이 한다. Xcode Edit Scheme의 Run 구성을
   Release로 선택하고 Debug executable을 해제한다. 개발자 서명 설정은 기존 실기기 설정을 쓴다.
   Debug/디버거 연결 측정도 가능하지만 별도 탐색 결과로 기록하고 Release와 섞지 않는다.
3. Mac의 Console(콘솔) 앱에서 연결한 아이폰을 선택해 로그 스트리밍을 시작한다.
   StreamLab의 PlaybackQoE 로그를 수집한다. Xcode 콘솔을 사용했다면 디버거 연결 여부를 기록한다.
4. 고정된 Wi-Fi, VPN 상태, 전원/저전력 상태, 기기 발열을 기록한다. 이 조건을 측정 도중 바꾸지 않는다.
5. 같은 프로필/작품/소스/이어보기 조건을 유지한다. warm 반복과 cold 앱 재실행을 분리한다.
   앱 재실행은 CDN/OS 캐시 제거를 뜻하지 않는다. 캐시 cold라고 단정하지 않는다.

## 첫 측정: 같은 앱 세션에서 HLS 20회 반복

1. 상세 → 데모 재생 → 소스 'HLS 스트리밍'을 선택한다.
2. 첫 영상이 나오면 약 5초 후 플레이어 X로 닫는다. 이렇게 해야 summary가 기록된다.
3. 1~2를 20회 반복한다. 재시도/오류도 기록하고 성공한 시도만 골라내지 않는다.
4. 자동 PiP/Home/화면 잠금/언어 변경/시킹은 이 측정과 섞지 않는다.
5. 최초 로컬 데모 재생 로그도 생기지만 source=apple-bipbop-v1 필터가 분리한다.
   이 절차는 소스 load부터이며 로컬 데모 선택/화면 진입 시간은 포함하지 않는다.
6. 마지막 플레이어도 닫고 attempt_started 및 summary가 포함된 일반 텍스트 로그를 보관한다.
   summary만 필터하면 시작 누락 판정이 난다. .logarchive는 직접 입력하지 말고 메시지를 텍스트로 내보낸다.
7. 재시도 등으로 실제 시도 수가 20회를 넘으면 그대로 보고한다. 로그 완전성 확인은 기록된 시도에 한정된다.

로그 예시 형식(실측 결과 아님):
```
attempt_started attempt=<UUID> source=apple-bipbop-v1
summary attempt=<UUID> source=apple-bipbop-v1 first_frame_ready_seconds=<seconds> rebuffer_count=0 rebuffer_seconds=0 failures=0 invalid_transitions=0
```

## 보고서 생성

아래 환경값은 실제 값으로 교체한다. 동일 디렉터리의 기존 보고서는 덮어쓰지 않는다.
```bash
python3 scripts/summarize-ttff.py \
  --log /path/to/qoe-device.log \
  --source apple-bipbop-v1 \
  --device '실제 아이폰 모델' --os '실제 iOS 버전' \
  --configuration 'Release, debugger detached' \
  --scenario 'Wi-Fi, same app session, 20 attempts, resume enabled' \
  --commit "$(git rev-parse HEAD)" \
  --output-dir "Docs/Validation/ttff-$(date +%Y%m%dT%H%M%S)"
```
REPORT.md와 samples.csv가 생성된다. p50/p95는 nearest-rank 방식이며, 20개면 정렬한
10번째/19번째 값이다. percentile 계산 방식을 다른 보고서와 통일한다.
실패/첫 프레임 미관측/시작 또는 종료 누락은 별도로 기재한다. 목표치가 없으므로 자동 성능 PASS는 없다.

## 추가 측정

앱 재실행 조건, 다른 Wi-Fi/셀룰러 조건을 각각 별도 파일로 20회 측정한다.
20회는 초기 표본이며 p95 신뢰도를 보장하지 않는다. 먼저 이 조건의 결과를 보고 추가 표본을 결정한다.
2026-10-25 실기기 HLS 22회 수집·집계 완료: [결과](Measurements/HLS-2026-10-25/REPORT.md).
측정 완전성 PASS이며 성능 목표 판정과 C4 전체 검증 완료를 뜻하지 않는다. 예시 데이터는 실측으로 사용하지 않는다.

## 재버퍼링 집계와 로그 완전성

보고서는 재버퍼링 총 횟수·누적 대기 시간, 발생 시도 비율, 시도별 누적 대기 시간 p50/p95와
실패 시도 비율을 함께 계산한다. 초기 로딩과 seeking에서 바로 buffering으로 바뀌는 구간은 제외한다.
재버퍼링 percentile은 사건 하나의 길이가 아닌 시도별 합계이며, 관측된 0초도 포함한다.
종료 요약이 없는 시도의 성공/실패는 추정하지 않는다. 전체 재생 시간 대비 비율은 제공하지 않는다.

5초 재생 반복은 첫 프레임 측정에 적합하지만 장시간 재버퍼링 품질을 대표하지 않는다.
재버퍼링을 비교할 때는 별도 로그로 재생 길이와 네트워크 조건을 고정해 기록한다.

- 재버퍼링 필드가 모두 없는 구버전 로그는 누락으로 표시하고 CSV 셀은 비운다.
- 필드가 하나만 있거나 음수/비유한 값, 서로 다른 중복 요약은 입력 오류로 거부한다.
- `--require-complete`를 추가하면 보고서 생성 후 불완전한 수집에 종료 코드 2를 반환한다.
  첫 프레임 20개 이상과 시작/종료/재버퍼링 지표 누락 없음만 확인한다. 성능 합격 검사가 아니다.
- 원본 SHA-256을 기록해 입력 파일을 식별한다. 기기·조건은 사용자가 정확히 입력해야 한다.
- 집계 도구 자체 검증: `python3 scripts/test-ttff-summary.py` (합성 로그 사용).
