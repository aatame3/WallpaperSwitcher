import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("WallpaperSwitcher")
                .font(.title2)
                .fontWeight(.bold)

            Text("バージョン 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("壁紙プリセットをワンクリックで切り替え")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 4)

            HStack(spacing: 0) {
                Text("Vibe-coded by ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("@aatame3")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .onTapGesture {
                        if let url = URL(string: "https://aata.me") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                Text(" with Claude Opus")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 4) {
                Text("Made with")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("💩")
                    .font(.caption)
                Text("in Kagoshima")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .frame(width: 300)
    }
}
