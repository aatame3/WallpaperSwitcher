#!/bin/bash

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
  build/WallpaperSwitcher.app
