import SwiftUI

struct GoogleAuthView: View {
    @StateObject private var viewModel = GoogleAuthViewModel()
    @Environment(\.dismiss) private var dismiss
    let onSuccess: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // Google Logo
                Image(systemName: "g.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                
                Text("Sign in with Google")
                    .font(.title2.bold())
                
                Text("Connect your Google account to continue")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                // Google Sign In Button
                Button {
                    Task {
                        let success = await viewModel.signInWithGoogle()
                        if success {
                            onSuccess()
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "g.circle.fill")
                            .font(.title3)
                        Text("Continue with Google")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.red)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(viewModel.isLoading)
                
                if viewModel.isLoading {
                    ProgressView()
                }
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Google Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

@MainActor
class GoogleAuthViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    func signInWithGoogle() async -> Bool {
        isLoading = true
        errorMessage = nil
        
        // TODO: Implement Google Sign-In SDK integration
        // This requires adding GoogleSignIn pod/package
        // For now, show placeholder message
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        isLoading = false
        errorMessage = "Google Sign-In requires GoogleSignIn SDK integration"
        
        return false
    }
}

struct GoogleAuthView_Previews: PreviewProvider {
    static var previews: some View {
        GoogleAuthView(onSuccess: {})
    }
}
