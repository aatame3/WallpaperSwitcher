import Foundation

final class PresetStore: ObservableObject {
    private static let presetsKey = "savedPresets"
    private static let activePresetIDKey = "activePresetID"

    @Published var presets: [Preset] = []
    @Published var activePresetID: UUID?

    init() {
        load()
    }

    // MARK: - Persistence

    func load() {
        if let data = UserDefaults.standard.data(forKey: Self.presetsKey),
           let decoded = try? JSONDecoder().decode([Preset].self, from: data) {
            presets = decoded
        }
        if let idString = UserDefaults.standard.string(forKey: Self.activePresetIDKey) {
            activePresetID = UUID(uuidString: idString)
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: Self.presetsKey)
        }
        if let id = activePresetID {
            UserDefaults.standard.set(id.uuidString, forKey: Self.activePresetIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.activePresetIDKey)
        }
    }

    // MARK: - CRUD

    func add(_ preset: Preset) {
        presets.append(preset)
        save()
    }

    func update(_ preset: Preset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
            save()
        }
    }

    func delete(_ preset: Preset) {
        presets.removeAll { $0.id == preset.id }
        if activePresetID == preset.id {
            activePresetID = nil
        }
        save()
    }

    func setActive(_ preset: Preset) {
        activePresetID = preset.id
        save()
    }
}
