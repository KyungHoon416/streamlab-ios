# 셀룰러 다운로드 허용

2026-10-31 사용자 요청에 따라 AVAssetDownloadURLSession의 allowsCellularAccess와 allowsExpensiveNetworkAccess를 true로 설정했다. 기존 background session identifier와 task 복원/일시정지/취소/로그아웃 처리는 유지한다. 안내 문구에 Wi-Fi·셀룰러 지원과 모바일 데이터 사용을 표시했다.

실기기 확인: 새 빌드 설치 후 설정 앱에서 Wi-Fi를 끄고 StreamLab의 셀룰러 데이터 사용을 허용한다. 새 샘플 다운로드 시작 → 진행률 증가 → 백그라운드 완료 → 저장된 샘플 재생을 확인한다. 기존 작업이 계속 대기하면 해당 작업의 취소 및 기록 삭제 후 새 다운로드로 확인한다. 다운로드 완료 파일을 일괄 삭제할 필요는 없다.

셀룰러 실전송은 실기기 확인 대기다. 네트워크 이용 가능 여부와 시스템의 백그라운드 전송 일정까지 보장하는 설정은 아니다.

검증: 기기용 Release 빌드 성공(서명 제외, Swift warnings-as-errors), 빌드 로그 warning/error 없음. git diff --check 통과.

## 셀룰러 대기 진단

사용자가 afd6f4a 새 설치·새 작업에서도 진행되지 않음을 확인했다. Fig 메시지만으로 원인은 미확정이다. 설정 기본값을 또 바꾸거나 세션 ID를 바꾸는 대신, 작업 시작/10초 뒤 상태·진행률·세션 정책·CTCellularData 제한 상태와 connectivity 대기 콜백 로그를 추가했다. 진단은 전송 정책을 변경하지 않는다. 앱 셀룰러 권한 상태 unknown은 허용으로 해석하지 않는다. URL/계정/토큰은 기록하지 않는다.

실기기에서 새 작업 시작 후 10초 이상 기다리고 `Offline HLS diagnostic` 및 `Offline HLS transfer failed` 행을 확인한다. 백그라운드 세션의 대기 콜백이 없다는 이유만으로 연결 정상으로 판정하지 않는다. 실제 셀룰러 해결 여부는 미확정이다.
