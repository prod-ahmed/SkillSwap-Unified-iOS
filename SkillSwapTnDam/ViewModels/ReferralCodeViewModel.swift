import Foundation
import SwiftUI

@MainActor
final class ReferralCodeViewModel: ObservableObject {
    @Published var code: String? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private let api: ReferralAPI
    private let token: String

    init(api: ReferralAPI = .shared, token: String) {
        self.api = api
        self.token = token
    }

    func createCode(usageLimit: Int = 0, expiresAt: Date? = nil, campaign: String? = nil) async {
        isLoading = true
        errorMessage = nil
        do {
            let resp = try await api.createCode(usageLimit: usageLimit, expiresAt: expiresAt, campaign: campaign, token: token)
            self.code = resp.code
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refreshMyReferrals() async {
        isLoading = true
        errorMessage = nil
        do {
            let me = try await api.getMyReferrals(token: token)
            // If user has any inviterReferrals we may infer a referralCode by checking their user record server-side.
            // For now, pick the first inviter referral's codeId -> not guaranteed. Prefer to create a code if none.
            if let first = me.inviterReferrals.first, let codeId = first.codeId {
                // In practice you would call a GET /referrals/codes/:code endpoint; instead we fallback
                self.code = "(code for: \(codeId))"
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
