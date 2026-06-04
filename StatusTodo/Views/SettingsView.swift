import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: TodoStore
    @State private var newCategoryName = ""
    @State private var editingId: UUID? = nil
    @State private var editingName = ""
    @State private var showDeleteAllConfirm = false
    @State private var showClearDoneConfirm = false
    @State private var backupFlash = false

    var body: some View {
        TabView {
            categoriesTab
                .tabItem { Label("Categories", systemImage: "folder") }

            automationTab
                .tabItem { Label("Automation", systemImage: "clock.arrow.2.circlepath") }

            backupTab
                .tabItem { Label("Backup", systemImage: "externaldrive") }

            dangerTab
                .tabItem { Label("Danger Zone", systemImage: "exclamationmark.triangle") }
        }
        .frame(width: 460, height: 400)
        .preferredColorScheme(.dark)
    }

    // MARK: - Categories

    private var categoriesTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Drag to reorder. Double-click a name to rename.")
                .font(.caption)
                .foregroundColor(.gray)

            List {
                ForEach(store.sortedCategories) { category in
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.gray.opacity(0.4))
                            .font(.system(size: 11))

                        if editingId == category.id {
                            TextField("Name", text: $editingName)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit { commitRename(category.id) }
                                .onExitCommand { editingId = nil }
                        } else {
                            Text(category.name)
                                .font(.system(size: 13))
                                .onTapGesture(count: 2) {
                                    editingName = category.name
                                    editingId = category.id
                                }
                        }

                        Spacer()

                        let count = store.items.filter { $0.categoryId == category.id }.count
                        Text("\(count) item\(count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Button {
                            store.deleteCategory(category.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(Color(hex: "E2445C").opacity(0.8))
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
                .onMove(perform: store.moveCategories)
            }
            .listStyle(.plain)
            .background(Color(hex: "222222"))
            .cornerRadius(8)
            .frame(minHeight: 100)

            HStack(spacing: 8) {
                TextField("New category name", text: $newCategoryName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addCategory() }
                Button("Add") { addCategory() }
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
    }

    // MARK: - Automation

    private var automationTab: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $store.launchAtLogin)
                Toggle("Keep window always on top", isOn: $store.alwaysOnTop)
                    .onChange(of: store.alwaysOnTop) { _, value in
                        setWindowLevel(floating: value)
                    }
            }

            Section {
                LabeledContent("Weekly auto-clear") {
                    Text("Every Sunday at 9 pm")
                        .foregroundColor(.gray)
                }
                Text("Done items across all tabs are automatically removed each Sunday night. A backup is saved first.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Backup

    private var backupTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("Saved backups") {
                        Text("\(store.backupCount) / 14")
                            .foregroundColor(.gray)
                    }
                    LabeledContent("Last backup") {
                        if let date = store.latestBackupDate {
                            Text(date, style: .relative) + Text(" ago")
                        } else {
                            Text("None yet").foregroundColor(.gray)
                        }
                    }
                    Text("Backups are saved automatically on launch and before each Sunday auto-clear. The 14 most recent are kept.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(8)
            }

            HStack(spacing: 12) {
                Button {
                    store.backupNow()
                    backupFlash = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { backupFlash = false }
                } label: {
                    Label(backupFlash ? "Backed up!" : "Back up now", systemImage: backupFlash ? "checkmark" : "externaldrive.badge.plus")
                }
                .tint(backupFlash ? .green : .accentColor)

                Button {
                    store.openBackupFolder()
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Danger Zone

    private var dangerTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("These actions cannot be undone. A backup is recommended first.")
                .font(.caption)
                .foregroundColor(.gray)

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Button("Clear done items in current tab") {
                        showClearDoneConfirm = true
                    }
                    .foregroundColor(Color(hex: "FF8C00"))
                    .alert("Clear done items?", isPresented: $showClearDoneConfirm) {
                        Button("Clear", role: .destructive) { store.clearDoneItems() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Removes all done items from the currently selected tab.")
                    }

                    Divider()

                    Button("Delete ALL items in current tab") {
                        showDeleteAllConfirm = true
                    }
                    .foregroundColor(Color(hex: "E2445C"))
                    .alert("Delete all items?", isPresented: $showDeleteAllConfirm) {
                        Button("Delete", role: .destructive) { store.deleteAllItems() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Permanently deletes every item in the current tab.")
                    }
                }
                .padding(8)
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Helpers

    private func addCategory() {
        store.addCategory(name: newCategoryName)
        newCategoryName = ""
    }

    private func commitRename(_ id: UUID) {
        store.renameCategory(id, to: editingName)
        editingId = nil
    }

    private func setWindowLevel(floating: Bool) {
        NSApp.windows.forEach { $0.level = floating ? .floating : .normal }
    }
}
