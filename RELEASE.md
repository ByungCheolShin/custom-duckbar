# DuckBar 빌드 & 릴리스 가이드

## 개발 중 빌드 (debug)

Sparkle.framework는 `/Applications/DuckBar.app/Contents/Frameworks/`에 이미 있어야 한다.
바이너리만 교체하고 재서명 후 실행:

```bash
swift build && pkill -x DuckBar; sleep 1; cp ".build/debug/DuckBar" "/Applications/DuckBar.app/Contents/MacOS/DuckBar" && codesign --force --deep --sign - /Applications/DuckBar.app && open /Applications/DuckBar.app
```

---

# 릴리스 가이드

Sparkle 프레임워크를 통한 자동 업데이트 배포 방법.

---

## 최초 설정 (1회만)

### 1. Ed25519 서명 키 생성

```bash
.build/artifacts/sparkle/Sparkle/bin/generate_keys
```

출력된 공개키를 `Resources/Info.plist`의 `SUPublicEDKey`에 붙여넣는다.
**비밀키는 macOS Keychain에 저장됨 — Mac을 바꾸거나 Keychain을 초기화하면 영구 소실되므로 반드시 백업.**

### 2. GitHub Pages 활성화

```bash
git checkout --orphan gh-pages
touch appcast.xml
git add appcast.xml
git commit -m "gh-pages 초기화"
git push origin gh-pages
git checkout -
```

저장소 → Settings → Pages → Source: `gh-pages` 브랜치 루트(`/`) 선택.

`SUFeedURL`은 이미 `https://rofeels.github.io/duckbar/appcast.xml` 로 설정되어 있다.

---

## 릴리스 절차

### 1. 버전 올리기

`Resources/Info.plist`에서 두 값을 모두 올린다:

```xml
<key>CFBundleShortVersionString</key>
<string>1.1.0</string>   <!-- 표시용 버전 -->

<key>CFBundleVersion</key>
<string>2</string>        <!-- 빌드 번호 (정수, 반드시 이전보다 커야 함) -->
```

### 2. 빌드 및 패키징

```bash
./build.sh --release
```

생성 파일:
- `.build/releases/DuckBar-x.x.x.zip` — GitHub Releases에 업로드할 바이너리
- `.build/releases/appcast.xml` — GitHub Pages에 업로드할 피드

### 3. GitHub Releases에 zip 업로드

```bash
gh release create vX.X.X \
  ".build/releases/DuckBar-X.X.X.zip" \
  --title "vX.X.X" \
  --notes "변경 사항 작성"
```

또는 GitHub 웹에서 수동으로 업로드.

### 4. appcast.xml을 GitHub Pages에 업로드

```bash
# appcast.xml 임시 복사
cp .build/releases/appcast.xml /tmp/appcast.xml

# gh-pages 브랜치로 이동
git checkout gh-pages

# 붙여넣고 푸시
cp /tmp/appcast.xml appcast.xml
git add appcast.xml
git commit -m "appcast v X.X.X"
git push origin gh-pages

# 원래 브랜치로 복귀
git checkout -
```

---

## 동작 방식

- 앱 실행 시 자동으로 `SUFeedURL`을 체크
- 새 버전 감지 시 사용자에게 업데이트 알림
- 우클릭 메뉴 → **업데이트 확인...** 으로 수동 체크 가능
- 다운로드 및 설치까지 Sparkle이 자동 처리

---

## Sparkle 도구 경로

```
.build/artifacts/sparkle/Sparkle/bin/generate_keys
.build/artifacts/sparkle/Sparkle/bin/generate_appcast
.build/artifacts/sparkle/Sparkle/bin/sign_update
```
