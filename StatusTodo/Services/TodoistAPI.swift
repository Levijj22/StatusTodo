import Foundation

/// Todoist REST client. StatusTodo is now a *view* onto Todoist rather than a
/// local store, so the Mac being off never matters - Ava and the phone talk to
/// the same account.
///
/// Uses API v1. The old /rest/v2 endpoints are retired and return 410.
enum TodoistAPI {
    private static let base = "https://api.todoist.com/api/v1"

    enum APIError: LocalizedError {
        case http(Int, String)
        var errorDescription: String? {
            if case let .http(code, body) = self { return "Todoist \(code): \(body)" }
            return nil
        }
    }

    /// Only open/closed now, so priority is left alone entirely - it stays
    /// whatever it is in Todoist and no longer encodes status.
    static func status(fromPriority p: Int) -> TodoStatus { .todo }

    private static func send(_ method: String, _ path: String, body: [String: Any]? = nil) async throws -> Data {
        // Not appendingPathComponent - it percent-encodes "?" and every call 404s.
        guard let url = URL(string: base + "/" + path) else { throw APIError.http(-1, path) }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 20
        req.setValue("Bearer \(Secrets.todoistToken)", forHTTPHeaderField: "Authorization")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    /// The completed-tasks endpoint wraps its payload in `items`, not
    /// `results` like every other collection. Decoding it as Paged silently
    /// yields nothing.
    private struct CompletedPage: Decodable { let items: [RawTask] }

    private struct Paged<T: Decodable>: Decodable {
        let results: [T]
        let nextCursor: String?
        enum CodingKeys: String, CodingKey { case results; case nextCursor = "next_cursor" }
    }

    private struct RawProject: Decodable { let id: String; let name: String }
    private struct RawTask: Decodable {
        let id: String, content: String, projectId: String
        let priority: Int
        let order: Int?
        enum CodingKeys: String, CodingKey {
            case id, content, priority, order
            case projectId = "project_id"
        }
    }

    // MARK: - Reads

    static func fetchAll() async throws -> ([TodoCategory], [TodoItem]) {
        let pData = try await send("GET", "projects")
        let projects = try JSONDecoder().decode(Paged<RawProject>.self, from: pData).results

        var raw: [RawTask] = []
        var cursor: String?
        repeat {
            var path = "tasks?limit=200"
            if let cursor { path += "&cursor=\(cursor)" }
            let d = try await send("GET", path)
            let page = try JSONDecoder().decode(Paged<RawTask>.self, from: d)
            raw.append(contentsOf: page.results)
            cursor = page.nextCursor
        } while cursor != nil

        let categories = projects.enumerated().map {
            TodoCategory(id: $1.id, name: $1.name, sortOrder: $0)
        }
        // Ordering has to come from the Sync API; a failure there just means
        // an unordered list, not a broken one.
        let order = (try? await fetchOrder()) ?? [:]
        let items = raw.map {
            TodoItem(id: $0.id,
                     title: $0.content,
                     status: status(fromPriority: $0.priority),
                     categoryId: $0.projectId,
                     sortOrder: order[$0.id] ?? 0)
        }
        return (categories, items)
    }

    /// Tasks completed since `since`, so the UI can show them greyed at the
    /// bottom until the user cleans up. Todoist omits completed tasks from the
    /// normal /tasks feed, so they have to be asked for separately.
    static func fetchCompleted(since: Date) async throws -> [TodoItem] {
        let fmt = DateFormatter()
        // en_US_POSIX, or a 12-hour or non-Gregorian device locale silently
        // produces a string Todoist rejects.
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        let until = Date().addingTimeInterval(3600)
        let path = "tasks/completed/by_completion_date?since=\(fmt.string(from: since))&until=\(fmt.string(from: until))&limit=200"
        let d = try await send("GET", path)
        let raw = try JSONDecoder().decode(CompletedPage.self, from: d).items
        return raw.map {
            TodoItem(id: $0.id, title: $0.content, status: .done,
                     categoryId: $0.projectId, sortOrder: $0.order ?? 0)
        }
    }

    // MARK: - Ordering
    //
    // REST v1 does not return or accept task order at all - `order` comes back
    // null. Ordering lives in the Sync API as `child_order`, which is both
    // readable and writable, so a drag here shows up on the phone.

    private struct SyncItem: Decodable { let id: String; let childOrder: Int?
        enum CodingKeys: String, CodingKey { case id; case childOrder = "child_order" } }
    private struct SyncRead: Decodable { let items: [SyncItem] }

    private static func sync(_ payload: [String: Any]) async throws -> Data {
        var req = URLRequest(url: URL(string: base + "/sync")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.setValue("Bearer \(Secrets.todoistToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    /// task id -> child_order
    static func fetchOrder() async throws -> [String: Int] {
        let d = try await sync(["sync_token": "*", "resource_types": ["items"]])
        let read = try JSONDecoder().decode(SyncRead.self, from: d)
        return Dictionary(uniqueKeysWithValues: read.items.map { ($0.id, $0.childOrder ?? 0) })
    }

    /// Writes `ids` as consecutive positions, so the list reads top to bottom.
    static func reorder(_ ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        let payload: [String: Any] = ["commands": [[
            "type": "item_reorder",
            "uuid": UUID().uuidString,
            "args": ["items": ids.enumerated().map { ["id": $1, "child_order": $0 + 1] }],
        ]]]
        _ = try await sync(payload)
    }

    // MARK: - Task writes

    static func addTask(_ content: String, projectId: String) async throws -> String {
        let d = try await send("POST", "tasks", body: ["content": content, "project_id": projectId])
        return (try? JSONDecoder().decode(RawTask.self, from: d))?.id ?? ""
    }

    static func setStatus(_ id: String, _ status: TodoStatus) async throws {
        if status == .done {
            _ = try await send("POST", "tasks/\(id)/close")
        } else {
            // Un-ticking genuinely reopens the task, rather than nudging a field.
            _ = try await send("POST", "tasks/\(id)/reopen")
        }
    }

    static func setTitle(_ id: String, _ title: String) async throws {
        _ = try await send("POST", "tasks/\(id)", body: ["content": title])
    }

    static func deleteTask(_ id: String) async throws {
        _ = try await send("DELETE", "tasks/\(id)")
    }

    // MARK: - Project writes

    static func addProject(_ name: String) async throws -> String {
        let d = try await send("POST", "projects", body: ["name": name])
        return (try? JSONDecoder().decode(RawProject.self, from: d))?.id ?? ""
    }

    static func renameProject(_ id: String, to name: String) async throws {
        _ = try await send("POST", "projects/\(id)", body: ["name": name])
    }

    static func deleteProject(_ id: String) async throws {
        _ = try await send("DELETE", "projects/\(id)")
    }
}
