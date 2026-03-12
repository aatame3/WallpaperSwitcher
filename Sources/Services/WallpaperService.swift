import AppKit
import Foundation

enum WallpaperService {
    static let supportedExtensions: Set<String> = ["jpg", "jpeg", "png", "heic"]
    private static var overlayWindows: [NSWindow] = []
    private static var isTransitioning = false
    private static var pendingRequest: (() -> Void)?

    /// 指定フォルダから画像を取得し、ソート済みリストを返す
    static func imageURLs(from folderPath: String) -> [URL] {
        let folderURL = URL(fileURLWithPath: folderPath)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return contents
            .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// プリセットの設定に従って壁紙を適用し、更新後のcurrentIndexを返す
    static func applyWallpaper(for preset: Preset) -> Int {
        // Security-Scoped Bookmark があれば復元してアクセス権を取得
        var scopedURL: URL?
        if let bookmark = preset.folderBookmark {
            scopedURL = FolderAccess.resolveBookmark(bookmark)
        }
        defer { scopedURL?.stopAccessingSecurityScopedResource() }

        let images = imageURLs(from: scopedURL?.path ?? preset.folderPath)
        guard !images.isEmpty else { return preset.currentIndex }

        let chosen: URL
        var nextIndex = preset.currentIndex

        switch preset.order {
        case .random:
            chosen = images.randomElement()!
        case .sequential:
            let idx = preset.currentIndex % images.count
            chosen = images[idx]
            nextIndex = idx + 1
        }

        transitionToWallpaper(chosen, style: preset.transitionStyle)
        return nextIndex
    }

    /// トランジション付きで壁紙を切り替える
    private static func transitionToWallpaper(_ imageURL: URL, style: TransitionStyle) {
        // 前のトランジションが進行中なら保留（完遂後に実行される）
        if isTransitioning {
            pendingRequest = { transitionToWallpaper(imageURL, style: style) }
            return
        }
        isTransitioning = true

        // 各スクリーンにオーバーレイウィンドウを作成
        for screen in NSScreen.screens {
            guard let currentWallpaperURL = NSWorkspace.shared.desktopImageURL(for: screen),
                  let sourceImage = NSImage(contentsOf: currentWallpaperURL) else { continue }

            let screenSize = screen.frame.size
            let filledImage = renderFillImage(sourceImage, to: screenSize)

            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.level = .init(Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
            window.isOpaque = true
            window.backgroundColor = .black
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]
            window.animationBehavior = .none

            let localRect = NSRect(origin: .zero, size: screenSize)
            let imageView = NSImageView(frame: localRect)
            imageView.image = filledImage
            imageView.imageScaling = .scaleNone
            imageView.autoresizingMask = [.width, .height]
            window.contentView = imageView

            window.orderFront(nil)
            overlayWindows.append(window)
        }

        // 新しい壁紙をセット（オーバーレイの裏側で切り替わる）
        do {
            for screen in NSScreen.screens {
                try NSWorkspace.shared.setDesktopImageURL(imageURL, for: screen, options: [:])
            }
        } catch {
            print("壁紙設定エラー: \(error.localizedDescription)")
        }

        // スタイルに応じたアニメーション
        switch style {
        case .crossfade:
            animateFadeOut(duration: 2.0)
        case .slideLeft:
            animateSlide(dx: -1, dy: 0, duration: 1.2)
        case .slideRight:
            animateSlide(dx: 1, dy: 0, duration: 1.2)
        case .slideUp:
            animateSlide(dx: 0, dy: 1, duration: 1.2)
        case .slideDown:
            animateSlide(dx: 0, dy: -1, duration: 1.2)
        case .fade:
            animateFadeToBlack(duration: 1.5)
        }
    }

    // MARK: - Animation Helpers

    private static func animateFadeOut(duration: Double) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for window in overlayWindows {
                window.animator().alphaValue = 0.0
            }
        }, completionHandler: {
            transitionDidFinish()
        })
    }

    private static func animateSlide(dx: CGFloat, dy: CGFloat, duration: Double) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for window in overlayWindows {
                var frame = window.frame
                frame.origin.x += frame.width * dx
                frame.origin.y += frame.height * dy
                window.animator().setFrame(frame, display: true)
                window.animator().alphaValue = 0.3
            }
        }, completionHandler: {
            transitionDidFinish()
        })
    }

    private static func animateFadeToBlack(duration: Double) {
        let halfDuration = duration / 2.0
        // まず黒にフェード
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = halfDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            for window in overlayWindows {
                if let imageView = window.contentView as? NSImageView {
                    imageView.animator().alphaValue = 0.0
                }
            }
        }, completionHandler: {
            // 黒背景のままフェードアウト
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = halfDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                for window in overlayWindows {
                    window.animator().alphaValue = 0.0
                }
            }, completionHandler: {
                transitionDidFinish()
            })
        })
    }

    /// トランジション完了時に呼ばれる共通処理
    private static func transitionDidFinish() {
        cleanUpOverlays()
        isTransitioning = false

        // 保留中のリクエストがあれば実行
        if let pending = pendingRequest {
            pendingRequest = nil
            pending()
        }
    }

    private static func cleanUpOverlays() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }

    /// macOSの「画面全体に表示」と同じ描画（外部からもアクセス可能）
    static func renderFillImagePublic(_ source: NSImage, to targetSize: NSSize) -> NSImage {
        return renderFillImage(source, to: targetSize)
    }

    /// macOSの「画面全体に表示」と同じ描画：アスペクト比を維持しつつ画面を埋め、はみ出た部分は中央トリミング
    private static func renderFillImage(_ source: NSImage, to targetSize: NSSize) -> NSImage {
        let sourceSize = source.size
        let scaleX = targetSize.width / sourceSize.width
        let scaleY = targetSize.height / sourceSize.height
        let scale = max(scaleX, scaleY)

        let scaledWidth = sourceSize.width * scale
        let scaledHeight = sourceSize.height * scale
        let offsetX = (targetSize.width - scaledWidth) / 2.0
        let offsetY = (targetSize.height - scaledHeight) / 2.0

        let result = NSImage(size: targetSize)
        result.lockFocus()
        source.draw(
            in: NSRect(x: offsetX, y: offsetY, width: scaledWidth, height: scaledHeight),
            from: .zero,
            operation: .copy,
            fraction: 1.0
        )
        result.unlockFocus()
        return result
    }
}
