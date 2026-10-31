# 프로필 전환·키즈 접근·이전 화면 상태 회귀

기준 c16260a. 로그인/잠금 복귀 실기기 확인 후 운영 서버 없이 진행 가능한 프로필 경계 검증을 선택했다. 새 기능의 전체 구현이나 과제 전체 완료를 주장하지 않는다.

## 검증 구성

- 검색 24→48개 로드 후 성인→키즈 변경: 검색어 초기화·키즈 결과 확인.
- 느린 추가 페이지 로딩 중 프로필 변경: 이전 로딩 표시 제거와 키즈 결과 확인.
- 탭 상세 경로: 탭 왕복에서는 유지하고 프로필 다시 선택 시 초기화.
- 느린 재생 승인 흐름에서 닫기/키즈 재열기: 재생 가능 및 이후 프로필 전환 시 재생 화면 잔존 없음.
- Core 카탈로그: 제한 콘텐츠를 키즈가 ID로 직접 조회해도 nil, 홈/검색/페이지네이션 및 진도 격리.

기존 테스트를 현재 코드에서 재실행한다. UI의 느린 응답은 4초 Mock 지연이며 실제 서버/DRM 권한과 다르다. UI 테스트만으로 모든 네트워크 타이밍이나 취소 불응 응답 순서를 증명하지 않는다. 화면에서 확인한 키즈 행과 전체 데이터 직접 ID 차단의 근거를 분리한다.

## 실행 방법

`bash scripts/check-profile-boundaries-mac.sh`

데모 로그인에 필요한 ad-hoc 서명을 유지하고 4개 필수 테스트 각각의 passed 및 xcodebuild exit 0을 확인한다. Core 카탈로그는 `swift test --package-path Packages/StreamLabCore --filter MockCatalogRepositoryTests`로 별도 실행한다. 원시 결과는 로컬 Docs/Validation에, 요약/해시는 이 폴더에 보존한다.

## 남은 범위

운영 서버 권한·TLS·DRM, 실제 HLS, 실제 여러 기기 계정 동기화, 전체 UI 회귀/과제 F01~F10 종합 매핑은 별도다. 추가 trace 수집을 요구하지 않는다.

## 결과

- UI 4개 PASS, Core 카탈로그 7개 PASS. 앱 결함은 발견되지 않아 런타임 코드는 변경하지 않았다.
- ad-hoc 서명한 simulator 앱과 warnings-as-errors 빌드로 검증했다. 원시 UI/Core 로그에 컴파일 warning/error 행 없음.
- 새 스크립트 결과 판정 6개 확인 PASS: 정상 결과, 테스트 명령 비정상 종료, 필수 테스트 각각 1개 누락. bash 문법/diff 검사 PASS.
- 전체 원시 로그/xcresult는 Docs/Validation/profile-boundaries-8g2K2Y/에 보존했다. 본 결과는 해당 시나리오의 로컬 회귀 증빙이며 모든 프로필 보안 경계의 완전한 증명은 아니다.
