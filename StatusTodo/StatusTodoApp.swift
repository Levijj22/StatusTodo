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
