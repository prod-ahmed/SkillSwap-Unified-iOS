import Foundation

// MARK: - Recommendation Response
struct RecommendationResponse: Codable {
    let message: String?
    let data: [Recommendation]
}

// MARK: - Recommendation Model
struct Recommendation: Codable, Identifiable {
    let id: String
    let mentorName: String
    let mentorImage: String?
    let age: Int
    let skills: [String]
    let description: String
    let availability: String
    let distance: String
    let rating: Double
    let lastActive: String
    let sessionsCount: Int
    
    var initials: String {
        let components = mentorName.split(separator: " ")
        let initials = components.prefix(2).map { String($0.prefix(1)) }.joined()
        return initials.isEmpty ? String(mentorName.prefix(1)) : initials
    }
    
    init(id: String, mentorName: String, mentorImage: String?, age: Int, skills: [String], description: String, availability: String, distance: String, rating: Double, lastActive: String, sessionsCount: Int) {
        self.id = id
        self.mentorName = mentorName
        self.mentorImage = mentorImage
        self.age = age
        self.skills = skills
        self.description = description
        self.availability = availability
        self.distance = distance
        self.rating = rating
        self.lastActive = lastActive
        self.sessionsCount = sessionsCount
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case mentorName
        case mentorImage
        case age
        case skills
        case description
        case availability
        case distance
        case rating
        case lastActive
        case sessionsCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        mentorName = try container.decode(String.self, forKey: .mentorName)
        mentorImage = try container.decodeIfPresent(String.self, forKey: .mentorImage)
        age = try container.decodeIfPresent(Int.self, forKey: .age) ?? 0
        skills = try container.decodeIfPresent([String].self, forKey: .skills) ?? []
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        availability = try container.decodeIfPresent(String.self, forKey: .availability) ?? "Disponible"
        distance = try container.decodeIfPresent(String.self, forKey: .distance) ?? ""
        if let ratingInt = try? container.decode(Int.self, forKey: .rating) {
            rating = Double(ratingInt)
        } else {
            rating = try container.decodeIfPresent(Double.self, forKey: .rating) ?? 0.0
        }
        lastActive = try container.decodeIfPresent(String.self, forKey: .lastActive) ?? "Récemment"
        sessionsCount = try container.decodeIfPresent(Int.self, forKey: .sessionsCount) ?? 0
    }
}
