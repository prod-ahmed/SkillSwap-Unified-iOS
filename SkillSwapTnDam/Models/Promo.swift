//
//  Promo.swift
//  SkillSwapTnDam
//

import Foundation

struct Promo: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let discount: Int
    let imageUrl: String?
    let promoCode: String?
    let validFrom: String?
    let validUntil: String
    let createdAt: String
    let updatedAt: String

    // 🔥 Local-only image data (not sent to backend)
    var imageData: Data?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case description
        case discount = "discountPercent"
        case imageUrl
        case promoCode
        case validFrom
        case validUntil = "validTo"
        case createdAt
        case updatedAt
    }
    
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
        return URL(string: "\(baseURL)/uploads/promos/\(imageUrl)")
    }

    // MARK: - DATE PARSING
    var validUntilDate: Date? {
        if let d = Promo.formatterWithMs.date(from: validUntil) { return d }
        if let d = Promo.formatterNoMs.date(from: validUntil) { return d }
        if let d = Promo.iso8601WithMs.date(from: validUntil) { return d }
        if let d = Promo.iso8601NoMs.date(from: validUntil) { return d }
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
