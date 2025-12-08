import Foundation

@MainActor
class LessonPlanViewModel: ObservableObject {
    @Published var lessonPlan: LessonPlan?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let service = LessonPlanService.shared
    
    // MARK: - Load Lesson Plan
    func loadLessonPlan(sessionId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let plan = try await service.getLessonPlan(sessionId: sessionId)
            lessonPlan = plan
        } catch {
            errorMessage = "Impossible de charger le plan de cours: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Generate Lesson Plan
    func generateLessonPlan(
        sessionId: String,
        level: String? = nil,
        goal: String? = nil
    ) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let plan = try await service.generateLessonPlan(
                sessionId: sessionId,
                level: level,
                goal: goal
            )
            lessonPlan = plan
            successMessage = "Plan de cours généré avec succès"
        } catch {
            errorMessage = "Impossible de générer le plan: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Regenerate Lesson Plan
    func regenerateLessonPlan(
        sessionId: String,
        level: String? = nil,
        goal: String? = nil
    ) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let plan = try await service.regenerateLessonPlan(
                sessionId: sessionId,
                level: level,
                goal: goal
            )
            lessonPlan = plan
            successMessage = "Plan de cours régénéré avec succès"
        } catch {
            errorMessage = "Impossible de régénérer le plan: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Update Progress
    func updateProgress(
        sessionId: String,
        checklistIndex: Int,
        completed: Bool
    ) async {
        do {
            let plan = try await service.updateProgress(
                sessionId: sessionId,
                checklistIndex: checklistIndex,
                completed: completed
            )
            lessonPlan = plan
        } catch {
            errorMessage = "Impossible de mettre à jour la progression: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Clear Messages
    func clearMessage() {
        successMessage = nil
        errorMessage = nil
    }
}

