import SwiftUI

struct ReferralStatusView: View {
    @StateObject var vm: ReferralStatusViewModel

    var body: some View {
        VStack {
            if vm.isLoading {
                ProgressView()
            } else {
                List {
                    if let invitee = vm.inviteeReferral {
                        Section(header: Text("You're invited")) {
                            VStack(alignment: .leading) {
                                Text("Status: \(invitee.status ?? "unknown")")
                                Text("Reward applied: \((invitee.rewardApplied ?? false) ? "Yes" : "No")")
                            }
                        }
                    }

                    Section(header: Text("Your invites")) {
                        ForEach(vm.inviterReferrals, id: \._id) { r in
                            VStack(alignment: .leading) {
                                Text("Invitee: \(r.inviteeId ?? "-")")
                                Text("Status: \(r.status ?? "-")")
                                Text("Rewarded: \(r.rewardApplied == true ? "Yes" : "No")")
                            }
                            .padding(.vertical, 8)
                        }
                    }

                    Section(header: Text("Rewards")) {
                        ForEach(vm.rewards, id: \._id) { reward in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Type: \(reward.rewardType)")
                                    if let amount = reward.amount {
                                        Text("Amount: \(amount)")
                                    }
                                    Text("Status: \(reward.status)")
                                }
                                Spacer()
                                Text(reward.createdAt ?? "")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
        }
        .navigationTitle("Referrals & Rewards")
        .onAppear {
            Task { await vm.load() }
        }
    }
}

struct ReferralStatusView_Previews: PreviewProvider {
    static var previews: some View {
        ReferralStatusView(vm: ReferralStatusViewModel(token: ""))
    }
}
