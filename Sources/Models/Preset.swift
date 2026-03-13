import Foundation

/// 壁紙切り替えのトリガー
enum WallpaperTrigger: Int, Codable, CaseIterable, Equatable {
    case off = 0
    case everyMinute = 60
    case every5Minutes = 300
    case every15Minutes = 900
    case every30Minutes = 1800
    case everyHour = 3600
    case onUnlock = -1
    case daily = -2

    var label: String {
        switch self {
        case .off: return "オフ"
        case .everyMinute: return "1分ごと"
        case .every5Minutes: return "5分ごと"
        case .every15Minutes: return "15分ごと"
        case .every30Minutes: return "30分ごと"
        case .everyHour: return "1時間ごと"
        case .onUnlock: return "画面ロック解除時"
        case .daily: return "1日1回"
        }
    }
}

/// 壁紙の選択順序
enum WallpaperOrder: String, Codable, CaseIterable, Equatable {
    case random = "random"
    case sequential = "sequential"

    var label: String {
        switch self {
        case .random: return "ランダム"
        case .sequential: return "順序どおり"
        }
    }
}

/// トランジションスタイル
enum TransitionStyle: String, Codable, CaseIterable, Equatable {
    case crossfade = "crossfade"
    case slideLeft = "slideLeft"
    case slideRight = "slideRight"
    case slideUp = "slideUp"
    case slideDown = "slideDown"
    case fade = "fade"

    var label: String {
        switch self {
        case .crossfade: return "クロスフェード"
        case .slideLeft: return "左へスライド"
        case .slideRight: return "右へスライド"
        case .slideUp: return "上へスライド"
        case .slideDown: return "下へスライド"
        case .fade: return "フェード（黒）"
        }
    }
}

struct Preset: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var folderPath: String
    var folderBookmark: Data?
    var trigger: WallpaperTrigger
    var order: WallpaperOrder
    var transitionStyle: TransitionStyle
    var currentIndex: Int

    init(id: UUID = UUID(), name: String, folderPath: String, folderBookmark: Data? = nil,
         trigger: WallpaperTrigger = .off, order: WallpaperOrder = .random,
         transitionStyle: TransitionStyle = .crossfade, currentIndex: Int = 0) {
        self.id = id
        self.name = name
        self.folderPath = folderPath
        self.folderBookmark = folderBookmark
        self.trigger = trigger
        self.order = order
        self.transitionStyle = transitionStyle
        self.currentIndex = currentIndex
    }

    // 旧 "shuffleInterval" キーからのマイグレーション
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        folderPath = try container.decode(String.self, forKey: .folderPath)
        folderBookmark = try container.decodeIfPresent(Data.self, forKey: .folderBookmark)
        order = try container.decode(WallpaperOrder.self, forKey: .order)
        transitionStyle = try container.decode(TransitionStyle.self, forKey: .transitionStyle)
        currentIndex = try container.decode(Int.self, forKey: .currentIndex)

        if let t = try? container.decode(WallpaperTrigger.self, forKey: .trigger) {
            trigger = t
        } else {
            // 旧キー "shuffleInterval" から読み込み
            trigger = (try? container.decode(WallpaperTrigger.self, forKey: .shuffleInterval)) ?? .off
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(folderPath, forKey: .folderPath)
        try container.encodeIfPresent(folderBookmark, forKey: .folderBookmark)
        try container.encode(trigger, forKey: .trigger)
        try container.encode(order, forKey: .order)
        try container.encode(transitionStyle, forKey: .transitionStyle)
        try container.encode(currentIndex, forKey: .currentIndex)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, folderPath, folderBookmark, trigger, order, transitionStyle, currentIndex
        case shuffleInterval // 旧キー（読み込み専用）
    }

    static func == (lhs: Preset, rhs: Preset) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.folderPath == rhs.folderPath &&
        lhs.folderBookmark == rhs.folderBookmark && lhs.trigger == rhs.trigger &&
        lhs.order == rhs.order && lhs.transitionStyle == rhs.transitionStyle &&
        lhs.currentIndex == rhs.currentIndex
    }
}

// MARK: - Security-Scoped Bookmark Helpers

enum FolderAccess {
    /// NSOpenPanel で選ばれた URL から bookmark を作成
    static func createBookmark(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// 保存した bookmark から URL を復元し、アクセスを開始する
    /// 返された URL は使い終わったら stopAccessingSecurityScopedResource() を呼ぶこと
    static func resolveBookmark(_ bookmark: Data) -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        if isStale {
            // ブックマークが古い場合、再作成を試みる（アクセス権がまだあれば成功する）
            _ = try? url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }

        guard url.startAccessingSecurityScopedResource() else { return nil }
        return url
    }
}
