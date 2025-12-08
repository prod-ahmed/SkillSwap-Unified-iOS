import SwiftUI

struct RatingView: View {
    let sessionId: String
    let ratedUser: SessionUserSummary
    let skill: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedRating: Int = 0
    @State private var comment: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Laisser un avis")
                        .font(.title2.bold())
                        .padding(.top)
                    
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.orange.opacity(0.2))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Text(ratedUser.initials)
                                    .font(.title2.bold())
                                    .foregroundColor(.orange)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ratedUser.username)
                                .font(.headline)
                            Text(skill)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Divider()
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { index in
                                Button {
                                    selectedRating = index
                                } label: {
                                    Image(systemName: index <= selectedRating ? "star.fill" : "star")
                                        .font(.system(size: 40))
                                        .foregroundColor(index <= selectedRating ? .yellow : Color(.systemGray3))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        Text(ratingLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(selectedRating >= 3 ? .green : .red)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Votre commentaire")
                            .font(.subheadline.weight(.semibold))
                        TextEditor(text: $comment)
                            .frame(minHeight: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .padding(4)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Button {
                        submitRating()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Envoyer l'avis")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedRating > 0 ? Color.orange : Color.gray)
                    )
                    .disabled(selectedRating == 0 || isLoading)
                }
                .padding()
            }
            .navigationTitle("Avis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var ratingLabel: String {
        switch selectedRating {
        case 0: return "Sélectionnez une note"
        case 1: return "Très mauvais"
        case 2: return "Mauvais"
        case 3: return "Très bien"
        case 4: return "Excellent"
        case 5: return "Parfait"
        default: return ""
        }
    }
    
    private func submitRating() {
        guard selectedRating > 0 else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await SessionService.shared.rateSession(
                    sessionId: sessionId,
                    ratedUserId: ratedUser.id,
                    rating: selectedRating,
                    comment: comment.isEmpty ? nil : comment
                )
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Erreur lors de l'envoi de l'avis: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct RatingView_Previews: PreviewProvider {
    static var previews: some View {
        RatingView(
            sessionId: "123",
            ratedUser: SessionUserSummary(
                id: "456",
                username: "John Doe",
                email: "john@example.com",
                image: nil,
                avatarUrl: nil
            ),
            skill: "Photoshop"
        )
    }
}
