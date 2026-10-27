# 포스터 레이어와 홈 뷰 분리의 독립 비교

## 목적과 범위

이전 A/B는 두 변경을 동시에 적용했고 스크롤 동작·열 상태·기록 길이가 달랐다.
원인이나 개선률을 확정하지 않는다. 이 실험은 동일 바이너리에서 두 요인을 독립적으로
선택한다. 기준은 과거 커밋 전체가 아니라 **현재 코드에서 두 렌더링 변경만 끈 구성**이다.
로그아웃 접근성 수정, 데이터 로딩, 캐시, 디코딩, 지연 탭 생성은 모두 동일하다.

| Scheme | 코드 | 포스터 | 홈 구조 |
| --- | --- | --- | --- |
| StreamLab-Home-C | C | SwiftUI GeometryReader + clip | 기존 인라인 |
| StreamLab-Home-P | P | 단일 UIView/CALayer | 기존 인라인 |
| StreamLab-Home-V | V | SwiftUI GeometryReader + clip | HomeHero/HomeRail 분리 |
| StreamLab-Home-PV | PV | 단일 UIView/CALayer | HomeHero/HomeRail 분리 |

C↔P는 포스터 효과, C↔V는 홈 분리 효과, V↔PV와 P↔PV는 상대 변경이 있을 때의
효과를 본다. 2회씩은 탐색적 비교이며 통계적 유의성이나 원인 확정을 보장하지 않는다.

선택은 `--home-render-experiment=C|P|V|PV` 시작 인자로 고정된다. 실행 중에는
변경되지 않으며 저장하지 않는다. 일반 StreamLab Scheme/아이콘 실행은 PV이다.
테스트용 인자가 필요한 비교는 반드시 해당 Scheme의 Product → Profile로 시작한다.
모든 비교 Scheme은 Run/Profile에 Release 및 명시적 인자를 설정했다.
`project.yml`에서도 재생성 가능하다. Memory Scheme은 사용하지 않는다.

시작 로그 예:

```
home_render_experiment=C poster=swiftui home=inline
home_render_experiment=P poster=layer home=inline
home_render_experiment=V poster=swiftui home=split
home_render_experiment=PV poster=layer home=split
```

선택한 Scheme과 이 로그를 함께 확인한다. Mac 콘솔 앱에서 연결된 iPhone의
StreamLab 로그 중 `home_render_experiment`를 검색해도 된다. 로그가 없으면 추측하지
말고 Instruments 시작 설정의 인자를 확인한다. 파일 이름만으로 구성을 확정하지 않는다.
별도의 화면 배지/타이머/추가 래스터 캐시를 넣지 않았다. 공통 조건 분기와 기존 홈 복사본이
포함되므로 과거 바이너리와의 절대 시간 비교보다 이번 네 구성끼리 비교한다.

## 측정 준비

1. 최신 main을 pull한다. Xcode에서 같은 iPhone을 선택하고 서명 설정은 유지한다.
2. 같은 계정·프로필·추천 카테고리, 같은 목록/다운로드 데이터, 같은 Wi-Fi와 밝기를 유지한다.
   앱 삭제/데이터 초기화, 목록 추가/재생/다운로드, 다른 기기의 미러링은 하지 않는다.
3. 빌드/설치 직후 열을 식힌다. 충전 상태·저전력 모드도 모든 측정에서 동일하게 한다.
   실제 열 상태는 trace 분석에서 확인하며, 기다렸다는 이유만으로 Nominal이라 판단하지 않는다.
4. Instruments Animation Hitches 템플릿과 같은 수집 항목을 사용한다.
   Leaks/Allocations/MallocStackLogging을 추가하지 않는다. 디버거는 붙이지 않는다.
5. 각 회차는 앱을 종료한 상태에서 새 Instruments 문서를 만들어 한 Run만 기록한다.
   같은 문서의 녹화를 반복해서 누적 저장하지 않는다. Profile에서 자동으로 녹화가
   시작된다면 그 첫 기록을 사용한다. 이미 실행된 앱에 attach한 기록과 섞지 않는다.

## 한 회차: 초기 진입 + 스크롤 (약 45초)

- 00:00: 앱 시작부터 녹화. 같은 방식으로 프로필을 선택해 홈 추천 맨 위로 진입한다.
- 00:15까지 대기. 홈이 늦게 뜬 경우에도 기록을 버리지 말고 진입 시각을 메모한다.
  15초까지 준비되지 않았다면 해당 파일은 초기 진입 분석에 보존하고 스크롤 비교에서 구분한다.
- **00:15~00:40: 세로 스크롤 정확히 5왕복.** 한 왕복은 아래 콘텐츠 방향 1회 +
  위로 돌아오기 1회이다. 화면 가로 중앙에서 높이 약 75%→25%, 반대 25%→75%로
  같은 거리를 움직인다. 편도 약 2.5초, 왕복 약 5초로 맞춘다. 가로 목록은 움직이지 않는다.
  여러 번 빠르게 튕기거나 추가 왕복하지 않는다. 맨 위 바운스도 같은 방식으로 유지한다.
- 00:40: 손을 떼고 5초 대기 → 00:45쯤 녹화 중지.
- 처리가 끝난 뒤 아래 이름으로 바탕화면에 저장하고 다시 열리는지 확인한다.
- 추가 스크롤/알림/늦은 홈 진입 등이 있었다면 해당 회차와 내용을 메모한다.
  느렸던 기록만 골라 제거하지 않는다. 재측정은 `-retry1` 같은 별도 이름으로 보존한다.

초기 구간과 15~40초 구간을 따로 집계한다. 같은 시간창만으로 동작량이 같다고 가정하지
않고 스크롤 횟수·동작 메모·열 상태·프레임 수를 함께 검토한다.

## 순서와 파일명

순서에 따른 열/캐시 영향을 줄이기 위해 두 번째 묶음은 역순으로 한다. 회차 사이 열을
식히고 항상 앱을 새로 시작한다. 브랜치 전환이나 앱 재설치는 필요 없다.

| 순서 | Scheme | 바탕화면 파일명 |
| --- | --- | --- |
| 1 | StreamLab-Home-C | home-isolate-C1.trace |
| 2 | StreamLab-Home-P | home-isolate-P1.trace |
| 3 | StreamLab-Home-V | home-isolate-V1.trace |
| 4 | StreamLab-Home-PV | home-isolate-PV1.trace |
| 5 | StreamLab-Home-PV | home-isolate-PV2.trace |
| 6 | StreamLab-Home-V | home-isolate-V2.trace |
| 7 | StreamLab-Home-P | home-isolate-P2.trace |
| 8 | StreamLab-Home-C | home-isolate-C2.trace |

각 파일에는 초기 진입과 스크롤이 모두 들어 있다. entry/scroll 파일을 따로 만들지 않는다.
파일 8개와 구성이 확인된 시작 로그, 기기/iOS, 코드 커밋, 실제 스크롤 시작 시각 및
예외 동작 메모를 함께 전달한다. 첫 C1만 먼저 저장·확인한 뒤 나머지를 진행해도 된다.

## 해석 및 검증 한계

- 초기 app update/hang/hitch 및 호출 스택, 스크롤 hitch 횟수/최대/합계, 매칭된
  render/update, offscreen pass, thermal state를 각각 비교한다.
- hang과 hitch는 겹칠 수 있으므로 합산하지 않는다. 대기시간이 들어간 전체 길이로
  계산한 비율을 Animation Hitch Ratio라고 부르지 않는다.
- 기능 테스트/Release 빌드 성공은 실기기 성능 개선 증명이 아니다.
- 실험이 끝나면 채택할 경로를 결정하고 InlineHomeView 복사본과 비교 설정을 정리한다.
  복사본은 340055c의 홈 동작을 보존했으며 실험 중 다른 홈 기능을 한쪽만 수정하면 안 된다.

## 준비 검증 (2026-10-27)

- 네 Scheme의 Run/Profile이 Release이며 올바른 인자를 명시하는지 확인.
- iOS 패키지 테스트 4개 통과: 독립 요인/기본값, 이미지 픽셀·터치 비수신,
  기존 이미지 메모리 캐시 2개. 최종 소스 컴파일 포함.
- 시뮬레이터 UI 4개 통과: C/P/V/PV별 선택값, 홈 스크롤, 포스터 이미지 탭으로
  상세 진입, 검색 썸네일 상세 진입. 각 모드의 카드 캡처도 육안 확인.
- 기기용 Release 빌드 통과 (코드 서명 생략, Swift 경고를 오류로 처리).
- 첫 UI 실행은 서명을 생략해 keychain -34018로 로그인에서 실패했다.
  시뮬레이터 임시 서명으로 재실행해 4개 모두 통과했다. 인증 검사를 우회하지 않았다.
- UI 테스트용 접근성 선택값은 Debug의 UI 테스트 인자 사용 시에만 제공한다.
  Release 접근성 화면에는 기술적인 선택값을 노출하지 않으며 시작 로그로 확인한다.
- 실기기 초기 진입/스크롤 성능 결과는 아직 미측정이다.
