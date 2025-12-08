import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case discover
    case chat
    case sessions
    case progress
    case map

    var id: String { rawValue }

    var title: String {
        switch self {
        case .discover: return LocalizationManager.shared.localized(.tabDiscover)
        case .chat: return LocalizationManager.shared.localized(.tabMessages)
        case .sessions: return LocalizationManager.shared.localized(.tabSessions)
        case .progress: return LocalizationManager.shared.localized(.tabProgress)
        case .map: return LocalizationManager.shared.localized(.tabMap)
        }
    }

    var systemImage: String {
        switch self {
        case .discover: return "house.fill"
        case .chat: return "bubble.left.and.text.bubble.right.fill"
        case .sessions: return "calendar"
        case .progress: return "chart.bar.fill"
        case .map: return "map.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .discover: return .orange
        case .chat: return Color(red: 0.98, green: 0.35, blue: 0.25)
        case .sessions: return Color(red: 0.07, green: 0.58, blue: 0.49)
        case .progress: return Color(red: 0.95, green: 0.56, blue: 0.14)
        case .map: return Color(red: 0.36, green: 0.32, blue: 0.75)
        }
    }
}

struct AppTabBar: View {
    @Binding var selected: AppTab

    var body: some View {
        HStack(spacing: 12) {
            ForEach(AppTab.allCases) { tab in
                Button(action: { selected = tab }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.title)
                            .font(.caption2.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(selected == tab ? tab.accentColor : .secondary)
                    .background(
                        Group {
                            if selected == tab {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(tab.accentColor.opacity(0.12))
                            } else {
                                Color.clear
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 22)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 6)
        )
        .padding(.horizontal)
        .padding(.bottom)
    }
}

struct AppTabBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            AppTabBar(selected: .constant(.discover))
        }
        .background(Color(.systemGroupedBackground))
    }
}
