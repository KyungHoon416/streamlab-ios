# ADR 0023 — 비동기 이미지 파이프라인

상태: 구현, Mac 검증 대기 (2026-10-16)

## 데이터 및 UI

CatalogTitle에 optional artworkURL을 추가하여 기존 2,000개 JSON과 호환한다.
URL이 없으면 visualSeed로 6개 자체 PNG Fixture를 재사용한다. 실제 작품 포스터는 아니다.
scripts/generate-artwork-fixtures.py로 같은 PNG를 재생성할 수 있다.
홈/추천/검색/상세/회차의 기존 CatalogArtwork 호출이 모두 같은 파이프라인을 사용한다.
장식용 이미지의 VoiceOver 숨김과 제목 라벨, 기존 레이아웃 크기를 유지한다.

## 비동기 및 메모리

ArtworkDataCache actor: URL 키, 원본 16MiB LRU, 건당 8MiB. 중복 요청은 continuation별
구독자를 등록하고 하나의 loader Task만 실행한다. 개별 취소는 자기 continuation만 종료한다.
마지막 구독자 취소 시 loader Task 취소와 generation 제거. 취소를 무시하는 loader의 늦은
완료도 새 요청/캐시를 덮지 못한다. 실패와 빈 payload/크기 초과는 저장하지 않는다.

ArtworkLoader: 번들 파일 읽기는 detached 작업, HTTPS는 status/MIME/크기를 검사하며
URLSession byte stream을 최대 8MiB까지만 누적한다. timeout은 20초다.
이미지를 위한 임의 HTTP 예외나 인증 토큰은 추가하지 않는다.

ArtworkPipeline actor: ImageIO 최대720px 디코딩, 24MiB LRU, CGImage immutable wrapper만 전달.
SwiftUI MainActor task는 URL/UUID/cancellation을 확인한 뒤 반영한다. 이탈 시 view의 참조를 해제한다.
캐시 한도는 전체 메모리 상한이 아니며 URLSession/화면 참조/디코딩 임시 할당은 별도다.
로컬 동기 파일 읽기는 실행 도중 중단할 수 없으나 취소된 결과는 UI에 반영하지 않는다.
디스크 캐시/인증 이미지/TTL/네트워크 동시성 제한은 이번 범위에 포함하지 않는다.

## 검증

Core5: LRU 예산, 같은URL 공유와 단일구독 취소, 마지막구독 취소와세대역전,
빈/과대 응답, 오류 재시도. 제어된 continuation으로 네트워크 없이 검증한다.
check-artwork-mac.sh는 Core 전체와 기존 화면/플레이어 smoke UI 테스트를 실행한다.
이미지 픽셀 표시 검증을 자동화했다고 주장하지 않는다. 수동으로 홈/검색/상세 포스터,
비행기 모드의 번들 이미지, 빠른 스크롤·왕복 시 이미지 섞임/메모리를 확인한다.
현재 환경에 Swift/Xcode가 없어 신규 Core/UI는 NOT TESTED.
