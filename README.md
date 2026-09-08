# Moon Atelier (달빛서재)

**Live:** https://elldia.github.io/Moon_Atelier/

## 한국어

Flutter로 만든 글래스모피즘 스타일의 웹 전자책 리더입니다.

### 지원 파일 형식
- EPUB, PDF, TXT, DOCX, RTF (한글 CP949 인코딩 자동 인식 포함)
- MusicXML / MXL (악보 파일, 오선보로 렌더링)

### 읽기 경험
- 글꼴 선택: 시스템 기본, Noto Sans KR, Pretendard, 마루부리, Noto Serif KR, 나눔고딕, 나눔명조, 고운바탕, 고운돋움, IBM 플렉스 산스
- 글자 굵기, 크기, 자간, 행간, 바깥 여백, 들여쓰기까지 세밀하게 조절 가능
- 배경색 5종 프리셋(화이트/세피아/그레이/다크/블랙) 및 라이트·다크·시스템 테마
- 모든 설정은 홈 화면과 읽는 중 어디서든 즉시 변경 가능
- EPUB·PDF·TXT·RTF·DOCX 전 형식에서 동일한 하단 진행바(클릭 & 드래그로 원하는 위치 이동) 및 진행률 표시
- PDF는 마우스 휠과 터치 핀치줌으로 화면 확대·축소 가능

### 문장 저장 및 탐색
- 텍스트를 드래그해 원하는 색상의 형광펜으로 저장(자주 찾는 글귀 모아보기)
- 원하는 위치를 북마크로 저장하고 목록에서 바로 이동
- 책마다 현재 읽은 글자수 / 전체 글자수 · 진행률(%)을 목록에서 확인

### 서재 관리
- 폴더 생성, 이동, 삭제로 책 정리
- 이름순·등록순·최근 읽은 순 등 다양한 정렬
- 검색 및 다중 선택 삭제(휴지통)
- 파일 등록은 로컬 파일 선택과 클립보드 붙여넣기를 지원(원드라이브·Dropbox 등 클라우드 연동은 준비 중)
- 책 이름 바꾸기, 형식 아이콘 표시 여부 설정

### 인터페이스
- 글래스모피즘(반투명 블러) 디자인, 320px 이하 좁은 화면까지 대응
- 한국어 / English / 日本語 / 中文 4개 언어로 인터페이스 전환 가능
- 앱 이름을 "Moon Atelier" 또는 "달빛서재" 중 선택 가능
- 첫 실행 시 사용법 안내 팝업, 새로고침 시 1.5초 스플래시 화면
- 개발자에게 커피 한 잔 후원 버튼(실제 결제 없는 감사 팝업)

## English

A glassmorphism-styled web ebook reader built with Flutter.

### Supported formats
- EPUB, PDF, TXT, DOCX, RTF (with automatic Korean CP949 encoding detection)
- MusicXML / MXL (sheet music, rendered as an actual musical score)

### Reading experience
- Font choice: system default, Noto Sans KR, Pretendard, MaruBuri, Noto Serif KR, Nanum Gothic, Nanum Myeongjo, Gowun Batang, Gowun Dodum, IBM Plex Sans KR
- Fine-grained control over weight, size, letter-spacing, line-height, page margin, and paragraph indent
- 5 background presets (white/sepia/gray/dark/black) plus light/dark/system theme
- Every setting can be changed instantly, from the home screen or while reading
- The same draggable progress bar and position indicator across EPUB, PDF, TXT, RTF, and DOCX
- PDF supports zoom via mouse wheel and touch pinch

### Saving & finding passages
- Drag-select text to save it as a colored highlight (with a personal quote collection)
- Bookmark any position and jump back to it from a list
- Each book's list entry shows current/total character count and overall progress %

### Library management
- Organize books into folders (create, move, delete)
- Sort by name, date added, recently read, and more
- Search and multi-select delete (trash)
- Add files from local storage or clipboard (cloud sources like OneDrive/Dropbox are coming soon)
- Rename books, toggle the per-book format icon on/off

### Interface
- Glassmorphism (translucent blur) design that holds up down to 320px width
- Switch the interface language between 한국어 / English / 日本語 / 中文
- Choose the app's display name: "Moon Atelier" or "달빛서재"
- A first-run onboarding guide and a 1.5s splash screen on load/refresh
- A "buy the developer a coffee" button (a friendly thank-you popup, no real payment)

## Getting started

```
flutter pub get
flutter run -d web-server --web-port=8765 --web-hostname=0.0.0.0
```

This project bundles a locally patched copy of `pdfx` under `vendor/pdfx`
(see `pubspec.yaml`'s `dependency_overrides`) to enable mouse-wheel zoom on
the PDF viewer, which upstream `pdfx` does not expose.

Pushes to `main` automatically build and deploy to GitHub Pages via
`.github/workflows/deploy.yml`.
