import SwiftUI

struct PresetListView: View {
    @ObservedObject var store: PresetStore
    let onEdit: (Preset) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if store.presets.isEmpty {
                Spacer()
                Text("プリセットがありません")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(store.presets) { preset in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(preset.name)
                                    .font(.body)
                                Text(preset.folderPath)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if preset.id == store.activePresetID {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                            Button {
                                onEdit(preset)
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)

                            Button {
                                store.delete(preset)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("閉じる") {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
                .padding(8)
            }
        }
        .frame(minWidth: 380, minHeight: 250)
    }
}
