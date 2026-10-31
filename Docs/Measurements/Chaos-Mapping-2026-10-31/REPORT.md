# 과제 카오스 대응 보강

기준 812dc8f. [F01–F10 매핑](../../CHAOS_ACCEPTANCE.md)을 처음으로 실제 테스트 이름/계층/한계에 대응시켰다.

## 구현 및 실패 이력

- F01 정확한 5회 역순 홈 응답 테스트에서 중복 레일·카드·이어보기 항목 15개 불변식 실패를 재현했다. CatalogStore의 홈 수신 경계에서 각 컬렉션의 첫 ID만 유지하도록 수정했다. 서로 다른 추천 레일에 같은 작품이 나오는 것은 유지한다.
- F03 100건의 서버 ACK 유실 후 로컬/서버 영속 저장소 재구성 테스트를 추가했다. 실제 OS kill과 동일하다고 과장하지 않는다.
- 기존 프로필 전환 테스트를 isSeeking=true 경계로 강화했다.
- foreground 전환+cache purge 10회 후 동일 player 유지와 최종 model/player 약한 참조 해제 테스트를 추가했다. 최초 테스트 컴파일에서 Swift 6 경고를 발견하여 weak reference 보관 클래스로 수정했다. 경고 검증을 끄지 않았다.
- CI Core 작업을 실제 loopback HTTP/더미 Keychain 통합도 켜는 assignment wrapper로 교체했다. 기존 3종 chaos 및 신규 F01/F03 표식도 요구한다.

F06/F09/F10 복합 통합과 실제 OS 강제 종료/메모리 압박은 매핑 문서에서 미완료로 명시한다. 이번 결과를 전체 D 완료로 표시하지 않는다.

## 로컬 검증

- Core XCTest 31 + Swift Testing 222 + Catalog 7 = **260 PASS**, 통합 테스트 skip 없음. 실제 loopback HTTP와 고유 더미 Keychain 테스트 포함.
- 기존 3종 chaos 각각 seed 1~1000 PASS. F01/F03 필수 완료 표식 확인.
- iOS 패키지 **17 PASS**. 프로필 전환 중 seek 및 10회 foreground/cache purge 테스트 포함.
- 새 Core gate 8개, iOS gate 12개 정상/누락/실패 입력 검증 PASS. Core marker를 줄 시작에 고정해 DOMAIN CHAOS가 CHAOS 표식을 대신 만족시키지 못하게 했다.
- bash 문법, workflow YAML 구문, git diff 공백 검사 PASS.
- 원시 로그는 ignored Docs/Validation에 보관하며 MANIFEST.json에 SHA-256 기록.
- Release iOS Simulator 빌드 PASS (warnings-as-errors 유지, 서명 없음).

## 원격 CI 1차

`f0fbfa6`, run 41174798707의 Core는 테스트 전에 auth fixture 준비 제한(5초)으로 실패했다. artifact의 auth-server.log에는 Python 예외가 없었으며, 최초 로그만으로 import/DNS/스케줄링 중 어느 부분이 지연됐는지는 식별할 수 없다. 준비 예산을 30초로 늘리고 unbuffered 출력과 살아 있는 프로세스/조기 종료 진단을 추가했다. HTTP 요청·재시도 제한은 변경하지 않았다. 이 실패를 테스트 통과로 계산하지 않는다.
