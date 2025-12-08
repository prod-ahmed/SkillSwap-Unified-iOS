import Foundation
import SwiftUI

@MainActor
final class EnterReferralCodeViewModel: ObservableObject {
    @Published var codeText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil

    private let api: ReferralAPI
    private let token: String?

    init(api: ReferralAPI = .shared, token: String? = nil) {
        self.api = api
        self.token = token
    }

    func redeem(idempotencyKey: String? = nil) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            let resp = try await api.redeemCode(code: codeText.trimmingCharacters(in: .whitespacesAndNewlines), idempotencyKey: idempotencyKey, token: token)
            successMessage = "Redeemed: \(resp.status)"
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
