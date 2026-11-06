# 0030 — 로컬 projection과 전송 큐를 SQLite에 함께 커밋

2026-11-06. B1의 로컬 DB 요구에 맞춰 기존 JSON journal 저장을 SQLite로 바꾼다. 찜·이어보기·최근 검색의 공개 API와 충돌/재시도 정책은 유지한다.

계정별 디렉터리·프로필별 `.sqlite` 파일을 사용한다. `metadata`는 deviceID/nextSequence/revision/acknowledged revisions, `local_values`는 key/value BLOB, `outbox`는 순서와 원본 mutation envelope를 저장한다. UInt64 sequence/revision은 Codable payload로 보존하여 SQLite signed INTEGER 범위로 잘라내지 않는다. key와 payload는 바인딩한다. 오류 로그는 SQLite 오류 코드만 내보내고 SQL·사용자 값·경로를 포함하지 않는다.

MainActor가 앱 안의 쓰기를 직렬화한다. `BEGIN IMMEDIATE`부터 projection·outbox·metadata 교체와 `user_version=1`을 한 트랜잭션에서 처리한다. `synchronous=FULL`을 사용하며 COMMIT 성공 뒤에만 메모리/화면에 새 상태를 공개한다. 쓰기 실패는 ROLLBACK한다. 여러 프로세스의 동시 편집/병합은 지원 범위가 아니다. BUSY는 즉시 실패해 UI를 장시간 잠그지 않으며 호출자는 기존 오류 처리로 돌아간다. DB 핸들은 연산 뒤 닫는다. 아직 메인 스레드 동기 디스크 쓰기이므로 이 변경을 프레임 성능 개선으로 주장하지 않는다.

처음 열 때 유효한 DB가 없고 기존 `.json`이 있으면 scope·version·sequence·중복 ID·baseRevision을 검사한다. 기존 deviceID/ID/FIFO/진도를 그대로 SQLite에 넣고 다시 읽은 뒤 JSON을 지운다. COMMIT 후 JSON 정리 전에 종료되어도 다음 실행은 DB를 우선한다. 읽을 수 없는 기존 JSON, 손상 DB, 알 수 없는 schema는 초기화하지 않고 실패한다. 첫 커밋 전에 죽어 남은 schema 0·빈 DB만 초기화 재시도한다.

로그아웃은 모든 살아 있는 계정 저장소를 먼저 무효화한다. 계정 디렉터리 제거에 DB·journal/WAL/SHM·잔여 JSON이 함께 포함된다. 단일 scope 삭제도 JSON을 먼저 제거해 다음 실행에서 과거 데이터가 되살아나지 않게 한다. iOS 계정 디렉터리는 첫 잠금 해제 후 접근 가능한 파일 보호를 사용한다. 토큰은 계속 Keychain에 두며 DB에 넣지 않는다.

검증은 실제 SQLite 파일 헤더, JSON 이전 후 ID·순서·3종 projection, 남은 JSON 무시, SQL trigger로 중간 INSERT 실패→전체 rollback, 미래 schema·손상 파일 실패, 두 저장소 인스턴스 편집, 로그아웃 중 ACK와 F03 SIGKILL을 포함한다. 전원 상실/실제 iOS jetsam까지 검증한 것은 아니다.

근거: [SQLite atomic commit](https://www.sqlite.org/atomiccommit.html), [synchronous pragma](https://www.sqlite.org/pragma.html#pragma_synchronous). 코드: `SQLiteMutationDatabase.swift`, `DurableMutationStore.swift`. 실행 결과는 [보완 보고서](../Measurements/Final-Gaps-2026-11-06/REPORT.md)에 남긴다.
