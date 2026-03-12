import Foundation

/// 壁紙シャッフルの間隔
enum ShuffleInterval: Int, Codable, CaseIterable, Equatable {
    case off = 0
    case everyMinute = 60
    case every5Minutes = 300
    case every15Minutes = 900
    case every30Minutes = 1800
    case everyHour = 3600

    var label: String {
        switch self {
        case .off: return "オフ"
        case .everyMinute: return "1分ごと"
        case .every5Minutes: return "5分ごと"
        case .every15Minutes: return "15分ごと"
        case .every30Minutes: return "30分ごと"
        case .everyHour: return "1時間ごと"
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
    var shuffleInterval: ShuffleInterval
    var order: WallpaperOrder
    var transitionStyle: TransitionStyle
    var currentIndex: Int

    init(id: UUID = UUID(), name: String, folderPath: String, folderBookmark: Data? = nil,
         shuffleInterval: ShuffleInterval = .off, order: WallpaperOrder = .random,
         transitionStyle: TransitionStyle = .crossfade, currentIndex: Int = 0) {
        self.id = id
        self.name = name
        self.folderPath = folderPath
        self.folderBookmark = folderBookmark
        self.shuffleInterval = shuffleInterval
        self.order = order
        self.transitionStyle = transitionStyle
        self.currentIndex = currentIndex
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
