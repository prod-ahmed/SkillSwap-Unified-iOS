import Foundation

final class WeeklyObjectiveService {
    static let shared = WeeklyObjectiveService()
    
    private let baseURL = NetworkConfig.baseURL
    
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter.full.date(from: value) { return date }
            if let date = ISO8601DateFormatter().date(from: value) { return date }
            return Date()
        }
        return decoder
    }()
    
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        return encoder
    }()
    
    private init() {}
    
    // MARK: - Get Current Objective
    
    func getCurrentObjective(accessToken: String) async throws -> WeeklyObjective? {
        guard let url = URL(string: "\(baseURL)/weekly-objectives/current") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // 404 means no active objective - return nil instead of throwing
        if http.statusCode == 404 {
            return nil
        }
        
        guard (200...299).contains(http.statusCode) else {
            throw decodeAPIError(data: data, statusCode: http.statusCode)
        }
        
        return try decoder.decode(WeeklyObjective.self, from: data)
    }
    
    // MARK: - Get History
    
    func getHistory(accessToken: String, page: Int = 1, limit: Int = 10) async throws -> WeeklyObjectiveHistoryResponse {
        guard let url = URL(string: "\(baseURL)/weekly-objectives/history?page=\(page)&limit=\(limit)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(http.statusCode) else {
            throw decodeAPIError(data: data, statusCode: http.statusCode)
        }
        
        return try decoder.decode(WeeklyObjectiveHistoryResponse.self, from: data)
    }
    
    // MARK: - Create Objective
    
    func createObjective(accessToken: String, title: String, targetHours: Int, startDate: Date, endDate: Date, tasks: [String]) async throws -> WeeklyObjective {
        guard let url = URL(string: "\(baseURL)/weekly-objectives") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let dailyTasks = tasks.enumerated().map { index, task in
            DailyTaskRequest(day: "Day \(index + 1)", task: task)
        }
        
        let payload = CreateWeeklyObjectiveRequest(
            title: title,
            targetHours: targetHours,
            startDate: formatter.string(from: startDate),
            endDate: formatter.string(from: endDate),
            dailyTasks: dailyTasks
        )
        
        request.httpBody = try encoder.encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(http.statusCode) else {
            throw decodeAPIError(data: data, statusCode: http.statusCode)
        }
        
        return try decoder.decode(WeeklyObjective.self, from: data)
    }
    
    // MARK: - Update Task Completion
    
    func updateTaskCompletion(accessToken: String, objectiveId: String, taskIndex: Int, isCompleted: Bool) async throws -> WeeklyObjective {
        guard let url = URL(string: "\(baseURL)/weekly-objectives/\(objectiveId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let payload = UpdateWeeklyObjectiveRequest(
            taskUpdates: [TaskUpdateRequest(index: taskIndex, isCompleted: isCompleted)]
        )
        
        request.httpBody = try encoder.encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(http.statusCode) else {
            throw decodeAPIError(data: data, statusCode: http.statusCode)
        }
        
        return try decoder.decode(WeeklyObjective.self, from: data)
    }
    
    // MARK: - Complete Objective
    
    func completeObjective(accessToken: String, objectiveId: String) async throws -> WeeklyObjective {
        guard let url = URL(string: "\(baseURL)/weekly-objectives/\(objectiveId)/complete") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(http.statusCode) else {
            throw decodeAPIError(data: data, statusCode: http.statusCode)
        }
        
        return try decoder.decode(WeeklyObjective.self, from: data)
    }
    
    // MARK: - Delete Objective
    
    func deleteObjective(accessToken: String, objectiveId: String) async throws {
        guard let url = URL(string: "\(baseURL)/weekly-objectives/\(objectiveId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - Helper
    
    private func decodeAPIError(data: Data, statusCode: Int) -> Error {
        struct ErrorResponse: Decodable {
            let message: String
        }
        
        if let apiErr = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            return NSError(domain: "WeeklyObjectiveService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: apiErr.message])
        }
        return NSError(domain: "WeeklyObjectiveService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error (\(statusCode))"])
    }
}
