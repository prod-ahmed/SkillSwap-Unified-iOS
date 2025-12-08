import SwiftUI

struct AppTextField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.systemGray6))
            )
    }
}

extension View {
    func appField() -> some View { self.modifier(AppTextField()) }
}


