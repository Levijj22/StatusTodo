import SwiftUI

enum TodoStatus: String, Codable, CaseIterable, Identifiable {
    case todo       = "Todo"
    case inProgress = "In Progress"
    case done       = "Done"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .todo:       return Color(hex: "808080")
        case .inProgress: return Color(hex: "FF8C00")
        case .done:       return Color(hex: "00C875")
        }
    }

    var label: String { rawValue }
}

struct TodoItem: Identifiable, Codable, Equatable {
    var id: UUID        = UUID()
    var title: String
    var status: TodoStatus  = .todo
    var categoryId: UUID
    var sortOrder: Int      = 0
    var createdAt: Date     = Date()
}
