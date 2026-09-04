import SwiftUI

@main
struct StatusTodoApp: App {
    @StateObject private var store = TodoStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 320, idealWidth: 420,
                       minHeight: 400, idealHeight: 650)
                .onAppear {
                    if store.alwaysOnTop {
                        NSApp.windows.first?.level = .floating
                    }
                    // Remove title bar buttons we don't need
                    NSApp.windows.first?.titlebarAppearsTransparent = true
                    NSApp.windows.first?.titleVisibility = .hidden
                    // Required for the frosted backing to sample the wallpaper.
                    NSApp.windows.first?.isOpaque = false
                    NSApp.windows.first?.backgroundColor = .clear
                    // Keep the frost dark regardless of wallpaper, otherwise
                    // the white text washes out over a light background.
                    NSApp.windows.first?.appearance = NSAppearance(named: .darkAqua)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
