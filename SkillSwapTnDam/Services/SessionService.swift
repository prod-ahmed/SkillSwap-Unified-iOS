import Foundation

class SessionService {
    static let shared = SessionService()
    
    private init() {}

    private let baseURL = NetworkConfig.baseURL
    
    private func createDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder -> Date in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = formatter.date(from: dateString) {
                return date
            }
            // Try without fractional seconds
            let basicFormatter = ISO8601DateFormatter()
            basicFormatter.formatOptions = [.withInternetDateTime]
            if let date = basicFormatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Cannot decode date string \(dateString)")
        }
        return decoder
    }

    private func authorizedRequest(url: URL, method: String) throws -> URLRequest {
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            throw NSError(domain: "SessionService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Utilisateur non connecté"])
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    // Fetch sessions
    func fetchSessions() async throws -> [Session] {
        guard let url = URL(string: "\(baseURL)/sessions/me") else {
            throw URLError(.badURL)
        }
        
        let request = try authorizedRequest(url: url, method: "GET")
        
        print("📥 Fetching sessions from: \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("📥 Sessions response status: \(httpResponse.statusCode)")
        if let dataString = String(data: data, encoding: .utf8) {
            print("📥 Sessions response data: \(dataString.prefix(500))")
        }

        switch httpResponse.statusCode {
        case 200:
            do {
                let decoder = createDecoder()
                
                // Try to decode as wrapped response first, then as direct array
                let sessions: [Session]
                if let sessionsResponse = try? decoder.decode(SessionsResponse.self, from: data) {
                    print("📥 Decoded as SessionsResponse")
                    sessions = sessionsResponse.data
                } else {
                    print("📥 Trying to decode as [Session] array")
                    sessions = try decoder.decode([Session].self, from: data)
                }
                
                print("📥 Successfully decoded \(sessions.count) sessions")
                
                let now = Date()
                var sessionsToUpdate: [Session] = []
                
                for session in sessions {
                    let sessionEndTime = session.date.addingTimeInterval(TimeInterval(session.duration * 60))
                    if sessionEndTime < now && session.status == "upcoming" {
                        sessionsToUpdate.append(session)
                    }
                }
                
                for session in sessionsToUpdate {
                    Task {
                        do {
                            _ = try await self.updateSessionStatus(sessionId: session.id, status: "completed")
                            print("✅ Session \(session.id) automatiquement marquée comme terminée")
                        } catch {
                            print("⚠️ Erreur lors de la mise à jour automatique du statut: \(error)")
                        }
                    }
                }
                
                return sessions
            } catch {
                print("❌ Decoding error:", error)
                if let dataString = String(data: data, encoding: .utf8) {
                    print("📥 Raw response data:", dataString)
                }
                throw error
            }
        case 401:
            throw NSError(domain: "SessionService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Session expirée ou non autorisée"])
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Erreur serveur (\(httpResponse.statusCode))"
            throw NSError(domain: "SessionService", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
    }

    // Create session
    func createSession(session: NewSession, token: String) async throws -> Session {
        guard let url = URL(string: "\(baseURL)/sessions") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let encoder = JSONEncoder()
            let bodyData = try encoder.encode(session)
            request.httpBody = bodyData
            if let bodyString = String(data: bodyData, encoding: .utf8) {
                print("📤 Request body:", bodyString)
            }
        } catch {
            print("❌ Encoding error:", error)
            throw error
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("📥 Response status:", httpResponse.statusCode)
        if let dataString = String(data: data, encoding: .utf8) {
            print("📥 Response data:", dataString)
        }
        
        switch httpResponse.statusCode {
        case 201, 200:
            do {
                let decoder = createDecoder()
                // Try wrapped response first, then direct session
                let createdSession: Session
                if let sessionResponse = try? decoder.decode(SessionResponse.self, from: data) {
                    createdSession = sessionResponse.data
                } else {
                    createdSession = try decoder.decode(Session.self, from: data)
                }
                print("✅ Session created successfully:", createdSession.title)
                return createdSession
            } catch {
                print("❌ Decoding error:", error)
                throw error
            }
        case 400:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Requête invalide"
            throw NSError(domain: "SessionService", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: errorMessage])
        case 401:
            throw NSError(domain: "SessionService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Session expirée ou non autorisée"])
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Erreur serveur (\(httpResponse.statusCode))"
            throw NSError(domain: "SessionService", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
    }
    
    // Update session status
    func updateSessionStatus(sessionId: String, status: String) async throws -> Session {
        guard let url = URL(string: "\(baseURL)/sessions/\(sessionId)/status") else {
            throw URLError(.badURL)
        }
        
        var request = try authorizedRequest(url: url, method: "PATCH")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["status": status]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        switch httpResponse.statusCode {
        case 200:
            do {
                let decoder = createDecoder()
                if let sessionResponse = try? decoder.decode(SessionResponse.self, from: data) {
                    return sessionResponse.data
                }
                let session = try decoder.decode(Session.self, from: data)
                return session
            } catch {
                print("❌ Decoding error:", error)
                if let dataString = String(data: data, encoding: .utf8) {
                    print("Response data:", dataString)
                }
                throw error
            }
        case 401:
            throw NSError(domain: "SessionService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Session expirée ou non autorisée"])
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Erreur serveur (\(httpResponse.statusCode))"
            throw NSError(domain: "SessionService", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
    }
    
    // MARK: - Availability
    func fetchAvailability(emails: [String], startDate: Date, duration: Int) async throws -> [String: AvailabilityResponse] {
        // Build GET URL with query parameters
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateString = formatter.string(from: startDate)
        let emailsParam = emails.joined(separator: ",")
        
        guard let url = URL(string: "\(baseURL)/sessions/availability?emails=\(emailsParam)&date=\(dateString)&duration=\(duration)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            throw URLError(.badURL)
        }
        
        let request = try authorizedRequest(url: url, method: "GET")
        
        print("📅 Checking availability for: \(emails) at \(dateString) for \(duration) min")
        print("📅 URL: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("📅 Availability response status: \(httpResponse.statusCode)")
        if let dataString = String(data: data, encoding: .utf8) {
            print("📅 Availability response: \(dataString)")
        }
        
        switch httpResponse.statusCode {
        case 200, 201:
            // Backend returns: { "data": [{ "user": {...}, "available": bool, "message": string, "conflictingSession": {...} }] }
            let decoder = JSONDecoder()
            let backendResponse = try decoder.decode(BackendAvailabilityResponse.self, from: data)
            
            var results: [String: AvailabilityResponse] = [:]
            for item in backendResponse.data {
                results[item.user.email] = AvailabilityResponse(
                    user: SessionUserSummary(
                        id: item.user.id,
                        username: item.user.username,
                        email: item.user.email,
                        image: item.user.image,
                        avatarUrl: nil
                    ),
                    isAvailable: item.available,
                    conflict: item.conflictingSession != nil ? ConflictInfo(
                        title: item.conflictingSession?.title,
                        date: item.conflictingSession?.date,
                        duration: nil
                    ) : nil,
                    conflictingSessions: nil
                )
            }
            return results
            
        default:
            let message = String(data: data, encoding: .utf8) ?? "Erreur serveur"
            throw NSError(domain: "SessionService", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
    
    // MARK: - Reschedule workflow
    func proposeReschedule(sessionId: String, newDate: Date, newTime: Date, note: String?) async throws -> Session {
        guard let url = URL(string: "\(baseURL)/sessions/\(sessionId)/reschedule") else {
            throw URLError(.badURL)
        }
        
        var request = try authorizedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        let payload = RescheduleProposalPayload(
            proposedDate: isoFormatter.string(from: newDate),
            proposedTime: timeFormatter.string(from: newTime),
            note: note?.isEmpty == true ? nil : note
        )
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = createDecoder()
            return try decoder.decode(Session.self, from: data)
        default:
            let message = String(data: data, encoding: .utf8) ?? "Erreur serveur"
            throw NSError(domain: "SessionService", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
    
    func respondToReschedule(sessionId: String, decision: RescheduleDecision) async throws -> Session {
        guard let url = URL(string: "\(baseURL)/sessions/\(sessionId)/vote") else {
            throw URLError(.badURL)
        }
        
        var request = try authorizedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let voteValue = decision == .yes
        request.httpBody = try JSONEncoder().encode(["vote": voteValue])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = createDecoder()
            return try decoder.decode(Session.self, from: data)
        default:
            let message = String(data: data, encoding: .utf8) ?? "Erreur serveur"
            throw NSError(domain: "SessionService", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
    
    // MARK: - Rating
    func rateSession(sessionId: String, ratedUserId: String, rating: Int, comment: String?) async throws {
        guard let url = URL(string: "\(baseURL)/sessions/\(sessionId)/rate") else {
            throw URLError(.badURL)
        }
        
        var request = try authorizedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "ratedUserId": ratedUserId,
            "rating": rating
        ]
        if let comment = comment, !comment.isEmpty {
            body["comment"] = comment
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        switch httpResponse.statusCode {
        case 200, 201:
            return
        default:
            let message = "Erreur serveur (\(httpResponse.statusCode))"
            throw NSError(domain: "SessionService", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
    
    // MARK: - Recommendations (Sessions pour vous)
    func fetchRecommendations() async throws -> [Recommendation] {
        guard let url = URL(string: "\(baseURL)/sessions/recommendations") else {
            throw URLError(.badURL)
        }
        
        let request = try authorizedRequest(url: url, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("📥 Recommendations response status: \(httpResponse.statusCode)")
        if let dataString = String(data: data, encoding: .utf8) {
            print("📥 Recommendations data: \(dataString.prefix(500))")
        }
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            // Try wrapped response first
            if let recommendationResponse = try? decoder.decode(RecommendationResponse.self, from: data) {
                return recommendationResponse.data
            }
            // Try direct array
            return try decoder.decode([Recommendation].self, from: data)
        case 401:
            throw NSError(domain: "SessionService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Session expirée ou non autorisée"])
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Erreur serveur (\(httpResponse.statusCode))"
            throw NSError(domain: "SessionService", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
    }
}

private struct RescheduleProposalPayload: Encodable {
    let proposedDate: String
    let proposedTime: String
    let note: String?
}
