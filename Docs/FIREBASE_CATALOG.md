# Firebase 콘텐츠 관리 — 2026-11-01

관리자 주소: https://streamlab-ios-eba4f.web.app

프로젝트 `streamlab-ios-eba4f`, Spark 요금제를 유지한다. Firestore `(default)`는 서울 `asia-northeast3`, 삭제 방지 활성화 상태다. Storage, Functions, 영상 업로드·인코딩은 만들지 않았다.

## 연결 범위

관리자가 Google 로그인 → 작품 초안 저장 → 공개 설정 → iOS가 공개 작품을 REST로 조회 → 등록된 HTTPS HLS URL을 AVPlayer로 재생한다. 웹과 서버 규칙에서 검증된 `kkh9172@gmail.com` Google 계정만 쓰기를 허용한다. 이메일 대소문자는 같은 계정으로 처리한다. 일반 사용자는 공개 작품만 조회할 수 있다.

작품 ID는 변경하지 않는다. 수정은 Firestore transaction과 revision으로 다른 창의 덮어쓰기를 막는다. 삭제 대신 비공개로 전환한다. 비공개 전환은 이후 목록·상세·재생 시작 조회에 반영되며, 이미 전달한 URL이나 재생 중인 플레이어 권한을 회수하지는 않는다. 공개 필드에 비밀 키나 비공개 서명 URL을 저장하지 않는다.

초기 카탈로그는 공개 작품 최대 200개를 대상으로 한다. 홈·검색·목록 요청마다 제한된 결과를 읽고, 페이지는 이 결과 내에서 나눈다. 201개가 반환되면 누락을 숨기지 않고 오류를 낸다. 본격적인 대규모 서비스 전에 서버 페이지네이션·검색 인덱스·읽기 예산을 재설계해야 한다. 실시간 구독은 없으며 새로 불러오기/앱 재실행으로 변경을 확인한다. 서버 오류 시 Mock 작품으로 대체하지 않는다.

**사용자 계정, 프로필, 찜, 진도 동기화, 재생 grant/키 상태는 기존 데모 구현이다.** 키즈 등급 필터는 앱의 표시 정책이며 서버의 법적 연령 인증이 아니다. Firebase Auth는 이번 단계에서 관리자 웹 로그인에만 사용한다. 등록된 작품의 다운로드는 아직 제공하지 않으며 Apple 샘플 다운로드를 실제 작품처럼 표시하지 않는다. 기존 `StreamLab` Scheme의 다운로드·오프라인 기능은 유지된다.

## 실기기 확인

1. 최신 코드를 pull하고 `StreamLab.xcodeproj`를 다시 연다. Scheme에서 **StreamLab-Firebase**와 iPhone을 선택한다.
2. Edit Scheme → Run → Arguments에 `--firebase-catalog`가 켜져 있는지 확인한다. 이전 `--ui-test-*` 오류 주입 인수는 끈다. 일반 StreamLab Scheme은 기존 Mock 카탈로그다.
3. 관리자 웹에서 승인된 Google 계정으로 로그인한다. 작품 ID·제목·장르·등급·시간과 이용 권한이 있는 HTTPS `.m3u8` 주소를 넣고 비공개로 저장한다. 포스터 URL은 생략 가능하다.
4. 앱에서 데모 시작 → 프로필 선택. 비공개 작품은 보이지 않아야 한다. 아직 공개 작품이 없으면 빈 카탈로그 오류가 표시된다.
5. 관리자에서 ‘앱에 공개’를 켜고 저장한다. 앱을 다시 실행해 홈·검색·상세에 작품이 나타나는지 확인한다.
6. 홈과 상세의 ‘영상 재생’에서 등록한 영상·하단 시간·탐색·닫기를 확인한다. 이 테스트는 실제 Firestore/HLS 연결이며 실제 유료 권한/DRM 검증은 아니다.
7. 비공개 전환 후 앱 재실행 시 사라지고, 새 재생 조회가 허용되지 않는지 확인한다. 이미 열린 재생의 즉시 중단은 범위 밖이다.

앱을 Xcode 없이 직접 실행하거나 배포 아카이브를 실행하면 Scheme launch argument가 적용되지 않는다. 운영 기본 전환은 후속 단계에서 별도 빌드 설정으로 결정한다.

## 재현 명령

```sh
npm --prefix admin ci
npm --prefix admin test
npm --prefix admin run build
firebase emulators:exec --only firestore --project demo-streamlab-admin 'npm --prefix admin run test:rules'
swift test --package-path Packages/StreamLabCore --scratch-path /private/tmp/streamlab-firebase-core
```

배포는 인증된 개발자 CLI에서 `firebase deploy --only firestore:rules,firestore:indexes,hosting --project streamlab-ios-eba4f`로 한다. CI는 테스트만 수행하며 배포 자격 증명을 저장하지 않는다. 웹 SDK config는 공개 클라이언트 설정이고 서비스 계정 비밀 키가 아니다. 실제 접근 통제는 배포된 Firestore 규칙에서 수행한다.

## 검증 기록

- Core 265개 통과(기존 260 + Firestore 저장소 5), iOS 재생 경계 25개 통과.
- Firebase Scheme iOS Release 빌드 통과.
- 관리자 입력/계정 테스트 3개, Firestore 규칙 에뮬레이터 테스트 3개 통과. 공개 조건 조회, 비공개 조회 차단, 다른 계정/미검증/비Google 로그인 쓰기 차단, revision·스키마·timestamp 검증, 삭제 차단 포함.
- 실제 배포 Firestore 공개 조건 HTTP 조회 성공(당시 문서 0개), 조건 없는 전체 조회 `PERMISSION_DENIED` 확인.
- Hosting 및 규칙 배포 완료. Google 제공자 활성화 확인.
- 기존 `scripts/validate-project.py`는 이전부터 있던 AppRootView의 UIKit 시스템 어댑터를 허용 목록에 포함하지 않아 중단됨. 이 구조 검사기의 통과를 주장하지 않으며, 실제 iOS 빌드 및 패키지 테스트 결과와 구분한다.
- 사용자 Google 로그인 후 실제 관리자 화면 확인 완료. `apple-hls-sample`을 비공개 생성(revision 1) → 공개(2) → 비공개(3) → 재공개(4)했다. 비공개 상태의 익명 직접 조회는 `PERMISSION_DENIED`, 공개 상태의 iOS 동일 홈·상세 REST 쿼리는 정상 반환됨을 확인했다. 실기기 확인을 위해 Apple 테스트 HLS 샘플 하나를 공개 상태로 남겼다. iPhone 원격 영상·시간·탐색 재생 확인은 아직 대기다.
- 원격 CI: [Firebase admin validation](https://github.com/KyungHoon416/streamlab-ios/actions/runs/41313300648), [StreamLab validation](https://github.com/KyungHoon416/streamlab-ios/actions/runs/41313300641) 모두 성공(`ddc116f`).
