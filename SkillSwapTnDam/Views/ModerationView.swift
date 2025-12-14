import SwiftUI

struct ModerationView: View {
    @StateObject private var viewModel = ModerationViewModel()
    @State private var imageBase64 = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Vérifiez une image (base64) avant de la publier.")
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    TextEditor(text: $imageBase64)
                        .frame(minHeight: 150)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    
                    Button(action: {
                        viewModel.checkImage(imageBase64: imageBase64)
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Vérifier")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "FF6B35"))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(imageBase64.isEmpty || viewModel.isLoading)
                    .padding(.horizontal)
                    
                    if let result = viewModel.result {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: result.safe ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.safe ? .green : .red)
                                Text(result.safe ? "Image acceptée" : "Image refusée")
                                    .fontWeight(.bold)
                                    .foregroundColor(result.safe ? .green : .red)
                            }
                            
                            if let reasons = result.reasons, !reasons.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Raisons:")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    ForEach(reasons, id: \.self) { reason in
                                        Text("• \(reason)")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    if let error = viewModel.error {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle("Modération")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
}

@MainActor
class ModerationViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var result: ModerationResult?
    @Published var error: String?
    
    func checkImage(imageBase64: String) {
        Task {
            isLoading = true
            error = nil
            result = nil
            
            do {
                result = try await ModerationService.shared.checkImage(imageBase64: imageBase64)
            } catch {
                self.error = "Erreur: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
}

struct ModerationResult: Codable {
    let safe: Bool
    let reasons: [String]?
}
