import Foundation

/// Backed by a Todoist project; `id` is the Todoist project id.
struct TodoCategory: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var sortOrder: Int = 0
}
