import Foundation

enum ReferralAPIError: Error, LocalizedError {
    case invalidURL
    case serverError(status: Int)
    case decodingError
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .serverError(let status): return "Server error (\(status))"
        case .decodingError: return "Failed to decode response"
        case .unknown: return "Unknown error"
        }
    }
}

struct ReferralCodeResponse: Codable {
    let code: String
    let codeId: String
    let expiresAt: String?
}

struct RedeemResponse: Codable {
    let referralId: String
    let status: String
}

struct ReferralItem: Codable {
    let _id: String
    let codeId: String?
    let inviterId: String?
    let inviteeId: String?
    let inviteeEmail: String?
    let status: String?
    let rewardApplied: Bool?
    let createdAt: String?
    let updatedAt: String?
}

struct RewardItem: Codable {
    let _id: String
    let referralId: String?
    let userId: String
    let rewardType: String
    let amount: Int?
    let status: String
    let createdAt: String?
}

struct ReferralsMeResponse: Codable {
    let inviterReferrals: [ReferralItem]
    let inviteeReferral: ReferralItem?
    let rewards: [RewardItem]
}

final class ReferralAPI {
    static let shared = ReferralAPI(baseURL: URL(string: NetworkConfig.baseURL)!)

    private let baseURL: URL
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder

    init(baseURL: URL) {
        self.baseURL = baseURL
        self.jsonDecoder = JSONDecoder()
        self.jsonEncoder = JSONEncoder()
        self.jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        self.jsonEncoder.keyEncodingStrategy = .convertToSnakeCase
    }

    private func makeRequest(path: String, method: String = "GET", token: String? = nil, body: Data? = nil, idempotencyKey: String? = nil) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw ReferralAPIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let idk = idempotencyKey {
            req.setValue(idk, forHTTPHeaderField: "Idempotency-Key")
        }
        req.httpBody = body
        return req
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ReferralAPIError.unknown }
        guard (200...299).contains(http.statusCode) else { throw ReferralAPIError.serverError(status: http.statusCode) }
        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            // If T is Void-backed, decode to empty
            throw ReferralAPIError.decodingError
        }
    }

    // MARK: - API Methods

    func createCode(usageLimit: Int = 0, expiresAt: Date? = nil, campaign: String? = nil, token: String) async throws -> ReferralCodeResponse {
        let path = "/referrals/codes"
        var payload: [String: Any] = ["usageLimit": usageLimit]
        if let expiresAt = expiresAt {
            let iso = ISO8601DateFormatter().string(from: expiresAt)
            payload["expiresAt"] = iso
        }
        if let campaign = campaign { payload["campaign"] = campaign }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let req = try makeRequest(path: path, method: "POST", token: token, body: body)
        return try await perform(req)
    }

    func redeemCode(code: String, idempotencyKey: String? = nil, token: String? = nil) async throws -> RedeemResponse {
        let path = "/referrals/redeem"
        let payload = ["code": code]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let req = try makeRequest(path: path, method: "POST", token: token, body: body, idempotencyKey: idempotencyKey)
        return try await perform(req)
    }

    func getMyReferrals(token: String) async throws -> ReferralsMeResponse {
        let path = "/referrals/me"
        let req = try makeRequest(path: path, method: "GET", token: token)
        return try await perform(req)
    }
}
