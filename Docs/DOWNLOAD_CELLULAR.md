# 셀룰러 다운로드 허용

2026-10-31 사용자 요청에 따라 AVAssetDownloadURLSession의 allowsCellularAccess와 allowsExpensiveNetworkAccess를 true로 설정했다. 기존 background session identifier와 task 복원/일시정지/취소/로그아웃 처리는 유지한다. 안내 문구에 Wi-Fi·셀룰러 지원과 모바일 데이터 사용을 표시했다.

실기기 확인: 새 빌드 설치 후 설정 앱에서 Wi-Fi를 끄고 StreamLab의 셀룰러 데이터 사용을 허용한다. 새 샘플 다운로드 시작 → 진행률 증가 → 백그라운드 완료 → 저장된 샘플 재생을 확인한다. 기존 작업이 계속 대기하면 해당 작업의 취소 및 기록 삭제 후 새 다운로드로 확인한다. 다운로드 완료 파일을 일괄 삭제할 필요는 없다.

셀룰러 실전송은 실기기 확인 대기다. 네트워크 이용 가능 여부와 시스템의 백그라운드 전송 일정까지 보장하는 설정은 아니다.

검증: 기기용 Release 빌드 성공(서명 제외, Swift warnings-as-errors), 빌드 로그 warning/error 없음. git diff --check 통과.
