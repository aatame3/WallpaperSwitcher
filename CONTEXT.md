
---

# WallpaperSwitcher 開発履歴まとめ

## 概要
macOS用壁紙プリセット切り替えアプリ「WallpaperSwitcher」をSwift/SwiftUIで開発。  
ユーザーのUX要望に応じて、機能・演出・操作性を段階的に拡張。

---

## 主な機能・構成

```md
- Swift 5.9 / SwiftUI / AppKit
- macOS 13+ 対応
- メニューバー常駐（NSStatusItem）
- プリセット管理（名前・フォルダ・シャッフル間隔・順序・トランジション）
- 壁紙切り替えAPI: NSWorkspace.shared.setDesktopImageURL
- オンボーディング（初回ガイド）ウィザード
- About画面（クレジット・バージョン）
- プリセット追加・編集・削除（リスト＆メニュー両方）
- ログイン時自動起動（SMAppService）
- UserDefaultsによる状態保存
```

---

## ユーザー要望と対応履歴

```md
1. シャッフル間隔・順序・トランジション選択機能追加
2. 「次の壁紙」メニュー追加
3. トランジション演出（クロスフェード/スライド/フェード等）実装
4. About画面・クレジット表記追加
5. オンボーディングウィザード追加
6. オンボーディングUIを「カラフル→落ち着いた色＋アニメ」に変更
7. 歯車アイコン回転アニメ追加
8. プリセット削除機能（リスト＆メニュー）追加
9. オンボーディング完了時、光のリング＋ぼかし＋円形マスクで壁紙切り替え演出実装
10. ウィンドウサイズ・UI見切れバグ修正
```

---

## 主要コード構成例

```swift
// オンボーディング完了時の光のリング＋壁紙切り替え演出
private func performLightRipple(from center: CGPoint, applyWallpaper: @escaping () -> Void) {
    // 旧壁紙をオーバーレイ
    // 円形マスクを拡大しながら新壁紙を中心から広げる
    // 境界にガウスぼかし付き白いリングを重ねる
    // アニメ完了後オーバーレイ除去
}

// プリセット削除
@objc private func deletePreset(_ sender: NSMenuItem) {
    guard let id = sender.representedObject as? UUID,
          let preset = store.presets.first(where: { $0.id == id }) else { return }
    store.delete(preset)
    rebuildMenu()
    restartTimerIfNeeded()
}

// 歯車アイコン回転（オンボーディング設定ページ）
Image(systemName: "gearshape.fill")
    .rotationEffect(.degrees(gearRotation))
    .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: gearRotation)
```

---

## ビルド・動作状況

```md
- すべてのビルド成功
- macOS 13環境で安定動作
- UI/UXはユーザーの細かい要望に合わせて随時調整
```

---

## まとめ

ユーザーの「見応え・操作性・演出」へのこだわりに応じて、  
アニメーションや壁紙切り替え演出を細かく実装・調整。  
全機能・演出はビルド成功＆安定動作を確認済み。