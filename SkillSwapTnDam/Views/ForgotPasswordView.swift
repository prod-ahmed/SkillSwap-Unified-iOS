import SwiftUI

struct ForgotPasswordView: View {
    @StateObject private var vm = ForgotPasswordVM()

    var body: some View {
        VStack(spacing: 16) {
            Text("Mot de passe oublié").font(.title2).bold()
            Text("Entrez votre email pour réinitialiser votre mot de passe.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField("votre@email.com", text: $vm.email)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)

            Button {
                vm.submit()
            } label: {
                if vm.isLoading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Text("Envoyer").frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .disabled(vm.isLoading || vm.email.isEmpty)

            if let message = vm.message {
                Text(message).font(.footnote).foregroundColor(.green)
            }

            if let error = vm.errorMessage {
                Text(error).font(.footnote).foregroundColor(.red)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Mot de passe oublié")
    }
}
