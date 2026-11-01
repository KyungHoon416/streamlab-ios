# 최종 제출 점검표

2026-11-01. 프로젝트 제출 전 확인용이며 자동으로 전체 합격을 선언하지 않는다.

## 준비된 자료

- [x] 프로젝트·모듈·실행 설명: [README](../README.md)
- [x] 현재 구현과 실제 남은 항목: [CURRENT_STATUS](CURRENT_STATUS.md)
- [x] 설계와 저장 구조: [아키텍처 문서](ARCHITECTURE_CURRENT.md), [PDF](Architecture/streamlab-architecture-ko.pdf), [ADR 목록](ADR)
- [x] 장애별 근거와 한계: [F01~F10](CHAOS_ACCEPTANCE.md)
- [x] CI 실행/범위: [CI_VALIDATION](CI_VALIDATION.md), [최신 검증 보고서](Measurements/Observer-Lifecycle-2026-11-01/REPORT.md)
- [x] 성능 수치와 미판정 항목: [C4 보고서](Measurements/C4-2026-10-31/REPORT.md)
- [x] 정상 흐름+장애 2개 시연 대본: [5분 시연](DEMO_SCRIPT.md)

## 제출 전에 남은 확인

- [ ] 실제 시연 영상 녹화·재생 확인. 대본 파일을 영상 제출로 대신하지 않음.
- [ ] C4 원문 목표와 지표 정의 대조 및 부족한 표시 프레임/반복 잔존량 증빙 판정. 현재 전체 성능 PASS는 아님.
- [ ] F09/F10 실기기 조합 확인 또는 미확인 범위 명시. [절차](CHAOS_ACCEPTANCE.md) 참고.
- [ ] 제출 커밋과 촬영 빌드, CI가 검사한 커밋을 구분해 기록. 문서 전용 후속 커밋은 새 CI가 실행되지 않을 수 있음.
- [ ] PDF의 2026-10-31 스냅샷 날짜와 이후 후속 구현 설명 확인. 최신 기능 전체가 그 PDF에 반영됐다고 주장하지 않음.
- [ ] 다른 Mac에서 필요한 Xcode/서명·Scheme 설정 확인. 개발자의 개인 서명 설정을 저장소 공통 설정으로 덮어쓰지 않음.

## 제출 시 채울 정보

| 항목 | 값 |
|---|---|
| 제출 커밋 | 미정 — 최종 제출 시 기록 |
| 검사한 코드의 CI 링크/커밋 | 최신 보고서에 있음. 제출 시 해당 값을 복사 |
| 촬영 기기·iOS·빌드 구성 | 미정 — 실제 녹화 조건 기록 |
| 시연 영상 경로 | 미녹화 |
| 성능 측정 빌드·기기 조건 | 각 C4 원본 보고서 참조. 촬영 빌드와 동일하다고 가정하지 않음 |
| 알려진 제한 | Mock 서버/권한, C4 미판정 및 F별 미확인 OS 조건 |

## 확인 명령

먼저 변경 내용을 보존한 상태에서 저장소 상태를 확인한다. 로컬 수정 충돌이 있으면 `reset --hard`로 버리지 않는다.

```bash
git status --short
git rev-parse HEAD
bash scripts/check-assignment-core-mac.sh
bash scripts/check-playback-session-lifecycle-mac.sh
```

앱 UI/외부 HLS는 별도 suite다. 제출 전에 필요한 범위만 선택하고, 실행하지 않은 것을 PASS로 적지 않는다.

```bash
bash scripts/check-profile-boundaries-mac.sh
bash scripts/check-download-combined-mac.sh
```

원시 trace/xcresult/개인 로그 전체를 무조건 Git에 넣지 않는다. 저장소의 요약·해시·실행 링크와 별도 보관 원본을 연결한다. 과거 보고서를 최신 결과처럼 날짜만 바꾸지 않는다.
