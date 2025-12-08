import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var rememberMe = true
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let network = NetworkService()

    func login() async -> Bool {
        errorMessage = nil
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Email et mot de passe sont requis."
            return false
        }
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await network.login(email: email, password: password)
            if rememberMe { UserDefaults.standard.set(email, forKey: "savedEmail") }
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Échec de connexion."
            return false
        }
    }
}
