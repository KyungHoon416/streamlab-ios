# SwiftUI Phase 1 수동 검증

새 SwiftUI 기준 전 항목 **NOT TESTED**. [UIKit 이력](Archive/UIKIT_PHASE1_MANUAL_QA.md)은 별도다.
Git SHA / Xcode / 기기 / iOS / 날짜 / 결과·증거를 기록한다.

## 기능·접근성

1. 세 프로필 각각 선택, Kids는 ALL/7+만 표시. 검색/상세 진입.
2. 홈 5개 레일·계속 시청 → 상세 → 기본 뒤로가기/edge-swipe. swipe 취소도 확인.
3. 검색 24 → 더 보기 48 → 상세/탭 왕복 후 48 유지.
4. 느린 Debug Mock에서 중앙 HUD, 재시도 비활성화. 요청 중 프로필 변경 후 이전 데이터/HUD 미노출.
5. VoiceOver 프로필 → 홈 → 검색 → 더 보기 → 상세 → Phase 2 안내 → 닫기 → 뒤로 → 프로필. 초점·로딩 안내 확인.
6. 최대 글자에서 프로필/히어로/레일/검색/상세/로딩/버튼 잘림·겹침 확인.
7. Reduce Motion, 고대비, 작은 iPhone/iPad 회전 시 정보 손실 없는지 확인.
8. 페이지 로딩 중 백그라운드 → 복귀 시 페이지 보존·중복 없는 재개.

## Instruments

1. 느린 Mock 인자 제거, Product > Profile로 Release 실행. 이전 UIKit trace와 별도 저장.
2. 홈/검색/상세 예열 후 홈 10초, 기준 generation 기록.
3. 홈 → 상세 → 뒤로 20/40/60회. 구간별 홈 10초 대기 후 persistent bytes, CatalogScreenModel/CatalogStore를 기록.
4. 검색 로딩 중 프로필 전환 10회. 이전 세션/Store 누적 여부, Memory Graph 참조 경로 확인.
5. Leaks 결과 또는 수집 실패를 기록. 빈 이름 검색을 전체 누수 0건으로 판정하지 않는다.
6. SwiftUI View는 값 타입. DetailViewController 대신 모델/Store 수명과 참조를 확인한다.
7. 스크롤 frame time p50/p95는 별도 계측하고 기기/OS/조건을 기록한다.

## 자동 검증

./scripts/verify-mac.sh 및 ./scripts/check-runtime-mac.sh.
60회 UI 이동은 누수 측정이 아니다. glassEffect 발생 시 동작과 runtime-diagnostics.txt를 제출한다.
