import AppKit
import Combine
import SwiftUI
import Metal

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let store = PresetStore()
    private var editorWindow: NSWindow?
    private var shuffleTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: "WallpaperSwitcher")
        }
        rebuildMenu()

        // 起動時にアクティブプリセットのタイマーを復元
        restartTimerIfNeeded()

        // 初回起動時はオンボーディングを表示
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            showOnboarding()
        }

        // StoreのプリセットやアクティブIDが変わったらメニューを再構築
        store.objectWillChange.receive(on: RunLoop.main).sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.rebuildMenu()
            }
        }.store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Menu Construction

    func rebuildMenu() {
        let menu = NSMenu()

        // プリセット一覧
        for preset in store.presets {
            let item = NSMenuItem(title: preset.name, action: #selector(presetSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset.id
            if preset.id == store.activePresetID {
                item.state = .on
            }
            menu.addItem(item)
        }

        if !store.presets.isEmpty {
            menu.addItem(NSMenuItem.separator())
        }

        // 次の壁紙（アクティブプリセットがある場合のみ表示）
        if store.activePresetID != nil {
            let nextItem = NSMenuItem(title: "次の壁紙", action: #selector(nextWallpaper), keyEquivalent: "")
            nextItem.target = self
            menu.addItem(nextItem)
            menu.addItem(NSMenuItem.separator())
        }

        // プリセット追加
        let addItem = NSMenuItem(title: "プリセットを追加", action: #selector(addPreset), keyEquivalent: "")
        addItem.target = self
        menu.addItem(addItem)

        // プリセット編集
        let editItem = NSMenuItem(title: "プリセットを編集", action: #selector(editPresets), keyEquivalent: "")
        editItem.target = self
        menu.addItem(editItem)

        menu.addItem(NSMenuItem.separator())

        // 設定
        let settingsItem = NSMenuItem(title: "設定", action: #selector(showSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // 終了
        let quitItem = NSMenuItem(title: "終了", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func presetSelected(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let preset = store.presets.first(where: { $0.id == id }) else { return }

        store.setActive(preset)
        applyAndUpdateIndex(for: preset)
        restartTimerIfNeeded()
    }

    @objc private func nextWallpaper() {
        guard let id = store.activePresetID,
              let preset = store.presets.first(where: { $0.id == id }) else { return }
        applyAndUpdateIndex(for: preset)
    }

    @objc private func showSettings() {
        closeEditorWindow()

        let settingsView = SettingsView {
            self.showOnboarding()
        }
        let hostingView = NSHostingView(rootView: settingsView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.title = "設定"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        editorWindow = window
    }

    private func showOnboarding() {
        closeEditorWindow()

        let onboardingView = OnboardingView { [weak self] preset in
            guard let self else { return }

            // ウィンドウの中心座標を取得
            let windowCenter: CGPoint
            if let frame = self.editorWindow?.frame, let screenFrame = self.editorWindow?.screen?.frame {
                windowCenter = CGPoint(
                    x: frame.midX,
                    y: screenFrame.height - frame.midY
                )
            } else {
                let screen = NSScreen.main!
                windowCenter = CGPoint(x: screen.frame.midX, y: screen.frame.midY)
            }

            self.store.add(preset)
            self.store.setActive(preset)

            // 光の演出を開始してから壁紙適用
            self.performLightRipple(from: windowCenter) {
                let newIndex = WallpaperService.applyWallpaper(for: preset)
                if var updated = self.store.presets.first(where: { $0.id == preset.id }) {
                    updated.currentIndex = newIndex
                    self.store.update(updated)
                }
            }

            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            self.closeEditorWindow()
            self.rebuildMenu()
            self.restartTimerIfNeeded()
        }

        let hostingView = NSHostingView(rootView: onboardingView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.title = "WallpaperSwitcher セットアップ"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        editorWindow = window
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = min(max((x - edge0) / (edge1 - edge0), 0.0), 1.0)
        return t * t * (3.0 - 2.0 * t)
    }

    // MARK: - Light Ripple Effect (Metal GPU Shader)

    private static let lightWaveShader = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexOut {
        float4 position [[position]];
        float2 uv;
    };

    struct Uniforms {
        float2 center;
        float progress;
        float maxRadius;
        float2 screenSize;
        float time;
        float padding;
    };

    vertex VertexOut lightWaveVertex(uint vid [[vertex_id]]) {
        float2 pos[6] = {
            float2(-1,-1), float2(1,-1), float2(-1,1),
            float2(-1,1),  float2(1,-1), float2(1,1)
        };
        VertexOut out;
        out.position = float4(pos[vid], 0, 1);
        out.uv = pos[vid] * 0.5 + 0.5;
        return out;
    }

    fragment float4 lightWaveFragment(VertexOut in [[stage_in]],
                                       constant Uniforms& u [[buffer(0)]]) {
        float2 pixelPos = in.uv * u.screenSize;
        float dist = distance(pixelPos, u.center);

        // 波の展開は progress 0.0〜0.6 でゆっくり完了
        float waveProgress = saturate(u.progress / 0.6);
        float wavefront = waveProgress * u.maxRadius;

        // --- ガウシアン色収差（リングの先端） ---
        float caShift = 40.0;
        float bandW = 130.0;
        float inv2s = 1.0 / (2.0 * bandW * bandW);

        float rI = exp(-(dist - (wavefront + caShift)) * (dist - (wavefront + caShift)) * inv2s);
        float gI = exp(-(dist - wavefront) * (dist - wavefront) * inv2s);
        float bI = exp(-(dist - (wavefront - caShift)) * (dist - (wavefront - caShift)) * inv2s);

        // --- スペクトラルフリンジ ---
        float nW = 65.0;
        float inv2n = 1.0 / (2.0 * nW * nW);
        float warmI = exp(-(dist - (wavefront + caShift * 2.2)) * (dist - (wavefront + caShift * 2.2)) * inv2n);
        float coolI = exp(-(dist - (wavefront - caShift * 2.2)) * (dist - (wavefront - caShift * 2.2)) * inv2n);

        // --- リング部分の色 ---
        float3 ringColor = float3(0.0);
        ringColor += float3(rI, gI * 0.97, bI * 0.93) * 0.6;
        ringColor += float3(1.0, 0.5, 0.12) * warmI * 0.35;
        ringColor += float3(0.35, 0.12, 1.0) * coolI * 0.35;

        // シマー
        float shimmer = sin(dist * 0.018 + u.time * 5.0) * 0.04 + 1.0;
        ringColor *= shimmer;

        // リングは展開中のみ、ゆっくりフェード
        float ringFade = 1.0 - smoothstep(0.45, 0.7, u.progress);
        ringColor *= ringFade;

        // --- 光の蓄積（波が通過した領域がじんわり明るくなる） ---
        float passed = smoothstep(wavefront + bandW, wavefront - bandW * 0.5, dist);
        float buildUp = passed * smoothstep(0.05, 0.35, u.progress);

        // --- 全画面グロー（しっかり覆い尽くしてから、ゆっくり引く） ---
        float glowUp = smoothstep(0.15, 0.45, u.progress);   // 早めに上がる
        float glowHold = 1.0 - smoothstep(0.55, 0.65, u.progress); // ピーク維持
        float glowDn = 1.0 - smoothstep(0.65, 1.0, u.progress);   // ゆっくり引く
        float glow = glowUp * glowHold * glowDn;

        // 蓄積光
        float3 fillColor = float3(0.95, 0.93, 1.0) * buildUp * 0.3;
        // グロー（画面を覆い尽くす強さ）
        fillColor += float3(0.97, 0.96, 1.0) * glow * 0.85;

        // --- 合成 ---
        float3 color = ringColor + fillColor;

        float a = saturate(max(max(color.r, color.g), color.b));
        return float4(color, a);
    }
    """

    private func performLightRipple(from center: CGPoint, applyWallpaper: @escaping () -> Void) {
        guard let screen = NSScreen.main else {
            applyWallpaper()
            return
        }

        let screenFrame = screen.frame
        let screenSize = screenFrame.size
        let centerInAppKit = CGPoint(x: center.x, y: screenFrame.height - center.y)

        guard let currentWallpaperURL = NSWorkspace.shared.desktopImageURL(for: screen),
              let oldImage = NSImage(contentsOf: currentWallpaperURL) else {
            applyWallpaper()
            return
        }

        let filledImage = WallpaperService.renderFillImagePublic(oldImage, to: screenSize)

        // --- Metal セットアップ ---
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue(),
              let library = try? device.makeLibrary(source: Self.lightWaveShader, options: nil),
              let vertFunc = library.makeFunction(name: "lightWaveVertex"),
              let fragFunc = library.makeFunction(name: "lightWaveFragment") else {
            applyWallpaper()
            return
        }

        let pipeDesc = MTLRenderPipelineDescriptor()
        pipeDesc.vertexFunction = vertFunc
        pipeDesc.fragmentFunction = fragFunc
        pipeDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipeDesc.colorAttachments[0].isBlendingEnabled = true
        pipeDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipeDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipeDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
        pipeDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipeDesc) else {
            applyWallpaper()
            return
        }

        // --- オーバーレイウィンドウ ---
        let overlayWindow = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        overlayWindow.backgroundColor = .clear
        overlayWindow.isOpaque = false
        overlayWindow.hasShadow = false
        overlayWindow.ignoresMouseEvents = true
        overlayWindow.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
        overlayWindow.animationBehavior = .none

        let overlayView = NSView(frame: NSRect(origin: .zero, size: screenSize))
        overlayView.wantsLayer = true
        overlayView.layer = CALayer()
        overlayView.layer?.frame = NSRect(origin: .zero, size: screenSize)
        overlayWindow.contentView = overlayView

        guard let rootLayer = overlayView.layer else {
            applyWallpaper()
            return
        }

        // 旧壁紙画像レイヤー
        let imageLayer = CALayer()
        imageLayer.frame = NSRect(origin: .zero, size: screenSize)
        imageLayer.contentsGravity = .resizeAspectFill
        imageLayer.contents = filledImage
        rootLayer.addSublayer(imageLayer)

        // Metal レイヤー（光エフェクト、スクリーン合成）
        let metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.frame = NSRect(origin: .zero, size: screenSize)
        metalLayer.drawableSize = CGSize(
            width: screenSize.width * screen.backingScaleFactor,
            height: screenSize.height * screen.backingScaleFactor
        )
        metalLayer.isOpaque = false
        metalLayer.compositingFilter = "screenBlendMode"
        rootLayer.addSublayer(metalLayer)

        let maxDist = max(
            hypot(center.x, center.y),
            hypot(screenFrame.width - center.x, center.y),
            hypot(center.x, screenFrame.height - center.y),
            hypot(screenFrame.width - center.x, screenFrame.height - center.y)
        ) + 100

        // 壁紙適用（オーバーレイの裏で新壁紙に切り替わる）＆表示
        applyWallpaper()
        overlayWindow.orderFront(nil)

        // --- フレームループ ---
        // タイムライン:
        //   0.0〜0.45: 光の波が中心から画面全体へ広がる
        //   0.45〜0.65: 画面が光で完全に覆い尽くされる（ピーク）
        //   0.55〜0.65: 光に隠れた状態で旧壁紙をフェードアウト
        //   0.65〜1.0: 光がゆっくり引いて新壁紙が現れる
        let duration: TimeInterval = 4.5
        let animStart = CACurrentMediaTime()

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            let elapsed = CACurrentMediaTime() - animStart
            let rawT = min(Float(elapsed / duration), 1.0)
            // quadratic ease-in-out（ゆっくり始まり、ゆっくり終わる）
            let progress: Float = rawT < 0.5
                ? 2.0 * rawT * rawT
                : 1.0 - pow(-2.0 * rawT + 2.0, 2) / 2.0

            // 旧壁紙のフェードアウト（光が画面を完全に覆った瞬間に消す）
            let wallpaperFade: Float = 1.0 - Float(AppDelegate.smoothstep(0.55, 0.65, Double(progress)))
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            imageLayer.opacity = wallpaperFade
            CATransaction.commit()

            // Metal 描画
            guard let drawable = metalLayer.nextDrawable() else { return }

            var uniforms = (
                SIMD2<Float>(Float(centerInAppKit.x), Float(centerInAppKit.y)),
                progress,
                Float(maxDist),
                SIMD2<Float>(Float(screenSize.width), Float(screenSize.height)),
                Float(elapsed),
                Float(0)
            )

            let rpd = MTLRenderPassDescriptor()
            rpd.colorAttachments[0].texture = drawable.texture
            rpd.colorAttachments[0].loadAction = .clear
            rpd.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            rpd.colorAttachments[0].storeAction = .store

            guard let cb = commandQueue.makeCommandBuffer(),
                  let enc = cb.makeRenderCommandEncoder(descriptor: rpd) else { return }

            enc.setRenderPipelineState(pipelineState)
            enc.setFragmentBytes(&uniforms, length: MemoryLayout.size(ofValue: uniforms), index: 0)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            enc.endEncoding()

            cb.present(drawable)
            cb.commit()

            if rawT >= 1.0 {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    overlayWindow.orderOut(nil)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func addPreset() {
        showEditorWindow(preset: nil)
    }

    @objc private func editPresets() {
        showPresetListWindow()
    }

    // MARK: - Editor Window

    private func showEditorWindow(preset: Preset?) {
        closeEditorWindow()

        let editorView = PresetEditorView(preset: preset) { [weak self] savedPreset in
            guard let self else { return }
            if preset != nil {
                self.store.update(savedPreset)
            } else {
                self.store.add(savedPreset)
            }
            self.closeEditorWindow()
            self.rebuildMenu()
            self.restartTimerIfNeeded()
        } onCancel: { [weak self] in
            self?.closeEditorWindow()
        }

        let hostingView = NSHostingView(rootView: editorView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.title = preset == nil ? "プリセットを追加" : "プリセットを編集"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        editorWindow = window
    }

    private func showPresetListWindow() {
        closeEditorWindow()

        let listView = PresetListView(store: store) { [weak self] preset in
            self?.showEditorWindow(preset: preset)
        } onClose: { [weak self] in
            self?.closeEditorWindow()
            self?.rebuildMenu()
        }

        let hostingView = NSHostingView(rootView: listView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.title = "プリセットを編集"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        editorWindow = window
    }

    private func closeEditorWindow() {
        editorWindow?.close()
        editorWindow = nil
    }

    // MARK: - Wallpaper Apply & Timer

    private func applyAndUpdateIndex(for preset: Preset) {
        let newIndex = WallpaperService.applyWallpaper(for: preset)
        if var updated = store.presets.first(where: { $0.id == preset.id }) {
            updated.currentIndex = newIndex
            store.update(updated)
        }
    }

    private func restartTimerIfNeeded() {
        shuffleTimer?.invalidate()
        shuffleTimer = nil

        guard let id = store.activePresetID,
              let preset = store.presets.first(where: { $0.id == id }),
              preset.shuffleInterval != .off else { return }

        let interval = TimeInterval(preset.shuffleInterval.rawValue)
        shuffleTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self,
                  let current = self.store.presets.first(where: { $0.id == id }) else { return }
            self.applyAndUpdateIndex(for: current)
        }
    }
}
