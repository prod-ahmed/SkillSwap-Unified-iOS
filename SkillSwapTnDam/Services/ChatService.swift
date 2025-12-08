import Foundation

final class ChatService {
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
            if let date = ISO8601DateFormatter.full.date(from: value) {
                return date
            }
            if let fallback = ISO8601DateFormatter().date(from: value) {
                return fallback
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(value)")
        }
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()

    private let isoFormatter = ISO8601DateFormatter.full

    func fetchThreads(limit: Int = 20, skip: Int = 0, accessToken: String) async throws -> ChatThreadPage {
        guard var components = URLComponents(string: "\(baseURL)/chat/threads") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "skip", value: String(skip))
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(ChatThreadPage.self, from: data)
    }

    func createThread(
        participantId: String? = nil,
        participantEmail: String? = nil,
        sessionId: String? = nil,
        topic: String? = nil,
        accessToken: String
    ) async throws -> ChatThread {
        let normalizedEmail = participantEmail?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard participantId != nil || (normalizedEmail?.isEmpty == false) else {
            throw NSError(domain: "ChatService", code: 422, userInfo: [NSLocalizedDescriptionKey: "Destinataire requis"])
        }
        guard let url = URL(string: "\(baseURL)/chat/threads") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let body = CreateThreadPayload(
            participantId: participantId,
            participantEmail: normalizedEmail,
            sessionId: sessionId,
            topic: topic
        )
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(ChatThread.self, from: data)
    }

    func fetchMessages(threadId: String, limit: Int = 40, before: Date? = nil, accessToken: String) async throws -> ChatMessagePage {
        guard var components = URLComponents(string: "\(baseURL)/chat/threads/\(threadId)/messages") else {
            throw URLError(.badURL)
        }
        var items = [URLQueryItem(name: "limit", value: String(limit))]
        if let before {
            items.append(URLQueryItem(name: "before", value: isoFormatter.string(from: before)))
        }
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(ChatMessagePage.self, from: data)
    }

    func sendMessage(threadId: String, content: String, kind: ChatMessageKind = .text, attachmentUrl: String? = nil, replyToId: String? = nil, accessToken: String) async throws -> ChatMessage {
        guard let url = URL(string: "\(baseURL)/chat/threads/\(threadId)/messages") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let body = SendMessagePayload(content: content, type: kind, attachmentUrl: attachmentUrl, replyToId: replyToId)
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(ChatMessage.self, from: data)
    }

    func react(to messageId: String, emoji: String, accessToken: String) async throws -> ChatMessage {
        guard let url = URL(string: "\(baseURL)/chat/messages/\(messageId)/react") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let body = ["reaction": emoji]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(ChatMessage.self, from: data)
    }

    func delete(messageId: String, accessToken: String) async throws -> ChatMessage {
        guard let url = URL(string: "\(baseURL)/chat/messages/\(messageId)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(ChatMessage.self, from: data)
    }

    func markThreadRead(threadId: String, messageIds: [String]? = nil, accessToken: String) async throws -> Int {
        guard let url = URL(string: "\(baseURL)/chat/threads/\(threadId)/read") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let messageIds, !messageIds.isEmpty {
            request.httpBody = try encoder.encode(MarkReadPayload(ids: messageIds))
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(MarkReadResponse.self, from: data).updated
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            if let apiError = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NSError(domain: "ChatService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: apiError.message])
            }
            throw NSError(domain: "ChatService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Erreur serveur (\(http.statusCode))"])
        }
    }
}

private struct CreateThreadPayload: Encodable {
    let participantId: String?
    let participantEmail: String?
    let sessionId: String?
    let topic: String?
}

private struct SendMessagePayload: Encodable {
    let content: String
    let type: ChatMessageKind
    let attachmentUrl: String?
    let replyToId: String?
}

private struct MarkReadPayload: Encodable {
    let ids: [String]
}

private struct MarkReadResponse: Decodable {
    let updated: Int
}
