# 앱 인증 연결과 실기기 잠금 검증 준비

2026-10-31. 기준 커밋 662f8a1. 운영 서버 없이 데모 계정의 실제 앱 화면 → CatalogAccount → AuthenticationSession/KeychainTokenStore 연결을 검증한다. 실제 서버 로그인/갱신 endpoint 검증은 아니다.

## 이번 변경

- 앱 루트에 `--diagnose-keychain-lock`가 있을 때만 표시되는 Debug 전용 진단 화면을 추가했다.
- 고정된 전용 서비스/계정의 더미만 사용하고 실제 계정 토큰은 읽거나 변경하지 않는다. 매번 시작 시 이전 중단으로 남은 더미를 먼저 정리한다.
- 잠금 전 저장/읽기 → protected data unavailable 중 Keychain -25308 → 해제 후 동일 값 읽기 → 삭제 후 nil을 모두 확인한 경우에만 PASS로 표시한다.
- 잠금 미관측, 백그라운드 시간 만료, 취소, 저장소 오류, 정리 실패는 미판정으로 남긴다. 시뮬레이터의 결과는 실제 잠금 보호 PASS로 취급하지 않는다.
- 중단/화면 닫힘에도 취소되지 않은 정리 작업으로 더미 삭제를 시도한다. 강제 종료 후에는 다음 진단 시작에서 정리한다.
- 기존 로그인 UI 검증 스크립트에 오프라인 변경 로그아웃 정리와 진단 시작·중단·재시작을 추가했다.

## 자동 검증

iPhone 17 Pro / iOS 26.4 simulator에서 **5개 UI 테스트, 실패 0개**로 종료했다. 앱 로그인 연결 결함은 발견되지 않았다. 결과는 RESULTS.txt와 MANIFEST.json에 기록했다. iOS simulator의 로그인/복원/로그아웃, 모든 프로필 정리, 미전송 변경 정리를 실제 화면 조작으로 검사한다. 잠금 진단 UI 회귀는 시작과 중단/정리 두 번을 확인하며 잠금 자체를 시뮬레이션하지 않는다.

실기기용 Release 컴파일 빌드(서명 없음)도 PASS했다. Debug 앱 서명 검증 exit 0, warnings-as-errors 빌드와 bash 문법/diff 검사 PASS. Debug 바이너리에 진단 심볼이 있고 Release에는 없는지 별도로 검사해 일반 배포 코드에 진단이 들어가지 않았음을 확인했다(Debug 진단 심볼 201개, Release 0개).

## 남은 실기기 확인

[순서와 결과 전달 방법](DEVICE_CHECK.md)을 따른다. Instruments/trace 없이 결과 화면 캡처와 기종/iOS 버전으로 확인한다. 자동 검증 당시 실기기 잠금 보호는 미판정이었다. 이후 사용자 PASS 확인은 아래 후속 확인에 기록했다.

기본 정책은 WhenUnlockedThisDeviceOnly를 유지한다. 인증정보의 메모리 사본을 잠금마다 삭제하거나 다운로드 전체를 중단하는 기능을 추가한 것은 아니다. 앱 재시작이 잠금 상태에서 OS에 의해 이루어지는 경우, 재부팅 후 첫 잠금 해제 전 상태, 운영 서버/TLS는 이번 범위 밖이다.

## 재현

`bash scripts/check-demo-authentication-mac.sh`

로컬 원시 UI 로그/xcresult/서명 기록은 Docs/Validation/demo-authentication-hx96mF/에 보존한다. Release 빌드 로그는 /private/tmp/streamlab-auth-lock-release.log에 있으며 Git에는 요약과 해시를 남긴다.

보조 OSLog 수집은 대상 simulator가 종료된 상태여서 exit 149로 수집하지 못했다. 따라서 OSLog에 인증 오류가 없었다고 주장하지 않는다. 위 PASS의 근거는 5개 개별 UI 테스트 결과와 xcresult이며 원시 UI 로그에 보존했다.

## 실기기 후속 확인 — 2026-10-31

사용자가 최신 코드를 받은 뒤 실기기 잠금 진단에서 PASS를 확인했다고 보고했다. 진단의 잠금 중 읽기 거부·해제 후 동일 값 복구·더미 삭제 확인을 **사용자 보고 기준 완료**로 갱신한다. 별도 캡처/원시 로그와 이번 확인의 기종·OS 버전은 제공되지 않았다. 기존 시뮬레이터 자동 검증과 증거 출처를 구분한다. 잠금 상태 cold launch나 운영 서버 인증까지 완료한 것은 아니다.
