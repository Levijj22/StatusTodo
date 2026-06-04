import Foundation

struct TodoCategory: Identifiable, Codable, Equatable {
    var id: UUID    = UUID()
    var name: String
    var sortOrder: Int = 0
}
