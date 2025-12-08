//
//  AuthService.swift
//  SkillSwapTnDam
//
//  Created by Ahmed BT on 09/11/2025.
//

import Foundation

final class AuthService {
    private let baseURL = NetworkConfig.baseURL

    struct SignInPayload: Encodable {
        let email: String
        let password: String
    }

    struct RefreshTokenResponse: Decodable {
        let accessToken: String
        
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
        }
    }

    func signIn(email: String, password: String) async throws -> SignInResponse {
        guard let url = URL(string: "\(baseURL)/auth/login") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(SignInPayload(email: email, password: password))

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                print("AuthService: Bad server response (not HTTP)")
                throw URLError(.badServerResponse)
            }

            if (200...299).contains(http.statusCode) {
                return try JSONDecoder().decode(SignInResponse.self, from: data)
            }
            
            print("AuthService: Server returned status code \(http.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("AuthService: Response body: \(responseString)")
            }

            if let apiErr = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NSError(domain: "AuthService", code: http.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: apiErr.message])
            }
            throw NSError(domain: "AuthService", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Unexpected server response (\(http.statusCode))."])
        } catch {
            print("AuthService: Request failed with error: \(error.localizedDescription)")
            print("AuthService: Full error details: \(error)")
            throw error
        }
    }

    func refreshToken(token: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/auth/refresh") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        print("🔐 [AuthService] Refresh token response: \(http.statusCode)")
        
        if (200...299).contains(http.statusCode) {
            let res = try JSONDecoder().decode(RefreshTokenResponse.self, from: data)
            return res.accessToken
        }
        
        // Log the error response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("🔐 [AuthService] Refresh token error body: \(responseString)")
        }
        
        throw NSError(domain: "AuthService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to refresh token (\(http.statusCode))"])
    }
}
