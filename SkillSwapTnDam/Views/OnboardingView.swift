import SwiftUI

struct OnboardingCard: View {
    let imageName: String
    let title: String
    let subtitle: String
    let accent: Color

    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.1))
                    .frame(width: 280, height: 280)
                    .blur(radius: 20)
                
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .shadow(color: accent.opacity(0.3), radius: 15, x: 0, y: 10)
            }
            .padding(.top, 40)

            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
                    .lineSpacing(4)
            }
        }
        .padding(.bottom, 40)
    }
}

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page: Int = 0

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack {
                TabView(selection: $page) {
                    OnboardingCard(
                        imageName: "logo", // Ensure this asset exists or use systemImage fallback
                        title: "Apprends",
                        subtitle: "Découvre de nouvelles compétences avec des experts passionnés près de chez toi.",
                        accent: .orange
                    ).tag(0)

                    OnboardingCard(
                        imageName: "logo",
                        title: "Partage",
                        subtitle: "Enseigne tes talents et aide les autres à progresser tout en gagnant des crédits.",
                        accent: Color.cyan
                    ).tag(1)

                    OnboardingCard(
                        imageName: "logo",
                        title: "Connecte",
                        subtitle: "Rejoins une communauté tunisienne dynamique d'apprenants et de mentors.",
                        accent: .purple
                    ).tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: page)

                // Custom Page Indicator
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Capsule()
                            .fill(page == index ? Color.orange : Color.gray.opacity(0.3))
                            .frame(width: page == index ? 24 : 8, height: 8)
                            .animation(.spring(), value: page)
                    }
                }
                .padding(.bottom, 32)

                // Buttons
                VStack(spacing: 16) {
                    Button {
                        withAnimation {
                            if page < 2 {
                                page += 1
                            } else {
                                onFinish()
                            }
                        }
                    } label: {
                        Text(page < 2 ? "Suivant" : "Commencer")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(16)
                            .shadow(color: .orange.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    
                    if page < 2 {
                        Button("Passer") { onFinish() }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("") // Spacer to keep layout consistent
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("")
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onFinish: {})
    }
}


