# Moon Atelier (달빛서재)

**Live:** https://elldia.github.io/Moon_Atelier/
**Windows download (offline fallback):** https://github.com/elldia/Moon_Atelier/releases
**Privacy policy:** https://elldia.github.io/Moon_Atelier/privacy.html

## 한국어

Flutter로 만든 글래스모피즘 스타일의 웹 전자책 리더입니다.

### 지원 파일 형식
- EPUB, PDF, TXT, DOCX, RTF (한글 CP949 인코딩 자동 인식 포함)
- HWPX(한글 2014 이후 버전의 XML 기반 형식) — 옛 바이너리 .hwp 형식은 지원하지 않음
- MusicXML / MXL (악보 파일, 오선보로 렌더링)
- 위 형식이 ZIP 압축파일 안에 들어있어도 자동으로 찾아서 열림(파일명이 한글 CP949로 되어 있어도 깨지지 않게 자동 복구)

### 읽기 경험
- 글꼴 선택: 시스템 기본, Noto Sans KR, Pretendard, 마루부리, Noto Serif KR, 나눔고딕, 나눔명조, 고운바탕, 고운돋움, IBM 플렉스 산스 — 각 버튼이 실제 그 글꼴·굵기로 미리보기되어 고르기 전에 바로 확인 가능
- 글자 크기·자간·행간·바깥 여백·들여쓰기는 매우작게~매우 크게 5단계 중에서 실제 미리보기를 보며 선택(드래그 슬라이더 아님)
- 배경색 5종 프리셋(화이트/세피아/그레이/다크/블랙) 및 라이트·다크·시스템 테마
- 모든 설정은 홈 화면과 읽는 중 어디서든 즉시 변경 가능
- EPUB·PDF·TXT·RTF·DOCX·HWPX 전 형식에서 동일한 하단 진행바(클릭 & 드래그로 원하는 위치 이동) 및 진행률 표시 — 기본은 숨김이며 설정에서 켤 수 있음
- 100페이지(EPUB은 1000문단) 이상인 책은 처음·끝·±10페이지 이동 버튼이 진행바 옆에 추가로 표시(진행바를 켰을 때만)
- 스크롤하면 상단·하단 UI가 자동으로 숨겨지고, 화면을 탭하거나 위로 스크롤하면 다시 나타남(단, 본문 검색 중에는 스크롤해도 숨겨지지 않고 검색을 닫아야 다시 숨겨짐)
- PDF는 마우스 휠과 터치 핀치줌으로 화면 확대·축소 가능
- 음성으로 듣기(TTS): 시스템에 설치된 목소리 중에서 선택 가능하고 배속을 x1.0~x2.0(0.2 단위)로 조절 — EPUB·PDF·TXT·DOCX·RTF·HWPX 전 형식 지원

### 문장 저장 및 탐색
- 텍스트를 드래그해 원하는 색상의 형광펜으로 저장(자주 찾는 글귀 모아보기) — TXT·DOCX·RTF·HWPX에서 지원(EPUB·PDF는 아직 지원하지 않음: EPUB 렌더링 라이브러리에 텍스트 선택 기능이 없고, PDF는 페이지를 이미지로만 그려서 텍스트 레이어가 없음)
- 저장한 글귀는 목록에서 바로 공유(다른 앱으로 보내기) 가능
- 원하는 위치를 북마크로 저장하고 목록에서 바로 이동
- 책마다 현재 읽은 글자수 / 전체 글자수 · 진행률(%)을 목록에서 확인
- 본문 내용 검색(EPUB·PDF·TXT·DOCX·RTF·HWPX): 원하는 단어가 나오는 위치로 바로 이동, 이전/다음 결과 탐색

### 서재 관리
- 폴더 생성, 이동, 삭제로 책 정리
- 이름순·등록순·최근 읽은 순 등 다양한 정렬
- 검색 및 다중 선택 삭제(휴지통), 선택 모드에서 전체 선택/해제 한 번에 가능
- 파일 등록은 로컬 파일 선택과 클립보드 붙여넣기를 지원(원드라이브·Dropbox 등 클라우드 연동은 준비 중)
- 책 이름 바꾸기, 형식 아이콘 표시 여부 설정
- 서재 전체(책 원본 파일, 폴더, 북마크, 형광펜)를 zip 파일 하나로 내려받기/메일로 공유 가능, 그 백업 파일을 다시 불러와 서재에 더하는 복원 기능도 지원(기존 항목은 지워지지 않음)

### 인터페이스
- 홈 화면에 가장 최근에 읽던 책/만화로 바로 이어보기 카드 표시(진행률 포함, 한 번도 안 읽었으면 표시 안 됨)
- 홈 화면 하단에 개인정보처리방침 링크 상시 노출(플레이스토어 등 앱스토어 심사에서 앱 내부에서도 접근 가능해야 함)
- 웹 버전에서는 브라우저 탭 제목이 화면에 따라 바뀜(홈: 앱 이름, 이북 서재/만화 서재: "앱 이름 | ebook" 또는 "앱 이름 | Comic"). 화면 안 제목은 이북/만화 서재 모두 "ebook Viewer" / "Comic Viewer"로 표시
- 글래스모피즘(반투명 블러) 디자인, 320px 이하 좁은 화면까지 대응
- 한국어 / English / 日本語 / 中文 4개 언어로 인터페이스 전환 가능
- 앱 이름은 모든 언어에서 기본적으로 "Moon Atelier"로 표시되며, 한국어 설정에서는 설정 화면에서 "달빛서재"로 바꿀 수도 있음
- 첫 실행 시 실제 화면 위에 반투명 오버레이로 버튼마다 설명을 보여주는 안내, "다음에 다시 보기" 또는 "다신 안 보기" 중 선택 가능. 새로고침 시 0.8초 스플래시 화면
- 개발자에게 커피 한 잔 후원 버튼([Buy Me a Coffee](https://buymeacoffee.com/elldia1222w)로 연결)

### 만화 뷰어
- CBZ, ZIP 만화책을 페이지 단위로 감상(전자책과는 별도의 만화 서재)
- 보기 방식: 한 장씩 / 두 장씩(스프레드) — 페이지는 항상 가로로 넘어가며, 두 장씩 볼 때는 두 페이지가 가운데(책등)에서 맞닿도록 정렬됨
- 읽기 방향을 좌→우(서양 만화) / 우→좌(망가)로 선택 가능 — 두 장씩 볼 때는 스프레드 안 페이지 순서도 그에 맞게 바뀜
- 화면 가장자리를 탭하면 이전/다음 페이지로 넘어가고 가운데를 탭하면 화면 UI가 보이거나 숨겨짐 — 탭 영역의 방향과 크기(화면의 25~50%)를 설정에서 조절 가능(길게 누르면 항상 UI 전환)
- 마우스 휠·트랙패드 스크롤과 방향키(←→ / ↑↓)로도 페이지 이동 가능(핀치/휠 확대축소는 탭 넘기기와 겹치지 않도록 지원하지 않음)
- 이미지 화질(선명하게/평균/부드럽게) 선택 및 페이지 전환 애니메이션 켜기/끄기
- 원본 이미지가 화면 해상도보다 훨씬 큰 대용량 만화책도, 보이는 화질은 유지하면서 기기 해상도에 맞춰 자동으로 디코딩 크기를 줄여 더 빠르게 넘어감
- 북마크 추가 및 목록에서 바로 이동, 상단에 진행률(현재 페이지/전체 · %) 표시
- 배경색 5종 프리셋(화이트/세피아/그레이/다크/블랙, 기본값 블랙)을 이북과 별도로 선택 가능
- 보기 설정 창에서 인터페이스 언어(한국어/English/日本語/中文)와 화면 모드(시스템/라이트/다크)도 함께 변경 가능(이북 설정과 값 공유)
- 보기 설정은 화면 중앙에 뜨는 별도 창(화면의 80% 크기)에서 즉시 적용

## English

A glassmorphism-styled web ebook reader built with Flutter.

### Supported formats
- EPUB, PDF, TXT, DOCX, RTF (with automatic Korean CP949 encoding detection)
- HWPX (the XML-based format used by 한글/Hangul Word Processor since 2014) — the older binary .hwp format isn't supported
- MusicXML / MXL (sheet music, rendered as an actual musical score)
- Any of the above works even zipped inside a `.zip` — it's found and opened automatically, and a Korean filename encoded as CP949 is recovered instead of showing up as mojibake

### Reading experience
- Font choice: system default, Noto Sans KR, Pretendard, MaruBuri, Noto Serif KR, Nanum Gothic, Nanum Myeongjo, Gowun Batang, Gowun Dodum, IBM Plex Sans KR — each option is a live preview rendered in its own font and weight, not just a label
- Font size, letter-spacing, line-height, page margin, and paragraph indent are each picked from 5 levels (very small to very large) with a live preview of that level — not a drag slider
- 5 background presets (white/sepia/gray/dark/black) plus light/dark/system theme
- Every setting can be changed instantly, from the home screen or while reading
- The same draggable progress bar and position indicator across EPUB, PDF, TXT, RTF, DOCX, and HWPX — hidden by default, can be turned on from Settings
- Books over 100 pages (1000 paragraphs for EPUB) get extra first/last/±10-page jump buttons next to the progress bar (only shown when it's on)
- Scrolling auto-hides the top/bottom UI; tap the screen or scroll up to bring it back (this pauses while in-content search is open, resuming once you close it)
- PDF supports zoom via mouse wheel and touch pinch
- Text-to-speech: pick from the voices installed on your system and adjust playback speed from x1.0 to x2.0 in 0.2 steps — available across EPUB, PDF, TXT, DOCX, RTF, and HWPX

### Saving & finding passages
- Drag-select text to save it as a colored highlight (with a personal quote collection) — supported in TXT, DOCX, RTF, and HWPX (not yet in EPUB or PDF: the EPUB rendering library has no text-selection API, and PDF pages are drawn as images with no text layer)
- Share a saved quote straight from the list
- Bookmark any position and jump back to it from a list
- Each book's list entry shows current/total character count and overall progress %
- In-content search across EPUB, PDF, TXT, DOCX, RTF, and HWPX — jump straight to a match and step through previous/next results

### Library management
- Organize books into folders (create, move, delete)
- Sort by name, date added, recently read, and more
- Search and multi-select delete (trash), with a select-all/deselect-all toggle in selection mode
- Add files from local storage or clipboard (cloud sources like OneDrive/Dropbox are coming soon)
- Rename books, toggle the per-book format icon on/off
- Download or email the whole library (book files, folders, bookmarks, highlights) as one zip, and restore that backup back in later — nothing already in the library gets removed by a restore

### Interface
- The home screen shows a "continue reading" card for the most recently opened book/comic, progress included (hidden until you've actually opened something)
- A privacy policy link is always shown at the bottom of the home screen — app store review requires it to be reachable from inside the app, not just the store listing
- On the web build, the browser tab title changes per screen (home: the app name, e-book/comic library: "App Name | ebook" or "App Name | Comic"); the on-screen title reads "ebook Viewer" / "Comic Viewer" for both libraries
- Glassmorphism (translucent blur) design that holds up down to 320px width
- Switch the interface language between 한국어 / English / 日本語 / 中文
- The app defaults to the "Moon Atelier" display name in every language; in Korean, Settings also lets you switch it to "달빛서재"
- A first-run guide overlays the real screen with a translucent scrim and spotlights each button with its own explanation, with a choice between "show again next time" or "never show again". A 0.8s splash screen appears on load/refresh
- A "buy the developer a coffee" button, linking out to [Buy Me a Coffee](https://buymeacoffee.com/elldia1222w)

### Comic Viewer
- Read CBZ/ZIP comic archives page by page, in its own library separate from the e-book reader
- View modes: single page or two-page spread — pages always turn horizontally, and spreads have the two pages center-aligned so they meet at the spine like a real book
- Pick a reading direction, left-to-right (Western comics) or right-to-left (manga) — spreads reorder their pages to match
- Tap an edge of the screen to turn to the previous/next page, or the middle to show/hide the UI — both the tap zones' direction and size (25-50% of the screen) are configurable from Settings (long-press always toggles the UI as a fallback)
- Also supports mouse-wheel/trackpad scrolling and arrow keys (←→ / ↑↓) for page turns (no pinch/wheel zoom, so it never fights with edge-tap page turning)
- Choice of image quality (sharp/medium/smooth) and a toggle for the page-turn animation
- Large comics whose source images are much bigger than the screen decode faster automatically — pages are downscaled to match the device's resolution while keeping the visible quality the same
- Add bookmarks and jump back to them from a list, plus a progress indicator (page/total, %) up top
- Choose from 5 background presets (white/sepia/gray/dark/black, black by default), independent of the e-book reader's background
- The settings dialog also lets you change the interface language (한국어/English/日本語/中文) and display mode (system/light/dark) — these are shared with the e-book reader's settings
- Settings open in their own dialog, centered over the viewer at 80% of the screen size, applying instantly

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
