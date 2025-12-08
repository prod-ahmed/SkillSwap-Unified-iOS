import Foundation
import UIKit

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
        
        // Convert to UIImage and then to JPEG to ensure proper format
        guard let uiImage = UIImage(data: imageData) else {
            throw NSError(domain: "ModerationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
        }
        
        // Compress to JPEG with 0.8 quality to reduce size and ensure valid format
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ModerationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])
        }
        
        // Convert to base64
        let base64String = jpegData.base64EncodedString(options: [])
        
        print("📤 Sending image for moderation (size: \(jpegData.count) bytes)")
        
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
        
        print("📥 Moderation response status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Server error: \(errorText)")
            throw NSError(domain: "ModerationService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
        }
        
        let result = try JSONDecoder().decode(ModerationResult.self, from: data)
        return result
    }
}
