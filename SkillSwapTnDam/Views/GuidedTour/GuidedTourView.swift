import SwiftUI

/// Main coordinator view that displays the guided tour overlay
struct GuidedTourView: View {
    @StateObject private var tourManager = GuidedTourManager.shared
    let anchors: [String: CGRect]
    
    var body: some View {
        if tourManager.isShowingTour, let step = tourManager.currentStep {
            let targetRect = anchors[step.targetId] ?? .zero
            
            CoachMarkOverlay(
                step: step,
                targetRect: targetRect,
                onNext: { tourManager.nextStep() },
                onSkip: { tourManager.skipTour() },
                isLastStep: tourManager.isLastStep,
                progress: tourManager.progress
            )
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .id(step.id) // Force view recreation for each step
        }
    }
}

/// View modifier to add guided tour capability to any view
struct GuidedTourModifier: ViewModifier {
    @StateObject private var tourManager = GuidedTourManager.shared
    @State private var anchors: [String: CGRect] = [:]
    
    func body(content: Content) -> some View {
        content
            .onPreferenceChange(TourAnchorPreferenceKey.self) { prefs in
                // Convert anchor preferences to actual CGRects
                // This happens via GeometryReader in the overlay
            }
            .overlayPreferenceValue(TourAnchorPreferenceKey.self) { preferences in
                GeometryReader { geometry in
                    // Convert anchors to CGRects
                    let rects = preferences.mapValues { anchor in
                        geometry[anchor]
                    }
                    
                    // Show tour overlay
                    GuidedTourView(anchors: rects)
                }
            }
    }
}

extension View {
    /// Add guided tour overlay capability to this view hierarchy
    func withGuidedTour() -> some View {
        modifier(GuidedTourModifier())
    }
}

#Preview {
    ZStack {
        VStack {
            HStack {
                Spacer()
                Circle()
                    .fill(Color.blue)
                    .frame(width: 40, height: 40)
                    .tourTarget(id: "notifications_button")
            }
            .padding()
            
            Spacer()
            
            HStack(spacing: 40) {
                VStack {
                    Image(systemName: "tag.fill")
                    Text("Promos")
                }
                .tourTarget(id: "tab_promos")
                
                VStack {
                    Image(systemName: "megaphone.fill")
                    Text("Annonces")
                }
                .tourTarget(id: "tab_annonces")
                
                VStack {
                    Image(systemName: "calendar")
                    Text("Sessions")
                }
                .tourTarget(id: "tab_sessions")
            }
            .padding(.bottom, 50)
        }
    }
    .withGuidedTour()
    .onAppear {
        GuidedTourManager.shared.resetTour()
        GuidedTourManager.shared.startTour()
    }
}
