// SignInResponse.swift
import Foundation

struct SignInResponse: Codable {
    let accessToken: String
    let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case user
    }
}



struct User: Codable {
    let id: String
    let username: String
    let email: String
    let password: String?
    let role: String
    let image: String?
    let credits: Int?
    let ratingAvg: Double?
    let isVerified: Bool?
    let xp: Int?
    let nombreParainnage: Int?
    let maxParannaige: Int?
    let codeParainnage: String?
    let bio: String?
    let age: Int?

    let skillsTeach: [String]?
    let skillsLearn: [String]?
    let location: UserLocation?
    let badges: [BadgeTier]?
    let availability: [String]?
    let createdAt: String?
    let updatedAt: String?
    let v: Int?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case username, email, password, role, image, credits, ratingAvg, isVerified
        case xp, nombreParainnage, maxParannaige, codeParainnage, bio, age
        case skillsTeach, skillsLearn, location, badges, availability, createdAt, updatedAt
        case v = "__v"
    }
}

struct RegisterResponse: Codable {
    let user: User
}

struct UserLocation: Codable {
    let lat: Double?
    let lon: Double?
    let city: String?
    private let fallbackText: String?

    private enum CodingKeys: String, CodingKey {
        case lat, lon, city
    }

    init(lat: Double? = nil, lon: Double? = nil, city: String? = nil, fallbackText: String? = nil) {
        self.lat = lat
        self.lon = lon
        self.city = city
        self.fallbackText = fallbackText
    }

    init(from decoder: Decoder) throws {
        if let keyed = try? decoder.container(keyedBy: CodingKeys.self) {
            lat = try keyed.decodeIfPresent(Double.self, forKey: .lat)
            lon = try keyed.decodeIfPresent(Double.self, forKey: .lon)
            city = try keyed.decodeIfPresent(String.self, forKey: .city)
            fallbackText = nil
            return
        }

        let single = try decoder.singleValueContainer()
        if single.decodeNil() {
            lat = nil
            lon = nil
            city = nil
            fallbackText = nil
            return
        }

        if let text = try? single.decode(String.self) {
            lat = nil
            lon = nil
            city = nil
            fallbackText = text
            return
        }

        throw DecodingError.typeMismatch(
            UserLocation.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Expected string or object for location")
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(lat, forKey: .lat)
        try container.encodeIfPresent(lon, forKey: .lon)
        let cityValue = city ?? fallbackText
        try container.encodeIfPresent(cityValue, forKey: .city)
    }

    var displayText: String? {
        if let city, !city.isEmpty { return city }
        return fallbackText
    }
}

extension User {
    var imageURL: URL? {
        guard let image, !image.isEmpty else { return nil }
        #if targetEnvironment(simulator)
        let baseURL = NetworkConfig.baseURL
        #else
        let baseURL = NetworkConfig.baseURL
        #endif
        return URL(string: "\(baseURL)/uploads/users/\(image)")
    }

    var locationDisplay: String? {
        location?.displayText
    }
    
    // Convenience init for placeholder users
    init(id: String, username: String, email: String = "", role: String = "user", image: String? = nil) {
        self.id = id
        self.username = username
        self.email = email
        self.role = role
        self.image = image
        self.password = nil
        self.credits = nil
        self.ratingAvg = nil
        self.isVerified = nil
        self.xp = nil
        self.nombreParainnage = nil
        self.maxParannaige = nil
        self.codeParainnage = nil
        self.bio = nil
        self.age = nil
        self.skillsTeach = nil
        self.skillsLearn = nil
        self.location = nil
        self.badges = nil
        self.availability = nil
        self.createdAt = nil
        self.updatedAt = nil
        self.v = nil
    }
}
struct ErrorResponse: Codable {
    let message: String
    let statusCode: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case message
        case statusCode
        case error
    }

    init(message: String, statusCode: Int? = nil, error: String? = nil) {
        self.message = message
        self.statusCode = statusCode
        self.error = error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        statusCode = try container.decodeIfPresent(Int.self, forKey: .statusCode)
        error = try container.decodeIfPresent(String.self, forKey: .error)

        if let single = try? container.decode(String.self, forKey: .message) {
            message = single
        } else if let multiple = try? container.decode([String].self, forKey: .message) {
            message = multiple.joined(separator: "\n")
        } else {
            message = "An unknown error occurred."
        }
    }
}

struct UserSuggestion: Identifiable, Codable, Hashable {
    let id: String
    let username: String
    let email: String
    let avatarUrl: String?
    let image: String?

    var displayImage: String? {
        avatarUrl ?? image
    }

    var initials: String {
        let components = username.split(separator: " ")
        let initials = components.prefix(2).map { String($0.prefix(1)) }.joined()
        return initials.isEmpty ? String(username.prefix(2)) : initials
    }

    enum CodingKeys: String, CodingKey {
        case id
        case fallbackId = "_id"
        case username, email, avatarUrl, image
    }

    init(id: String, username: String, email: String, avatarUrl: String?, image: String?) {
        self.id = id
        self.username = username
        self.email = email
        self.avatarUrl = avatarUrl
        self.image = image
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Try "id" first, then "_id" as fallback
        if let value = try container.decodeIfPresent(String.self, forKey: .id) {
            id = value
        } else if let fallback = try container.decodeIfPresent(String.self, forKey: .fallbackId) {
            id = fallback
        } else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: decoder.codingPath,
                                                                 debugDescription: "Missing user id"))
        }
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        image = try container.decodeIfPresent(String.self, forKey: .image)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
        try container.encodeIfPresent(image, forKey: .image)
    }
}

struct UserSearchResponse: Decodable {
    let users: [UserSuggestion]
    let total: Int?
}
