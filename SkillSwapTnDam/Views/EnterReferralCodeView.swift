import SwiftUI

struct EnterReferralCodeView: View {
    @StateObject var vm: EnterReferralCodeViewModel
    var idempotencyKeyProvider: (() -> String)? = { UUID().uuidString }

    var body: some View {
        VStack(spacing: 16) {
            Text("Have a referral code?")
                .font(.headline)
            TextField("Enter code", text: $vm.codeText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.horizontal)

            if vm.isLoading {
                ProgressView()
            }

            if let err = vm.errorMessage {
                Text(err).foregroundColor(.red)
            }

            if let success = vm.successMessage {
                Text(success).foregroundColor(.green)
            }

            Button(action: {
                Task {
                    await vm.redeem(idempotencyKey: idempotencyKeyProvider?())
                }
            }) {
                Text("Apply Code")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}

struct EnterReferralCodeView_Previews: PreviewProvider {
    static var previews: some View {
        EnterReferralCodeView(vm: EnterReferralCodeViewModel(token: nil))
    }
}
