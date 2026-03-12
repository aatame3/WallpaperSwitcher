import SwiftUI

struct PresetEditorView: View {
    @State private var name: String
    @State private var folderPath: String
    @State private var folderBookmark: Data?
    @State private var shuffleInterval: ShuffleInterval
    @State private var order: WallpaperOrder
    @State private var transitionStyle: TransitionStyle
    private let existingID: UUID?
    private let existingIndex: Int
    private let onSave: (Preset) -> Void
    private let onCancel: () -> Void

    init(preset: Preset?, onSave: @escaping (Preset) -> Void, onCancel: @escaping () -> Void) {
        _name = State(initialValue: preset?.name ?? "")
        _folderPath = State(initialValue: preset?.folderPath ?? "")
        _folderBookmark = State(initialValue: preset?.folderBookmark)
        _shuffleInterval = State(initialValue: preset?.shuffleInterval ?? .off)
        _order = State(initialValue: preset?.order ?? .random)
        _transitionStyle = State(initialValue: preset?.transitionStyle ?? .crossfade)
        existingID = preset?.id
        existingIndex = preset?.currentIndex ?? 0
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(existingID == nil ? "新しいプリセット" : "プリセットを編集")
                .font(.headline)

            TextField("プリセット名", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                TextField("フォルダパス", text: $folderPath)
                    .textFieldStyle(.roundedBorder)
                Button("選択…") {
                    chooseFolder()
                }
            }

            Divider()

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
                .frame(width: 200)
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

            HStack {
                Spacer()
                Button("キャンセル") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                Button("保存") {
                    let preset = Preset(
                        id: existingID ?? UUID(),
                        name: name,
                        folderPath: folderPath,
                        folderBookmark: folderBookmark,
                        shuffleInterval: shuffleInterval,
                        order: order,
                        transitionStyle: transitionStyle,
                        currentIndex: existingIndex
                    )
                    onSave(preset)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || folderPath.isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 400)
    }

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
