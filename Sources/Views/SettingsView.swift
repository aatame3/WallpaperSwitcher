import SwiftUI
import ServiceManagement

struct SettingsView: View {
    let onReplayOnboarding: () -> Void

    var body: some View {
        TabView {
            GeneralTab(onReplayOnboarding: onReplayOnboarding)
                .tabItem {
                    Label("一般", systemImage: "gearshape")
                }

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 400, height: 340)
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    let onReplayOnboarding: () -> Void
    @State private var launchAtLogin = false

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                Text("一般設定")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // カード風セクション
            VStack(spacing: 12) {
                // 起動設定
                SettingsRow(
                    icon: "power.circle.fill",
                    iconColor: .green,
                    title: "ログイン時に起動",
                    subtitle: "Mac起動時に自動で常駐します"
                ) {
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: launchAtLogin) { newValue in
                            toggleLaunchAtLogin(enabled: newValue)
                        }
                }

                Divider().padding(.horizontal, 8)

                // はじめてガイド
                SettingsRow(
                    icon: "sparkles",
                    iconColor: .purple,
                    title: "はじめてガイドを再生",
                    subtitle: "セットアップウィザードをもう一度"
                ) {
                    Button {
                        onReplayOnboarding()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.accentColor)
                            .frame(width: 28, height: 28)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
            )
            .padding(.horizontal, 20)

            Spacer()

            // フッター
            Text("WallpaperSwitcher v1.0.0")
                .font(.caption2)
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                .padding(.bottom, 12)
        }
        .onAppear {
            if #available(macOS 13.0, *) {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    private func toggleLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("ログイン項目の変更に失敗: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Settings Row

private struct SettingsRow<Trailing: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(iconColor.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            trailing()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - About Tab

private struct AboutTab: View {
    @State private var iconScale: CGFloat = 0.8
    @State private var iconOpacity: Double = 0

    var body: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 8)

            // アイコン（アニメーション付き）
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 52, weight: .thin))
                .foregroundColor(.white)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        iconScale = 1.0
                        iconOpacity = 1.0
                    }
                }

            Text("WallpaperSwitcher")
                .font(.system(size: 20, weight: .bold, design: .rounded))

            Text("バージョン 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.secondary.opacity(0.1)))

            Text("壁紙プリセットをワンクリックで切り替え")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 4)

            // クレジット
            VStack(spacing: 6) {
                HStack(spacing: 0) {
                    Text("Vibe-coded by ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("@aatame3")
                        .font(.system(size: 12, weight: .medium))
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

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
