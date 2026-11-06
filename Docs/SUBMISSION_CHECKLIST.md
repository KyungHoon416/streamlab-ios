# 최종 제출 점검표

2026-11-06. 제출 태그: `submission-2026-11-06`. 버전·촬영 조건·CI·영상 장면과 한계는 [제출 기록](SUBMISSION_RECORD.md)에 모았다.

## 준비 완료

- [x] 실행 안내와 모듈 설명: [README](../README.md)
- [x] 최신 구현 범위: [CURRENT_STATUS](CURRENT_STATUS.md)
- [x] 제출 태그에 Firebase·업로드·다운로드 예산을 반영한 [6쪽 PDF](https://github.com/KyungHoon416/streamlab-ios/blob/submission-2026-11-06/Docs/Architecture/streamlab-architecture-ko.pdf) 보존. 이후 보완은 [현재 본문](ARCHITECTURE_CURRENT.md)과 [그림 중심 14쪽 PDF](Architecture/streamlab-architecture-ko.pdf)에서 확인
- [x] 3분 32초 합본의 핵심 재생 및 F09·F10 장애 장면 확인, 만료 인수 전환 문구 추가, 개인 알림 가림, 전체 디코딩 검사
- [x] F09 실기기 만료·갱신 실패·남은 2회·목록 복귀 확인
- [x] F10 실기기 영어 자막·오프라인 닫기·재연결 후 10초 정상 재생 확인
- [x] 11월 6일 F09·F10 다운로드 완료와 비행기 모드 재생·시간·탐색 확인
- [x] 앱 구현 커밋, 촬영 전 소스 상태, 제출 태그, 실제 검사된 CI 커밋 구분
- [x] C4 수치와 미입증 항목 명시. [C4 보고서](Measurements/C4-2026-10-31/REPORT.md)

## 완료로 표시하지 않는 항목

- [ ] 통제된 조건의 스크롤 성능 전후 개선 증거. 기존 trace는 열 상태·손동작·빌드가 달라 개선을 입증하지 못한다.
- [ ] 촬영 바이너리의 정확한 SHA 확인. 촬영 전 체크아웃과 사용자 보고는 있지만 바이너리 각인/아카이브는 미확보다.
- [ ] 다른 Mac의 새 체크아웃·서명·실행 검증. 개발자의 개인 서명 설정을 공통 설정으로 덮어쓰지 않는다.

최종 영상 파일은 `streamlab-demo-final.mp4`다. 개인 알림을 가리기 전 `streamlab-demo-submission.mp4`와 구분한다. 영상에는 검색·찜 추가·전송 진행/삭제·프로필 격리 조작이 없으며 기존 보고서의 증빙으로 남긴다. 원안 [시연 대본](DEMO_SCRIPT.md) 전체를 촬영한 것으로 표시하지 않는다.

## 확인 명령

```sh
git status --short
git rev-parse 'submission-2026-11-06^{commit}'
git show --stat submission-2026-11-06
```

실제 자동 검증 링크와 범위는 [CI_VALIDATION](CI_VALIDATION.md)에 있다. 원시 trace·영상·개인 로그 전체는 Git에 넣지 않으며 영상 해시와 별도 전달 경로는 제출 기록에 남긴다.
