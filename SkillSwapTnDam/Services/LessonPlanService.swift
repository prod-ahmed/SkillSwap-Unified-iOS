import Foundation

final class LessonPlanService {
    static let shared = LessonPlanService()
    
    private let baseURL = NetworkConfig.baseURL
    
    private init() {}
    
    // MARK: - Get Lesson Plan
    func getLessonPlan(sessionId: String) async throws -> LessonPlan? {
        guard let url = URL(string: "\(baseURL)/lesson-plan/\(sessionId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await MainActor.run(body: { AuthenticationManager.shared.accessToken }) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 404 {
            return nil
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NSError(domain: "LessonPlanService", code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: errorResponse.message])
            }
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(LessonPlan.self, from: data)
    }
    
    // MARK: - Generate Lesson Plan
    func generateLessonPlan(sessionId: String, level: String? = nil, goal: String? = nil) async throws -> LessonPlan {
        guard let url = URL(string: "\(baseURL)/lesson-plan/generate/\(sessionId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await MainActor.run(body: { AuthenticationManager.shared.accessToken }) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body: [String: Any] = [:]
        if let level = level { body["level"] = level }
        if let goal = goal { body["goal"] = goal }
        
        if !body.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            if let httpResponse = response as? HTTPURLResponse,
               let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NSError(domain: "LessonPlanService", code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: errorResponse.message])
            }
            throw URLError(.badServerResponse)
        }
        
        // Backend returns { message, data: LessonPlan }
        struct GenerateResponse: Decodable {
            let message: String?
            let data: LessonPlan?
        }
        
        if let wrapper = try? JSONDecoder().decode(GenerateResponse.self, from: data), let plan = wrapper.data {
            return plan
        }
        
        return try JSONDecoder().decode(LessonPlan.self, from: data)
    }
    
    // MARK: - Regenerate Lesson Plan
    func regenerateLessonPlan(sessionId: String, level: String? = nil, goal: String? = nil) async throws -> LessonPlan {
        guard let url = URL(string: "\(baseURL)/lesson-plan/regenerate/\(sessionId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await MainActor.run(body: { AuthenticationManager.shared.accessToken }) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body: [String: Any] = [:]
        if let level = level { body["level"] = level }
        if let goal = goal { body["goal"] = goal }
        
        if !body.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            if let httpResponse = response as? HTTPURLResponse,
               let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NSError(domain: "LessonPlanService", code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: errorResponse.message])
            }
            throw URLError(.badServerResponse)
        }
        
        // Backend returns { message, data: LessonPlan }
        struct GenerateResponse: Decodable {
            let message: String?
            let data: LessonPlan?
        }
        
        if let wrapper = try? JSONDecoder().decode(GenerateResponse.self, from: data), let plan = wrapper.data {
            return plan
        }
        
        return try JSONDecoder().decode(LessonPlan.self, from: data)
    }
    
    // MARK: - Update Progress
    func updateProgress(sessionId: String, checklistIndex: Int, completed: Bool) async throws -> LessonPlan {
        guard let url = URL(string: "\(baseURL)/lesson-plan/progress/\(sessionId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await MainActor.run(body: { AuthenticationManager.shared.accessToken }) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "checklistIndex": checklistIndex,
            "completed": completed
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            if let httpResponse = response as? HTTPURLResponse,
               let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NSError(domain: "LessonPlanService", code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: errorResponse.message])
            }
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(LessonPlan.self, from: data)
    }
}
