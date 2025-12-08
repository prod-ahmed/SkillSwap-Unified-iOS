import Foundation

struct LocationPayload: Encodable {
    var lat: Double?
    var lon: Double?
    var city: String?
}

struct UpdateUserRequest: Encodable {
    var username: String?
    var email: String?
    var location: LocationPayload?
    var skillsTeach: [String]?
    var skillsLearn: [String]?
    var availability: [String]?
}

final class UserService {
    static let shared = UserService()
    
    #if targetEnvironment(simulator)
    private let baseURL = NetworkConfig.baseURL
    #else
    private let baseURL = NetworkConfig.baseURL
    #endif
    
    init() {}

    // MARK: - List users (Discover)
    /// GET /users  -> [User]
    func fetchUsers(accessToken: String? = nil) async throws -> [User] {
        guard let url = URL(string: "\(baseURL)/users") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = accessToken, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if (200...299).contains(http.statusCode) {
            return try JSONDecoder().decode([User].self, from: data)
        }
        if let apiErr = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            throw NSError(domain: "UserService", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: apiErr.message])
        }
        throw NSError(domain: "UserService", code: http.statusCode,
                      userInfo: [NSLocalizedDescriptionKey: "Unexpected server response (\(http.statusCode))."])
    }

    // MARK: - Me
    /// GET /users/me  -> User
    func fetchCurrentUser(accessToken: String) async throws -> User {
        guard let url = URL(string: "\(baseURL)/users/me") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if (200...299).contains(http.statusCode) {
            return try JSONDecoder().decode(User.self, from: data)
        }
        if let apiErr = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            throw NSError(domain: "UserService", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: apiErr.message])
        }
        throw NSError(domain: "UserService", code: http.statusCode,
                      userInfo: [NSLocalizedDescriptionKey: "Unexpected server response (\(http.statusCode))."])
    }

    // MARK: - Update me
    /// PATCH /users/me  -> User
    func updateCurrentUser(accessToken: String, payload: UpdateUserRequest) async throws -> User {
        guard let url = URL(string: "\(baseURL)/users/me") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if (200...299).contains(http.statusCode) {
            return try JSONDecoder().decode(User.self, from: data)
        }
        if let apiErr = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            throw NSError(domain: "UserService", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: apiErr.message])
        }
        throw NSError(domain: "UserService", code: http.statusCode,
                      userInfo: [NSLocalizedDescriptionKey: "Unexpected server response (\(http.statusCode))."])
    }

    func fetchRewards(accessToken: String) async throws -> RewardsSummary {
        guard let url = URL(string: "\(baseURL)/users/me/rewards") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if (200...299).contains(http.statusCode) {
            return try JSONDecoder().decode(RewardsSummary.self, from: data)
        }
        if let apiErr = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            throw NSError(domain: "UserService", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: apiErr.message])
        }
        throw NSError(domain: "UserService", code: http.statusCode,
                      userInfo: [NSLocalizedDescriptionKey: "Unexpected server response (\(http.statusCode))."])
    }

    func uploadProfileImage(accessToken: String, imageData: Data, filename: String) async throws -> User {
        guard let url = URL(string: "\(baseURL)/users/me/image") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(mimeType(for: filename))\r\n\r\n")
        body.append(imageData)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")

        let (data, resp) = try await URLSession.shared.upload(for: req, from: body)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if (200...299).contains(http.statusCode) {
            return try JSONDecoder().decode(User.self, from: data)
        }
        if let apiErr = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            throw NSError(domain: "UserService", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: apiErr.message])
        }
        throw NSError(domain: "UserService", code: http.statusCode,
                      userInfo: [NSLocalizedDescriptionKey: "Unexpected server response (\(http.statusCode))."])
    }

    // MARK: - Fetch user by email
    /// GET /users/by-email/:email -> User
    func fetchUserByEmail(_ email: String, accessToken: String) async throws -> User {
        let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
        guard let url = URL(string: "\(baseURL)/users/by-email/\(encodedEmail)") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if (200...299).contains(http.statusCode) {
            return try JSONDecoder().decode(User.self, from: data)
        }
        if let apiErr = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            throw NSError(domain: "UserService", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: apiErr.message])
        }
        throw NSError(domain: "UserService", code: http.statusCode,
                      userInfo: [NSLocalizedDescriptionKey: "Unexpected server response (\(http.statusCode))."])
    }
    
    // MARK: - Search users
    func searchUsers(query: String) async throws -> [UserSuggestion] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "\(baseURL)/users/search?query=\(encodedQuery)") else { throw URLError(.badURL) }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        print("🔍 Searching users with query: \(query)")
        print("🔍 URL: \(url.absoluteString)")
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        print("🔍 Response status: \(http.statusCode)")
        if let dataString = String(data: data, encoding: .utf8) {
            print("🔍 Response data: \(dataString)")
        }
        
        if (200...299).contains(http.statusCode) {
            // Backend returns raw array: [{"id": ..., "username": ..., "email": ..., "image": ...}]
            if let users = try? JSONDecoder().decode([UserSuggestion].self, from: data) {
                print("✅ Got \(users.count) user results")
                return users
            }
            print("⚠️ Failed to decode user results")
            return []
        }
        if let apiErr = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            throw NSError(domain: "UserService", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: apiErr.message])
        }
        throw NSError(domain: "UserService", code: http.statusCode,
                      userInfo: [NSLocalizedDescriptionKey: "Unexpected server response (\(http.statusCode))."])
    }
    
    // MARK: - Fetch user suggestion by email
    func fetchUserSuggestion(email: String) async throws -> UserSuggestion {
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            throw NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Non authentifié"])
        }
        
        let user = try await fetchUserByEmail(email, accessToken: token)
        return UserSuggestion(
            id: user.id,
            username: user.username,
            email: user.email,
            avatarUrl: nil,
            image: user.image
        )
    }
    
    // MARK: - Google Calendar Integration
    func checkGoogleConnection() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/auth/google/status") else { throw URLError(.badURL) }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if (200...299).contains(http.statusCode) {
            struct StatusResponse: Decodable {
                let connected: Bool
            }
            if let status = try? JSONDecoder().decode(StatusResponse.self, from: data) {
                return status.connected
            }
            return false
        }
        return false
    }
    
    func getGoogleAuthUrl() async throws -> String {
        guard let url = URL(string: "\(baseURL)/auth/google/url") else { throw URLError(.badURL) }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if (200...299).contains(http.statusCode) {
            struct UrlResponse: Decodable {
                let url: String
            }
            if let urlResponse = try? JSONDecoder().decode(UrlResponse.self, from: data) {
                return urlResponse.url
            }
        }
        throw NSError(domain: "UserService", code: http.statusCode,
                      userInfo: [NSLocalizedDescriptionKey: "Failed to get Google auth URL"])
    }
    
    func generateMeetLink(title: String, description: String, startTime: String, endTime: String, attendees: [String]) async throws -> String {
        guard let url = URL(string: "\(baseURL)/auth/google/create-event") else { throw URLError(.badURL) }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "title": title,
            "description": description,
            "startTime": startTime,
            "endTime": endTime,
            "attendees": attendees
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if (200...299).contains(http.statusCode) {
            struct MeetResponse: Decodable {
                let meetLink: String?
                let hangoutLink: String?
            }
            if let meetResponse = try? JSONDecoder().decode(MeetResponse.self, from: data) {
                if let link = meetResponse.meetLink ?? meetResponse.hangoutLink {
                    return link
                }
            }
        }
        throw NSError(domain: "UserService", code: http.statusCode,
                      userInfo: [NSLocalizedDescriptionKey: "Failed to generate Meet link"])
    }
    
    // MARK: - Match Check
    func checkMatch(userId: String, accessToken: String) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/users/match/\(userId)") else { throw URLError(.badURL) }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if (200...299).contains(http.statusCode) {
            struct MatchResponse: Decodable {
                let isMatch: Bool
            }
            if let matchResponse = try? JSONDecoder().decode(MatchResponse.self, from: data) {
                return matchResponse.isMatch
            }
        }
        
        // If endpoint doesn't exist, throw error so fallback logic is used
        throw NSError(domain: "UserService", code: http.statusCode,
                      userInfo: [NSLocalizedDescriptionKey: "Match check failed"])
    }
}

private extension UserService {
    func mimeType(for filename: String) -> String {
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
