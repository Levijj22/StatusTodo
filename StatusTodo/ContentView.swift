import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: TodoStore

    private var statusSummary: [(TodoStatus, Int)] {
        TodoStatus.allCases.compactMap { status in
            let count = store.filteredItems.filter { $0.status == status }.count
            return count > 0 ? (status, count) : nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Top toolbar ────────────────────────────────────
            HStack(spacing: 10) {
                // Status counts
                HStack(spacing: 8) {
                    ForEach(statusSummary, id: \.0) { status, count in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(status.color)
                                .frame(width: 7, height: 7)
                            Text("\(count)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.65))
                        }
                    }
                }

                Spacer()

                Button {
                    store.clearDoneItems()
                } label: {
                    Image(systemName: "checkmark.circle")
                        .toolbarIcon()
                }
                .buttonStyle(.plain)
                .help("Clear done items")

                SettingsLink {
                    Image(systemName: "gearshape")
                        .toolbarIcon()
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))

            Rectangle()
                .fill(Color.gray.opacity(0.18))
                .frame(height: 1)

            // ── Main list ──────────────────────────────────────
            TodoListView()

            // ── Category tabs ──────────────────────────────────
            CategoryTabBar()
        }
        .background(VisualEffectBackground().ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

// Small helper to keep icon styling DRY
private extension Image {
    func toolbarIcon() -> some View {
        self
            .foregroundColor(Color.gray.opacity(0.7))
            .font(.system(size: 14))
            .frame(width: 24, height: 24)
    }
}
