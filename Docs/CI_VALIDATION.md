# GitHub Actions 검증

## 이번 보완의 실행 경로 — 2026-11-06

[실행 42239749042](https://github.com/KyungHoon416/streamlab-ios/actions/runs/42239749042), 앱 `9a4d395`의 네 job 모두 성공했다. Core·재생·앱 UI는 attempt 1, native 다운로드는 attempt 2다. Core 31+247, chaos 각 1,000 seed, SIGKILL 100건, iOS 재생 25, 앱 UI 9, 네이티브 HLS 3 및 Release 빌드를 확인했다. 새 runner·새 simulator의 빌드/Mock 로그인/재생 smoke는 **424초**다. 로그·환경·해시는 [증빙](Measurements/Final-Gaps-2026-11-06/evidence.json)에 기록했다.

`ios-app-acceptance`는 README와 같은 스크립트로 새 시뮬레이터에서 빌드·로그인·재생 시간을 기록하고 SQLite 저장/프로필/접근성/자동 스크롤 9개를 실행한다. `ios-native-downloads`는 별도 runner·시뮬레이터에서 F06/F09와 정상 HLS 다운로드 3개를 실행한다. [현재 실행 결과](Measurements/Final-Gaps-2026-11-06/REPORT.md). 실제 VoiceOver·물리 기기 전력·표시 프레임은 별도이며 자동 CI 통과로 대신하지 않는다.

## 제출 버전에서 확인한 실행 - 2026-11-06

- 앱: [실행 42156350319](https://github.com/KyungHoon416/streamlab-ios/actions/runs/42156350319), `04bb9854351240b66cb5040ec648de14c02d5111`, 두 job 성공. Core XCTest 31개와 Swift Testing 243개, 카오스 3종 각 1,000시드, F03 SIGKILL 복구, TTFF 집계 6개, iOS 패키지 25개, 서명 없는 Release 빌드 통과.
- 관리자: [실행 41415755215](https://github.com/KyungHoon416/streamlab-ios/actions/runs/41415755215), `33f45dc60c5d55c42d25f7df584339363ddb8fce`, 단위 테스트·웹 빌드·Firestore/Storage 규칙 성공. 이후 관리자 코드·규칙·관련 workflow는 동일함을 diff로 확인했다.
- 제출 태그 `submission-2026-11-06`은 앱 코드가 같은 문서 후속 버전이다. 문서 전용 변경에는 새 CI가 실행되지 않으므로 태그 커밋 자체에 새 실행이 성공했다고 주장하지 않는다. [제출 기록](SUBMISSION_RECORD.md).

`.github/workflows/validation.yml`은 main push, pull request, 수동 workflow_dispatch에서 실행한다. 문서만 바뀐 push/PR은 제외한다. 문서 전용 PR의 필수 체크로 이 workflow를 지정하면 대기 상태가 될 수 있으므로 별도의 항상 실행되는 gate 없이 필수 체크로 지정하지 않는다. 브랜치 보호 설정은 변경하지 않는다.

## 자동 실행 범위

| 작업 | 범위 | 시간 제한 |
|---|---|---|
| core-chaos | Core 전체 및 loopback HTTP/더미 Keychain, durable queue/domain conflict/virtual clock retry 각각 seed 1~1000, TTFF parser 6개, F03 SIGKILL 복구 | 20분 |
| ios-app-acceptance | 새 iPhone simulator·초기 빌드/실행 600초 gate, 앱 UI 9개 | 30분 |
| ios-native-downloads | 새 iPhone simulator·실제 HLS F06/F09 및 정상 다운로드 3개 | 30분 |
| ios-playback | 가용 iPhone simulator 자동 선택, 재생·권한·회전 콜백 25개, 서명 없는 Release 빌드 | 30분 |

동일 ref의 새 실행이 생기면 오래된 실행을 취소한다. macos-26의 기본 Xcode를 사용하며 실제 버전을 environment.txt에 기록한다. 로컬 Xcode 27과 CI 기본 Xcode가 같다고 가정하지 않는다. Xcode 26.6의 패키지 경고 억제 기본값과 warnings-as-errors가 충돌하지 않도록 SWIFT_SUPPRESS_WARNINGS=NO를 명시한다. 경고 검증을 끄지 않는다. 공식 액션은 확인한 v6 commit SHA에 고정했다. contents: read만 부여하고 checkout 자격 증명은 보관하지 않는다. 배포·릴리스·실기기 설치·서명 인증서/비밀키 업로드는 하지 않는다.

실패해도 `core-chaos-<run>-<attempt>`, `ios-playback-<run>-<attempt>`, `ios-app-acceptance-<run>-<attempt>`, `ios-native-downloads-<run>-<attempt>` artifact로 로그/RESULTS/environment를 14일 보관한다. 앱 UI 또는 네이티브 다운로드 job 실패 시에는 `ios-app-failure-xcresult-*` / `ios-native-failure-xcresult-*`에 화면·계층·진단이 담긴 xcresult도 보존한다. 전체 DerivedData는 업로드하지 않는다. artifact 보존 기간 뒤에는 지워질 수 있으므로 제출용 근거는 별도 요약 보고서에 기록한다.

## 사용법

GitHub 저장소 → Actions → StreamLab validation에서 실행/결과를 확인한다. 수동 실행은 Run workflow → main. 실패 job의 첫 실패 step과 artifact RESULTS.txt를 확인한다. 도구 실패/필수 테스트 누락은 PASS로 처리하지 않는다. 대기/계정 제한은 테스트 통과가 아니다.

로컬 재현:

```bash
bash scripts/check-assignment-core-mac.sh
python3 scripts/test-ttff-summary.py
bash scripts/check-playback-session-lifecycle-mac.sh
bash scripts/check-submission-app-mac.sh
bash scripts/check-download-combined-mac.sh
```

카오스 개별 재현은 `STREAMLAB_CHAOS_SEED=42 bash scripts/check-assignment-core-mac.sh`. CI 기본값은 세 suite 모두 1000개 seed다.

## 미포함 범위

F01~F10의 자동화 가능한 범위는 Core/패키지/네이티브 UI로 나누어 실행한다. 앱의 모든 화면·실제 VoiceOver·운영 DRM·실기기 전력/프레임/메모리는 이 workflow에 포함되지 않는다. 25개는 패키지의 iOS 플레이어 테스트이며 앱 UI 테스트가 아니다. 이번 CI 구성을 과제 전체 통과로 표시하지 않는다.

공식 runner 기준: https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md

외부 Apple HLS가 필요한 F06/F09 UI 및 정상 다운로드 재생 회귀 3개는 `bash scripts/check-download-combined-mac.sh`로 로컬 및 새 CI job에서 실행한다. 외부 샘플이 실패하거나 테스트가 건너뛰어지면 PASS가 아니다. CI 패키지 25개의 F09 권한 경계·F10 콜백 순열과 네이티브 전송 UI의 근거는 구분한다.

다운로드 복합 스크립트는 다른 계정의 고정 파일이 기기 전체 예산에 영향을 주므로 기본적으로 전용 시뮬레이터를 생성·정리한다. 명시적 `SIMULATOR_ID` 사용 시 해당 기기는 삭제하지 않는다.

F03 프로세스 검증은 `bash scripts/check-mutation-process-crash-mac.sh`로 실행한다. 별도 macOS 실행 파일이 고유 임시 폴더의 더미 100건만 사용하며 부모가 자신이 만든 자식만 종료한다. 준비 표식·SIGKILL 종료 코드·재실행 결과 표식이 모두 있어야 PASS다. iOS 앱에는 이 도구를 연결하지 않는다.

프로필 전환 UI 5개는 `bash scripts/check-profile-boundaries-mac.sh`로 로컬 실행한다. F04의 탐색 완료 처리 보류 중 닫기→B 프로필→새 재생을 포함한다. 이 독립 5개 suite 전체를 새 Actions에 추가한 것은 아니다. F04와 찜·검색 경계는 새 앱 인수 스크립트에도 포함해 원격 실행하며 나머지는 기존 로컬 근거를 따른다.
