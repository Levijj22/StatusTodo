import Foundation
import Combine
import ServiceManagement
import AppKit

class TodoStore: ObservableObject {
    @Published var items: [TodoItem] = []
    @Published var categories: [TodoCategory] = []
    @Published var selectedCategoryId: UUID? = nil {
        didSet {
            if let id = selectedCategoryId {
                UserDefaults.standard.set(id.uuidString, forKey: "selectedCategoryId")
            }
        }
    }
    @Published var alwaysOnTop: Bool = false {
        didSet { UserDefaults.standard.set(alwaysOnTop, forKey: "alwaysOnTop") }
    }
    @Published var launchAtLogin: Bool = false {
        didSet { applyLaunchAtLogin(launchAtLogin) }
    }

    private let dataURL: URL
    private let backup = BackupManager()
    private var autoClearTimer: Timer?
    private var autosaveTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    struct AppData: Codable {
        var items: [TodoItem]
        var categories: [TodoCategory]
    }

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("StatusTodo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        dataURL = dir.appendingPathComponent("data.json")

        alwaysOnTop = UserDefaults.standard.bool(forKey: "alwaysOnTop")
        launchAtLogin = SMAppService.mainApp.status == .enabled

        load()
        backupNow()          // backup on every launch

        if categories.isEmpty { setupDefaults() }

        // Restore last active tab, fall back to first category
        if let saved = UserDefaults.standard.string(forKey: "selectedCategoryId"),
           let uuid = UUID(uuidString: saved),
           categories.contains(where: { $0.id == uuid }) {
            selectedCategoryId = uuid
        } else {
            selectedCategoryId = sortedCategories.first?.id
        }

        scheduleAutoClear()
        startAutosave()
    }

    // MARK: - Computed

    var filteredItems: [TodoItem] {
        guard let catId = selectedCategoryId else { return [] }
        let cat = items.filter { $0.categoryId == catId }
        let active = cat.filter { $0.status != .done }.sorted { $0.sortOrder < $1.sortOrder }
        let done   = cat.filter { $0.status == .done  }.sorted { $0.sortOrder < $1.sortOrder }
        return active + done
    }

    var sortedCategories: [TodoCategory] {
        categories.sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Item operations

    func addItem(title: String) {
        guard let catId = selectedCategoryId, !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let minOrder = items.filter { $0.categoryId == catId }.map(\.sortOrder).min() ?? 0
        items.append(TodoItem(title: title.trimmingCharacters(in: .whitespaces),
                              categoryId: catId,
                              sortOrder: minOrder - 1))
        save()
    }

    func deleteItems(at offsets: IndexSet) {
        let filtered = filteredItems
        let ids = offsets.map { filtered[$0].id }
        items.removeAll { ids.contains($0.id) }
        save()
    }

    func moveItems(from source: IndexSet, to destination: Int) {
        guard let catId = selectedCategoryId else { return }
        var filtered = filteredItems
        filtered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in filtered.enumerated() {
            if let i = items.firstIndex(where: { $0.id == item.id }) {
                items[i].sortOrder = index
            }
        }
        objectWillChange.send()
        save()
    }

    func updateStatus(_ item: TodoItem, to status: TodoStatus) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].status = status
        save()
    }

    func updateTitle(_ item: TodoItem, to title: String) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty,
              let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].title = title.trimmingCharacters(in: .whitespaces)
        save()
    }

    func clearDoneItems() {
        guard let catId = selectedCategoryId else { return }
        items.removeAll { $0.categoryId == catId && $0.status == .done }
        save()
    }

    func clearAllDoneItems() {
        items.removeAll { $0.status == .done }
        save()
    }

    func deleteAllItems() {
        guard let catId = selectedCategoryId else { return }
        items.removeAll { $0.categoryId == catId }
        save()
    }

    // MARK: - Category operations

    func addCategory(name: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        categories.append(TodoCategory(name: name.trimmingCharacters(in: .whitespaces),
                                       sortOrder: categories.count))
        save()
    }

    func deleteCategory(_ id: UUID) {
        categories.removeAll { $0.id == id }
        items.removeAll { $0.categoryId == id }
        if selectedCategoryId == id { selectedCategoryId = categories.first?.id }
        save()
    }

    func renameCategory(_ id: UUID, to name: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              let i = categories.firstIndex(where: { $0.id == id }) else { return }
        categories[i].name = name.trimmingCharacters(in: .whitespaces)
        save()
    }

    func moveCategories(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        for i in categories.indices { categories[i].sortOrder = i }
        save()
    }

    // MARK: - Backup

    func backupNow() {
        guard let data = try? JSONEncoder().encode(AppData(items: items, categories: categories)) else { return }
        backup.backup(data: data)
    }

    func openBackupFolder() { backup.openFolder() }
    var backupCount: Int { backup.backupCount }
    var latestBackupDate: Date? { backup.latestBackupDate }

    // MARK: - Auto-clear every Sunday night

    private func scheduleAutoClear() {
        autoClearTimer?.invalidate()
        // Check every 30 minutes
        autoClearTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.checkSundayClear()
        }
        checkSundayClear()
    }

    private func checkSundayClear() {
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now) // 1 = Sunday
        let hour = cal.component(.hour, from: now)

        guard weekday == 1 && hour >= 21 else { return }

        let key = "lastAutoClearDate"
        if let last = UserDefaults.standard.object(forKey: key) as? Date,
           cal.isDate(last, inSameDayAs: now) { return }

        backupNow()         // safety backup before wiping
        clearAllDoneItems()
        UserDefaults.standard.set(now, forKey: key)
    }

    // MARK: - Launch at login

    private func applyLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Launch at login error: \(error)")
        }
    }

    // MARK: - Persistence

    func save() {
        do {
            let encoded = try JSONEncoder().encode(AppData(items: items, categories: categories))
            try encoded.write(to: dataURL, options: .atomic)
        } catch {
            NSLog("StatusTodo: save failed — %@", error.localizedDescription)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: dataURL) else { return }
        do {
            let appData = try JSONDecoder().decode(AppData.self, from: data)
            items = appData.items
            categories = appData.categories
        } catch {
            NSLog("StatusTodo: load failed — %@", error.localizedDescription)
        }
    }

    // Layer 2: Combine observer — saves 0.5 s after any item/category change
    private func startAutosave() {
        Publishers.Merge(
            $items.map { _ in () },
            $categories.map { _ in () }
        )
        .dropFirst()
        .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
        .sink { [weak self] in self?.save() }
        .store(in: &cancellables)

        // Layer 3: Save every 60 s regardless, and on app quit
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.save()
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.save()
        }
    }

    private func setupDefaults() {
        let names = ["Work", "Life", "Personal"]
        categories = names.enumerated().map { TodoCategory(name: $1, sortOrder: $0) }
        selectedCategoryId = categories.first?.id
        save()
    }
}
