import SwiftUI

struct ReferralCodeView: View {
    @StateObject var vm: ReferralCodeViewModel
    @State private var showShare = false
    @State private var showCopied = false

    var body: some View {
        VStack(spacing: 16) {
            if let code = vm.code {
                Text("Your referral code")
                    .font(.headline)
                Text(code)
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .padding()
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = code
                            showCopied = true
                        }) {
                            Text("Copy code")
                            Image(systemName: "doc.on.doc")
                        }
                    }
                HStack(spacing: 16) {
                    Button(action: { showShare = true }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button(action: {
                        UIPasteboard.general.string = code
                        showCopied = true
                    }) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            } else if vm.isLoading {
                ProgressView()
            } else {
                Text("You don't have a referral code yet.")
                Button("Create code") {
                    Task { await vm.createCode() }
                }
            }

            if let err = vm.errorMessage {
                Text(err).foregroundColor(.red).font(.caption)
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showShare) {
            if let code = vm.code {
                ShareSheet(activityItems: ["Join SkillSwap with my code: \(code)"])
            }
        }
        .alert("Copied", isPresented: $showCopied) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Referral code copied to clipboard")
        }
        .task {
            // attempt to refresh existing referrals or create if none
            await vm.refreshMyReferrals()
        }
    }
}

struct ReferralCodeView_Previews: PreviewProvider {
    static var previews: some View {
        ReferralCodeView(vm: ReferralCodeViewModel(token: ""))
    }
}
