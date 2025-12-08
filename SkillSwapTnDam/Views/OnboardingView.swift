import SwiftUI

struct OnboardingCard: View {
    let imageName: String
    let title: String
    let subtitle: String
    let accent: Color

    var body: some View {
        VStack(spacing: 24) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                )
                .frame(height: 220)
                .clipped()
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)

            Text(title)
                .font(.title2.weight(.bold))
                .foregroundColor(accent)
            Text(subtitle)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page: Int = 0

    var body: some View {
        VStack {
            TabView(selection: $page) {
                OnboardingCard(
                    imageName: "logo",
                    title: "Apprends",
                    subtitle: "Découvre de nouvelles compétences avec des experts passionnés",
                    accent: .orange
                ).tag(0)

                OnboardingCard(
                    imageName: "logo",
                    title: "Partage",
                    subtitle: "Enseigne tes talents et aide les autres à progresser",
                    accent: Color.cyan
                ).tag(1)

                OnboardingCard(
                    imageName: "logo",
                    title: "Connecte",
                    subtitle: "Rejoins une communauté tunisienne dynamique d'apprenants",
                    accent: .orange
                ).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            PrimaryButton(title: page < 2 ? "Suivant" : "Commencer", systemImage: "chevron.right") {
                if page < 2 { page += 1 } else { onFinish() }
            }
            .padding()

            Button("Passer") { onFinish() }
                .foregroundColor(.secondary)
                .padding(.bottom)
        }
        .navigationTitle("")
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onFinish: {})
    }
}


