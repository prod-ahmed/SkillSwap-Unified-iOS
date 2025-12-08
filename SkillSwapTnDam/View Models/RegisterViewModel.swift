import Foundation

@MainActor
final class RegisterViewModel: ObservableObject {
    @Published var fullName = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var referralCode = "" {
        didSet {
            let alphanumerics = referralCode
                .uppercased()
                .filter { $0.isLetter || $0.isNumber }
            let limited = String(alphanumerics.prefix(5))
            if referralCode != limited {
                referralCode = limited
            }
        }
    }
    @Published var referralPreview: ReferralPreview?
    @Published var referralMessage: String?
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isValidatingReferral = false

    private let network = NetworkService()

    func register() async -> Bool {
        errorMessage = nil
        guard !fullName.isEmpty, !email.isEmpty, !password.isEmpty else {
            errorMessage = "Tous les champs sont requis."
            return false
        }
        guard password == confirmPassword else {
            errorMessage = "Les mots de passe ne correspondent pas."
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Your backend expects "username" => we pass fullName as username
            _ = try await network.register(
                username: fullName,
                email: email,
                password: password,
                referralCode: referralCode.isEmpty ? nil : referralCode.uppercased()
            )

            // Optional: auto-login after register
            _ = try await network.login(email: email, password: password)
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Inscription impossible."
            return false
        }
    }

    func validateReferral() async {
        referralMessage = nil
        referralPreview = nil
        guard referralCode.trimmingCharacters(in: .whitespacesAndNewlines).count == 5 else {
            referralMessage = "Code à 5 caractères."
            return
        }

        isValidatingReferral = true
        defer { isValidatingReferral = false }
        do {
            let preview = try await network.validateReferral(code: referralCode)
            referralPreview = preview
            referralMessage = "Code de \(preview.username) appliqué."
        } catch {
            referralMessage = (error as? LocalizedError)?.errorDescription
                ?? "Code invalide."
        }
    }
}
