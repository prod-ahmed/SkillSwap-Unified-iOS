import Foundation

enum NotificationStatusFilter: String {
    case all
    case unread
    case read
}

final class NotificationService {
    #if targetEnvironment(simulator)
    private let baseURL = NetworkConfig.baseURL
    #else
    private let baseURL = NetworkConfig.baseURL
    #endif

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter.full.date(from: value) { return date }
            if let date = ISO8601DateFormatter().date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
        }
        return decoder
    }()

    func fetchNotifications(
        status: NotificationStatusFilter = .all,
        page: Int = 1,
        limit: Int = 20,
        accessToken: String
    ) async throws -> NotificationPage {
        guard let url = URL(string: "\(baseURL)/notifications?status=\(status.rawValue)&page=\(page)&limit=\(limit)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            throw try decodeAPIError(data: data, statusCode: http.statusCode)
        }
        return try decoder.decode(NotificationPage.self, from: data)
    }

    func fetchUnreadCount(accessToken: String) async throws -> Int {
        guard let url = URL(string: "\(baseURL)/notifications/unread-count") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            throw try decodeAPIError(data: data, statusCode: http.statusCode)
        }
        struct CountDTO: Decodable { let unread: Int }
        return try decoder.decode(CountDTO.self, from: data).unread
    }

    func markRead(ids: [String], accessToken: String) async throws -> Int {
        guard let url = URL(string: "\(baseURL)/notifications/mark-read") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(["ids": ids])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            throw try decodeAPIError(data: data, statusCode: http.statusCode)
        }
        return try decoder.decode(UnreadResponse.self, from: data).unread
    }

    func markAllRead(accessToken: String) async throws -> Int {
        guard let url = URL(string: "\(baseURL)/notifications/mark-all-read") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            throw try decodeAPIError(data: data, statusCode: http.statusCode)
        }
        return try decoder.decode(UnreadResponse.self, from: data).unread
    }

    func respond(
        notificationId: String,
        accepted: Bool,
        message: String? = nil,
        accessToken: String
    ) async throws -> NotificationItem {
        guard let url = URL(string: "\(baseURL)/notifications/\(notificationId)/respond") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let body = RespondPayload(accepted: accepted, message: message)
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            throw try decodeAPIError(data: data, statusCode: http.statusCode)
        }
        return try decoder.decode(NotificationItem.self, from: data)
    }

    private func decodeAPIError(data: Data, statusCode: Int) throws -> Error {
        if let apiErr = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            return NSError(domain: "NotificationService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: apiErr.message])
        }
        return NSError(domain: "NotificationService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Erreur serveur (\(statusCode))"])
    }

    private struct RespondPayload: Encodable {
        let accepted: Bool
        let message: String?
    }

    private struct UnreadResponse: Decodable {
        let unread: Int
    }
}
