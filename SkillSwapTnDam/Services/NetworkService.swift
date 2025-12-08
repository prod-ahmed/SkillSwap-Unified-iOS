// NetworkService.swift
import Foundation

// MARK: - Errors
// If you already have this enum in another file, delete this block.
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
    case invalidResponse
    case unauthorized
    case emailAlreadyExists
    case encodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL."
        case .noData: return "No data received."
        case .decodingError: return "Failed to decode the response."
        case .serverError(let msg): return msg
        case .invalidResponse: return "Invalid server response."
        case .unauthorized: return "Unauthorized."
        case .emailAlreadyExists: return "Email already exists."
        case .encodingError: return "Failed to encode the request body."
        }
    }
}

// MARK: - Service
final class NetworkService {

    // Use localhost for the iOS Simulator; LAN IP for a physical device
    #if targetEnvironment(simulator)
    private let baseURL = NetworkConfig.baseURL
    #else
    private let baseURL = NetworkConfig.baseURL
    #endif

    // MARK: Helpers
    private func makeURL(_ path: String) throws -> URL {
        guard let url = URL(string: baseURL + path) else { throw NetworkError.invalidURL }
        return url
    }

    private func decodeAPIError(_ data: Data) -> NetworkError {
        if let apiErr = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            return .serverError(apiErr.message)
        }
        return .serverError("An unknown error occurred.")
    }

    private func setAuthHeader(on request: inout URLRequest) async {
        // AuthenticationManager is @MainActor, so read token on main actor
        let token: String? = await MainActor.run { AuthenticationManager.shared.accessToken }
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    // MARK: DTOs
    private struct LoginBody: Encodable { let email: String; let password: String }
    private struct RegisterBody: Encodable {
        let username: String
        let email: String
        let password: String
        let referralCode: String?
    }
    private struct ValidateReferralBody: Encodable { let codeParainnage: String }

    // MARK: - Auth
    /// Login and persist token/user via AuthenticationManager.
    func login(email: String, password: String) async throws -> SignInResponse {
        print("🔐 [NetworkService] Starting login for: \(email)")
        var req = URLRequest(url: try makeURL("/auth/login")) // use "/auth/signin" if your backend uses that
        req.httpMethod   = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody     = try JSONEncoder().encode(LoginBody(email: email, password: password))

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }

        print("🔐 [NetworkService] Login response status: \(http.statusCode)")
        
        switch http.statusCode {
        case 200, 201:
            let res = try JSONDecoder().decode(SignInResponse.self, from: data)
            print("🔐 [NetworkService] Login successful, token: \(res.accessToken.prefix(20))...")

            // Touch main-actor isolated state on main actor
            await MainActor.run {
                let auth = AuthenticationManager.shared
                auth.signIn(with: res)         // saves token in UserDefaults
                auth.saveCurrentUser(res.user) // persist user snapshot from response
                print("🔐 [NetworkService] Token saved, verifying: \(auth.accessToken?.prefix(20) ?? "NIL")...")
            }
            return res

        case 401:
            throw NetworkError.unauthorized
        default:
            throw decodeAPIError(data)
        }
    }

    func register(
        username: String,
        email: String,
        password: String,
        referralCode: String?
    ) async throws -> User {
        var req = URLRequest(url: try makeURL("/auth/register"))
        req.httpMethod   = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody     = try JSONEncoder().encode(
            RegisterBody(
                username: username,
                email: email,
                password: password,
                referralCode: referralCode?.isEmpty == false ? referralCode : nil
            )
        )

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }

        switch http.statusCode {
        case 201:
            do { return try JSONDecoder().decode(User.self, from: data) }
            catch { throw NetworkError.decodingError }
        case 409:
            throw NetworkError.emailAlreadyExists
        default:
            throw decodeAPIError(data)
        }
    }

    func validateReferral(code: String) async throws -> ReferralPreview {
        var req = URLRequest(url: try makeURL("/users/referrals/validate"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(
            ValidateReferralBody(codeParainnage: code.uppercased())
        )

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }

        switch http.statusCode {
        case 200:
            return try JSONDecoder().decode(ReferralPreview.self, from: data)
        default:
            throw decodeAPIError(data)
        }
    }

    // MARK: - Me
    func fetchMe() async throws -> User {
        var req = URLRequest(url: try makeURL("/users/me"))
        req.httpMethod   = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        await setAuthHeader(on: &req)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }

        switch http.statusCode {
        case 200:
            let user = try JSONDecoder().decode(User.self, from: data)
            // Save on main actor
            await MainActor.run {
                AuthenticationManager.shared.saveCurrentUser(user)
            }
            return user
        case 401:
            throw NetworkError.unauthorized
        default:
            throw decodeAPIError(data)
        }
    }

    // MARK: - Logout
    func logout(userId: String) async throws {
        var req = URLRequest(url: try makeURL("/auth/logout"))
        req.httpMethod   = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        await setAuthHeader(on: &req)

        let body: [String: String] = ["userId": userId]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: .fragmentsAllowed)

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }

        if http.statusCode == 200 {
            await MainActor.run {
                AuthenticationManager.shared.signOut()
            }
        } else {
            let msg = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw NetworkError.serverError("Logout failed: \(msg)")
        }
    }

    // MARK: - JWT decode (utility)
    func decodeJWT(token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var b64 = String(parts[1])
        while b64.count % 4 != 0 { b64.append("=") }
        guard let data = Data(base64Encoded: b64, options: .ignoreUnknownCharacters) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String : Any]
    }
}
