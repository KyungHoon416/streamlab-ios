# C4 App Update / Hitch 집계 도구

C4 성능 보고에 필요한 반복 집계를 위한 도구다. 앱 UI는 변경하지 않는다.
Frame Lifetimes/FPS와 App Update 시간을 혼동하지 않도록 출력 이름을 구분한다.
전체 C4(실제 프레임 간격, 메모리, 에너지, 디스크, 성능 목표)의 완료를 뜻하지 않는다.

## 사용법

원본 trace를 읽기만 하며 XML 출력은 원본 밖 새 경로에 둔다.
다음 예시는 Run 1 기준이며 여러 Run이 있으면 export XPath와 --run을 함께 변경한다.

```bash
xcrun xctrace export --input '/path/measurement.trace' --toc --output /tmp/measurement-toc.xml
xcrun xctrace export --input '/path/measurement.trace' \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="hitches-updates" or @schema="hitches"]' \
  --output /tmp/measurement-events.xml
python3 scripts/summarize-frames.py \
  --toc /tmp/measurement-toc.xml --events /tmp/measurement-events.xml \
  --start 3.723 --end 4.08 > /tmp/measurement-summary.json
```

start/end는 녹화 시작 기준 초이며 예시의 값은 staged1에만 해당한다.
다른 trace에는 앱 표식에 맞춘 구간을 지정한다. 생략하면 전체 기록이다.
초기 진입/스크롤/탭 왕복이 섞인 파일 전체를 동일 조건으로 비교하지 않는다.

- 대상 프로세스의 PID는 TOC에서 읽고 같은 이름의 다른 프로세스는 제외한다.
- 최상위 App Update만 집계하며 중첩 update와 정확한 중복 행을 제외한다.
- [start,end)에 시작하는 이벤트를 선택한다. 경계를 넘는 duration은 자르지 않는다.
- nearest-rank p50/p95, 최대·합계·건수를 JSON으로 출력한다.
- hitches 테이블이 없거나 App Update가 비어 있으면 종료 코드 1이다.
- 잘못된 인자, 참조/스키마 불일치 등은 종료 코드 2다.
- 정상 집계의 종료 코드 0은 성능 PASS가 아니다. available은 집계 가능하다는 뜻이다.
- XML/TOC는 같은 trace에서 추출해야 한다. 출력에 PID/장치 UUID/환경변수는 포함하지 않는다.
  원본 XML에는 장치 정보가 포함될 수 있어 Git에 올리지 않는다.

## 해석 제한

p95 App Update는 FPS, 화면 표시 프레임 간격, TTFF가 아니다.
Hitch가 0이어도 main-thread hang이 없다는 뜻은 아니다.
적은 표본의 p95는 최대값과 같을 수 있다. 예: 5개 update의 p95는 최댓값이다.
프로필/열/페이지 로딩/구간/실행 조건이 다른 결과로 인과관계를 단정하지 않는다.

## 검증

- 새 Python 단위 테스트 6개: nearest-rank/빈 값, 다른 PID/중첩/중복 제외,
  빈 테이블과 누락 테이블 구분, 구간 경계, XML 참조, 잘못된 입력.
- 기존 runtime/TTFF 집계 테스트 각 6개도 통과.
- 기존 실기기 staged1 [3.723,4.08) 자료: App Update 5개, p50 38.675875ms,
  p95/최대 90.263875ms. Hitch 3개, 최대 83.350833ms, 합계 133.361332ms.
  기존 수작업 분석의 세 hitch(83.350833/16.670166/33.340333ms)와 일치.
- 앱 코드를 바꾸지 않아 Xcode 빌드/UI 테스트는 반복하지 않았다.
