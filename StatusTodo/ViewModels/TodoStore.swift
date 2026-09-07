import Foundation
import Combine
import ServiceManagement
import AppKit

/// StatusTodo is now a client for Todoist rather than a local store.
///
/// Nothing lives on this Mac any more: Ava (on the VPS) and the phone talk to
/// the same account, so the laptop being asleep or off changes nothing. Local
/// edits are applied optimistically and pushed; a failed push triggers a
/// refresh so the UI can never drift from the server.
@MainActor
class TodoStore: ObservableObject {
    @Published var items: [TodoItem] = []
    @Published var categories: [TodoCategory] = []
    @Published var isLoading = false
    @Published var syncError: String?

    @Published var alwaysOnTop: Bool = false {
        didSet { UserDefaults.standard.set(alwaysOnTop, forKey: "alwaysOnTop") }
    }
    @Published var launchAtLogin: Bool = false {
        didSet { applyLaunchAtLogin(launchAtLogin) }
    }

    private let backup = BackupManager()

    /// Completed tasks are shown greyed until the user cleans up; this marks
    /// the cut-off. Defaults to the start of today on first run.
    private var doneSince: Date {
        get {
            (UserDefaults.standard.object(forKey: "doneSince") as? Date)
                ?? Calendar.current.startOfDay(for: Date())
        }
        set { UserDefaults.standard.set(newValue, forKey: "doneSince") }
    }
    private var refreshTimer: Timer?

    struct AppData: Codable {
        var items: [TodoItem]
        var categories: [TodoCategory]
    }

    init() {
        alwaysOnTop = UserDefaults.standard.bool(forKey: "alwaysOnTop")
        launchAtLogin = SMAppService.mainApp.status == .enabled

        Task { await refresh() }
        startPolling()

        // Re-sync when the window comes back to the front, so changes made on
        // the phone or by Ava show up immediately rather than on the next tick.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    // MARK: - Sync

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let (cats, its) = try await TodoistAPI.fetchAll()
            // Completed tasks are a separate feed; a failure there must not
            // blank the open list, so it degrades to showing none.
            var done: [TodoItem] = []
            do { done = try await TodoistAPI.fetchCompleted(since: doneSince) }
            catch { NSLog("completed fetch failed: \(error)") }
            categories = cats
            items = its + done
            syncError = nil

        } catch {
            syncError = error.localizedDescription
        }
    }

    /// Runs an API call, and on failure resyncs so the UI matches the server.
    private func push(_ work: @escaping () async throws -> Void) {
        Task {
            do {
                try await work()
                syncError = nil
            } catch {
                syncError = error.localizedDescription
                await refresh()
            }
        }
    }

    private func startPolling() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    // MARK: - Computed

    /// Windows each pick their own category, so this is a function rather
    /// than shared state on the store.
    func items(in categoryId: String?) -> [TodoItem] {
        guard let catId = categoryId else { return [] }
        let inCat = items.filter { $0.categoryId == catId }
        let active = inCat.filter { $0.status != .done }.sorted { $0.sortOrder < $1.sortOrder }
        let done = inCat.filter { $0.status == .done }.sorted { $0.sortOrder < $1.sortOrder }
        return active + done
    }

    var sortedCategories: [TodoCategory] {
        categories.sorted { $0.sortOrder < $1.sortOrder }
    }

    func categoryName(_ id: String?) -> String {
        categories.first(where: { $0.id == id })?.name ?? ""
    }

    /// The tab a freshly opened window should land on. Inbox is Todoist's
    /// catch-all, not somewhere he works from.
    var defaultCategoryId: String? {
        sortedCategories.first(where: { $0.name != "Inbox" })?.id ?? sortedCategories.first?.id
    }

    // MARK: - Item operations

    func addItem(title: String, in categoryId: String?) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard let catId = categoryId, !trimmed.isEmpty else { return }
        // Top of the list.
        let minOrder = items.filter { $0.categoryId == catId }.map(\.sortOrder).min() ?? 0

        // Optimistic insert with a placeholder id, swapped for the real one.
        let tempId = "pending-" + UUID().uuidString
        items.append(TodoItem(id: tempId, title: trimmed, status: .todo,
                              categoryId: catId, sortOrder: minOrder - 1))
        Task {
            do {
                let realId = try await TodoistAPI.addTask(trimmed, projectId: catId)
                if let i = items.firstIndex(where: { $0.id == tempId }) {
                    if realId.isEmpty { await refresh() } else { items[i].id = realId }
                }
                syncError = nil
            } catch {
                items.removeAll { $0.id == tempId }
                syncError = error.localizedDescription
            }
        }
    }

    func deleteItems(at offsets: IndexSet, in categoryId: String?) {
        let filtered = items(in: categoryId)
        let ids = offsets.map { filtered[$0].id }
        items.removeAll { ids.contains($0.id) }
        push { for id in ids { try await TodoistAPI.deleteTask(id) } }
    }

    /// Local-only. Todoist ordering is not writable through this API, so a
    /// manual reorder lasts until the next refresh.
    func moveItems(from source: IndexSet, to destination: Int, in categoryId: String?) {
        var filtered = items(in: categoryId)
        filtered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in filtered.enumerated() {
            if let i = items.firstIndex(where: { $0.id == item.id }) {
                items[i].sortOrder = index
            }
        }
        objectWillChange.send()
    }

    /// Marking Done completes the task in Todoist, which removes it from the
    /// list - Todoist does not return completed tasks.
    func updateStatus(_ item: TodoItem, to status: TodoStatus) {
        let id = item.id
        if status == .done {
            items.removeAll { $0.id == id }
        } else if let i = items.firstIndex(where: { $0.id == id }) {
            items[i].status = status
        }
        push { try await TodoistAPI.setStatus(id, status) }
    }

    func updateTitle(_ item: TodoItem, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        let id = item.id
        items[i].title = trimmed
        push { try await TodoistAPI.setTitle(id, trimmed) }
    }

    /// Hides completed tasks. They are already closed in Todoist - this just
    /// moves the cut-off forward so they stop being listed.
    func clearDoneItems() {
        doneSince = Date()
        items.removeAll { $0.status == .done }
    }

    func clearAllDoneItems() { clearDoneItems() }

    func deleteAllItems(in categoryId: String?) {
        guard let catId = categoryId else { return }
        let ids = items.filter { $0.categoryId == catId }.map(\.id)
        items.removeAll { $0.categoryId == catId }
        push { for id in ids { try await TodoistAPI.deleteTask(id) } }
    }

    // MARK: - Category operations

    func addCategory(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        push {
            _ = try await TodoistAPI.addProject(trimmed)
            await self.refresh()
        }
    }

    func deleteCategory(_ id: String) {
        categories.removeAll { $0.id == id }
        items.removeAll { $0.categoryId == id }
        push { try await TodoistAPI.deleteProject(id) }
    }

    func renameCategory(_ id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let i = categories.firstIndex(where: { $0.id == id }) else { return }
        categories[i].name = trimmed
        push { try await TodoistAPI.renameProject(id, to: trimmed) }
    }

    /// Local-only; Todoist project order is not written back.
    func moveCategories(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        for i in categories.indices { categories[i].sortOrder = i }
    }

    // MARK: - Backup

    /// Manual only, and off the main thread: the backup folder lives under
    /// ~/Documents, which is OneDrive-synced, so touching it can block on
    /// network I/O. Todoist is the real backup now.
    func backupNow() {
        guard let data = try? JSONEncoder().encode(AppData(items: items, categories: categories)) else { return }
        let b = backup
        Task.detached(priority: .background) { b.backup(data: data) }
    }

    func openBackupFolder() { backup.openFolder() }
    var backupCount: Int { backup.backupCount }
    var latestBackupDate: Date? { backup.latestBackupDate }

    // MARK: - Launch at login

    private func applyLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            }
        } catch {
            NSLog("launch at login failed: \(error)")
        }
    }
}
