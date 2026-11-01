# F03 프로세스 강제 종료 복구

2026-11-01

## 검증 경계

기존 테스트는 동일 프로세스 안에서 저장소/Mock 서버를 재구성했다. 새 독립 macOS 도구는 실제 DurableMutationStore와 영속 MockMutationServer를 사용한다. iOS 앱이나 사용자 데이터는 변경하지 않는다.

1. 고유 임시 폴더에 로컬 변경 100건과 원본 envelope 기준값 저장. 준비 표식 이후 부모가 자식에게 SIGKILL.
2. 새 프로세스에서 값·원본 ID/sequence/baseRevision/내용을 비교하고 서버에 100건 반영. 로컬 ACK 미기록 상태에서 두 번째 SIGKILL.
3. 새 프로세스에서 기존 envelope가 그대로인지 검사 후 flush. 로컬/서버 값 일치, revision 100(중복 효과 없음), pending 0 확인.
4. 마지막 새 프로세스에서 ACK 영속성·pending 0·서버 값과 revision 재확인.

부모는 각 종료가 실제 SIGKILL인지 검사한다. 준비 표식 타임아웃·조기 정상 종료·검증 실패·결과 표식 누락은 FAIL이다. 자신이 생성한 자식만 종료하며 종료 시 임시 폴더를 정리한다.

## 결과

- 로컬 실제 SIGKILL 2회/재실행 3회: PASS. 100건 유지·중복 효과 0·pending 0·ACK 영속성 확인.
- 조기 정상 종료를 준비 완료로 오인하지 않는 부정 검증: PASS.
- 경고 오류 처리/엄격한 동시성 빌드, 셸 문법·공백 검사: PASS.
- 원격 CI [#41299395393](https://github.com/KyungHoon416/streamlab-ios/actions/runs/41299395393): **PASS**. 구현 커밋 `9515c98dab27fe1a6b88d6ad9c55094f83b8f0b8`.
- 원격 로그에서 SIGKILL 두 단계와 F03 PROCESS PASS 표식 확인. 기존 Core/실제 loopback HTTP/카오스 3종 × 1000 seed/TTFF parser 6개, iOS 22개, iOS Release 빌드도 통과.
- 결과 JSON과 원시 로그 SHA-256은 CI.json/MANIFEST.json에 보관했다. 앱 런타임 수정 없이 검증 범위를 보강했다.

## 범위

macOS 프로세스 생명주기 및 파일 영속성 검증이다. iOS jetsam/실제 앱 강제 종료 UI, 잠금 파일 보호, 전원 손실, atomic write 도중 종료, 운영 HTTP 서버는 검증하지 않는다. 기존 loopback HTTP와 iOS 잠금 검증은 별도 근거다. 이번 도구 때문에 새 실기기 측정이나 trace 제출은 필요 없다.

재현: `bash scripts/check-mutation-process-crash-mac.sh`. 기존 Core gate에도 연결되어 GitHub Actions에서 실행한다.
