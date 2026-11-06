# 남은 실기기 확인 — 2026-11-06

로컬 DB, CI, 문서는 이번 변경에서 보완했다. 아래 세 가지는 구현·자동 검사만으로 완료 처리할 수 없는 실기기 확인이다. 영상을 새로 업로드할 필요는 없다.

## 준비

1. 최신 코드를 받은 뒤 **같은 `StreamLab.xcodeproj`**를 연다. 새 Scheme은 `StreamLab-C4-Scroll-C`, `StreamLab-C4-Scroll-PV`, `StreamLab-C4-Download-Energy`다.
2. 데이터 이전을 확인하려면 기존 앱을 삭제하지 않고 새 빌드를 설치한다. 이전 찜·최근 검색·이어보기 위치가 남는지 확인한다. 첫 접근에서 프로필별 JSON journal을 SQLite로 이전한다. 로그아웃은 로컬 기록을 삭제하므로 이전 확인 전에 누르지 않는다.
3. Xcode에서 기기를 선택한다. 성능 측정은 **Product → Profile**, 테스트용 오류 인수는 모두 끈다. 기기 모델·iOS·커밋·Wi-Fi/셀룰러·충전 연결 여부를 함께 적는다.

## 1. VoiceOver 전체 경로

Scheme `StreamLab-Firebase`, Run의 오류 주입 인수는 모두 끈다. 영어 자막 트랙을 확인한 공개 작품 **F10 영어 자막 HLS 샘플**을 사용한다. 일반 Apple HLS 연결 확인용 작품에는 필요한 자막 트랙이 없을 수 있다. iPhone의 설정 → 손쉬운 사용 → VoiceOver를 켠다.

화면을 직접 눌러 우회하지 않고, 한 손가락 좌우 쓸기로 이동하고 두 번 탭으로 선택한다.

1. 프로필을 선택하고 홈에서 작품 상세를 연다.
2. 영상 재생을 선택한다. 재생·일시 정지 버튼의 이름과 상태가 맞게 읽히는지 확인한다.
3. 자막 및 오디오 선택을 열어 영어 자막을 선택한다. `선택됨`이 읽히고 완료로 닫을 수 있어야 한다.
4. 재생 위치에서 위아래 쓸기로 탐색한다. 현재 시간과 전체 길이가 읽히는지 확인한다.
5. 일시 정지 → 닫기를 실행하고 상세 화면으로 돌아온다.

보낼 내용: `VoiceOver 전체 경로 PASS/FAIL`, 기기/iOS, 막힌 단계와 잘못 읽힌 문구. 자동 접근성 검사 통과는 실제 음성·초점 순서 확인을 대신하지 않는다.

## 2. 백그라운드 다운로드 전력

Scheme **`StreamLab-C4-Download-Energy`** → Product → Profile. Instruments에 **Power Profiler + Points of Interest**를 넣는다. Profile은 FirebaseRelease이며 `--trace-download-energy`가 켜져 있다.

- 기존 다운로드가 없는 Apple HLS 샘플을 사용한다. 다른 다운로드·영상 재생은 중단한다.
- Wi-Fi, 화면 밝기, 충전 연결 여부를 기록한다. 충전 연결 측정으로 배터리 소모량을 단정하지 않는다.
- iPhone 미러링·AirPlay는 끄고 실제 기기를 직접 조작한다.

| 순서 | 동작 | 확인할 앱 표식 |
|---|---|---|
| 1 | 홈에서 30초 대기 | 기준 구간 |
| 2 | 다운로드 시작 후 즉시 홈 제스처로 앱을 백그라운드로 보냄 | `DownloadTransferStarted`, `DownloadAppBackground` |
| 3 | 다운로드 완료 알림까지 대기 | `DownloadTransferCompleted` |
| 4 | 앱으로 돌아와 완료 목록에서 30초 대기 | `DownloadAppForeground` |
| 5 | 필요하면 파일 삭제 후 녹화 종료 | `DownloadDeleted` |

바탕화면에 **`c4-background-download-power-1.trace`**로 저장한다. 시작/백그라운드/완료 시간이 실제로 겹쳐야 유효하다. 너무 빨리 끝나면 그것을 숨기지 말고 알려 준다. 시스템 전송 데몬과 기기 전력도 포함해 해석하며 앱 프로세스 CPU만으로 에너지를 판단하지 않는다.

## 3. 같은 빌드에서 홈 스크롤 전후 비교

Scheme마다 빌드 코드는 동일하다. **C = 기존 포스터·인라인 홈**, **PV = 포스터 레이어·분리된 홈**이다. 현재 탭 구조와 SQLite는 두 조건에 똑같이 적용된다. 따라서 이 실험은 현재 코드에서 홈 렌더링 변경의 영향만 비교하며, 과거 모든 최적화의 효과를 합산하지 않는다.

Instruments의 **Animation Hitches + Points of Interest**를 사용한다. 프레임 표시 이벤트가 수집되는지 먼저 확인한다. CPU Profiler는 호출 스택을 추가로 볼 때만 같은 조건으로 함께 사용한다.

- 같은 iPhone·Wi-Fi·밝기·전원 연결, 저전력 모드 끔. 기기를 식힌 뒤 측정한다.
- iPhone 미러링·AirPlay 끔. 앱은 매번 종료한 뒤 새 프로세스로 시작한다.
- 별도 오류 주입·Firebase 인수를 추가하지 않는다. 같은 Mock 카탈로그와 같은 성인 프로필을 사용한다.
- 프로필 선택 후 **손으로 스크롤하지 않는다**. 홈 내용이 표시된 뒤 10초 준비 → 자동으로 30초 동안 5왕복 → 5초 대기 → 녹화 종료다.

| 순서 | Scheme | 바탕화면 파일 이름 |
|---|---|---|
| C1 | `StreamLab-C4-Scroll-C` | `c4-controlled-C1.trace` |
| PV1 | `StreamLab-C4-Scroll-PV` | `c4-controlled-PV1.trace` |
| PV2 | `StreamLab-C4-Scroll-PV` | `c4-controlled-PV2.trace` |
| C2 | `StreamLab-C4-Scroll-C` | `c4-controlled-C2.trace` |

각 측정 사이에 기기를 충분히 식힌다. `C4ScrollStart` → `C4ControlledScroll` → `C4ScrollEnd` 표식과 실제 표시 프레임이 있어야 한다. `C4ScrollCancelled` 또는 `C4ScrollUnavailable`이면 비교에 넣지 않는다. 시작·종료 로그에 왕복 거리, 열 상태와 저전력 상태가 기록된다. 두 조건의 거리가 다르거나 열 상태가 다르면 동등 조건이라고 쓰지 않는다.

분석은 **Instruments의 실제 화면 표시 시각**을 사용한다. CADisplayLink 콜백 횟수를 FPS로 대신 세지 않는다. p50/p95, hitch 수/시간, 초기 표시까지의 구간을 분리한다. 개선되지 않았으면 그대로 기록한다. 이 네 파일을 받기 전에는 전후 개선 완료로 표시하지 않는다.
