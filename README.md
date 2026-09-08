# Moon Atelier (달빛서재)

**Live:** https://elldia.github.io/Moon_Atelier/

## 한국어

Flutter로 만든 글래스모피즘 스타일의 웹 전자책 리더입니다.

### 지원 파일 형식
- EPUB, PDF, TXT, DOCX, RTF (한글 CP949 인코딩 자동 인식 포함)
- MusicXML / MXL (악보 파일, 오선보로 렌더링)
- 위 형식이 ZIP 압축파일 안에 들어있어도 자동으로 찾아서 열림(파일명이 한글 CP949로 되어 있어도 깨지지 않게 자동 복구)

### 읽기 경험
- 글꼴 선택: 시스템 기본, Noto Sans KR, Pretendard, 마루부리, Noto Serif KR, 나눔고딕, 나눔명조, 고운바탕, 고운돋움, IBM 플렉스 산스 — 각 버튼이 실제 그 글꼴·굵기로 미리보기되어 고르기 전에 바로 확인 가능
- 글자 굵기, 크기, 자간, 행간, 바깥 여백, 들여쓰기까지 세밀하게 조절 가능
- 배경색 5종 프리셋(화이트/세피아/그레이/다크/블랙) 및 라이트·다크·시스템 테마
- 모든 설정은 홈 화면과 읽는 중 어디서든 즉시 변경 가능
- EPUB·PDF·TXT·RTF·DOCX 전 형식에서 동일한 하단 진행바(클릭 & 드래그로 원하는 위치 이동) 및 진행률 표시
- 100페이지(EPUB은 1000문단) 이상인 책은 처음·끝·±10페이지 이동 버튼이 진행바 옆에 추가로 표시
- 스크롤하면 상단·하단 UI가 자동으로 숨겨지고, 화면을 탭하거나 위로 스크롤하면 다시 나타남
- PDF는 마우스 휠과 터치 핀치줌으로 화면 확대·축소 가능
- 음성으로 듣기(TTS): 시스템에 설치된 목소리 중에서 선택 가능하고 배속을 x1.0~x2.0(0.2 단위)로 조절 — EPUB·PDF·TXT·DOCX·RTF 전 형식 지원

### 문장 저장 및 탐색
- 텍스트를 드래그해 원하는 색상의 형광펜으로 저장(자주 찾는 글귀 모아보기)
- 원하는 위치를 북마크로 저장하고 목록에서 바로 이동
- 책마다 현재 읽은 글자수 / 전체 글자수 · 진행률(%)을 목록에서 확인
- 본문 내용 검색(EPUB·PDF·TXT·DOCX·RTF): 원하는 단어가 나오는 위치로 바로 이동, 이전/다음 결과 탐색

### 서재 관리
- 폴더 생성, 이동, 삭제로 책 정리
- 이름순·등록순·최근 읽은 순 등 다양한 정렬
- 검색 및 다중 선택 삭제(휴지통), 선택 모드에서 전체 선택/해제 한 번에 가능
- 파일 등록은 로컬 파일 선택과 클립보드 붙여넣기를 지원(원드라이브·Dropbox 등 클라우드 연동은 준비 중)
- 책 이름 바꾸기, 형식 아이콘 표시 여부 설정

### 인터페이스
- 글래스모피즘(반투명 블러) 디자인, 320px 이하 좁은 화면까지 대응
- 한국어 / English / 日本語 / 中文 4개 언어로 인터페이스 전환 가능
- 앱 이름은 인터페이스 언어에 따라 자동 전환(한국어 → "달빛서재", 그 외 → "Moon Atelier")
- 첫 실행 시 실제 화면 위에 반투명 오버레이로 버튼마다 설명을 보여주는 안내, "다음에 다시 보기" 또는 "다신 안 보기" 중 선택 가능. 새로고침 시 1.5초 스플래시 화면
- 개발자에게 커피 한 잔 후원 버튼(실제 결제 없는 감사 팝업)

## English

A glassmorphism-styled web ebook reader built with Flutter.

### Supported formats
- EPUB, PDF, TXT, DOCX, RTF (with automatic Korean CP949 encoding detection)
- MusicXML / MXL (sheet music, rendered as an actual musical score)
- Any of the above works even zipped inside a `.zip` — it's found and opened automatically, and a Korean filename encoded as CP949 is recovered instead of showing up as mojibake

### Reading experience
- Font choice: system default, Noto Sans KR, Pretendard, MaruBuri, Noto Serif KR, Nanum Gothic, Nanum Myeongjo, Gowun Batang, Gowun Dodum, IBM Plex Sans KR — each option is a live preview rendered in its own font and weight, not just a label
- Fine-grained control over weight, size, letter-spacing, line-height, page margin, and paragraph indent
- 5 background presets (white/sepia/gray/dark/black) plus light/dark/system theme
- Every setting can be changed instantly, from the home screen or while reading
- The same draggable progress bar and position indicator across EPUB, PDF, TXT, RTF, and DOCX
- Books over 100 pages (1000 paragraphs for EPUB) get extra first/last/±10-page jump buttons next to the progress bar
- Scrolling auto-hides the top/bottom UI; tap the screen or scroll up to bring it back
- PDF supports zoom via mouse wheel and touch pinch
- Text-to-speech: pick from the voices installed on your system and adjust playback speed from x1.0 to x2.0 in 0.2 steps — available across EPUB, PDF, TXT, DOCX, and RTF

### Saving & finding passages
- Drag-select text to save it as a colored highlight (with a personal quote collection)
- Bookmark any position and jump back to it from a list
- Each book's list entry shows current/total character count and overall progress %
- In-content search across EPUB, PDF, TXT, DOCX, and RTF — jump straight to a match and step through previous/next results

### Library management
- Organize books into folders (create, move, delete)
- Sort by name, date added, recently read, and more
- Search and multi-select delete (trash), with a select-all/deselect-all toggle in selection mode
- Add files from local storage or clipboard (cloud sources like OneDrive/Dropbox are coming soon)
- Rename books, toggle the per-book format icon on/off

### Interface
- Glassmorphism (translucent blur) design that holds up down to 320px width
- Switch the interface language between 한국어 / English / 日本語 / 中文
- The app's display name follows the interface language automatically (Korean → "달빛서재", everything else → "Moon Atelier")
- A first-run guide overlays the real screen with a translucent scrim and spotlights each button with its own explanation, with a choice between "show again next time" or "never show again". A 1.5s splash screen appears on load/refresh
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
