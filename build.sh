#!/bin/bash
set -e

APP_NAME="DuckBar"
BUILD_DIR=".build/app"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
RELEASES_DIR=".build/releases"

echo "=== DuckBar Build ==="

# 1. Build Swift Package
echo "[1/4] Compiling..."
swift build -c release 2>&1

# 2. Create app bundle structure
echo "[2/4] Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp .build/release/DuckBar "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp Resources/Info.plist "$APP_BUNDLE/Contents/"

# Copy icon
cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/"

# Copy Sparkle.framework
mkdir -p "$APP_BUNDLE/Contents/Frameworks"
cp -R .build/arm64-apple-macosx/release/Sparkle.framework "$APP_BUNDLE/Contents/Frameworks/"

# rpath 추가 (Sparkle.framework 로딩 경로)
install_name_tool -add_rpath "@loader_path/../Frameworks" "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true

# 3. Code sign
echo "[3/4] Signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

# 4. Release 패키징 (--release 플래그가 있을 때만)
if [[ "$1" == "--release" ]]; then
    VERSION=$(defaults read "$(pwd)/$APP_BUNDLE/Contents/Info.plist" CFBundleShortVersionString)
    echo "[4/4] Packaging release v$VERSION..."

    mkdir -p "$RELEASES_DIR"
    ZIP_PATH="$RELEASES_DIR/${APP_NAME}-${VERSION}.zip"

    # 심볼릭 링크 보존하며 zip 생성
    ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

    # generate_appcast 실행 (Sparkle 도구가 PATH에 있어야 함)
    SPARKLE_BIN=$(find .build/artifacts/sparkle -name "generate_appcast" 2>/dev/null | head -1)
    if [[ -n "$SPARKLE_BIN" ]]; then
        "$SPARKLE_BIN" "$RELEASES_DIR"
        echo "appcast.xml 생성 완료: $RELEASES_DIR/appcast.xml"
    else
        echo "generate_appcast를 찾을 수 없습니다. 수동으로 실행하세요:"
        echo "  <sparkle_bin>/generate_appcast $RELEASES_DIR"
    fi

    echo ""
    echo "릴리스 파일: $ZIP_PATH"
    echo "다음 단계:"
    echo "  1. $RELEASES_DIR/appcast.xml 을 GitHub Pages에 업로드"
    echo "  2. $ZIP_PATH 를 GitHub Releases에 업로드 (태그: v$VERSION)"
else
    echo "[4/4] 건너뜀 (릴리스 패키징은 --release 플래그 사용)"
fi

echo ""
echo "=== Build Complete ==="
echo "App: $APP_BUNDLE"
echo ""
echo "Run: open $APP_BUNDLE"
echo "Install: cp -r $APP_BUNDLE /Applications/"
