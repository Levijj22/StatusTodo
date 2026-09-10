import SwiftUI

/// Deliberately two states. In Progress / On Hold were dropped - the pill is a
/// tick box, not a workflow.
enum TodoStatus: String, Codable, CaseIterable, Identifiable {
    case todo = "Todo"
    case done = "Done"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .todo: return Color(hex: "808080")
        case .done: return Color(hex: "00C875")
        }
    }

    var label: String { rawValue }
}

/// Ids are Todoist task ids - Todoist is the store.
struct TodoItem: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var status: TodoStatus = .todo
    var categoryId: String
    var sortOrder: Int = 0
}
