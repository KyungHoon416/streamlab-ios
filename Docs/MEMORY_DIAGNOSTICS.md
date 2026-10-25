# 실기기 Instruments 메모리 검증 — 2026-10-25 절차

현재 상태: 실기기 Allocations 반복 측정 대기. HLS 첫 프레임 22회 측정과 별도 실행한다.

1. 최신 코드/측정 커밋을 기록하고 기본 StreamLab Scheme, 실제 iPhone을 선택한다.
   Edit Scheme → Profile → Build Configuration을 Release로 확인한다.
   기존 DEBUG 오류 주입 실행 인자, Zombies 등 별도 진단 옵션은 해제한다.
2. Product → Profile (⌘I)로 Instruments를 연다. Allocations를 선택하고 대상이
   실제 iPhone의 StreamLab인지 확인한 뒤 Record를 누른다.
3. 같은 프로필로 홈에 들어가 10초 대기하고 Allocations의 Mark Generation으로 기준을 남긴다.
4. 같은 작품에서 상세 → 데모 재생 → HLS 스트리밍 선택 → 영상이 나온 뒤 5초 → X로 닫기 → 홈 복귀를
   20회 반복한다. HLS만 카운트한다. 재생 바 조작/다른 앱 이동/프로필 변경은 섞지 않는다.
5. 5·10·15·20회 홈 복귀 시 10초 대기하고 Mark Generation을 누른다.
   마지막 표시 이후 홈에서 30초 더 대기하고 마지막 세대 표시를 남긴다.
6. 앱을 종료하지 않은 상태에서 Instruments 기록을 멈추고 File → Save로
   바탕화면에 memory-hls-20.trace를 저장한다. 앱 종료 시 해제된 메모리를 정상 회수 증거로 삼지 않는다.
7. 전체 Allocations 타임라인, Generations 표의 Persistent Bytes/남아 있는 할당 수를 캡처한다.
   증가하는 세대의 상세 타입/Call Tree도 가능하면 캡처한다. 지표 이름은 Xcode 버전별로 다를 수 있다.
8. .trace의 전체 경로 또는 파일(첨부가 어려우면 Finder에서 압축한 zip), 위 스크린샷,
   기기/iOS/Xcode/커밋/Release/반복 횟수/특이사항을 전달한다. 콘솔 텍스트만으로 대체하지 않는다.

Leaks는 별도 측정으로 추가할 수 있다. Allocations는 생존 객체 증가를 확인하고,
Leaks의 0건만으로 유지 순환이나 불필요한 객체 보유가 없다고 결론내리지 않는다.
캐시/AVFoundation 초기 할당으로 기준보다 메모리가 높아질 수 있으므로 각 반복 구간에서
남는 객체와 증가 추세/호출 경로를 비교한다. Instruments 실행의 TTFF는 기존 일반 실행 수치와 섞지 않는다.

참고: [Apple 메모리 측정 및 세대 표시](https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use),
[Apple Instruments 프로파일링](https://help.apple.com/xcode/mac/current/en.lproj/devcc15e6912.html).

---

# Simulator 메모리 진단

2026-10-12: Instruments가 시작 구간에 Malloc 32 Bytes 1개를 보고했다.
후속 검사 하나의 tooltip은 사용자 확인상 No new leaks였다. 최초 항목의
Responsible Frame은 <Call stack limit reached>, 라이브러리는 빈 값이다.
이는 할당 원인을 판정할 충분한 정보가 아니다. 시스템 누수 또는 앱 누수로 단정하지 않는다.

별도 Debug 실행의 Memory Graph에서는 사용자 확인상 누수 필터 목록이 비었다.
그 실행에는 Malloc stack logging is not enabled가 표시되었다.
Debug 캡처의 탐지 결과를 Release Instruments 결과의 해결 증거로 사용하지 않는다.

## 할당 경로 수집

1. `./scripts/bootstrap-mac.sh` 후 Xcode에서 **StreamLab-Memory** Scheme과
   같은 iPhone Simulator를 선택한다. 기본 StreamLab Scheme은 일반 검증용이다.
2. Command-R로 새로 실행한다. 이 Scheme은 `MallocStackLogging=1`을 전달한다.
   이미 실행 중인 프로세스나 과거 trace에 호출 경로를 소급 추가할 수 없다.
3. 우선 프로필 선택 화면에서 10초 대기 후 Debug Memory Graph를 캡처한다.
   Show only leaked allocations 필터 결과를 기록한다. 항목이 있으면 선택하고
   Object/Backtrace의 크기, 타입, 라이브러리, 할당 경로를 보관한다.
4. 실행을 재개하고 프로필 선택 → 홈 → 상세 → 뒤로가기 1회 후 홈에서 10초
   대기해 다시 캡처한다. 필터 결과를 비교한다. 시작부터 있는 항목과 화면 이동 후
   생긴 항목을 구분한다. 호출 경로가 없는 상태에서 반복 횟수만 늘리지 않는다.
5. 필요하면 File > Export Memory Graph로 `.memgraph`를 보관한다.
   먼저 항목/Backtrace 텍스트나 화면을 공유한다. 대용량 trace 전체 업로드는 필수가 아니다.
6. 호출 경로가 여전히 비어 있으면 Scheme > Run > Arguments에서 환경변수 적용을
   확인하고, Run > Diagnostics의 Malloc Stack Logging 설정을 확인한다.
   실제 호출 경로 수집 성공 여부는 Mac에서 검증해야 한다.

Stack logging 실행 수치를 일반 실행의 메모리/프레임 성능 기준과 직접 비교하지 않는다.
메모리 진단 후 기본 StreamLab Scheme으로 돌아간다. 기록에 Scheme, 구성, Git SHA,
기기/OS, 동작, 측정 시간을 같이 남긴다. 최초 32바이트 항목은 원인 확인 전까지 미해결이다.

## 화면 이상 없는 glassEffect 경고

사용자는 2026-10-12 15:32 KST 현재 화면 이상은 없고 콘솔에만 경고가 나온다고 확인했다.
앱 소스에는 glassEffect 직접 호출이 없으며 TabView/NavigationStack/toolbar를 사용한다.
이 사실만으로 시스템 버그라고 확정할 수 없다. 콘솔 경고와 누수의 인과관계도 확인되지 않았다.

Debug 조건의 자동 회귀를 별도로 수집한다:

```sh
CONFIGURATION=Debug ./scripts/check-runtime-mac.sh
```

기본값은 Release다. 각 실행의 RESULTS.txt, environment.txt,
runtime-diagnostics.txt를 비교한다. 경고를 숨기거나 무시하는 PASS 처리는 하지 않는다.
자동 검사는 정해진 홈/상세 60회 경로만 다루므로 수동 검색/탭 경로 전체를 보증하지 않는다.

## 참고

- Apple: https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use
- Apple: https://developer.apple.com/library/archive/documentation/Performance/Conceptual/ManagingMemory/Articles/MallocDebug.html
