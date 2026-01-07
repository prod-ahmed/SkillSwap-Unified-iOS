import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case promos
    case annonces
    case discover // Profiles
    case progress
    case sessions
    // case map // Ignored for now

    var id: String { rawValue }

    var title: String {
        switch self {
        case .promos: return LocalizationManager.shared.localized(.promos)
        case .annonces: return LocalizationManager.shared.localized(.announcements)
        case .discover: return LocalizationManager.shared.localized(.profiles)
        case .progress: return LocalizationManager.shared.localized(.tabProgress)
        case .sessions: return LocalizationManager.shared.localized(.tabSessions)
        }
    }

    var systemImage: String {
        switch self {
        case .promos: return "tag.fill"
        case .annonces: return "megaphone.fill"
        case .discover: return "person.2.fill" // Or house.fill
        case .progress: return "chart.bar.fill"
        case .sessions: return "calendar"
        }
    }

    var accentColor: Color {
        switch self {
        case .promos: return .pink
        case .annonces: return .green
        case .discover: return .orange
        case .progress: return Color(red: 0.95, green: 0.56, blue: 0.14)
        case .sessions: return Color(red: 0.07, green: 0.58, blue: 0.49)
        }
    }
}

struct AppTabBar: View {
    @Binding var selected: AppTab

    var body: some View {
        HStack(spacing: 0) {
            // Left Group
            tabButton(for: .promos)
            Spacer()
            tabButton(for: .annonces)
            
            Spacer()
            
            // Center Button (Profiles)
            Button(action: { selected = .discover }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#FF6B35"), Color(hex: "#FFB347")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .shadow(color: Color(hex: "#FF6B35").opacity(0.4), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: "person.2.fill") // Profiles icon
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .offset(y: -24)
            .buttonStyle(.plain)
            
            Spacer()
            
            // Right Group
            tabButton(for: .progress)
            Spacer()
            tabButton(for: .sessions)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 34) // Safe area
        .background(
            Color.white
                .clipShape(CustomTabBarShape())
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
        )
        .ignoresSafeArea()
    }
    
    private func tabButton(for tab: AppTab) -> some View {
        Button(action: { selected = tab }) {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 20, weight: .medium))
                Text(tab.title)
                    .font(.caption2.weight(.medium))
            }
            .foregroundColor(selected == tab ? tab.accentColor : .gray)
            .frame(width: 60)
        }
        .buttonStyle(.plain)
        .tourTarget(id: tourTargetId(for: tab))
    }
    
    private func tourTargetId(for tab: AppTab) -> String {
        switch tab {
        case .promos: return "tab_promos"
        case .annonces: return "tab_annonces"
        case .sessions: return "tab_sessions"
        case .progress: return "tab_progress"
        case .discover: return "tab_discover"
        }
    }
}

struct CustomTabBarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath()
        let center = rect.width / 2
        
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: center - 50, y: 0))
        
        path.addCurve(
            to: CGPoint(x: center, y: -20),
            controlPoint1: CGPoint(x: center - 30, y: 0),
            controlPoint2: CGPoint(x: center - 30, y: -20)
        )
        
        path.addCurve(
            to: CGPoint(x: center + 50, y: 0),
            controlPoint1: CGPoint(x: center + 30, y: -20),
            controlPoint2: CGPoint(x: center + 30, y: 0)
        )
        
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.close()
        
        return Path(path.cgPath)
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
