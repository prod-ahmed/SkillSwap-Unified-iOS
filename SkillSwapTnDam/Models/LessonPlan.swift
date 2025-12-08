import Foundation

// MARK: - Lesson Plan Response
struct LessonPlanResponse: Codable {
    let message: String?
    let data: LessonPlan?
    let error: String?
}

// MARK: - Lesson Plan Model
struct LessonPlan: Codable, Identifiable {
    let id: String
    let sessionId: String
    let skill: String
    let level: String
    let duration: Int
    let goal: String
    let plan: String
    let checklist: [String]
    let resources: [String]
    let homework: String
    let progress: [String: Bool]
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case sessionId
        case skill
        case level
        case duration
        case goal
        case plan
        case checklist
        case resources
        case homework
        case progress
        case createdAt
        case updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId) ?? ""
        skill = try container.decodeIfPresent(String.self, forKey: .skill) ?? ""
        level = try container.decodeIfPresent(String.self, forKey: .level) ?? "intermediate"
        duration = try container.decodeIfPresent(Int.self, forKey: .duration) ?? 60
        goal = try container.decodeIfPresent(String.self, forKey: .goal) ?? ""
        plan = try container.decodeIfPresent(String.self, forKey: .plan) ?? ""
        checklist = try container.decodeIfPresent([String].self, forKey: .checklist) ?? []
        resources = try container.decodeIfPresent([String].self, forKey: .resources) ?? []
        homework = try container.decodeIfPresent(String.self, forKey: .homework) ?? ""
        progress = try container.decodeIfPresent([String: Bool].self, forKey: .progress) ?? [:]
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

// MARK: - Generate Lesson Plan Request
struct GenerateLessonPlanRequest: Codable {
    let level: String?
    let goal: String?
}

// MARK: - Update Progress Request
struct UpdateProgressRequest: Codable {
    let checklistIndex: Int
    let completed: Bool
}
