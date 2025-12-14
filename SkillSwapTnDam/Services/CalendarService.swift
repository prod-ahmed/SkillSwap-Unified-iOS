import Foundation

struct CalendarEvent: Codable, Identifiable {
    let id: String
    let userId: String
    let title: String
    let description: String?
    let startTime: String
    let endTime: String
    let location: String?
    let participants: [String]?
    let sessionId: String?
    let reminder: Int?
    let isAllDay: Bool?
    let status: String?
    let googleEventId: String?
    let createdAt: String?
    let updatedAt: String?
}

struct CreateEventRequest: Codable {
    let title: String
    let description: String?
    let startTime: String
    let endTime: String
    let location: String?
    let participants: [String]?
    let sessionId: String?
    let reminder: Int
    let isAllDay: Bool
    let syncToGoogle: Bool
}

struct UpdateEventRequest: Codable {
    let title: String?
    let description: String?
    let startTime: String?
    let endTime: String?
    let location: String?
    let status: String?
}

struct CalendarEventsResponse: Codable {
    let events: [CalendarEvent]
}

struct GoogleAuthUrlResponse: Codable {
    let authUrl: String
}

struct GoogleSyncResponse: Codable {
    let synced: Int
}

struct GoogleCalendarTokenRequest: Codable {
    let code: String
    let redirectUri: String?
}

class CalendarService {
    static let shared = CalendarService()
    
    private let baseURL: String
    
    private init() {
        if let url = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String, !url.isEmpty {
            self.baseURL = url
        } else {
            self.baseURL = "https://8rq89w2v-3000.uks1.devtunnels.ms"
        }
    }
    
    private func authHeader() -> String? {
        guard let token = UserDefaults.standard.string(forKey: "authToken") else { return nil }
        return "Bearer \(token)"
    }
    
    // MARK: - Event CRUD
    
    func getEvents(startDate: String? = nil, endDate: String? = nil) async throws -> [CalendarEvent] {
        var components = URLComponents(string: "\(baseURL)/calendar/events")!
        var queryItems: [URLQueryItem] = []
        if let start = startDate {
            queryItems.append(URLQueryItem(name: "startDate", value: start))
        }
        if let end = endDate {
            queryItems.append(URLQueryItem(name: "endDate", value: end))
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        guard let url = components.url else { throw URLError(.badURL) }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let auth = authHeader() {
            req.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let response = try JSONDecoder().decode(CalendarEventsResponse.self, from: data)
        return response.events
    }
    
    func getEvent(id: String) async throws -> CalendarEvent {
        guard let url = URL(string: "\(baseURL)/calendar/events/\(id)") else { throw URLError(.badURL) }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let auth = authHeader() {
            req.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(CalendarEvent.self, from: data)
    }
    
    func createEvent(request: CreateEventRequest) async throws -> CalendarEvent {
        guard let url = URL(string: "\(baseURL)/calendar/events") else { throw URLError(.badURL) }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let auth = authHeader() {
            req.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        
        req.httpBody = try JSONEncoder().encode(request)
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(CalendarEvent.self, from: data)
    }
    
    func updateEvent(id: String, request: UpdateEventRequest) async throws -> CalendarEvent {
        guard let url = URL(string: "\(baseURL)/calendar/events/\(id)") else { throw URLError(.badURL) }
        
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let auth = authHeader() {
            req.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        
        req.httpBody = try JSONEncoder().encode(request)
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(CalendarEvent.self, from: data)
    }
    
    func deleteEvent(id: String) async throws {
        guard let url = URL(string: "\(baseURL)/calendar/events/\(id)") else { throw URLError(.badURL) }
        
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        
        if let auth = authHeader() {
            req.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - Participants
    
    func addParticipant(eventId: String, userId: String) async throws -> CalendarEvent {
        guard let url = URL(string: "\(baseURL)/calendar/events/\(eventId)/participants") else {
            throw URLError(.badURL)
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let auth = authHeader() {
            req.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        
        let body = ["userId": userId]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(CalendarEvent.self, from: data)
    }
    
    func removeParticipant(eventId: String, userId: String) async throws -> CalendarEvent {
        guard let url = URL(string: "\(baseURL)/calendar/events/\(eventId)/participants/\(userId)") else {
            throw URLError(.badURL)
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        
        if let auth = authHeader() {
            req.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(CalendarEvent.self, from: data)
    }
    
    func respondToInvite(eventId: String, response: String) async throws -> CalendarEvent {
        guard let url = URL(string: "\(baseURL)/calendar/events/\(eventId)/respond") else {
            throw URLError(.badURL)
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let auth = authHeader() {
            req.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        
        let body = ["response": response]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(CalendarEvent.self, from: data)
    }
    
    // MARK: - Google Calendar Integration
    
    func checkGoogleCalendarStatus() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/calendar/google/status") else { throw URLError(.badURL) }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        
        if let auth = authHeader() {
            req.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return false
        }
        
        struct StatusResponse: Decodable {
            let connected: Bool
        }
        
        if let status = try? JSONDecoder().decode(StatusResponse.self, from: data) {
            return status.connected
        }
        return false
    }
    
    func getGoogleAuthUrl() async throws -> String {
        guard let url = URL(string: "\(baseURL)/calendar/google/auth") else { throw URLError(.badURL) }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        
        if let auth = authHeader() {
            req.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let response = try JSONDecoder().decode(GoogleAuthUrlResponse.self, from: data)
        return response.authUrl
    }
    
    func handleGoogleCallback(code: String, redirectUri: String? = nil) async throws {
        guard let url = URL(string: "\(baseURL)/calendar/google/callback") else { throw URLError(.badURL) }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let auth = authHeader() {
            req.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        
        let request = GoogleCalendarTokenRequest(code: code, redirectUri: redirectUri)
        req.httpBody = try JSONEncoder().encode(request)
        
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    func syncWithGoogle(bidirectional: Bool = true) async throws -> Int {
        guard let url = URL(string: "\(baseURL)/calendar/google/sync") else { throw URLError(.badURL) }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let auth = authHeader() {
            req.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        
        let body = ["bidirectional": bidirectional]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let response = try JSONDecoder().decode(GoogleSyncResponse.self, from: data)
        return response.synced
    }
    
    func disconnectGoogleCalendar() async throws {
        guard let url = URL(string: "\(baseURL)/calendar/google/disconnect") else { throw URLError(.badURL) }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        
        if let auth = authHeader() {
            req.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
