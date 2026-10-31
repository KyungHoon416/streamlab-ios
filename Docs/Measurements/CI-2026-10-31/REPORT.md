# CI 도입 검증

기준 72af88e. 실기기 이어보기/시간/다운로드 완료·삭제 정상 사용자 보고를 기록하고, 기존 검증 명령을 GitHub Actions에 연결했다.

## 로컬 검증

- CI와 동일한 check-domain-chaos-mac.sh PASS. Core 실행 247개 PASS, 조건부 HTTP/Keychain 11개 SKIP. 카오스 3종 각각 seed 1~1000 완료 표식 확인.
- TTFF parser 6개 PASS. YAML 구문 및 git diff 공백 검사 PASS.
- 앱 실행 코드는 이번에 변경하지 않았다. iOS 16개와 Release는 직전 72af88e 작업의 로컬 PASS 증빙을 재사용한다. 원격 runner 실행 결과와 구분한다.

[운영·범위·재현 방법](../../CI_VALIDATION.md). 전체 과제 카오스 10종 통과가 아니다.

## GitHub 실행

workflow 추가 커밋 push 후 실제 실행 결과를 후속 기록한다. 로컬 PASS만으로 GitHub PASS를 주장하지 않는다.
