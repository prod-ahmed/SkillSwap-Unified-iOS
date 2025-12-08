//
//  AnnonceService.swift
//  SkillSwapTnDam
//
//  Created by Ahmed BT on 15/11/2025.
//
//

import Foundation

final class AnnonceService {

    #if targetEnvironment(simulator)
    private let base = NetworkConfig.baseURL
    #else
    private let base = NetworkConfig.baseURL
    #endif

    private var annoncesURL: URL {
        URL(string: "\(base)/annonces")!
    }

    private func authHeader() async -> String? {
        await MainActor.run { AuthenticationManager.shared.accessToken }
    }

    // MARK: GET all (optional)
    func fetchAll() async throws -> [Annonce] {
        var req = URLRequest(url: annoncesURL)
        if let t = await authHeader(), !t.isEmpty {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode([Annonce].self, from: data)
    }

    // MARK: GET /annonces/me
    func fetchMyAnnonces() async throws -> [Annonce] {
        let meURL = URL(string: "\(base)/annonces/me")!
        var req = URLRequest(url: meURL)
        if let t = await authHeader(), !t.isEmpty {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode([Annonce].self, from: data)
    }

    // MARK: POST /annonces
    struct CreatePayload: Encodable {
        let title: String
        let description: String
        let imageUrl: String?
        let city: String?
        let category: String?
        // Do NOT send userId; backend takes it from JWT
    }

    func create(
        title: String,
        description: String,
        imageUrl: String?,
        city: String?,
        category: String?
    ) async throws -> Annonce {
        var req = URLRequest(url: annoncesURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = await authHeader(), !t.isEmpty {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        let body = CreatePayload(
            title: title,
            description: description,
            imageUrl: imageUrl,
            city: city,
            category: category
        )
        req.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(Annonce.self, from: data)
    }

    // MARK: PATCH /annonces/:id
    struct UpdateAnnoncePayload: Encodable {
        let title: String
        let description: String
        let imageUrl: String?
        let city: String?
        let category: String?
    }

    func updateAnnonce(id: String, payload: UpdateAnnoncePayload) async throws -> Annonce {
        let url = annoncesURL.appendingPathComponent(id)
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = await authHeader(), !t.isEmpty {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONEncoder().encode(payload)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(Annonce.self, from: data)
    }

    // MARK: DELETE /annonces/:id
    func deleteAnnonce(id: String) async throws {
        let url = annoncesURL.appendingPathComponent(id)
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        if let t = await authHeader(), !t.isEmpty {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        _ = try await URLSession.shared.data(for: req)
    }

    // MARK: - AI Generation
    
    func generateAnnonceContent(prompt: String) async throws -> (title: String, description: String, category: String) {
        let url = URL(string: "\(base)/ai/generate")!
        
        let systemPrompt = """
        You are an expert copywriter for a skill swapping platform.
        Based on the user's input: "\(prompt)", generate an attractive announcement.
        Return ONLY a JSON object with these keys: "title", "description", "category".
        The description should be engaging and clear.
        The category should be one word (e.g., "Education", "Technology", "Art").
        Do not include markdown formatting like ```json.
        """
        
        let body = ["prompt": systemPrompt]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: req)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(http.statusCode) {
            // Try to parse backend error
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                
                // Check for quota/rate limit keywords in the backend error message
                if message.contains("429") || message.lowercased().contains("quota") || message.lowercased().contains("rate limit") {
                    throw NSError(domain: "AnnonceService", code: 429, userInfo: [NSLocalizedDescriptionKey: message])
                }
                
                throw NSError(domain: "AnnonceService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
            }
            throw NSError(domain: "AnnonceService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error \(http.statusCode)"])
        }
        
        struct AIResponse: Decodable {
            let data: String
        }
        
        let aiResponse = try JSONDecoder().decode(AIResponse.self, from: data)
        let content = aiResponse.data
        
        // Clean up potential markdown
        let cleanContent = content.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
        
        guard let jsonData = cleanContent.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String],
              let title = result["title"],
              let description = result["description"],
              let category = result["category"] else {
            throw NSError(domain: "AIError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse AI response"])
        }
        
        return (title, description, category)
    }

    // MARK: - Upload Image
    func uploadImage(id: String, imageData: Data, filename: String) async throws -> Annonce {
        let url = annoncesURL.appendingPathComponent("\(id)/image")
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if let t = await authHeader(), !t.isEmpty {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(mimeType(for: filename))\r\n\r\n")
        body.append(imageData)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")
        
        let (data, _) = try await URLSession.shared.upload(for: req, from: body)
        return try JSONDecoder().decode(Annonce.self, from: data)
    }
    
    private func mimeType(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "png": return "image/png"
        case "gif": return "image/gif"
        default: return "image/jpeg"
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

