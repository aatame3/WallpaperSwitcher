import SwiftUI
import UniformTypeIdentifiers

struct PresetEditorView: View {
    @State private var name: String
    @State private var folderPath: String
    @State private var folderBookmark: Data?
    @State private var trigger: WallpaperTrigger
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
        _trigger = State(initialValue: preset?.trigger ?? .off)
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
                TextField("壁紙またはフォルダ", text: $folderPath)
                    .textFieldStyle(.roundedBorder)
                Button("選択…") {
                    chooseFolder()
                }
            }

            Divider()

            if !isSingleFile {
                HStack {
                    Text("切り替え")
                    Spacer()
                    Picker("", selection: $trigger) {
                        ForEach(WallpaperTrigger.allCases, id: \.self) { t in
                            Text(t.label).tag(t)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
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
                        trigger: trigger,
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

    private var isSingleFile: Bool {
        guard !folderPath.isEmpty else { return false }
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: folderPath, isDirectory: &isDir) && !isDir.boolValue
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.jpeg, .png, .heic]
        panel.message = "壁紙ファイルまたはフォルダを選択してください"
        if panel.runModal() == .OK, let url = panel.url {
            folderPath = url.path
            folderBookmark = FolderAccess.createBookmark(for: url)
        }
    }
}
