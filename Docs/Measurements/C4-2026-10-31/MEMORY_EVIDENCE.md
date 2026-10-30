> 기존 로컬 분석 보존본. 아래 PNG/XML/CSV 이름은 로컬 분석 폴더의 증빙이며 이 저장소에 포함하지 않는다.

# 실기기 HLS 메모리 분석

분석일: 2026-10-26. 원본: `memory-hls-20.trace`.

## 결론

전체 Current Bytes 그래프는 초기 증가 후 비슷한 범위에서 오르내린다. 반복마다 큰 폭으로
계속 누적되는 양상은 시각적으로 관측되지 않았다. 다만 회차별 시점과 연결된 정확한
baseline/5/10/15/20회 잔존량 및 전체 프로세스 resident/dirty 메모리 시계열은 확보하지 못해
정량적인 증가율 또는 전체 메모리 검증 PASS로 표시하지 않는다.

주요 재생 객체의 기록 종료 시점 잔존 수는 모두 0이다. 이 실행에서 플레이어 객체가
반복 횟수만큼 남는 문제는 확인되지 않았다. Leaks instrument가 기록되지 않았으므로
자동 누수 탐지 0건 또는 누수 없음 확정으로 대체하지 않는다.

## 기록 조건

- Instruments 27.0 (27A266a), Allocations 템플릿, Deferred 기록.
- iPhone 15 Pro, iOS 26.6.1 (23G83).
- 기록 시각: 2026-10-25 21:01:11.025 ~ 21:11:09.453 +09:00.
- 길이 598.427752초 (약 9분 58초). 종료 사유 User pressed Stop.
- 메타데이터에 process exit(0)도 있다. 그래프에는 종료 시 전체가 0으로 내려가는 구간이
  보이지 않는다. 앱 종료 전 마지막 홈 상태인지와 정확한 반복 경계는 별도 확인이 필요하다.
- 사용자는 HLS 20회 반복을 보고했다. 객체 생성 수로 HLS 반복 횟수를 추정하지 않았다.
- 측정 바이너리 커밋과 Release 설정은 이 trace 메타데이터만으로 확인하지 못했다.
- 기록 설정: Heap and VM allocations, Freed memory Keep events,
  When stopping Immediately discard unrecorded data. 이 설정만으로 실제 유실 여부를 단정하지 않는다.

## 전체 구간의 종료 시점 생존 할당

| 구분 | 잔존 바이트 | 잔존 할당 수 |
|---|---:|---:|
| Heap + Anonymous VM | 40,231,712 (38.37 MiB) | 124,430 |
| Heap | 22,733,600 (21.68 MiB) | 124,330 |
| Anonymous VM | 17,498,112 (16.69 MiB) | 100 |

누적 할당은 4,623,113,424바이트(약 4.31 GiB)다. 이는 실행 중 생성된 총량이며
동시에 사용 중인 메모리나 누수량이 아니다. VM Tracker의 resident/dirty 전체 메모리와도 구분한다.

## 재생 객체 회수

| 타입 | 생성된 할당 | 종료 시점 잔존 |
|---|---:|---:|
| StreamLabCatalogFeature.PlaybackModel | 32 | 0 |
| StreamLabCatalogFeature.PlaybackPictureInPicture | 32 | 0 |
| PlayerSurface.SurfaceView | 32 | 0 |
| AVPlayer | 61 | 0 |
| AVPlayerItem | 61 | 0 |
| AVPlayerLayer | 61 | 0 |

CatalogSession은 1개 남아 있다. 앱의 현재 세션 수와 맞는 값이지만, 이 숫자만으로 모든
세션 관련 객체의 정상 여부까지 보증하지 않는다.

## 남아 있는 주요 항목

- VM: Stack 10.39 MiB / 19개.
- Malloc 16 KiB 3.73 MiB / 239개.
- VM: CG Raster Data 3.56 MiB / 24개.
- MockMutationServer.Receipt 사전 backing storage 608 KiB / 1개.

유형과 크기만으로 위 항목을 누수로 분류할 수 없다. 특히 요청 영수증 저장소는 장시간
요청 수 증가에 따른 보유량을 별도 확인할 수 있는 후보이며, 이번 한 번의 최종 수치로
무한 증가를 입증하지 않는다.

## 생존 할당 목록 분석의 한계

별도 Allocations List 내보내기에서는 124,400개/40,229,936바이트가 반환됐다.
Statistics와 30개/1,776바이트 차이가 있어 목록 분석을 정확한 전체 합계로 대체하지 않았다.
`surviving-allocation-age.json`은 최종 생존 할당을 생성 시각별로 나눈 값이다.
이는 각 시점의 실시간 메모리 사용량이 아니다. 후반에 생성된 stack 등이 이전 것을
대체했을 수 있으므로 후반 생성량 자체를 순증가량으로 해석하지 않는다.

## 증빙 및 다음 단계

- `allocations-overview.png`: 전체 구간 그래프와 Persistent/Total Bytes 표.
- `allocation-statistics.csv`, `allocation-statistics.xml`: xctrace Statistics 직접 내보내기.
- `surviving-allocation-age.json`: 최종 생존 할당의 생성 시각 분포와 목록 차이 설명.
- 누수 검증은 Leaks 템플릿에서 같은 앱/동작으로 별도 수집하고, 앱을 종료하기 전에
  마지막 홈 대기 상태까지 기록한다. 누수가 탐지되면 해당 객체의 호출 스택/소유 관계를 조사한다.
- 정확한 반복별 증가 추세가 필요하면 Allocations의 Mark Generation 표를 기준/5/10/15/20회와
  대응시켜 확인한다. 현재 표를 확보하지 못했다는 이유만으로 기록 전체를 폐기할 필요는 없다.

Apple 참고: https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use
https://developer.apple.com/videos/play/wwdc2024/10173/
