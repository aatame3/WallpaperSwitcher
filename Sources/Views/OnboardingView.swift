import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var presetName = ""
    @State private var folderPath = ""
    @State private var folderBookmark: Data?
    @State private var shuffleInterval: ShuffleInterval = .off
    @State private var order: WallpaperOrder = .random
    @State private var transitionStyle: TransitionStyle = .crossfade

    // アニメーション用State
    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var gearRotation: Double = 0

    let onComplete: (Preset) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // ページコンテンツ
            ZStack {
                pageContent(for: 0, view: welcomePage)
                pageContent(for: 1, view: namePage)
                pageContent(for: 2, view: folderPage)
                pageContent(for: 3, view: settingsPage)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // ナビゲーションバー
            HStack {
                // ページインジケーター
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? Color.primary.opacity(0.7) : Color.secondary.opacity(0.2))
                            .frame(width: i == currentPage ? 18 : 6, height: 6)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
                    }
                }

                Spacer()

                if currentPage > 0 {
                    Button("戻る") {
                        navigateTo(currentPage - 1)
                    }
                }

                if currentPage < 3 {
                    Button("次へ") {
                        navigateTo(currentPage + 1)
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canProceed)
                } else {
                    Button("始める！") {
                        let preset = Preset(
                            name: presetName,
                            folderPath: folderPath,
                            folderBookmark: folderBookmark,
                            shuffleInterval: shuffleInterval,
                            order: order,
                            transitionStyle: transitionStyle
                        )
                        onComplete(preset)
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canFinish)
                }
            }
            .padding(16)
        }
        .frame(width: 480, height: 380)
        .onAppear {
            startEntranceAnimation()
        }
    }

    // MARK: - Page Wrapper

    private func pageContent<V: View>(for page: Int, view: V) -> some View {
        view
            .opacity(currentPage == page ? 1 : 0)
            .offset(x: currentPage == page ? 0 : (currentPage > page ? -30 : 30))
            .animation(.easeInOut(duration: 0.35), value: currentPage)
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

            VStack(spacing: 6) {
                Text("WallpaperSwitcher")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)

                Text("へようこそ！")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)
            }

            Text("壁紙のプリセットを作って、\nワンクリックで気分を切り替えよう")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .opacity(subtitleOpacity)

            Spacer()
        }
        .padding(32)
    }

    private var namePage: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "tag.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

            Text("プリセットに名前をつけよう")
                .font(.title2)
                .fontWeight(.semibold)
                .opacity(titleOpacity)
                .offset(y: titleOffset)

            Text("例：「オタク壁紙」「仕事モード」「落ち着く風景」")
                .font(.caption)
                .foregroundColor(.secondary)
                .opacity(subtitleOpacity)

            TextField("プリセット名", text: $presetName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
                .opacity(contentOpacity)

            Spacer()
        }
        .padding(32)
    }

    private var folderPage: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "folder.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

            Text("壁紙フォルダを選ぼう")
                .font(.title2)
                .fontWeight(.semibold)
                .opacity(titleOpacity)
                .offset(y: titleOffset)

            Text("好きな壁紙を入れたフォルダを指定してね\nJPEG・PNG・HEIC に対応しています")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .opacity(subtitleOpacity)

            HStack {
                TextField("フォルダパス", text: $folderPath)
                    .textFieldStyle(.roundedBorder)
                Button("選択…") {
                    chooseFolder()
                }
            }
            .frame(width: 320)
            .opacity(contentOpacity)

            if !folderPath.isEmpty {
                let count = WallpaperService.imageURLs(from: folderPath).count
                Label("\(count) 枚の画像が見つかりました", systemImage: count > 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(count > 0 ? .green : .orange)
                    .transition(.opacity)
            }

            Spacer()
        }
        .padding(32)
    }

    private var settingsPage: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "gearshape.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
                .rotationEffect(.degrees(gearRotation))
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

            Text("お好みに設定")
                .font(.title2)
                .fontWeight(.semibold)
                .opacity(titleOpacity)
                .offset(y: titleOffset)

            Text("あとからいつでも変更できます")
                .font(.caption)
                .foregroundColor(.secondary)
                .opacity(subtitleOpacity)

            VStack(spacing: 12) {
                HStack {
                    Text("シャッフル")
                    Spacer()
                    Picker("", selection: $shuffleInterval) {
                        ForEach(ShuffleInterval.allCases, id: \.self) { interval in
                            Text(interval.label).tag(interval)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                }

                HStack {
                    Text("順序")
                    Spacer()
                    Picker("", selection: $order) {
                        ForEach(WallpaperOrder.allCases, id: \.self) { o in
                            Text(o.label).tag(o)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }

                HStack {
                    Text("トランジション")
                    Spacer()
                    Picker("", selection: $transitionStyle) {
                        ForEach(TransitionStyle.allCases, id: \.self) { style in
                            Text(style.label).tag(style)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }
            }
            .frame(width: 320)
            .opacity(contentOpacity)

            Spacer()
        }
        .padding(32)
    }

    // MARK: - Computed

    private var canProceed: Bool {
        switch currentPage {
        case 1: return !presetName.isEmpty
        case 2: return !folderPath.isEmpty
        default: return true
        }
    }

    private var canFinish: Bool {
        !presetName.isEmpty && !folderPath.isEmpty
    }

    // MARK: - Navigation

    private func navigateTo(_ page: Int) {
        // アニメーション状態をリセット
        iconScale = 0.3
        iconOpacity = 0
        titleOffset = 20
        titleOpacity = 0
        subtitleOpacity = 0
        contentOpacity = 0

        currentPage = page

        // 段階的にアニメーション
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startPageAnimation()
        }
    }

    // MARK: - Animations

    private func startEntranceAnimation() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.25)) {
            titleOffset = 0
            titleOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.45)) {
            subtitleOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.6)) {
            contentOpacity = 1.0
        }
    }

    private func startPageAnimation() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        if currentPage == 3 {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                gearRotation = 360
            }
        } else {
            gearRotation = 0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
            titleOffset = 0
            titleOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.35).delay(0.2)) {
            subtitleOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.35).delay(0.3)) {
            contentOpacity = 1.0
        }
    }

    // MARK: - Helpers

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "壁紙フォルダを選択してください"
        if panel.runModal() == .OK, let url = panel.url {
            folderPath = url.path
            folderBookmark = FolderAccess.createBookmark(for: url)
        }
    }
}
