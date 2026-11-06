"""Diagram-first architecture. Requires reportlab and macOS AppleGothic.
Rebuilds only the PDF; does not overwrite the manually maintained current-state docs.
Usage: python3 Docs/Architecture/build_pdf.py
"""
from pathlib import Path
import html
import json
import math
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import Paragraph
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'Docs/Architecture/streamlab-architecture-summary-2026-11-07.pdf'
APP_CODE = '9a4d39539bf7afaad759bacf8966d650b0477970'
APP_SHORT = APP_CODE[:7]
W, H = 841.89, 595.28
INK, MUTED, LINE = '#243039', '#66737C', '#CCD7DC'
TEAL, BLUE, RUST = '#176473', '#EAF3F5', '#A75034'
PALE, WARM = '#F5F7F7', '#FAF0EB'
pdfmetrics.registerFont(TTFont('Ko', '/System/Library/Fonts/Supplemental/AppleGothic.ttf'))
C = canvas.Canvas(str(OUT), pagesize=(W,H), pageCompression=1)
C.setTitle('StreamLab 아키텍처 - 시스템·데이터·재생·다운로드')
C.setAuthor('StreamLab')
C.setSubject(f'앱 코드 {APP_SHORT} / Firebase 관리자, SQLite 이전, 상태 전이와 검증 범위')
PAGE = 0


def text(x,y,s,size=11,color=INK,font='Ko'):
    C.setFillColor(HexColor(color)); C.setFont(font,size)
    C.drawString(x,H-y-size*.82,s)


def para(x,y,w,s,size=11,color=INK,leading=None,maxh=None):
    style=ParagraphStyle('p',fontName='Ko',fontSize=size,leading=leading or size*1.45,
                         textColor=HexColor(color),wordWrap='CJK')
    p=Paragraph(html.escape(s).replace('\n','<br/>'),style)
    _,h=p.wrap(w,1000)
    if maxh is not None and h>maxh+.1: raise ValueError((PAGE,s,h,maxh))
    p.drawOn(C,x,H-y-h)
    return h


def box(x,y,w,h,title,body='',fill=PALE,stroke=LINE,size=13):
    C.setFillColor(HexColor(fill)); C.setStrokeColor(HexColor(stroke)); C.setLineWidth(.8)
    C.roundRect(x,H-y-h,w,h,4,fill=1,stroke=1)
    th=para(x+13,y+12,w-26,title,size,TEAL if fill!=WARM else RUST,maxh=h-20)
    if body: para(x+13,y+15+th,w-26,body,10.5,INK,maxh=h-22-th)


def boundary(x,y,w,h,label):
    C.setStrokeColor(HexColor(LINE)); C.setLineWidth(.8); C.setDash(4,3)
    C.roundRect(x,H-y-h,w,h,5,fill=0,stroke=1); C.setDash()
    label_at(x+14,y,label,9,MUTED,align='left')


def label_at(x,y,s,size=9.5,color=MUTED,align='center'):
    tw=pdfmetrics.stringWidth(s,'Ko',size)
    left=x-tw/2 if align=='center' else x
    C.setFillColor(HexColor('#FFFFFF'));C.rect(left-3,H-y-size-2,tw+6,size+4,fill=1,stroke=0)
    text(left,y,s,size,color)


def arrow(points,color=TEAL,dashed=False,both=False,width=1.15):
    C.setStrokeColor(HexColor(color));C.setFillColor(HexColor(color));C.setLineWidth(width)
    C.setDash(4,3) if dashed else C.setDash()
    p=C.beginPath();p.moveTo(points[0][0],H-points[0][1])
    for x,y in points[1:]:p.lineTo(x,H-y)
    C.drawPath(p,stroke=1);C.setDash()
    def head(a,b):
        angle=math.atan2(b[1]-a[1],b[0]-a[0]);l=6;d=2.8
        x,y=b;ux,uy=math.cos(angle),math.sin(angle)
        p=C.beginPath();p.moveTo(x,H-y)
        p.lineTo(x-l*ux+d*uy,H-(y-l*uy-d*ux))
        p.lineTo(x-l*ux-d*uy,H-(y-l*uy+d*ux));p.close()
        C.drawPath(p,fill=1,stroke=0)
    head(points[-2],points[-1])
    if both:head(points[1],points[0])


def page(section,title,subtitle):
    global PAGE
    if PAGE:C.showPage()
    PAGE+=1
    C.bookmarkPage(f'page-{PAGE}')
    C.addOutlineEntry(f'{PAGE:02d} {title}',f'page-{PAGE}',level=0)
    text(40,24,'STREAMLAB  /  ARCHITECTURE',9,TEAL,'Helvetica-Bold')
    text(650,24,f'2026.11.07  ·  {APP_SHORT}',9,MUTED)
    C.linkURL(f'https://github.com/KyungHoon416/streamlab-ios/tree/{APP_CODE}',
              (650,H-36,800,H-22),relative=0,thickness=0)
    text(40,53,title,25)
    para(40,92,760,subtitle,11,MUTED,maxh=34)
    C.setStrokeColor(HexColor(LINE));C.setLineWidth(.6);C.line(40,39,W-40,39)
    text(40,565,section+'  |  현재 구현 기준 · 기존 제출 태그/영상은 별도 스냅샷',8.5,MUTED)
    text(779,562,f'{PAGE:02d}',11,TEAL,'Helvetica-Bold')


def source(s):text(40,541,s,8.5,MUTED)


# 1. Service and device boundaries, not a marketing overview.
page('01 SYSTEM','전체 시스템 구성','관리자가 등록한 작품 정보와 영상 파일은 서로 다른 경로로 앱에 도착한다.')
boundary(319,133,482,166,'Firebase · Firestore/Storage 서울 · Blaze')
box(40,168,233,106,'관리자 웹 / Hosting','Google 로그인\n작품 편집 · MP4 드롭 업로드')
box(339,161,130,108,'Auth','관리자 Google 인증\n허용 계정 확인',size=13)
box(485,161,142,108,'Firestore','공개 카탈로그\n작품 정보 · 영상 URL',size=13)
box(643,161,140,108,'Storage','업로드 MP4\n다운로드 토큰 URL',size=13)
arrow([(273,220),(319,220)]);label_at(296,196,'관리 API',8.5)
boundary(319,325,482,210,'iPhone / 앱 컨테이너')
box(40,347,233,77,'외부 HLS 제공자','Apple 테스트 URL 또는 등록한 HTTPS URL')
box(339,347,444,87,'iOS 앱 / SwiftUI','홈 · 검색 · 상세 · 다운로드\nAVPlayer / AVAssetDownloadURLSession / URLSession\n앱 로그인·동기화·재생 권한은 Mock')
arrow([(556,269),(556,347)]);label_at(556,311,'REST로 공개 작품 조회')
arrow([(713,269),(713,347)]);label_at(713,289,'HTTPS 영상',9)
arrow([(273,388),(339,388)]);label_at(304,367,'HLS',9)
box(339,451,444,75,'기기 내부 저장','진도·찜·검색: SQLite / 다운로드 metadata: journal\n오프라인 영상: HLS .movpkg / MP4 · 로그인 자격: Keychain')
arrow([(560,434),(560,451)],both=True)
source('그림 1. 실선은 데이터 흐름. Firebase 운영 연결은 관리자 인증·카탈로그·파일 저장까지다.')

# 2. Actual package responsibility and selected dependency paths.
page('02 MODULES','화면, 정책, 저장소의 의존 관계','화면은 StreamLabUI, 화면 상태와 저장 정책은 StreamLabCore에 둔다. App이 두 패키지를 조립한다.')
box(255,136,333,62,'App / AppRootView','계정·프로필 수명 · 탭 · 알림 경로 · 저장소 주입',fill=BLUE)
arrow([(421,198),(421,234)]);label_at(421,208,'세션과 의존성 주입')
boundary(40,234,760,119,'StreamLabUI')
box(57,256,220,76,'DesignSystem','테마 · 접근성 · 포스터 캐시\n화면 준비 / C4 계측')
box(303,256,220,76,'ProfileFeature','프로필 선택\n성인 / 키즈 진입')
box(549,256,232,76,'CatalogFeature','홈·상세·검색·다운로드\nPlaybackModel · 네이티브 전송')
arrow([(421,353),(421,390)]);label_at(421,365,'UI가 Core API에 의존')
boundary(40,390,760,137,'StreamLabCore')
box(57,414,220,91,'Presentation','상태 저장소 · 인증 경계\nSQLite projection / outbox\n취소 · 재시도 · 충돌 정책')
box(303,414,220,91,'CatalogData','2,000개 Mock 작품\nFirebase 공개 카탈로그\n전송 구현')
box(549,414,232,91,'Domain','프로필·작품·진도 모델\n다운로드 예산 · 상태 전이\nUI / AVPlayer에 의존하지 않음')
source('그림 2. 주요 계층 관계. 전체 import·객체 소유권: Architecture/ARCHITECTURE_DIAGRAMS_2026-11-06.md.')

# 3. Real schema and atomic publication, plus the migration path.
page('03 LOCAL DATABASE','SQLite에서 값과 전송 큐를 함께 저장한다','계정 디렉터리 안에 프로필별 DB를 둔다. 찜·최근 검색·이어보기는 서버 응답보다 먼저 로컬에 기록한다.')
box(40,155,150,78,'사용자 변경','찜 · 최근 검색\n재생 위치')
box(232,155,160,78,'DurableMutationStore','MainActor 직렬화\n현재 revision 읽기',size=12)
arrow([(190,194),(232,194)])
boundary(435,141,365,219,'BEGIN IMMEDIATE → COMMIT / 실패 시 ROLLBACK')
box(451,162,332,57,'metadata','deviceID · nextSequence · revision · 승인 정보',size=12)
box(451,229,332,57,'local_values','화면 projection: key / value BLOB',size=12)
box(451,296,332,57,'outbox','FIFO 순서 · 원본 mutation ID / payload',size=12)
arrow([(392,194),(435,194)])
box(40,270,352,90,'COMMIT 성공 뒤 화면에 반영','중간 쓰기 실패는 세 테이블 모두 롤백한다.\nUInt64 순번·revision은 Codable로 보존한다.\n손상·미지원 schema를 빈 DB로 초기화하지 않는다.',fill=BLUE,size=13)
arrow([(435,324),(392,324)],both=False)
box(435,377,365,70,'동기화는 별도 수명','같은 ID로 FIFO 재전송 → ACK 후 outbox 제거\n충돌은 revision 정책, 로그아웃은 늦은 ACK 차단',size=12)
arrow([(617,360),(617,377)])
text(40,425,'기존 설치 데이터 이전',12,TEAL)
for x,t,b in [(40,'기존 JSON','scope·순서·ID 검사'),(237,'SQLite 커밋','기존 값과 요청 ID 유지'),(434,'DB 다시 읽기','이전 결과 검증'),(631,'JSON 정리','다음 실행은 DB 우선')]:
    box(x,457,169,67,t,b,size=12)
for x in (209,406,603):arrow([(x,491),(x+28,491)])
source('그림 3. 실제 schema와 이전 순서. 다운로드 metadata는 별도 journal. 근거: ADR 0030 / SQLiteMigrationTests.')

# 4. Source selection and ownership, separate from observed state.
page('04 PLAYBACK PATH','재생 진입 경로와 플레이어 수명','PlaybackModel은 플레이어 화면에, 저장 파일은 계정·프로필·작품·소스에 귀속된다. 홈 이어보기는 유효한 저장본을 우선한다.')
for x,t,b in [(40,'홈 이어보기','저장된 위치로 시작'),(320,'작품 상세','재생 소스 선택'),(600,'다운로드 목록','오프라인 저장 파일')]:box(x,143,200,65,t,b,fill=BLUE)
for x in (140,420,700):arrow([(x,208),(x,244)])
box(40,244,760,56,'재생 식별자와 소스 확인','account / profile / title / source · 바뀐 영상의 진도를 다른 영상에 적용하지 않음',size=13)
box(40,346,230,76,'유효한 저장 파일','HLS .movpkg 또는 MP4\n재생 시 파일 lease 획득')
box(328,346,184,76,'권한 확인','Mock grant 만료·키 검사\n실패 시 유한 수동 재시도')
box(570,346,230,76,'네트워크 / 번들 소스','카탈로그 HLS·MP4 URL\n기본 데모는 앱 번들 파일')
arrow([(155,300),(155,346)]);label_at(155,315,'저장본이 유효함')
arrow([(685,300),(685,346)]);label_at(685,315,'그 밖의 소스')
arrow([(270,384),(328,384)]);arrow([(570,384),(512,384)])
box(328,467,184,61,'AVPlayer','하나의 현재 item / generation',fill=BLUE,size=13)
arrow([(420,422),(420,467)])
box(40,467,230,61,'주기적 시간 관측','하단 시간 갱신 · SQLite 진도 저장',size=12)
arrow([(328,496),(270,496)])
box(570,467,230,61,'종료·프로필 변경·로그아웃','Task / observer / PiP / lease 정리',size=12)
arrow([(570,496),(512,496)],color=RUST)
source('그림 4. 실제 재생 경로. 스트리밍·저장 재생의 권한 정책은 Mock이며 FairPlay 라이선스 서버는 없다.')

# 5. Reduced state machine with explicit scope, full graph remains in Mermaid.
page('05 PLAYER STATES','재생 상태와 실패 복구 경계','관측 상태는 PlaybackDiagnostics, 실제 player·Task·observer 수명은 PlaybackModel이 관리한다.')
boundary(180,147,485,277,'활성 재생 상태')
box(40,185,110,58,'idle','재생 없음',size=13)
box(201,185,111,58,'preparing','권한·소스 준비',size=12)
box(361,185,111,58,'ready','item 준비됨',size=13)
box(521,185,111,58,'playing','재생 관측',size=13)
box(700,185,101,58,'ended','종료 관측',size=13)
for a,b in [(150,201),(312,361),(472,521),(632,700)]:arrow([(a,214),(b,214)])
label_at(666,195,'종료',9)
box(201,350,111,58,'paused','일시 정지',size=13)
box(361,350,111,58,'buffering','데이터 대기',size=12)
box(521,350,111,58,'seeking','위치 이동',size=13)
arrow([(555,243),(555,279),(256,279),(256,350)],both=True)
arrow([(577,243),(577,297),(416,297),(416,350)],both=True)
arrow([(610,243),(610,350)],both=True)
label_at(256,313,'pause / play',9)
label_at(416,313,'stall / 회복',9)
label_at(610,313,'seek / 완료',9)
arrow([(750,243),(750,378),(632,378)])
label_at(718,349,'다시 재생',9)
box(40,463,140,63,'failed','권한 또는 player 오류',fill=WARM,size=13)
arrow([(180,391),(110,391),(110,463)],color=RUST)
label_at(109,429,'활성 상태 오류',9,RUST)
arrow([(40,494),(22,494),(22,133),(256,133),(256,185)],color=RUST,dashed=True)
label_at(107,124,'수동 재시도: 새 시도',9,RUST)
box(230,453,571,75,'닫기 · 프로필 변경 · 로그아웃 → idle','이전 item / generation 콜백은 무시한다. 탐색 완료도 새 탐색을 덮지 않는다.\n수동 재시도는 3회. 종료된 시도에 늦게 온 오류로 실패 화면을 다시 띄우지 않는다.',fill=BLUE,size=12)
arrow([(420,424),(420,453)],color=MUTED)
source('그림 5. 대표 전이. ready 분기·paused/buffering/seeking 간 모든 전이는 Docs/States/PLAYER.md에 수록했다.')

# 6. Native download state and resource budget side by side.
page('06 DOWNLOAD STATES','다운로드 상태와 기기 전체 예산','OfflineDownloadStore.shared가 OS 전송 세션에 재연결한다. 취소 후 늦은 완료는 상태나 알림으로 되돌리지 않는다.')
box(40,159,120,66,'queued','대기',size=13)
box(224,159,125,66,'downloading','실제 전송',size=12)
box(409,159,124,66,'complete','파일 검증·저장',size=13)
arrow([(160,191),(224,191)]);arrow([(349,191),(409,191)])
box(40,310,120,66,'failed','실패 기록 유지',fill=WARM,size=13)
box(224,310,125,66,'paused','예약·자리 유지',size=13)
box(409,310,124,66,'expired','새 재생 차단',fill=WARM,size=13)
arrow([(274,225),(274,310)],both=True);label_at(274,266,'pause / resume',9)
arrow([(471,225),(471,310)]);label_at(471,266,'완료 후 7일',9)
arrow([(224,206),(193,206),(193,276),(100,276),(100,310)],color=RUST)
label_at(120,256,'전송·공간 오류',9,RUST)
arrow([(65,310),(65,225)],color=RUST,dashed=True);label_at(65,242,'새 작업',9,RUST)
box(224,447,125,66,'removing','전송 중 취소 기록',size=12)
arrow([(286,376),(286,447)]);label_at(286,405,'취소 / 로그아웃',9)
arrow([(349,210),(371,210),(371,435),(318,435),(318,447)])
box(40,447,120,66,'기록 삭제','잔여 파일 정리 후',size=12)
box(409,447,124,66,'파일·기록 삭제','수동 삭제 / LRU',size=12)
arrow([(224,480),(160,480)],color=MUTED)
arrow([(100,376),(100,447)],color=MUTED)
arrow([(471,376),(471,447)])
C.setStrokeColor(HexColor(LINE));C.line(553,H-141,553,H-525)
box(577,145,223,206,'전체 다운로드 예산 1GB','모든 프로필의 파일·예약량 합계\n\n동시 전송 최대 2개\n작업당 초기 예약 최소 500MB\n예약량은 파일 한 편의 고정 상한이 아님\n\n현재 작업 허용량 = 전체 1GB\n- 다른 파일·다른 작업 예약량',fill=BLUE,size=14)
box(577,372,223,148,'완료·정리 때 다시 확인','완료 시 실제 파일 크기 반영\n고정·재생 중인 파일은 LRU 보호\n만료 후 재다운로드는 새 UUID\n취소·로그아웃은 완료 알림 억제\nOS의 순간 디스크 상한을 보장하지 않음',size=12)
source('그림 6. 대표 전이와 예산 정책. 제거 실패·복원 경로를 포함한 전체 상태도: Docs/States/DOWNLOAD.md.')

# 7. Admin actual flow with opt-in local compression boundary.
page('07 ADMIN & MEDIA','관리자 업로드에서 앱 공개까지','원본 업로드 한도는 5GB다. 앱의 오프라인 다운로드 예산 1GB와 서로 다른 정책이다.')
box(40,151,200,77,'MP4 선택','드래그 앤 드롭 / 파일 선택\n기존 업로드 다시 연결 가능',fill=BLUE)
box(320,151,200,77,'파일·작품 정보 검증','MP4 형식 · 크기 · 필수 정보\nURL 없는 새 작품도 시작 가능')
box(600,151,200,77,'비공개 초안 저장','새 작품 ID 확보\n관리자 인증·규칙 검사')
arrow([(240,189),(320,189)]);arrow([(520,189),(600,189)])
box(600,314,200,83,'Storage 업로드','videos/{작품ID}/{고유ID}.mp4\n진행률 · 취소 · 전송 완료',fill=BLUE,size=13)
arrow([(700,228),(700,314)]);label_at(700,267,'원본 또는 완성된 압축본')
box(320,314,200,83,'영상 URL 연결·공개 저장','비공개 작품은 URL 자동 저장\n공개·영상 교체는 저장 후 반영',size=12)
box(40,314,200,83,'iOS 카탈로그 갱신','홈·검색·상세 반영\nHLS / MP4 스트리밍 재생',fill=BLUE,size=13)
arrow([(600,355),(520,355)]);label_at(560,335,'완료 URL',9)
arrow([(320,355),(240,355)]);label_at(280,335,'공개 조회',9)
box(40,452,480,70,'2GB 이상: 압축 계획 선택 → Mac에서 압축','원본 40% / 1GB 목표 / 화질 우선 / 원본 업로드. 예상치는 안내이며 보장값이 아니다.\n실제 압축 파일을 다시 선택해 업로드한다. 웹·서버 자동 압축이나 HLS 변환은 없다.',fill=PALE,size=12)
arrow([(420,228),(420,267),(22,267),(22,487),(40,487)],dashed=True,color=MUTED)
label_at(140,252,'선택 사항',9)
box(570,452,230,70,'공개 취소 ≠ 파일 접근권 폐기','비공개여도 토큰 URL은 유지\n이전 파일 자동 삭제 없음',fill=WARM,size=12)
source('그림 7. 운영 중인 관리자 흐름. 장시간 영상 업로드는 사용자가 진행하며 과제 기본 fixture에는 포함하지 않는다.')

# 8. Evidence and remaining device boundaries, loaded from the audit rather than guessed.
audit=json.loads((ROOT/'Docs/Measurements/Assignment-Audit-2026-11-06/checklist.json').read_text())
complete,remaining=audit['complete'],audit['remaining']
proof_path=ROOT/'Docs/Measurements/Final-Gaps-2026-11-06/evidence.json'
proof=json.loads(proof_path.read_text()) if proof_path.exists() else {}
ci=proof.get('ci',{})
if proof:
    assert proof['app_code'] == APP_CODE, 'PDF app code must match the validation evidence'
    assert audit['app_commit'] == APP_CODE, 'PDF app code must match the assignment audit'
status='성공 확인' if ci.get('conclusion')=='success' else '실행 결과 확인 중'
smoke=f"새 시뮬레이터 smoke {ci['clean_reproduction_seconds']}초 / 600초" if ci.get('conclusion')=='success' else '새 시뮬레이터 600초 smoke gate'
page('08 VERIFICATION','검증 근거와 아직 남아 있는 경계','자동 테스트의 성공, 사용자의 실기기 확인, Instruments의 성능 측정은 서로 다른 근거로 기록한다.')
text(40,136,f'앱 코드 {APP_SHORT} → GitHub Actions / '+status,13,TEAL)
box(40,174,240,129,'Core / HTTP / chaos','XCTest 31 + Swift Testing 247\n카오스 3종 각 1,000시드\nSIGKILL 2회 / 100건 복구\n인증 만료·로그아웃·충돌 경계',fill=BLUE,size=14)
box(300,174,240,129,'iOS playback','재생·권한·콜백 경계 25개\nF10 콜백 순서 검증\n서명 없는 Release 빌드\n물리 기기 테스트와 구분',fill=BLUE,size=14)
box(560,174,240,129,'App / native UI',f'빌드·로그인·재생 + 경계 UI 9개\nF06/F09·정상 다운로드 UI 3개\n{smoke}\n테스트 누락·skip은 PASS 아님',fill=BLUE,size=14)
text(40,328,'실기기 결과가 필요한 3항목',13,RUST)
box(40,360,240,90,'VoiceOver 전체 조작','탐색 → 상세 → 재생 → 자막 → 중단\n자동 접근성 검사 통과\n실제 음성·초점 확인 대기',fill=WARM,size=12)
box(300,360,240,90,'백그라운드 다운로드 전력','전송·백그라운드·완료 표식 추가\nPower Profiler 기록 대기',fill=WARM,size=12)
box(560,360,240,90,'동일 조건 C / PV 비교','10초 준비 + 30초 자동 5왕복\n실제 표시 프레임의 전후 결과 대기',fill=WARM,size=12)
text(40,468,f'과제 확인 단위 {complete}/79 완료 ({complete/79:.1%}) · {remaining}/79 남음 ({remaining/79:.1%})',16,TEAL)
para(40,499,760,'동일 가중치의 확인 단위이며 점수·공수 비율이 아니다. 과거 홈 표시 간격 p50 12.503ms / p95 25.005ms는 확보했지만 전후 개선의 증거는 아니다. 원격 UI의 간헐적 실패와 재검증 이력은 Final-Gaps 보고서에 함께 남겼다.',10,MUTED,maxh=31)
source('근거: ASSIGNMENT_AUDIT / CI_VALIDATION / Final-Gaps 보고서 / C4 보고서. 실기기 순서: Docs/FINAL_DEVICE_QA.md.')

C.save()
print(OUT)
print(f'{PAGE} pages; app code {APP_SHORT}; audit {complete}/79')
