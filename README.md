# StreamLab

프로필별 스트리밍·오프라인 재생과 오프라인 우선 데이터 동기화를 검증하는 iOS 과제 앱입니다. Swift 6 / iOS 18 이상이며 SwiftUI 화면과 UIKit·AVFoundation 플레이어를 사용합니다. 운영 인증·DRM은 Mock이고, Firebase 카탈로그는 선택 기능입니다.

## 처음 실행하기

Xcode 26 이상과 iOS Simulator 런타임이 설치된 Mac을 전제로 합니다. Xcode 설치 시간과 실기기 서명 계정 준비는 10분 재현 범위에서 제외합니다. 별도 CocoaPods·Firebase 계정·XcodeGen 설치 없이 커밋된 프로젝트를 사용합니다.

```sh
git clone https://github.com/KyungHoon416/streamlab-ios.git
cd streamlab-ios
open StreamLab.xcodeproj
```

1. Scheme **StreamLab**, 실행 대상 **iPhone Simulator**를 선택하고 ⌘R을 누릅니다.
2. ‘데모 로그인’ → 성인 A 프로필 → 홈 작품 상세 → ‘데모 재생’을 선택합니다. 인터넷 없이 번들 테스트 영상과 데모 자막을 확인할 수 있습니다.
3. 찜·검색·이어보기는 SQLite에 먼저 저장됩니다. 앱을 종료하고 같은 프로필로 다시 열어 기록을 확인합니다. 로그아웃은 해당 계정의 모든 프로필 기록을 지우므로 보존 확인 중에는 사용하지 않습니다.
4. HLS·백그라운드 다운로드는 인터넷이 필요합니다. 아래 Apple 테스트 URL만 연결하며 외부 서버 실패를 앱 테스트 성공으로 처리하지 않습니다.

실기기는 대상 iPhone을 고른 뒤 Signing & Capabilities에서 자신의 Team을 지정합니다. Firebase 카탈로그는 **StreamLab-Firebase** Scheme으로 실행합니다. 기본 StreamLab의 Mock 재현에는 관리자 계정이나 비공개 설정 파일이 필요 없습니다. 프로젝트가 예전 상태로 보이면 `git status --short`로 로컬 변경을 확인하고 `git pull --ff-only --no-rebase origin main`으로 갱신합니다. 로컬 변경을 강제로 지우지 마세요.

## 테스트와 10분 재현 기록

```sh
# Core/실제 loopback HTTP/더미 Keychain/3종 1000 seed/강제 종료 복구
bash scripts/check-assignment-core-mac.sh
# 새 시뮬레이터 빌드·실행 시간 + 앱 저장/접근성/프로필 경계
bash scripts/check-submission-app-mac.sh
# 외부 HLS를 사용하는 F06/F09 복합 및 정상 오프라인 재생
bash scripts/check-download-combined-mac.sh
# iOS 패키지의 재생·권한·F10 콜백 순열
bash scripts/check-playback-session-lifecycle-mac.sh
```

앱 재현 스크립트는 자신이 생성한 시뮬레이터만 정리하고, 실제 실행한 테스트 이름과 소요 시간을 `Docs/Validation/submission-app-*/RESULTS.txt`에 남깁니다. 초기 빌드·로그인·재생 2개 smoke 테스트가 600초 이상이면 실패합니다. 후속 경계 테스트는 별도 시간입니다. 한 Mac의 성공을 모든 Mac에서 10분 보장으로 확대하지 않습니다. [CI 범위·결과](Docs/CI_VALIDATION.md).

장애를 수동으로 확인하려면 Debug의 Edit Scheme → Run → Arguments에서 다음 중 **하나만** 켭니다. 확인 후 모두 해제합니다. `--ui-test-…` 인수는 검증용입니다.

| 인수 | 동작 |
|---|---|
| `--ui-test-entitlement-expired-once` | 첫 재생 권한 만료, 수동 재시도는 정상 권한 |
| `--ui-test-entitlement-offline-expired` | 저장 영상 권한 만료와 갱신 불가, 유한 재시도 |
| `--ui-test-download-lifecycle` | 다운로드 검증 버튼·상태 노출 |

## 구조와 정책

- Domain: 프로필·진도·다운로드 모델과 충돌/예산/상태 전이 정책.
- Presentation: MainActor 저장소, 취소·인증 경계, SQLite projection/outbox 트랜잭션. [DB 이전 ADR](Docs/ADR/0030-sqlite-local-projection-outbox.md).
- CatalogData: 2,000개 Mock fixture와 선택 가능한 Firebase 공개 카탈로그.
- UI: 홈/상세/검색/다운로드, AVPlayer와 네이티브 HLS/MP4 전송 연결.

다운로드는 계정·프로필별로 격리합니다. 기기 전체 예산 1GB·동시 작업 2개·고정 보호/LRU·과제용 7일 만료가 있으며 실제 DRM은 아닙니다. 관리자 원본 업로드 한도 5GB는 이 오프라인 예산과 별개입니다.

[최신 아키텍처 다이어그램](Docs/Architecture/ARCHITECTURE_DIAGRAMS_2026-11-06.md) · [Player 상태도](Docs/States/PLAYER.md) · [Download 상태도](Docs/States/DOWNLOAD.md) · [상세 아키텍처](Docs/ARCHITECTURE_CURRENT.md) · [ADR](Docs/ADR) · [F01–F10 대응표](Docs/CHAOS_ACCEPTANCE.md)

## 샘플 URL·출처·사용 범위

| 데이터 | URL / 로컬 경로 | 출처와 사용 범위 |
|---|---|---|
| 기본 테스트 영상·자막 | `Packages/StreamLabUI/Sources/StreamLabCatalogFeature/Resources/playback-demo.mp4`, `playback-demo-{ko,en}.srt` | 이 프로젝트에서 직접 생성한 테스트 패턴·안내 자막. 저장소의 실행·테스트·과제 시연에 사용. 외부 영화/음원 없음 |
| 합성 작품·포스터 | Core CatalogData의 `catalog.json`, `scripts/generate-artwork-fixtures.py` | 합성 작품 2,000개와 코드로 생성한 포스터. 실제 영화 라이브러리 아님 |
| Apple Bip Bop 기본 | [HLS](https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8) | Apple 개발자 스트리밍 예제, 기능 검증 목적으로만 연결 |
| Apple Bip Bop 일반 음성 | [HLS](https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8) | 일반 음성/트랙 대체 검증 |
| Apple 고급 음성·자막 | [HLS](https://devstreaming-cdn.apple.com/videos/streaming/examples/adv_dv_atmos/main.m3u8) | 음성 역할·자막·HLS 회차 검증 |

외부 샘플의 제공자는 Apple입니다. [공식 예제 안내](https://developer.apple.com/streaming/examples/)와 [Apple 사이트 이용약관](https://www.apple.com/legal/internet-services/terms/site.html)을 확인합니다. 공개 URL은 상업 서비스의 재배포·재판매 허가를 의미하지 않습니다. 저장소는 외부 영상 바이너리를 재배포하지 않으며 네이티브 오프라인 저장은 개발 테스트 범위입니다. 각 과거 URL에 별도의 포괄적 재배포 허가가 확인됐다고 주장하지 않습니다. 외부 샘플을 사용할 수 없으면 기본 번들 데모로 실행하고, 외부 HLS 전용 검증은 미실행/실패로 기록합니다.

Firebase 관리자가 올린 4K·장시간 영상은 과제 기본 재현 자료에 포함하지 않습니다. 해당 영상의 이용·공개 권한은 업로더가 확인해야 하며, URL 토큰이나 개인 원본 파일을 제출 저장소에 넣지 않습니다.

## 제출과 남은 확인

[현재 완료·잔여 점검](Docs/ASSIGNMENT_AUDIT_2026-11-06.md) · [이번 보완 결과](Docs/Measurements/Final-Gaps-2026-11-06/REPORT.md) · [실기기 마무리 순서](Docs/FINAL_DEVICE_QA.md)

[C4 성능 보고서](Docs/Measurements/C4-2026-10-31/REPORT.md)는 측정값과 전후 개선 입증을 구분합니다. VoiceOver 실제 조작과 백그라운드 다운로드 전력은 자동 UI 테스트로 대신하지 않습니다.

[기존 제출 기록](Docs/SUBMISSION_RECORD.md)의 `submission-2026-11-06` 태그·영상·PDF는 당시 스냅샷입니다. 이후 변경을 반영한 새 제출 버전으로 표시하지 않습니다. 이전 날짜별 README 기록은 [이력 문서](Docs/History/README-before-final-audit-2026-11-06.md)에 보존했습니다.
