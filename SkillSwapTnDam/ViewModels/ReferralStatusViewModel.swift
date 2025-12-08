import Foundation
import SwiftUI

@MainActor
final class ReferralStatusViewModel: ObservableObject {
    @Published var inviterReferrals: [ReferralItem] = []
    @Published var inviteeReferral: ReferralItem? = nil
    @Published var rewards: [RewardItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let api: ReferralAPI
    private let token: String

    init(api: ReferralAPI = .shared, token: String) {
        self.api = api
        self.token = token
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let me = try await api.getMyReferrals(token: token)
            inviterReferrals = me.inviterReferrals
            inviteeReferral = me.inviteeReferral
            rewards = me.rewards
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
