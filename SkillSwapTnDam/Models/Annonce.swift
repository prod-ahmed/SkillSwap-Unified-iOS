//
//  Annonce.swift
//  SkillSwapTnDam
//

import Foundation

struct AnnonceUser: Codable {
    let _id: String
    let username: String
    let image: String?
}

struct Annonce: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let imageUrl: String?
    let isNew: Bool
    let city: String?
    let category: String?
    // User can be either a string ID (legacy) or an object (populated)
    let user: AnnonceUser?
    let createdAt: String
    let updatedAt: String

    // Local-only image cache (not sent to backend)
    var imageData: Data?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case description
        case imageUrl
        case isNew
        case city
        case category
        case user
        case createdAt
        case updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        isNew = try container.decode(Bool.self, forKey: .isNew)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        
        // Handle user field which can be String or Object
        if let userObj = try? container.decode(AnnonceUser.self, forKey: .user) {
            user = userObj
        } else if let userId = try? container.decode(String.self, forKey: .user) {
            // Fallback for legacy/unpopulated: create a dummy user with just ID
            user = AnnonceUser(_id: userId, username: "Utilisateur", image: nil)
        } else {
            user = nil
        }
    }
}

extension Annonce {
    var imageURL: URL? {
        guard let imageUrl, !imageUrl.isEmpty else { return nil }
        if imageUrl.hasPrefix("http") {
            return URL(string: imageUrl)
        }
        #if targetEnvironment(simulator)
        let baseURL = NetworkConfig.baseURL
        #else
        let baseURL = NetworkConfig.baseURL
        #endif
        return URL(string: "\(baseURL)/uploads/annonces/\(imageUrl)")
    }
}

// MARK: - Date parsing helpers (mirrors Promo’s approach)
extension Annonce {
    var createdAtDate: Date? {
        if let d = Annonce.formatterWithMs.date(from: createdAt) { return d }
        if let d = Annonce.formatterNoMs.date(from: createdAt) { return d }
        if let d = Annonce.iso8601WithMs.date(from: createdAt) { return d }
        if let d = Annonce.iso8601NoMs.date(from: createdAt) { return d }
        return nil
    }

    var updatedAtDate: Date? {
        if let d = Annonce.formatterWithMs.date(from: updatedAt) { return d }
        if let d = Annonce.formatterNoMs.date(from: updatedAt) { return d }
        if let d = Annonce.iso8601WithMs.date(from: updatedAt) { return d }
        if let d = Annonce.iso8601NoMs.date(from: updatedAt) { return d }
        return nil
    }

    static let formatterWithMs: DateFormatter = {
        let f = DateFormatter()
        f.locale = .init(identifier: "en_US_POSIX")
        f.timeZone = .init(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return f
    }()

    static let formatterNoMs: DateFormatter = {
        let f = DateFormatter()
        f.locale = .init(identifier: "en_US_POSIX")
        f.timeZone = .init(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return f
    }()

    static let iso8601WithMs: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let iso8601NoMs: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
