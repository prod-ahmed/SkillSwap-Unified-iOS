import SwiftUI

/// Defines a single step in the guided tour
struct TourStep: Identifiable, Equatable {
    let id: Int
    let targetId: String
    let title: String
    let description: String
    let icon: String
    let accentColor: Color
    
    static func == (lhs: TourStep, rhs: TourStep) -> Bool {
        lhs.id == rhs.id
    }
}

/// All tour steps for the app
extension TourStep {
    static let allSteps: [TourStep] = [
        TourStep(
            id: 0,
            targetId: "tab_annonces",
            title: "Annonces",
            description: "Découvrez les opportunités d'apprentissage publiées par la communauté",
            icon: "megaphone.fill",
            accentColor: .green
        ),
        TourStep(
            id: 1,
            targetId: "tab_promos",
            title: "Promotions",
            description: "Trouvez des offres exclusives et des réductions sur les sessions",
            icon: "tag.fill",
            accentColor: .pink
        ),
        TourStep(
            id: 2,
            targetId: "tab_sessions",
            title: "Sessions",
            description: "Planifiez et gérez vos sessions d'apprentissage",
            icon: "calendar",
            accentColor: Color(red: 0.07, green: 0.58, blue: 0.49)
        ),
        TourStep(
            id: 3,
            targetId: "notifications_button",
            title: "Notifications",
            description: "Restez informé des messages et rappels de session",
            icon: "bell.fill",
            accentColor: .orange
        )
    ]
}

/// Preference key to collect anchor positions from views
struct TourAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

/// View modifier to mark a view as a tour target
struct TourTargetModifier: ViewModifier {
    let id: String
    
    func body(content: Content) -> some View {
        content
            .anchorPreference(key: TourAnchorPreferenceKey.self, value: .bounds) { anchor in
                [id: anchor]
            }
    }
}

extension View {
    /// Mark this view as a target for the guided tour
    func tourTarget(id: String) -> some View {
        modifier(TourTargetModifier(id: id))
    }
}
