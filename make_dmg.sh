#!/bin/bash

# ステージングディレクトリを準備
STAGING_DIR="build/dmg_staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R build/WallpaperSwitcher.app "$STAGING_DIR/"

# BuildID を BuildID.swift から取得して .buildid を作成
BUILD_ID=$(grep 'static let buildID' Sources/Generated/BuildID.swift 2>/dev/null | sed 's/.*"\(.*\)"/\1/')
if [ -n "$BUILD_ID" ]; then
    echo "$BUILD_ID" > "$STAGING_DIR/.buildid"
fi

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
