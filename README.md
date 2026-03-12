# WallpaperSwitcher

macOS メニューバー常駐アプリ。壁紙プリセットを作って、ワンクリックで切り替え。

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

## 機能

- **プリセット管理** — フォルダを指定して壁紙プリセットを作成・編集・削除
- **ワンクリック切り替え** — メニューバーからプリセットを選ぶだけ
- **自動シャッフル** — 1分〜1時間間隔で壁紙を自動切り替え
- **トランジション** — クロスフェード、スライド（上下左右）、フェード（黒）
- **光のエフェクト** — オンボーディング時に Metal シェーダーによるリッチなライトエフェクト
- **ログイン時に自動起動** — 設定から有効化

## スクリーンショット

メニューバーの写真アイコンからすべての操作にアクセスできます。

## インストール

### りりーすから入れる

普通にリリースからdmg落としてよしなにやってください。 
適当な署名しかしてないのでOSに言い訳して起動してください。

### ビルド

```bash
xcodebuild -project WallpaperSwitcher.xcodeproj \
  -scheme WallpaperSwitcher \
  -configuration Release \
  build CONFIGURATION_BUILD_DIR=./build
```

`build/WallpaperSwitcher.app` をアプリケーションフォルダにコピーしてください。

### 要件

- macOS 13.0 (Ventura) 以上
- Xcode 15 以上（ビルド時）

## 使い方

1. 初回起動時にオンボーディングが表示されます
2. プリセット名を入力し、壁紙画像が入ったフォルダを選択
3. シャッフル間隔・順序・トランジションをお好みで設定
4. メニューバーのアイコンからプリセットを切り替え
5. 「次の壁紙」で手動切り替え

対応画像形式: JPEG, PNG, HEIC

## 技術スタック

- Swift 5.9 / SwiftUI / AppKit
- Metal (GPU シェーダーによるライトエフェクト)
- `NSWorkspace.setDesktopImageURL` による壁紙切り替え
- `SMAppService` によるログイン項目管理
- Security-Scoped Bookmarks によるフォルダアクセス権の永続化

## ライセンス

MIT

---

Built with [Claude Code](https://claude.ai/claude-code) by Anthropic.
