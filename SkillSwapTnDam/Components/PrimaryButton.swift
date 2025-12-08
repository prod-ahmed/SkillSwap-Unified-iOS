import SwiftUI

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var gradient: LinearGradient = LinearGradient(
        colors: [Color.orange, Color(red: 1.0, green: 0.55, blue: 0.2)],
        startPoint: .leading,
        endPoint: .trailing
    )
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(gradient)
            )
            .shadow(color: .orange.opacity(0.25), radius: 8, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

struct PrimaryButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            PrimaryButton(title: "Suivant", action: {})
            PrimaryButton(title: "Continuer", systemImage: "chevron.right", action: {})
        }
        .padding()
    }
}


