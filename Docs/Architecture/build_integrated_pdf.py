"""Fourteen-page architecture, preserving the supplied integrated document's layout.
Requires ReportLab and Pretendard Regular/Bold (set STREAMLAB_FONT_DIR if needed).
Usage: python3 Docs/Architecture/build_integrated_pdf.py
"""
from pathlib import Path
import os, html, json, math
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import Paragraph
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'Docs/Architecture/streamlab-architecture-revision-2026-11-07.pdf'
APP='9a4d39539bf7afaad759bacf8966d650b0477970'
PROOF=json.loads((ROOT/'Docs/Measurements/Final-Gaps-2026-11-06/evidence.json').read_text())
AUDIT=json.loads((ROOT/'Docs/Architecture/artifacts-2026-11-07.json').read_text())
assert PROOF['app_code']==APP and AUDIT['app_commit']==APP
AUDIT=AUDIT['assignment_units']
FONT=Path(os.environ.get('STREAMLAB_FONT_DIR',str(Path.home()/'Library/Fonts')))
for name,filename in [('KR','Pretendard-Regular.ttf'),('KB','Pretendard-Bold.ttf')]:
    pdfmetrics.registerFont(TTFont(name,str(FONT/filename)))
W,H=841.89,595.28
BG,INK,MUTED,LINE='#F7FAFD','#1B2C43','#60758F','#D9E4F2'
BLUE,TEAL,CYAN,AMBER,RED='#295CF1','#009786','#1383AC','#BD7829','#BB4254'
PAGE=0
C=canvas.Canvas(str(OUT),pagesize=(W,H),pageCompression=1,invariant=1)
C.setTitle('StreamLab 통합 기술 아키텍처')
C.setAuthor('StreamLab')
C.setSubject('시스템·모듈·저장·동기화·재생·다운로드 / 앱 9a4d395 / 2026-11-07')

def txt(x,y,s,size=10,color=INK,bold=False):
    C.setFillColor(HexColor(color));C.setFont('KB' if bold else 'KR',size)
    C.drawString(x,H-y-size*.82,s)

def para(x,y,w,s,size=10,color=INK,bold=False,maxh=None):
    style=ParagraphStyle('body',fontName='KB' if bold else 'KR',fontSize=size,leading=size*1.45,
                         textColor=HexColor(color),wordWrap='CJK')
    p=Paragraph(html.escape(s).replace('\n','<br/>'),style);_,h=p.wrap(w,1000)
    if maxh is not None and h>maxh+.1:raise ValueError((PAGE,s,h,maxh))
    if y+h>546:raise ValueError(('footer overflow',PAGE,s,y+h))
    p.drawOn(C,x,H-y-h);return h

def card(x,y,w,h,title,body='',color=BLUE,size=12,body_size=10,fill='#FFFFFF'):
    C.setFillColor(HexColor(fill));C.setStrokeColor(HexColor(LINE));C.setLineWidth(1)
    C.roundRect(x,H-y-h,w,h,10,fill=1,stroke=1)
    C.setStrokeColor(HexColor(color));C.setLineWidth(3);C.setLineCap(1)
    C.line(x+12,H-y-10,x+w-12,H-y-10);C.setLineCap(0)
    th=para(x+13,y+22,w-26,title,size,INK,True,maxh=h-28)
    if body:para(x+13,y+28+th,w-26,body,body_size,MUTED,maxh=h-37-th)

def panel(x,y,w,h,title,body,color=TEAL,fill='#EAF6F3',size=10):
    C.setFillColor(HexColor(fill));C.setStrokeColor(HexColor(LINE));C.setLineWidth(.7)
    C.roundRect(x,H-y-h,w,h,7,fill=1,stroke=1)
    th=para(x+12,y+10,w-24,title,11,color,True,maxh=h-15)
    if body:para(x+12,y+15+th,w-24,body,size,INK,maxh=h-22-th)

def line(points,color=BLUE,dashed=False,width=1.25,head=True,both=False):
    C.setStrokeColor(HexColor(color));C.setFillColor(HexColor(color));C.setLineWidth(width)
    C.setDash(3,3) if dashed else C.setDash()
    p=C.beginPath();p.moveTo(points[0][0],H-points[0][1])
    for x,y in points[1:]:p.lineTo(x,H-y)
    C.drawPath(p);C.setDash()
    ends = [points[-2:]] if head else []
    if both: ends.append([points[1],points[0]])
    for a,b in ends:
        ang=math.atan2(b[1]-a[1],b[0]-a[0]);ux,uy=math.cos(ang),math.sin(ang)
        x,y=b;p=C.beginPath();p.moveTo(x,H-y)
        p.lineTo(x-5*ux+2.5*uy,H-(y-5*uy-2.5*ux))
        p.lineTo(x-5*ux-2.5*uy,H-(y-5*uy+2.5*ux));p.close();C.drawPath(p,fill=1,stroke=0)

def label(x,y,s,color=MUTED,size=9):
    w=pdfmetrics.stringWidth(s,'KR',size);C.setFillColor(HexColor(BG))
    C.rect(x-w/2-3,H-y-size-2,w+6,size+4,fill=1,stroke=0);txt(x-w/2,y,s,size,color)

def page(title,subtitle):
    global PAGE
    if PAGE:C.showPage()
    PAGE+=1
    C.setFillColor(HexColor(BG));C.rect(0,0,W,H,fill=1,stroke=0)
    C.setFillColor(HexColor(INK));C.rect(0,H-7,W,7,fill=1,stroke=0)
    txt(38,27,'STREAMLAB  /  IOS ENGINEERING',10,BLUE,True)
    txt(625,28,'ARCHITECTURE  |  2026.11.07',8.5,MUTED)
    txt(38,57,title,24,INK,True);para(39,91,760,subtitle,10,MUTED,maxh=29)
    C.setStrokeColor(HexColor(LINE));C.setLineWidth(.6);C.line(38,48,W-38,48)
    txt(39,560,'앱 코드 9a4d395  ·  통합 기술 문서  ·  구현 / Mock / 실기기 검증 구분',8,MUTED)
    txt(763,560,f'{PAGE:02} / 14',8.5,MUTED,True)
    C.bookmarkPage(f'p{PAGE}');C.addOutlineEntry(title,f'p{PAGE}',0)
    C.linkURL(f'https://github.com/KyungHoon416/streamlab-ios/tree/{APP}',(38,20,390,38),thickness=0)

def note(s,y=522):para(40,y,760,s,8.5,MUTED,maxh=23)

def state(x,y,w,title,color=BLUE):
    C.setFillColor(HexColor('#FFFFFF'));C.setStrokeColor(HexColor(color));C.setLineWidth(1.4)
    C.roundRect(x,H-y-47,w,47,8,fill=1,stroke=1)
    tw=pdfmetrics.stringWidth(title,'KB',12);txt(x+(w-tw)/2,y+18,title,12,color,True)

# 1 - Same cover composition; concrete title instead of promotional slogans.
page('STREAMLAB  |  통합 기술 아키텍처','iOS 스트리밍 앱의 구성요소 · 데이터 흐름 · 장애 복구')
card(40,143,355,312,'SWIFT 6  /  iOS 18+','',size=12)
para(59,200,310,'화면에서 저장소까지\n데이터가 흐르는 구조',27,INK,True,maxh=90)
para(59,309,305,'실제 패키지 의존성과 세션 수명을 따라\nFirebase 운영 연결과 Mock 검증을 구분한다.',11,MUTED,maxh=43)
for y,n,s in [(380,'01','시스템 / 관리자 / 앱 경계'),(405,'02','모듈 의존성 / 화면과 세션 소유권'),(430,'03','SQLite / 동기화 / 재생 / 다운로드')]:
    txt(59,y,n,10,BLUE,True);txt(89,y,s,10)
for y,title,body,col in [(156,'SwiftUI App · AppRootView','프로필 / 홈 / 검색 / 상세 / 재생 / 다운로드',BLUE),
    (275,'StreamLabUI','CatalogFeature · ProfileFeature · DesignSystem',CYAN),
    (394,'StreamLabCore','Presentation · CatalogData · Domain · CSQLite',TEAL)]:
    card(480,y,321,73,title,body,col,13,10)
line([(640,229),(640,275)]);line([(640,348),(640,394)],TEAL)
txt(488,487,'Firebase 콘텐츠 공급  ·  Mock 계정·정합성·권한 검증',10,AMBER,True)
note('시스템 경계에서 시작해 모듈·저장·동기화·재생·다운로드를 살펴보고, 마지막에 검증 근거와 한계를 정리한다.')

# 2
page('01  시스템 구성 / 배포 경계','Firebase는 실제 콘텐츠 공급을 맡고, 앱 계정·동기화·재생 권한은 Mock으로 검증한다.')
card(40,145,220,130,'관리자 웹','Firebase Hosting\nGoogle 허용 계정 로그인\n작품 초안 · 공개 전환 · MP4 업로드')
card(310,145,220,130,'Firebase 운영 콘텐츠','Auth: 관리자 인증\nFirestore: 공개 작품·영상 URL\nStorage: MP4 파일',TEAL)
card(580,145,220,130,'iOS 앱','SwiftUI · AVPlayer\n공개 작품 REST 조회\nHTTPS HLS / MP4 재생',CYAN)
line([(260,202),(310,202)]);label(285,180,'쓰기·인증',size=8)
line([(530,202),(580,202)],TEAL);label(555,180,'HTTPS',size=8)
card(40,350,350,112,'iPhone 로컬 저장','SQLite: 찜·검색·진도 / outbox\nJSON: 다운로드 상태 저널\n.movpkg / MP4 · Keychain · UserDefaults',CYAN)
card(450,350,350,112,'Mock / loopback HTTP','앱 사용자 인증 · mutation ACK · revision\n충돌·재시도 · 재생 권한·카오스 주입\n실제 운영 사용자 백엔드는 아님',AMBER)
line([(690,275),(690,315),(215,315),(215,350)],CYAN)
line([(755,275),(755,350)],AMBER,True);label(755,302,'앱 내부 Mock',size=8)
panel(40,480,760,54,'배포 경계','운영 Firebase 카탈로그와 별개로, 운영 계정 동기화·FairPlay 라이선스 서버는 구현하지 않았다.',AMBER,'#FFF5E8',9.5)

# 3
page('02  작품 등록 → 공개 → 앱 재생','URL이 없는 새 작품도 비공개 초안으로 시작하고, 업로드 완료 주소를 연결해 공개한다.')
for i,(t,b) in enumerate([('① 관리자','Google 허용 계정\n로그인·수정 권한'),('② 작품 초안','Firestore 비공개\n작품 ID 확보'),('③ 파일 업로드','MP4 → Storage\n진행률·취소'),('④ 공개 저장','영상 주소 연결\n공개 플래그 저장'),('⑤ 앱 갱신','공개 REST 목록\n홈·검색·상세')]):
    x=40+i*155;card(x,155,140,115,t,b,TEAL if i%2 else BLUE,11,10)
    if i<4:line([(x+140,210),(x+155,210)],TEAL)
card(40,315,365,136,'관리자 파일 정책','단일 MP4 직접 업로드: 최대 5,000,000,000 bytes\n2GB 이상: 원본 40% / 1GB 목표 / 화질 우선 등\n예상 용량을 안내하고 실제 압축은 Mac에서 수행\n완성된 압축 파일을 다시 선택해 업로드',TEAL,12,10)
card(435,315,365,136,'공개·영상 교체 경계','HTTPS HLS URL도 직접 등록 가능\nMP4 → HLS 서버 변환 없음\n작품 ID + 소스 ID로 이어보기 위치를 구분\n비공개 전환만으로 기존 토큰 URL이 폐기되지는 않음',AMBER,12,10)
panel(40,475,760,54,'과제 기본 카탈로그와 분리','기본 Scheme: Mock 2,000개. StreamLab-Firebase: 공개 카탈로그 최대 200개. 업로드 경로: videos/{작품ID}/{UUID}.mp4',BLUE,'#EDF3FF',9.5)

# 4 - Selected edges plus complete adjacency table eliminates spaghetti and missing edges.
page('03  Swift Package 의존성 그래프','왼쪽은 대표 의존 경로, 오른쪽은 빠짐없이 대조한 직접 의존 목록이다. 화살표는 의존하는 쪽 → 제공하는 쪽.')
txt(40,134,'대표 경로',11,BLUE,True);txt(490,134,'전체 직접 의존 목록',11,BLUE,True)
for y,a,b,col in [(164,'CatalogFeature','Presentation',BLUE),(270,'DesignSystem','CatalogData',CYAN),(376,'ProfileFeature','Domain',TEAL)]:
    card(40,y,178,71,a,'StreamLabUI',col,12,9)
    card(280,y,178,71,b,'StreamLabCore',col,12,9)
    line([(218,y+35),(280,y+35)],col)
card(280,470,178,49,'CSQLite','',AMBER,11)
line([(458,199),(473,199),(473,494),(458,494)],AMBER)
rows=[('App','CatalogFeature · ProfileFeature\nDesignSystem · Presentation\nCatalogData · Domain'),
('CatalogFeature','CatalogData · DesignSystem\nPresentation · Domain'),
('ProfileFeature','DesignSystem · Domain'),('DesignSystem','CatalogData · Domain'),
('Presentation','Domain · CSQLite'),('CatalogData','Domain'),('Domain / CSQLite','추가 내부 타깃 의존 없음')]
y=159
for i,(name,deps) in enumerate(rows):
    h=61 if i==0 else (48 if i==1 else 43)
    C.setFillColor(HexColor('#EDF3FF' if i%2==0 else '#FFFFFF'));C.rect(490,H-y-h,310,h,fill=1,stroke=0)
    para(500,y+10,103,name,9.5,INK,True,maxh=h-14)
    para(612,y+9,180,deps,9,MUTED,maxh=h-13);y+=h
note('목록은 project.yml과 두 Package.swift 기준. StreamLab 접두사는 생략했다. Playback/Download는 CatalogFeature 내부이며 별도 타깃이 아니다.')

# 5
page('04  SwiftUI 화면 / 세션의 소유권','AppRootView가 화면을 조립하고, CatalogSession이 선택한 계정·프로필의 저장소와 작업 수명을 묶는다.')
card(40,145,240,85,'AppRootView','앱 시작 · 인증 복원 · 카탈로그 선택\n네트워크 관찰 · 탭 / 프로필 분기')
card(340,145,460,85,'CatalogSession · 새 UUID','account / profile · repository · 찜/진도/검색/언어 Store\n활성 상태 확인 · 동기화 Task 및 플레이어 등록',TEAL)
line([(280,185),(340,185)])
line([(570,230),(570,275),(344,275)],TEAL,head=False)
for i,(title,body) in enumerate([('HomeView','추천 · 이어보기'),('SearchView','검색 · 결과'),('DetailView','상세 · 회차'),('PlaybackView','재생 컨트롤'),('DownloadsView','오프라인 목록')]):
    x=172+i*128;card(x,320,116,84,title,body,TEAL,10.5,9.5)
    center=x+58;line([(center,275),(center,320)],TEAL)
line([(230,275),(742,275)],TEAL,head=False)
card(40,320,116,84,'ProfileFeature','프로필 선택',BLUE,10.5,9.5)
line([(98,230),(98,320)]);label(98,277,'App 조립',size=8.5)
panel(40,437,365,78,'프로필 변경','이전 세션 invalidate → 저장·동기화 수명 정리 → 새로운 세션 ID. 늦은 결과는 새 프로필 화면에 반영하지 않는다.',TEAL,size=10)
panel(435,437,365,78,'화면과 리소스 수명','재생 종료 시 observer·Task·lease를 해제한다. 백그라운드 다운로드는 화면 밖에서도 계속되며 별도 소유권 검사를 한다.',CYAN,'#EDF6FA',10)

# 6
page('05  로컬 데이터 계층 · 저장 경계','찜·검색·진도와 전송 큐는 SQLite에 함께 커밋하고, 다운로드 복원 정보와 미디어 본체는 따로 저장한다.')
card(40,145,215,92,'UI / MainActor Store','찜 · 최근 검색 · 이어보기\n로컬 커밋 성공 뒤 화면 반영')
card(315,145,215,92,'DurableMutationStore','계정 디렉터리 / 프로필 DB\nSQLiteMutationDatabase',TEAL)
card(590,145,210,92,'Sync Transport','Retry / ACK / revision\nMock · loopback HTTP',CYAN)
line([(255,190),(315,190)],TEAL);line([(530,190),(590,190)],TEAL)
card(40,300,215,150,'다운로드 전용 파일','offline-downloads.json\n소유자 · 상태 · 만료 · 스냅샷\n\n.movpkg / MP4 본체\nOS 전송·복원 메타데이터와 분리',CYAN,12,10)
card(315,280,250,183,'profile.sqlite','metadata: deviceID / revision / nextSequence\n\nlocal_values: key / value BLOB\n화면용 projection\n\noutbox: mutation / FIFO / 원본 요청 ID',TEAL,12,9.5,fill='#F0FAF7')
line([(422,237),(422,280)],TEAL)
card(605,300,195,150,'시스템 저장 분리','Keychain: 로그인 자격\nUserDefaults: 언어·환경\n로그아웃 복구 표식\n지원 범위의 파일 보호',AMBER,12,10)
panel(40,480,760,54,'원자 커밋과 기존 설치 이전','BEGIN IMMEDIATE → 세 테이블 갱신 → COMMIT. JSON 검증 → DB 저장·재읽기 → JSON 제거. 현재 쓰기는 MainActor 동기 I/O.',TEAL,size=9.5)

# 7
page('06  Local-first 동기화 · 장애 복구','사용자의 변경을 먼저 영속화하고 같은 mutation ID로 재전송한다. 서버 ACK 이전에도 로컬 화면을 사용할 수 있다.')
xs=[85,250,415,580,745]
for x,t in zip(xs,['사용자 / SwiftUI','MainActor Store','SQLite DB','Retry Transport','Mock HTTP']):
    panel(x-62,137,124,36,t,'',BLUE,'#EDF3FF')
    line([(x,180),(x,414)],'#ACC3DE',True,.6,False)
for a,b,y,t,col in [(0,1,197,'① 찜 / 진도 / 검색',BLUE),(1,2,224,'② BEGIN + 값/outbox 저장',TEAL),
 (2,1,251,'③ COMMIT 성공',TEAL),(1,0,278,'④ 화면 반영',TEAL),(1,3,306,'⑤ 같은 idempotencyKey',TEAL),
 (3,4,334,'⑥ 전송 / revision',BLUE),(4,3,362,'⑦ ACK 또는 409 / 429',BLUE),(3,1,390,'⑧ ACK / 충돌 / 재시도',BLUE)]:
    line([(xs[a]+(10 if b>a else -10),y),(xs[b]+(-10 if b>a else 10),y)],col)
    label((xs[a]+xs[b])/2,y-15,t,col,8.5)
for x,y,t,b in [(40,431,'409 Conflict','서버 revision / snapshot 기준 수렴'),(430,431,'429 / 503 / Timeout','Retry-After + 제한된 backoff / jitter'),
 (40,477,'프로필 전환','세션 ID 확인 → 늦은 응답 폐기'),(430,477,'SIGKILL 재시작','outbox 보존 → 같은 key로 재전송')]:
    panel(x,y,370,38,t+'  ·  '+b,'',TEAL,'#FFFFFF')
note('운영 다중기기 API가 아닌 Mock + loopback HTTP 계약 검증이다. 로컬 쓰기 실패 시 성공 UI나 전송을 진행하지 않는다.',529)

# 8
page('07  Playback 구성요소 / 데이터 흐름','한 PlaybackModel 세션에서 소스·권한·플레이어 관찰·탐색·진도 저장의 수명을 관리한다.')
card(40,145,215,90,'PlaybackView','SwiftUI 컨트롤 · 자막 / 오디오\n탐색 preview와 실제 시간 분리')
card(315,145,215,90,'PlaybackModel','generation · source identity\ngrant · seek · observer / Task',TEAL)
card(590,145,210,90,'AVPlayer / Item','HLS / MP4 / 저장 파일\ntime / control / status 관찰',CYAN)
line([(255,190),(315,190)]);line([(530,190),(590,190)],TEAL)
line([(422,235),(422,272)],TEAL,head=False);line([(128,272),(710,272)],TEAL,head=False)
for x,t,b in [(40,'Mock Entitlement','시작·재개·탐색·복귀\ngrant 만료 / 키 오류'),(235,'ProgressStore','계정·프로필·작품·소스\nSQLite 진도 저장'),(430,'LanguageStore','자막·오디오 선택\n프로필별 설정'),(625,'OfflineDownloadStore','유효한 동일 소스\n파일 lease 획득·반환')]:
    card(x,310,175,104,t,b,TEAL,11,10);line([(x+87,272),(x+87,310)],TEAL)
panel(40,440,760,78,'OS 통합 및 최근 보완','PiP · Now Playing · AudioSession · MediaReset · QoE. 회전 요청은 화면 표시 완료 후 실행한다.\nDebug UI 검사는 자체 600초 fixture를 선택해 느린 CI 중 자연 종료를 방지한다. 기본 영상·종료 동작은 변경하지 않았다.',BLUE,'#EDF3FF',10)

# 9
page('08  Player 상태 머신 · 취소 경계','대표 관측 상태 전이. 실제 리소스 수명은 PlaybackModel, 관측 전이는 PlaybackDiagnostics가 관리한다.')
C.setStrokeColor(HexColor(LINE));C.setLineWidth(.8);C.setDash(3,3)
C.roundRect(184,H-370,486,222,8,fill=0,stroke=1);C.setDash()
label(430,135,'활성 재생 상태',MUTED,8.5)
for x,t in [(40,'idle'),(200,'preparing'),(360,'ready'),(520,'playing'),(680,'ended')]:state(x,162,120,t)
for x in [160,320,480,640]:line([(x,186),(x+40,186)])
for x,t in [(200,'paused'),(370,'buffering'),(540,'seeking')]:state(x,310,120,t,TEAL)
for x,y in [(260,245),(430,268),(600,291)]:
    line([(555+(x-260)/10,209),(555+(x-260)/10,y),(x,y),(x,310)],TEAL,both=True)
label(260,280,'pause / play',TEAL);label(430,292,'stall / 회복',TEAL);label(600,280,'seek / 완료',TEAL)
line([(740,209),(740,333),(660,333)],AMBER);label(740,265,'다시 재생',AMBER,8.5)
state(40,414,120,'failed',RED)
line([(184,333),(179,333),(179,390),(100,390),(100,414)],RED)
label(103,365,'활성 상태 오류',RED,8.5)
line([(40,438),(24,438),(24,137),(260,137),(260,162)],RED,True)
label(119,122,'수동 재시도: 새 시도',RED,8.5)
panel(200,411,600,85,'닫기 / 프로필 변경 / 로그아웃 → idle','Task·observer·item·lease 정리와 generation 무효화. 이전 item / seek 콜백은 새 세션에 적용하지 않는다.\n수동 재시도는 최대 3회. 네트워크 단절만으로 즉시 failed가 되지는 않는다.',BLUE,'#EDF3FF',10)
note('paused / buffering / seeking에서 playing으로 복귀 가능. 그림은 대표 흐름이며 전체 분기·전이는 Docs/States/PLAYER.md 기준이다.')

# 10
page('09  Offline Download 서비스 구성','OS 네이티브 전송, 기기 전체 예산, 계정·프로필 소유권과 재생 lease를 함께 관리한다.')
card(40,145,210,95,'DownloadsView','시작 · 일시정지 · 재개\n취소 · 삭제 · 상태 표시')
card(315,145,215,95,'OfflineDownloadStore','예산 · 슬롯 · LRU · 만료\n소유권 · lease · 완료 알림',TEAL)
card(590,145,210,95,'OS transfer sessions','HLS: AVAssetDownloadURLSession\nMP4: URLSession',CYAN,12,9.5)
line([(250,190),(315,190)]);line([(530,190),(590,190)],TEAL)
card(40,300,240,115,'오프라인 메타데이터','offline-downloads.json\n계정 / 프로필 / 작품 + 소스\n상태 / 만료 / 작품 스냅샷',TEAL)
card(320,300,230,115,'로컬 미디어 파일','HLS → .movpkg\nMP4 → downloaded .mp4\n완료 후 과제용 이용 기간 7일',TEAL)
card(590,300,210,115,'Background Delegate','OS 백그라운드 이벤트 전달\n세션 재연결 · 완료 처리\n취소 뒤 알림 억제',CYAN)
line([(390,240),(390,270),(160,270),(160,300)],TEAL)
line([(435,240),(435,300)],TEAL);line([(695,240),(695,300)],CYAN)
panel(40,445,365,74,'자동 정리','고정되지 않고 재생 lease가 없는 오래된 완료·만료 파일부터 LRU. 실패 잔여 파일도 정리 전까지 예산에 반영한다.',TEAL,size=10)
panel(435,445,365,74,'소유권과 알림','늦은 완료는 계정·작업 ID·취소 상태를 검사한다. 유효한 완료 알림은 현재 프로필의 다운로드 목록으로 이동한다.',CYAN,'#EDF6FA',10)

# 11 - Normal and exceptional flows separated, no arrows through states.
page('10  Download 상태 머신 · 1GB 예산','정상 전송과 실패·취소 정리를 분리했다. 모든 복원 분기를 포함한 원본 상태도는 Docs/States/DOWNLOAD.md에 둔다.')
for x,t,col in [(40,'queued',BLUE),(250,'downloading',TEAL),(460,'complete',TEAL),(670,'expired',AMBER)]:state(x,160,130,t,col)
for a,b,t in [(170,250,'예산·자리 확보'),(380,460,'파일·예산 검증'),(590,670,'완료 후 7일')]:
    line([(a,183),(b,183)],TEAL);label((a+b)/2,141,t,size=8.5)
state(250,273,130,'paused',CYAN)
line([(290,207),(290,273)],CYAN);line([(340,273),(340,207)],CYAN)
label(268,234,'pause',CYAN,8);label(366,234,'resume',CYAN,8)
panel(40,345,350,113,'실패 / 다시 다운로드','전송·공간 오류, 작업 소실, 파일 손상 → failed\nfailed / expired → 정리·재승인 → 새 UUID의 queued\n재시도는 실패한 OS 작업을 그대로 재사용하지 않는다.',RED,'#FFF4F3',10)
panel(430,273,370,185,'취소 / 로그아웃 / 삭제','전송·일시정지 중 취소 → removing 영속화\n→ OS 취소 콜백·파일 정리 → 기록 삭제\n\n제거 실패 → failed. 늦은 완료를 성공으로 되돌리지 않음.\n완료·만료 파일의 수동 삭제 / LRU는 파일·기록 정리.\n재생 lease 또는 고정 항목은 자동 LRU에서 보호.',AMBER,'#FFF7EC',10)
panel(40,471,760,54,'기기 전체 1GB  ·  모든 프로필 합계','동시 전송 2개 / 작업당 초기 예약 최소 500MB(개별 파일 상한 아님) / 일시정지·제거 중에도 예약·자리 유지',BLUE,'#EDF3FF',10)
note('관리자 업로드 최대 5GB와 별도 정책이다. 앱의 관리 예산이며 OS 순간 디스크 사용량을 강제하는 물리 quota는 아니다.',532)

# 12
page('11  보안 · 프로필 격리 · 취소 규약','관리자 권한, 앱 로그인 자격, 재생 권한을 서로 다른 책임과 수명으로 관리한다.')
for x,t,b,col in [(40,'관리자 인증','Google + Firebase Auth\nFirestore / Storage 규칙\n허용 관리자만 쓰기',BLUE),
 (300,'앱 인증·저장','일반 사용자 인증은 Mock\nKeychain · 로그아웃 복구 표식\nSQLite 계정 / 프로필 범위',TEAL),
 (560,'재생 권한','Mock entitlement / grant\n만료·키 오류 · 유한 재시도\nFairPlay 키 서버 없음',AMBER)]:card(x,145,240,112,t,b,col)
txt(40,280,'Session invalidation',12,TEAL,True)
for i,(t,b) in enumerate([('Profile A','진행 중 Task'),('A → B 전환','기존 세션 무효화'),('오래된 응답','owner / generation 검사'),('반영 차단','B에 A 기록 미노출')]):
    x=40+i*195;panel(x,310,175,68,t,b,TEAL,'#EDF6FA',9.5)
    if i<3:line([(x+175,344),(x+195,344)],TEAL)
panel(40,411,365,104,'진단 로그 범위','오류는 안전한 domain / code 요약을 사용한다.\n재생 상태·시각·시도/소스 식별자 등의 진단값은 남긴다.\n토큰·영상 URL·인증 응답 원문과 구분해 관리한다.',BLUE,'#EDF3FF',10)
panel(435,411,365,104,'운영 보호와의 경계','비공개 전환만으로 Storage token URL은 폐기되지 않는다.\n운영 계정 서버·FairPlay 라이선스·신뢰 시계는 없다.\n과제 Mock 검증을 상용 콘텐츠 보호로 설명하지 않는다.',AMBER,'#FFF5E8',10)

# 13
page('12  QA / Chaos / Observability','동일 앱 코드 9a4d395의 자동 검증과 과거 실기기 측정값을 구분한다. 재검증 이력도 보존한다.')
rows=[('Core / HTTP','XCTest 31 + Swift Testing 247','Mock·loopback HTTP'),('Chaos / 복구','3종 × 1,000 seed · SIGKILL 2회 / 100건','물리 jetsam / ENOSPC 전체 아님'),
 ('iOS / Release','재생·권한·콜백 25개 + Release 빌드','서명 없는 컴파일'),('App / native UI','앱 UI 9개 + 실제 HLS UI 3개','네이티브는 2차 실행 성공'),('README 재현','새 simulator 빌드·로그인·재생 424초','Xcode / runtime 사전 설치')]
for i,(a,b,d) in enumerate([('검증','확인 결과','범위')]+rows):
    y=132+i*35;C.setFillColor(HexColor('#E8EFF8' if i==0 else ('#FFFFFF' if i%2 else '#F0F5FA')))
    C.rect(40,H-y-35,760,35,fill=1,stroke=0)
    for x,w,s in [(50,145,a),(207,330,b),(550,238,d)]:para(x,y+10,w,s,10,INK,i==0,maxh=22)
txt(40,357,f"과제 확인 단위 {AUDIT['complete']}/79 완료 (96.2%) · {AUDIT['remaining']}/79 실기기 대기 (3.8%)",14,TEAL,True)
para(40,385,760,'남음: VoiceOver 전체 조작 / 백그라운드 다운로드 전력 / 통제된 C·PV 표시 프레임 비교.\nCore·재생·앱 UI는 CI 1차, native 다운로드는 2차 성공. 점수·공수 비율이 아니며 이전 실패 원인이 모두 해결됐다는 뜻은 아니다.',10,MUTED,maxh=34)
for x,t,b,col in [(40,'HLS 준비 · 과거 22회','p50 0.742s / p95 1.269s\n실제 첫 화면 표시 TTFF와 구분',BLUE),
 (300,'반복 재생 메모리 · 과거','0회 28.92 → 20회 36.75MiB\n후반 안정 ≠ 누수 부재 증명',TEAL),
 (560,'홈 표시 간격 · 10/31','p50 12.503ms / p95 25.005ms\n통제된 전후 개선 증거는 아님',AMBER)]:card(x,439,240,83,t,b,col,11,9.5)
C.linkURL(PROOF['ci']['url'],(40,H-352,800,H-130),thickness=0)
note('표를 누르면 CI 실행으로 이동한다. 원격 로그·해시·실패 이력: Final-Gaps 보고서. 과거 성능 수치를 최신 빌드의 실측으로 합치지 않는다.',532)

# 14
page('13  코드 위치 · ADR · 제출 경계','그림의 객체와 정책을 소스·검증 문서에 연결한다. 이번 작업은 문서 개정이며 앱 코드는 변경하지 않았다.')
card(40,143,365,212,'Code map / 실제 소스','App/AppRootView.swift\nApp/Application/DownloadBackgroundDelegate.swift\nPackages/StreamLabUI/Package.swift\n  CatalogFeature/State/CatalogSession.swift\n  CatalogFeature/Playback/PlaybackModel.swift\n  CatalogFeature/Downloads/OfflineDownloadStore.swift\nPackages/StreamLabCore/Package.swift\n  Presentation/Sync/DurableMutationStore.swift\n  Presentation/Sync/SQLiteMutationDatabase.swift',BLUE,12,10)
card(435,143,365,212,'Decision / validation map','Docs/ADR/0030-sqlite-local-projection-outbox.md\nDocs/States/PLAYER.md · DOWNLOAD.md\nDocs/CHAOS_ACCEPTANCE.md · CI_VALIDATION.md\nDocs/Measurements/Final-Gaps-2026-11-06/REPORT.md\nDocs/Measurements/C4-2026-10-31/REPORT.md\nDocs/FIREBASE_CATALOG.md\nDocs/FINAL_DEVICE_QA.md\nDocs/ASSIGNMENT_AUDIT_2026-11-06.md',TEAL,12,9.8)
panel(40,380,760,105,'버전과 제출 자료를 구분한다','현재 앱 코드: 9a4d395. 이후 e9b5a09는 문서·검증 근거 정리 커밋이다.\n기존 submission-2026-11-06 태그·영상·ZIP은 보존한다. 현재 구조가 기존 촬영 바이너리에 포함됐다고 표시하지 않는다.\n의존성과 상태 전이는 소스·Package.swift에 대조했다. 성능 수치는 측정 조건과 시점을 함께 읽어야 한다.\n계측·자동 검사 준비가 끝나도 실제 VoiceOver·다운로드 전력·C/PV 비교 결과를 받기 전에는 완료로 세지 않는다.',AMBER,'#FFF5E8',10)
para(40,504,760,'코드 경로는 지면에서 StreamLab 접두사와 Sources 중간 경로를 일부 생략했다. 전체 경로·의존성은 함께 제공하는 Markdown과 저장소에서 확인한다.',9,MUTED,maxh=27)
C.linkURL('https://github.com/KyungHoon416/streamlab-ios/blob/main/Docs/FINAL_DEVICE_QA.md',(435,H-355,800,H-143),thickness=0)
assert PAGE==14
C.save()
print(OUT)
print('14 pages; app '+APP[:7]+'; complete '+str(AUDIT['complete'])+'/79')
