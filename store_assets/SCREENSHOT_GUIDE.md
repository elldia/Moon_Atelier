# 플레이스토어 스크린샷 가이드

## 1. 규격 (Play Console 기준)

| 구분 | 필수 여부 | 개수 | 권장 크기 |
|---|---|---|---|
| 휴대전화 | **필수** | 2~8장 (추천 4장 이상) | 1080×1920 (세로 9:16) |
| 7인치 태블릿 | 선택 (태블릿 노출에 유리) | 최대 8장 | 1200×1920 |
| 10인치 태블릿 | 선택 | 최대 8장 | 1600×2560 |

- 형식: PNG 또는 JPEG, 장당 8MB 이하, **투명 배경(알파) 없이**
- 비율: 긴 변이 짧은 변의 2배를 넘으면 안 됨 (예: 1080×2400 같은 최신 폰 원본은 거절될 수 있음 → 1080×1920으로 잘라서 사용)
- 1080px 이상 스크린샷이 4장 이상이면 추천/프로모션 노출 대상이 됨
- 그래픽 이미지(1024×500)는 `feature_graphic_en.png` / `feature_graphic_ko.png` 사용

## 2. 찍을 화면 (순서대로 추천 8장)

| # | 화면 | 준비 상태 | 전달 포인트 |
|---|---|---|---|
| 1 | **만화 서재 – 표지 보기** | 만화 6~9권 등록, 폴더 1개, 일부 진행률 표시 | 표지 썸네일 서재 |
| 2 | **전자책 읽기 – 쪽 넘김 모드** | 소설 본문 중간 페이지, 상단바 숨김 | 깔끔한 독서 화면 |
| 3 | **읽기 설정 시트** | 글꼴·크기·행간·여백·쪽 넘김 옵션이 보이게 | 세밀한 맞춤 설정 |
| 4 | **만화 뷰어** | 두 쪽 보기 또는 한 쪽 보기 + 하단 진행바 | 빠른 만화 읽기 |
| 5 | **와이파이 전송** | 전송 창 열고 파일 1~2개 받은 상태 | PC에서 바로 보내기 |
| 6 | **클라우드 가져오기** | OneDrive 또는 Dropbox 폴더 목록 | 클라우드 연동 |
| 7 | **전자책 서재 – 폴더 정리** | 폴더 2~3개 + 파일 목록 | 폴더 관리 |
| 8 | **다크 모드 / 이잉크 화면** | 어두운 테마 독서 화면 | 눈이 편한 독서 |

## 3. 꼭 지킬 것

- **저작권**: 상업 만화·소설 화면은 쓰면 안 됩니다. 아래처럼 저작권이 끝난 작품이나 직접 만든 샘플을 쓰세요.
  - 영어: Project Gutenberg (*Alice's Adventures in Wonderland*, *Pride and Prejudice* 등)
  - 한국어: 공유마당·위키문헌의 저작권 만료 작품 (김유정 「봄·봄」, 이상 「날개」 등)
  - 만화: 직접 그린 그림이나 무료 라이선스(CC0) 이미지로 만든 CBZ
- **개인정보**: OneDrive/Dropbox 화면에 실제 이메일·개인 파일명이 보이지 않게 테스트 계정 사용
- **상태바 정리**: 시간 10:00, 배터리 가득, 알림 아이콘 없음 (아래 데모 모드 명령 참고)
- **언어별 세트**: 기본 언어가 영어이므로 영어 세트를 먼저, 한국어 스토어 등록정보용으로 한국어 세트를 따로 찍기 (앱 설정에서 언어만 바꿔서 같은 화면 반복)

## 4. 찍는 방법

### 휴대폰 (USB 연결, 개발자 옵션 켬)

```bash
# 상태바 데모 모드 켜기 (시간 10:00, 배터리 100%, 알림 숨김)
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command enter
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1000
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false

# 스크린샷 저장
adb exec-out screencap -p > shot_01.png

# 끝나면 데모 모드 끄기
adb shell am broadcast -a com.android.systemui.demo -e command exit
```

### 태블릿 크기가 필요할 때
Android Studio 에뮬레이터에서 **Pixel Tablet** (2560×1600) 또는 **Nexus 7** 기기를 만들어 같은 방식으로 촬영.

### 크기 맞추기 (1080×2400 → 1080×1920)
상태바를 포함한 위쪽부터 1920px만 남기도록 자르거나, 필요하면 말씀해 주세요. 찍은 파일을 `store_assets/screens/`에 넣어 주시면 규격에 맞게 일괄 변환해 드립니다.

## 5. (선택) 문구 넣은 스크린샷
원본 화면 위에 짧은 문구(예: "Your comics, as covers" / "표지로 보는 만화 서재")를 얹으면 전환율이 올라갑니다. 원본을 주시면 그래픽 이미지와 같은 남색 배경 스타일로 만들어 드릴 수 있습니다.
