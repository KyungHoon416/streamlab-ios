# 관리자 압축 계획 — 2026-11-06

2GB 이상 MP4를 고르면 파일 크기·길이·해상도를 읽고 압축 방식을 선택한다. 선택만으로 서버 전송하지 않으며 실제 압축은 Mac에서 한다. 이번 범위에는 클라우드 인코딩 비용이나 새로운 서버 작업이 없다.

| 선택 | 표시/계산 | 실제 전송 |
|---|---|---|
| 원본의 40% 크기 | 약 60% 감소 목표. 오디오 96kbps와 용량 여유 2%를 고려한 영상 평균 비트레이트 | Mac 압축 후 완성본 재선택 |
| 1GB 이하 목표 | 길이·오디오 96kbps·여유 6%로 계산. 긴 영상은 디테일 손실 안내 | Mac 압축 후 완성본 재선택 |
| 화질 우선 | HEVC CRF 28. 같은 원본/설정의 10초 이상 샘플이 있을 때만 길이 비례 예상 | Mac 압축 후 완성본 재선택 |
| 원본 그대로 | 선택 파일 크기 그대로. 5GB 초과는 차단 | 기존 재개 가능한 Firebase 업로드 |

기본은 40% 크기, 최대 1080p/30fps다. 4K 소스의 1080p 축소를 안내하며 작은 소스는 확대하지 않는다. 원본 유지(최대 60fps) 선택은 실제 원본 FPS를 Mac에서 확인하도록 안내한다. 브라우저 메타데이터만으로 원본 FPS나 HDR을 추정하지 않는다. 화질 샘플의 원본·설정 일치는 사용자 확인 사항이며 자동 인증하지 않는다. 예상값을 정확한 최종 용량/원본 화질 보장으로 표현하지 않는다.

5GB보다 큰 원본도 계획 목적으로 선택할 수 있다. 파일 검증은 12바이트 헤더만 읽고, 길이/해상도는 native video blob URL로 읽는다. 메모리로 파일 전체를 복사하지 않는다. 업로드 클래스와 Storage의 5GB 한도는 유지한다. 완료본도 2GB 이상이면 ‘원본 그대로 업로드’를 선택하여 압축을 반복하지 않고 전송한다.

파일 교체·작품 변경·로그아웃 때 세대 번호/AbortSignal로 이전 메타데이터와 샘플 응답을 폐기하고 object URL을 해제한다. 압축 계획 선택 상태에서는 업로드가 비활성화된다. 폼의 압축 radio 필드가 Firestore 작품 문서에 섞이지 않도록 저장 필드를 whitelist로 제한했다.

## 검증

- Node 단위 테스트 22개 PASS: 2GB 경계, 8.88GB 분석과 5GB 업로드 차단 분리, 4시간/1GB 예산, 40% 의미, 미측정 화질 크기 미표시, 잘못된 메타데이터, 타임아웃/취소 정리, 전송/로그아웃 경계, Firestore 저장 필드 회귀.
- Firestore 에뮬레이터 8개 및 Storage 에뮬레이터 2개 PASS.
- Vite build PASS. 기존 Firebase SDK 포함 chunk 500kB 초과 안내는 유지되며 빌드 오류가 아니다.
- 실제 브라우저에서 `admin/tests/compression-browser.html` 9개 경계 PASS와 radio 변경 후 예상값/버튼 상태를 확인. console error/warn 없음. 가상 파일 크기와 주입 메타데이터를 사용하는 UI 시험이며 실제 4GB 업로드가 아니다.
- 사용자 원본 전체 압축은 별도 로컬 작업이다. 업로드·4시간 전체 시청·서버 자동 압축 완료로 확대하지 않는다.

재현:

```sh
npm --prefix admin test
npm --prefix admin run build
firebase emulators:exec --only firestore,storage --project demo-streamlab-admin 'npm --prefix admin run test:rules && npm --prefix admin run test:storage'
npm --prefix admin run dev -- --port 4177
# http://127.0.0.1:4177/tests/compression-browser.html
```

## 배포·원격 검증

구현 커밋 `923d3a689e9a7ac2f71e8bf9fc9a54bc68aee762`를 main에 푸시했다.

- [관리자 CI 42190580037](https://github.com/KyungHoon416/streamlab-ios/actions/runs/42190580037): SUCCESS.
- [앱 회귀 CI 42190580118](https://github.com/KyungHoon416/streamlab-ios/actions/runs/42190580118): core-chaos와 ios-playback 두 job SUCCESS. Core XCTest 31개 + Swift Testing 243개, 카오스 3종 각 1,000 seed, F03 SIGKILL 복구, iOS 패키지 25개와 Release 빌드 통과. 앱 소스 변경은 없지만 기존 회귀 workflow도 실행됐다.
- Firebase Hosting 배포 완료. 실제 `index.html`, JS, CSS가 검증한 `admin/dist`와 바이트 단위로 일치한다. [배포 해시](deployment.json).
- [로컬 검사/스크린샷 해시](local-validation.json), [관리자 실행](admin-ci.json), [앱 실행](app-ci.json)을 보존한다.

Storage·Firestore 규칙과 요금제는 이번에 변경하지 않았다. 제출 태그·ZIP/PDF는 보존한다. 실제 수 GB 파일 업로드·iPhone 재생은 이 UI/규칙 회귀와 별개다.

## 로컬 전체 영상 압축 결과

사용자가 지정한 원본을 변경하지 않고 Mac에서 전체 압축을 완료했다. 최종 선택은 1GB 제한이 아니라 **원본의 40% 크기**, 1080p/30fps다.

| 항목 | 원본 | 완성본 |
|---|---:|---:|
| 크기(십진 GB) | 8.8815 GB | 3.5040 GB |
| 바이트 | 8,881,545,500 | 3,503,966,872 |
| 해상도 | 1920×1080 | 1920×1080 |
| 프레임 | 약 59.94fps | 29.97fps |
| 길이 | 3시간 18분 46.84초 | 동일(차이 0.001초 미만) |

완성본은 원본의 **39.45%**, 감소율은 **60.55%**다. HEVC(hvc1)/AAC MP4이며 웹 재생을 위해 moov가 mdat 앞에 있는 faststart 구조를 확인했다. 원본 크기·수정시각 유지, 5GB 미만, 해상도/코덱/프레임/길이, 앞·중간·끝 각 30초 디코딩 검사를 통과했다. 전체 파일 SHA-256과 검사 범위는 [local-compression-result.json](local-compression-result.json)에 기록했다. 전체 압축과 검증에 약 30분이 걸렸다.

60초 동일 설정 비교 샘플의 VMAF는 75.58이었다. 이 수치는 샘플 기준이며 전체 영상 품질이나 60→30fps 움직임 품질을 보증하지 않는다. 원본은 파일명과 달리 실제 1080p/SDR이며 4K로 확대하지 않았다.

파일은 로컬 산출물 폴더에 보관하고 Git에는 측정 결과만 저장한다. 이 3.50GB 파일의 Firebase 업로드와 iPhone 재생은 아직 하지 않았다. 관리자에서 완성본을 고른 뒤 **‘원본 그대로 업로드’**를 선택하면 추가 압축 계획 없이 기존 5GB 업로더를 사용할 수 있다.
