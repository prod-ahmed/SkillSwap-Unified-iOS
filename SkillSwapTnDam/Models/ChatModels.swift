import Foundation

enum ChatMessageKind: String, Codable {
    case text
    case attachment
    case system
}

struct ChatParticipant: Codable, Identifiable, Hashable {
    let id: String
    let username: String?
    let email: String?
    let image: String?
    let badges: [String]?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case username
        case email
        case image
        case badges
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        image = try container.decodeIfPresent(String.self, forKey: .image)
        badges = try container.decodeIfPresent([String].self, forKey: .badges)
    }
}

struct ChatMessage: Codable, Identifiable, Hashable {
    let id: String
    let threadId: String?
    let senderId: String
    let recipientId: String
    let type: ChatMessageKind
    var content: String
    let attachmentUrl: String?
    let metadata: [String: String]?
    let read: Bool
    let readAt: Date?
    let createdAt: Date?
    let updatedAt: Date?
    
    // New fields
    var reactions: [String: [String]]? // emoji -> [userIds]
    var isDeleted: Bool?
    let replyTo: ReferencedMessage? // Nested message for reply

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case threadId = "thread"
        case senderId = "sender"
        case recipientId = "recipient"
        case type
        case content
        case attachmentUrl
        case metadata
        case read
        case readAt
        case createdAt
        case updatedAt
        case reactions
        case isDeleted
        case replyTo
    }
}

struct ReferencedMessage: Codable, Identifiable, Hashable {
    let id: String
    let content: String
    let senderId: String
    let type: ChatMessageKind
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case content
        case senderId = "sender"
        case type
    }
}

struct ChatThread: Codable, Identifiable, Hashable {
    let id: String
    let participants: [ChatParticipant]
    let sessionId: String?
    let topic: String?
    var metadata: [String: String]?
    var lastMessageAt: Date?
    var lastMessage: ChatMessage?
    var unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case mongoId = "_id"
        case participants
        case sessionId
        case topic
        case metadata
        case lastMessageAt
        case lastMessage
        case unreadCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let explicitId = try container.decodeIfPresent(String.self, forKey: .id) {
            id = explicitId
        } else {
            id = try container.decode(String.self, forKey: .mongoId)
        }
        participants = try container.decodeIfPresent([ChatParticipant].self, forKey: .participants) ?? []
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        topic = try container.decodeIfPresent(String.self, forKey: .topic)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
        lastMessageAt = try container.decodeIfPresent(Date.self, forKey: .lastMessageAt)
        lastMessage = try container.decodeIfPresent(ChatMessage.self, forKey: .lastMessage)
        unreadCount = try container.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(id, forKey: .mongoId)
        try container.encode(participants, forKey: .participants)
        try container.encodeIfPresent(sessionId, forKey: .sessionId)
        try container.encodeIfPresent(topic, forKey: .topic)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfPresent(lastMessageAt, forKey: .lastMessageAt)
        try container.encodeIfPresent(lastMessage, forKey: .lastMessage)
        try container.encode(unreadCount, forKey: .unreadCount)
    }
}

struct ChatThreadPage: Codable {
    let items: [ChatThread]
    let total: Int
    let limit: Int
    let skip: Int
    let hasNextPage: Bool
}

struct ChatMessagePage: Codable {
    let threadId: String
    let items: [ChatMessage]
    let hasMore: Bool
}

extension ChatParticipant {
    var displayName: String {
        username ?? email ?? "Membre SkillSwap"
    }

    var initials: String {
        if let username, !username.isEmpty {
            let components = username.split(separator: " ")
            let letters = components.compactMap { $0.first }.prefix(2)
            return letters.map { String($0) }.joined().uppercased()
        }
        if let email, let first = email.first {
            return String(first).uppercased()
        }
        return "?"
    }
}

extension ChatThread {
    func partner(for userId: String?) -> ChatParticipant? {
        guard let userId else { return participants.first }
        return participants.first { $0.id != userId }
    }

    func previewText() -> String {
        metadata?["lastPreview"] ?? lastMessage?.content ?? "Nouvelle conversation"
    }
}
