import SwiftUI

struct ProfileSetupView: View {
    var onContinue: () -> Void
    @EnvironmentObject private var auth: AuthenticationManager
    
    @State private var fullName: String = ""
    @State private var age: String = ""
    @State private var city: String = ""
    @State private var bio: String = ""
    
    @State private var teachSkills: [String] = []
    @State private var learnSkills: [String] = []
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let userService = UserService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Complète ton profil")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Aide-nous à trouver tes meilleurs matches en remplissant ces informations.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top)

                // Avatar Section (Placeholder for now, could be improved)
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: 80, height: 80)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Photo de profil")
                            .font(.headline)
                        Text("Ajoute une photo pour être plus visible")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)

                // Form Fields
                VStack(spacing: 20) {
                    CustomTextField(title: "Nom complet", placeholder: "Ex: Sarah Ben Ali", text: $fullName)
                    
                    HStack(spacing: 16) {
                        CustomTextField(title: "Âge", placeholder: "24", text: $age, keyboardType: .numberPad)
                        CustomTextField(title: "Ville", placeholder: "Tunis", text: $city)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bio")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $bio)
                            .frame(height: 100)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                }

                // Skills Sections
                VStack(spacing: 24) {
                    SkillSection(title: "Je peux enseigner", color: .orange, skills: $teachSkills)
                    SkillSection(title: "Je veux apprendre", color: .teal, skills: $learnSkills)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.top)
                }

                // Action Button
                Button {
                    saveProfile()
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        HStack {
                            Text("Continuer")
                                .fontWeight(.bold)
                            Image(systemName: "arrow.right")
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValid ? Color.orange : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(16)
                .disabled(!isValid || isLoading)
                .padding(.top, 10)
            }
            .padding(24)
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear {
            // Pre-fill if data exists
            if let user = auth.currentUser {
                fullName = user.username
                city = user.location?.city ?? ""
                teachSkills = user.skillsTeach ?? []
                learnSkills = user.skillsLearn ?? []
            }
        }
    }
    
    private var isValid: Bool {
        !fullName.isEmpty && !city.isEmpty && (!teachSkills.isEmpty || !learnSkills.isEmpty)
    }
    
    private func saveProfile() {
        guard let token = auth.accessToken else { return }
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let payload = UpdateUserRequest(
                    username: fullName,
                    email: nil, // Don't update email here
                    location: LocationPayload(lat: nil, lon: nil, city: city),
                    skillsTeach: teachSkills,
                    skillsLearn: learnSkills,
                    availability: nil
                )
                
                let updatedUser = try await userService.updateCurrentUser(accessToken: token, payload: payload)
                
                await MainActor.run {
                    auth.saveCurrentUser(updatedUser)
                    isLoading = false
                    onContinue()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct CustomTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .keyboardType(keyboardType)
        }
    }
}

struct SkillSection: View {
    let title: String
    let color: Color
    @Binding var skills: [String]
    @State private var newSkill = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(color)
            
            FlowLayout(spacing: 8) {
                ForEach(skills, id: \.self) { skill in
                    HStack(spacing: 4) {
                        Text(skill)
                            .font(.subheadline)
                        Button {
                            skills.removeAll { $0 == skill }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.1))
                    .foregroundColor(color)
                    .cornerRadius(20)
                }
                
                HStack {
                    Image(systemName: "plus")
                        .foregroundColor(.secondary)
                    TextField("Ajouter...", text: $newSkill)
                        .onSubmit {
                            addSkill()
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
                .frame(width: 120)
            }
        }
    }
    
    private func addSkill() {
        let trimmed = newSkill.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !skills.contains(trimmed) {
            skills.append(trimmed)
            newSkill = ""
        }
    }
}

// Simple FlowLayout implementation
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = flow(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = flow(proposal: proposal, subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func flow(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var points: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidthUsed: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            points.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxWidthUsed = max(maxWidthUsed, currentX)
        }

        return (CGSize(width: maxWidthUsed, height: currentY + lineHeight), points)
    }
}

struct ProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSetupView(onContinue: {})
    }
}


