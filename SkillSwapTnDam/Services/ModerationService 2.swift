import Foundation

struct ModerationResult: Codable {
    let safe: Bool
    let categories: [String]?
    let message: String?
}

class ModerationService {
    private let baseURL = NetworkConfig.baseURL
    
    func checkImage(imageData: Data, accessToken: String) async throws -> ModerationResult {
        guard let url = URL(string: "\(baseURL)/moderation/check-image") else {
            throw NSError(domain: "ModerationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        // Convert image to base64
        let base64String = imageData.base64EncodedString()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let body = ["imageBase64": base64String]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ModerationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw NSError(domain: "ModerationService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
        }
        
        let result = try JSONDecoder().decode(ModerationResult.self, from: data)
        return result
    }
}
