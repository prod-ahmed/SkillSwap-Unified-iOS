import Foundation

// MARK: - API Error
enum APIError: Error {
    case invalidURL
    case invalidResponse
    case decodingError
    case serverError(message: String)
    case unauthorized
}

// MARK: - HTTP Method
enum HTTPMethod: String {
    case GET, POST, PUT, DELETE, PATCH
}

// MARK: - API Client
class APIClient {
    static let shared = APIClient()
    private init() {}
    
    private let baseURL = "https://api.skillswap.com/v1" // Replace with your actual URL
    
    // MARK: - Token Management
    var authToken: String? {
        get { UserDefaults.standard.string(forKey: "authToken") }
        set { UserDefaults.standard.set(newValue, forKey: "authToken") }
    }
    
    // MARK: - Generic Request
    func request<T: Decodable>(endpoint: String,
                               method: HTTPMethod = .GET,
                               body: Encodable? = nil,
                               headers: [String: String] = [:]) async throws -> T {
        
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Auth Header
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Custom Headers
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        // Body
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw APIError.decodingError // Actually encoding error here
            }
        }
        
        // Perform Request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // Handle Status Codes
        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                return decodedResponse
            } catch {
                throw APIError.decodingError
            }
        case 401:
            throw APIError.unauthorized
        default:
            // Try to parse error message from server
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(message: errorResponse.message)
            }
            throw APIError.serverError(message: "Status code: \(httpResponse.statusCode)")
        }
    }
}
