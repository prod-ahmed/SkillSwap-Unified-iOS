import Foundation

struct ForgotResponse: Decodable {
    let message: String
}

struct ForgotRequest: Encodable {
    let email: String
}

@MainActor
final class ForgotPasswordVM: ObservableObject {
    @Published var email = ""
    @Published var message: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let endpoint = URL(string: "\(NetworkConfig.baseURL)/users/forgot-password")!

    func submit() {
        Task {
            isLoading = true
            errorMessage = nil
            message = nil

            do {
                var req = URLRequest(url: endpoint)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("application/json", forHTTPHeaderField: "Accept")

                let body = ForgotRequest(email: email)
                req.httpBody = try JSONEncoder().encode(body)

                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }

                if (200..<300).contains(http.statusCode) {
                    let res = try JSONDecoder().decode(ForgotResponse.self, from: data)
                    message = res.message
                } else {
                    errorMessage = "Server error (\(http.statusCode))"
                }
            } catch {
                errorMessage = "Network error. Please try again."
            }

            isLoading = false
        }
    }
}
