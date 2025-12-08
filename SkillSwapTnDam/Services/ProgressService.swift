import Foundation

final class ProgressService {
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
            return Date()
        }
        return decoder
    }()

    func fetchDashboard(accessToken: String) async throws -> ProgressDashboardResponse {
        guard let url = URL(string: "\(baseURL)/progress/dashboard") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            throw try decodeAPIError(data: data, statusCode: http.statusCode)
        }
        return try decoder.decode(ProgressDashboardResponse.self, from: data)
    }

    func createGoal(accessToken: String, title: String, targetHours: Double, period: String) async throws -> ProgressGoalItem {
        guard let url = URL(string: "\(baseURL)/progress/goals") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        struct Payload: Encodable {
            let title: String
            let targetHours: Double
            let period: String
        }
        req.httpBody = try JSONEncoder().encode(Payload(title: title, targetHours: targetHours, period: period))

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            throw try decodeAPIError(data: data, statusCode: http.statusCode)
        }
        return try decoder.decode(ProgressGoalItem.self, from: data)
    }

    func updateGoal(accessToken: String, goalId: String, title: String, targetHours: Double, period: String) async throws -> ProgressGoalItem {
        guard let url = URL(string: "\(baseURL)/progress/goals/\(goalId)") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        struct Payload: Encodable {
            let title: String
            let targetHours: Double
            let period: String
        }
        req.httpBody = try JSONEncoder().encode(Payload(title: title, targetHours: targetHours, period: period))

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            throw try decodeAPIError(data: data, statusCode: http.statusCode)
        }
        return try decoder.decode(ProgressGoalItem.self, from: data)
    }

    func deleteGoal(accessToken: String, goalId: String) async throws {
        guard let url = URL(string: "\(baseURL)/progress/goals/\(goalId)") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            throw try decodeAPIError(data: Data(), statusCode: http.statusCode)
        }
    }

    private func decodeAPIError(data: Data, statusCode: Int) throws -> Error {
        if let apiErr = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            return NSError(domain: "ProgressService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: apiErr.message])
        }
        return NSError(domain: "ProgressService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Erreur serveur (\(statusCode))"])
    }
}
