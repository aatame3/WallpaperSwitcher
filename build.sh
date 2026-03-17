#!/bin/bash
set -e

DERIVED_DATA="./DerivedData"
BUILD_DIR="build"
STAGING_DIR="$BUILD_DIR/dmg_staging"

# ユニバーサルバイナリでリリースビルド
echo "==> Building universal binary (arm64 + x86_64)..."
xcodebuild -project WallpaperSwitcher.xcodeproj \
  -scheme WallpaperSwitcher \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  clean build | tail -1

# ビルド成果物をコピー
mkdir -p "$BUILD_DIR"
cp -R "$DERIVED_DATA/Build/Products/Release/WallpaperSwitcher.app" "$BUILD_DIR/"

# ステージングディレクトリを準備
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$BUILD_DIR/WallpaperSwitcher.app" "$STAGING_DIR/"

# BuildID を BuildID.swift から取得して .buildid を作成
BUILD_ID=$(grep 'static let buildID' Sources/Generated/BuildID.swift 2>/dev/null | sed 's/.*"\(.*\)"/\1/')
if [ -n "$BUILD_ID" ]; then
    echo "$BUILD_ID" > "$STAGING_DIR/.buildid"
    echo "==> Build ID: $BUILD_ID"
fi

# DMG 作成
rm -f WallpaperSwitcher.dmg
echo "==> Creating DMG..."
create-dmg \
  --volname "WallpaperSwitcher" \
  --background ~/Documents/backImage.tiff \
  --window-pos 200 120 \
  --window-size 600 375 \
  --icon-size 100 \
  --icon "WallpaperSwitcher.app" 115 200 \
  --hide-extension "WallpaperSwitcher.app" \
  --app-drop-link 510 200 \
  WallpaperSwitcher.dmg \
  "$STAGING_DIR"

# クリーンアップ
rm -rf "$STAGING_DIR"

echo "==> Done! WallpaperSwitcher.dmg created."
