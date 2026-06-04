import Foundation
import AppKit

struct BackupManager {
    private let backupDir: URL
    private let maxBackups = 14

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        backupDir = docs.appendingPathComponent("StatusTodo Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
    }

    func backup(data: Data) {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let name = "backup_\(fmt.string(from: Date())).json"
        try? data.write(to: backupDir.appendingPathComponent(name), options: .atomic)
        pruneOldBackups()
    }

    func openFolder() {
        NSWorkspace.shared.open(backupDir)
    }

    var backupCount: Int {
        jsonFiles().count
    }

    var latestBackupDate: Date? {
        jsonFiles()
            .compactMap { try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate }
            .max()
    }

    private func jsonFiles() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: backupDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ))?.filter { $0.pathExtension == "json" } ?? []
    }

    private func pruneOldBackups() {
        let sorted = jsonFiles().sorted {
            let d1 = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let d2 = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return d1 > d2
        }
        sorted.dropFirst(maxBackups).forEach { try? FileManager.default.removeItem(at: $0) }
    }
}
