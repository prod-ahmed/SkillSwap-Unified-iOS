import Foundation

// MARK: - Request payloads

private struct CreatePromoPayload: Encodable {
    let title: String
    let description: String
    let imageUrl: String?
    let discountPercent: Int
    let promoCode: String?
    let validFrom: String
    let validTo: String
}

private struct UpdatePromoPayload: Encodable {
    let title: String?
    let description: String?
    let imageUrl: String?
    let discountPercent: Int?
    let promoCode: String?
    let validFrom: String?
    let validTo: String?
}

// MARK: - Service

final class PromoService {

    // Adapte l’IP si besoin pour les tests sur device
    #if targetEnvironment(simulator)
    private let baseURL = NetworkConfig.baseURL
    #else
    // Remplace 192.168.1.XX par l’IP locale de ton Mac si tu testes sur device
    private let baseURL = NetworkConfig.baseURL
    #endif

    private var promosURL: URL {
        URL(string: "\(baseURL)/promos")!
    }

    // Format de date ISO pour correspondre au backend (IsDateString)
    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // Récupérer éventuellement un token JWT depuis UserDefaults
    // (évite les soucis d’@MainActor d’AuthenticationManager)
    private func authHeaders() -> [String: String] {
        var headers: [String: String] = [:]
        if let token = UserDefaults.standard.string(forKey: "authToken"), !token.isEmpty {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }

    // MARK: - Helpers

    private func makeRequest(url: URL, method: String, body: Data? = nil, contentTypeJSON: Bool = false) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if contentTypeJSON {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        authHeaders().forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = body
        return request
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if !(200...299).contains(http.statusCode) {
            // Try to surface backend error message for easier debugging
            var message: String?
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                message = (json["message"] as? String) ?? (json["error"] as? String)
            }
            let bodySnippet = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            print("❌ HTTP \(http.statusCode) for \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
            print("   Response body: \(bodySnippet)")

            if let message {
                throw NSError(domain: "APIError", code: http.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: message])
            } else {
                throw URLError(.badServerResponse)
            }
        }

        return (data, http)
    }

    // MARK: - GET /promos

    func fetchAll() async throws -> [Promo] {
        let request = makeRequest(url: promosURL, method: "GET")
        let (data, _) = try await send(request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Promo].self, from: data)
    }

    // MARK: - GET /promos/me (mes promos)

    func fetchMyPromos() async throws -> [Promo] {
        let url = promosURL.appendingPathComponent("me")
        let request = makeRequest(url: url, method: "GET")
        let (data, _) = try await send(request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Promo].self, from: data)
    }

    // MARK: - POST /promos

    func create(
        title: String,
        description: String,
        discountPercent: Int,
        validFrom: Date,
        validTo: Date,
        promoCode: String?,
        imageUrl: String?
    ) async throws -> Promo {

        let body = CreatePromoPayload(
            title: title,
            description: description,
            imageUrl: imageUrl,
            discountPercent: discountPercent,
            promoCode: promoCode,
            validFrom: isoFormatter.string(from: validFrom),
            validTo: isoFormatter.string(from: validTo)
        )

        let request = makeRequest(
            url: promosURL,
            method: "POST",
            body: try JSONEncoder().encode(body),
            contentTypeJSON: true
        )

        let (data, _) = try await send(request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Promo.self, from: data)
    }

    // MARK: - PATCH /promos/:id

    func updatePromo(
        id: String,
        title: String? = nil,
        description: String? = nil,
        discountPercent: Int? = nil,
        validFrom: Date? = nil,
        validTo: Date? = nil,
        promoCode: String? = nil,
        imageUrl: String? = nil
    ) async throws -> Promo {

        let url = promosURL.appendingPathComponent(id)
        let body = UpdatePromoPayload(
            title: title,
            description: description,
            imageUrl: imageUrl,
            discountPercent: discountPercent,
            promoCode: promoCode,
            validFrom: validFrom.map { isoFormatter.string(from: $0) },
            validTo: validTo.map { isoFormatter.string(from: $0) }
        )

        let request = makeRequest(
            url: url,
            method: "PATCH",
            body: try JSONEncoder().encode(body),
            contentTypeJSON: true
        )

        let (data, _) = try await send(request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Promo.self, from: data)
    }

    // MARK: - DELETE /promos/:id

    func deletePromo(id: String) async throws {
        let url = promosURL.appendingPathComponent(id)
        let request = makeRequest(url: url, method: "DELETE")
        _ = try await send(request)
    }

    // MARK: - AI Generation
    
    func generateBannerImage(prompt: String) async throws -> Data {
        let url = URL(string: "\(baseURL)/ai/generate-image")!
        
        let body = ["prompt": prompt]
        let request = makeRequest(
            url: url,
            method: "POST",
            body: try JSONSerialization.data(withJSONObject: body),
            contentTypeJSON: true
        )
        
        let (data, _) = try await send(request)
        
        // Parse response { "url": "..." }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let imageUrlString = json["url"] as? String,
              let imageUrl = URL(string: imageUrlString) else {
            throw URLError(.badServerResponse)
        }
        
        // Download image
        let (imageData, _) = try await URLSession.shared.data(from: imageUrl)
        return imageData
    }

    // MARK: - Upload Image
    func uploadImage(id: String, imageData: Data, filename: String) async throws -> Promo {
        let url = promosURL.appendingPathComponent("\(id)/image")
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        authHeaders().forEach { key, value in
            req.setValue(value, forHTTPHeaderField: key)
        }
        
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(mimeType(for: filename))\r\n\r\n")
        body.append(imageData)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")
        
        let (data, _) = try await URLSession.shared.upload(for: req, from: body)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Promo.self, from: data)
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
