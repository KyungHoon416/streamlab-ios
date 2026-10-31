# Mock 재생 권한 확인

운영 DRM 서버 연결이 필요 없는 앱 오류·재시도 흐름이다. 새 Instruments trace는 필요 없다.

2026-10-31 실기기에서 발견한 화면 회전 오류 콜백의 큐 불일치를 수정했다. 반드시 해당 수정 이후 코드를 새로 빌드한다. 디버거를 끄거나 중단점을 무시하여 우회할 문제가 아니다. [수정 기록](Measurements/Playback-Orientation-2026-10-31/REPORT.md).

1. 최신 main을 pull하고 원래 StreamLab.xcodeproj를 연다. Scheme StreamLab의 Run을 Debug로 선택한다.
2. Edit Scheme → Run → Arguments에 `--ui-test-entitlement-expired-once` 하나만 체크한다.
3. 실기기에 새로 실행 → 성인 프로필 → 작품 상세 → 데모 재생. 권한 만료 안내가 나오고 영상이 시작하지 않아야 한다.
4. ‘재시도’를 누르면 같은 화면에서 데모 재생이 시작해야 한다. 닫고 탭 이동도 확인한다.
5. 앱을 종료하고 위 인수를 끈다. `--ui-test-entitlement-key-unavailable-once`, `--ui-test-entitlement-renewal-failed-once`를 각각 하나씩 켜서 3~4를 반복하면 키 오류와 갱신 실패 안내도 확인할 수 있다.
6. 끝나면 세 인수를 모두 끄고 다시 실행한다. 정상 재생과 다운로드 목록 이동을 확인한다.

인수는 Debug 전용이며 새 플레이어 모델마다 첫 요청만 실패시킨다. Release에는 오류 주입이 없다. 실제 HLS 다운로드 파일 만료/재다운로드 검증과 구분한다. 이 절차에서 비행기 모드의 로컬 데모를 재생해도 실제 오프라인 DRM 라이선스 검증이 되지는 않는다.

자동 검증: `bash scripts/check-playback-entitlement-mac.sh` 및 `bash scripts/check-playback-session-lifecycle-mac.sh`.
