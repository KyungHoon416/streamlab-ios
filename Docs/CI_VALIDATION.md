# GitHub Actions 검증

`.github/workflows/validation.yml`은 main push, pull request, 수동 workflow_dispatch에서 실행한다. 문서만 바뀐 push/PR은 제외한다. 문서 전용 PR의 필수 체크로 이 workflow를 지정하면 대기 상태가 될 수 있으므로 별도의 항상 실행되는 gate 없이 필수 체크로 지정하지 않는다. 브랜치 보호 설정은 변경하지 않는다.

## 자동 실행 범위

| 작업 | 범위 | 시간 제한 |
|---|---|---|
| core-chaos | Core 전체 및 loopback HTTP/더미 Keychain, durable queue/domain conflict/virtual clock retry 각각 seed 1~1000, TTFF parser 6개 | 20분 |
| ios-playback | 가용 iPhone simulator 자동 선택, 재생·권한·회전 콜백 17개, 서명 없는 Release 빌드 | 30분 |

동일 ref의 새 실행이 생기면 오래된 실행을 취소한다. macos-26의 기본 Xcode를 사용하며 실제 버전을 environment.txt에 기록한다. 로컬 Xcode 27과 CI 기본 Xcode가 같다고 가정하지 않는다. Xcode 26.6의 패키지 경고 억제 기본값과 warnings-as-errors가 충돌하지 않도록 SWIFT_SUPPRESS_WARNINGS=NO를 명시한다. 경고 검증을 끄지 않는다. 공식 액션은 확인한 v6 commit SHA에 고정했다. contents: read만 부여하고 checkout 자격 증명은 보관하지 않는다. 배포·릴리스·실기기 설치·서명 인증서/비밀키 업로드는 하지 않는다.

실패해도 `core-chaos-<run>-<attempt>` 또는 `ios-playback-<run>-<attempt>` artifact로 로그/RESULTS/environment를 14일 보관한다. 전체 DerivedData/xcresult는 업로드하지 않는다. artifact 보존 기간 뒤에는 지워질 수 있으므로 제출용 근거는 별도 요약 보고서에 기록한다.

## 사용법

GitHub 저장소 → Actions → StreamLab validation에서 실행/결과를 확인한다. 수동 실행은 Run workflow → main. 실패 job의 첫 실패 step과 artifact RESULTS.txt를 확인한다. 도구 실패/필수 테스트 누락은 PASS로 처리하지 않는다. 대기/계정 제한은 테스트 통과가 아니다.

로컬 재현:

```bash
bash scripts/check-assignment-core-mac.sh
python3 scripts/test-ttff-summary.py
bash scripts/check-playback-session-lifecycle-mac.sh
```

카오스 개별 재현은 `STREAMLAB_CHAOS_SEED=42 bash scripts/check-assignment-core-mac.sh`. CI 기본값은 세 suite 모두 1000개 seed다.

## 미포함 범위

전체 F01~F10, 앱 전체 UI/접근성, 실제 HLS/DRM, 실기기 전력·프레임·메모리 계측은 이 workflow에 포함되지 않는다. 17개는 패키지의 iOS 플레이어 테스트이며 앱 UI 테스트가 아니다. 이번 CI 구성을 과제 전체 통과로 표시하지 않는다.

공식 runner 기준: https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md
