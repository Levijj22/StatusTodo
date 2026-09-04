import SwiftUI

enum TodoStatus: String, Codable, CaseIterable, Identifiable {
    case todo       = "Todo"
    case inProgress = "In Progress"
    case onHold     = "On Hold"
    case done       = "Done"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .todo:       return Color(hex: "808080")
        case .inProgress: return Color(hex: "FF8C00")
        case .onHold:     return Color(hex: "E2445C")
        case .done:       return Color(hex: "00C875")
        }
    }

    var label: String { rawValue }
}

/// Ids are Todoist task ids now, not local UUIDs - Todoist is the store.
struct TodoItem: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var status: TodoStatus = .todo
    var categoryId: String
    var sortOrder: Int = 0
}
