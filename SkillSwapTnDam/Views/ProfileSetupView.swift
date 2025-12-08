import SwiftUI

struct ProfileSetupView: View {
    var onContinue: () -> Void

    @State private var fullName: String = ""
    @State private var age: String = ""
    @State private var city: String = ""
    @State private var bio: String = ""

    @State private var teachSkills: [String] = ["Photoshop", "Design"]
    @State private var learnSkills: [String] = ["Guitare", "Arabe"]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Complète ton profil")
                    .font(.title.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Aide-nous à trouver tes meilleurs matches")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: 88, height: 88)
                        Image(systemName: "camera")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ajouter une photo")
                            .font(.headline)
                        Text("Optionnel")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                section {
                    labeledField("Nom complet") { TextField("Sarah Ben Ali", text: $fullName) }
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Âge").font(.subheadline).foregroundColor(.secondary)
                            TextField("24", text: $age)
                                .keyboardType(.numberPad)
                                .appField()
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ville").font(.subheadline).foregroundColor(.secondary)
                            TextField("Tunis", text: $city)
                                .appField()
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bio courte").font(.subheadline).foregroundColor(.secondary)
                        TextEditor(text: $bio)
                            .frame(minHeight: 100)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Compétences à enseigner").font(.headline).foregroundColor(.orange)
                    SkillChipsEditor(skills: $teachSkills, color: .orange)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Compétences à apprendre").font(.headline).foregroundColor(.teal)
                    SkillChipsEditor(skills: $learnSkills, color: .teal)
                }

                PrimaryButton(title: "Continuer", systemImage: "arrow.right") { onContinue() }
            }
            .padding()
        }
        .navigationTitle("")
    }

    private func section(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 14) { content() }
            .padding()
            .background(RoundedRectangle(cornerRadius: 18).fill(.white))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
    }

    private func labeledField(_ label: String, @ViewBuilder field: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            HStack { field() }.appField()
        }
    }
}

struct ProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSetupView(onContinue: {})
    }
}


