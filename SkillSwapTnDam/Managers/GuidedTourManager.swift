import SwiftUI

/// Manages the guided tour state and persistence
@MainActor
final class GuidedTourManager: ObservableObject {
    static let shared = GuidedTourManager()
    
    @AppStorage("hasCompletedGuidedTour") private var hasCompletedTour: Bool = false
    @Published var isShowingTour: Bool = false
    @Published var currentStepIndex: Int = 0
    
    private init() {}
    
    var currentStep: TourStep? {
        guard currentStepIndex < TourStep.allSteps.count else { return nil }
        return TourStep.allSteps[currentStepIndex]
    }
    
    var isLastStep: Bool {
        currentStepIndex == TourStep.allSteps.count - 1
    }
    
    var progress: Double {
        Double(currentStepIndex + 1) / Double(TourStep.allSteps.count)
    }
    
    var shouldShowTour: Bool {
        !hasCompletedTour
    }
    
    func startTour() {
        guard shouldShowTour else { return }
        currentStepIndex = 0
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isShowingTour = true
        }
    }
    
    func nextStep() {
        if currentStepIndex < TourStep.allSteps.count - 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                currentStepIndex += 1
            }
        } else {
            completeTour()
        }
    }
    
    func previousStep() {
        if currentStepIndex > 0 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                currentStepIndex -= 1
            }
        }
    }
    
    func skipTour() {
        completeTour()
    }
    
    func completeTour() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isShowingTour = false
        }
        // Small delay before marking as complete to allow animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.hasCompletedTour = true
        }
    }
    
    /// Reset tour for testing purposes
    func resetTour() {
        hasCompletedTour = false
        currentStepIndex = 0
    }
}
