import Foundation
import SwiftUI

@MainActor
final class ProgressDashboardViewModel: ObservableObject {
    @Published var dashboard: ProgressDashboardResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isPresentingGoalForm = false
    @Published var newGoalTitle: String = ""
    @Published var newGoalHours: Double = 4
    @Published var newGoalPeriod: String = "week"
    @Published var editingGoal: ProgressGoalItem?
    @Published var deletingGoalId: String?

    private let service = ProgressService()

    func load() async {
        guard let token = AuthenticationManager.shared.accessToken else { return }
        isLoading = true
        errorMessage = nil
        do {
            dashboard = try await service.fetchDashboard(accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func presentGoalForm() {
        newGoalTitle = ""
        newGoalHours = 4
        newGoalPeriod = "week"
        editingGoal = nil
        isPresentingGoalForm = true
    }

    func startEditing(goal: ProgressGoalItem) {
        newGoalTitle = goal.title
        newGoalHours = goal.targetHours
        newGoalPeriod = goal.period
        editingGoal = goal
        isPresentingGoalForm = true
    }

    func dismissGoalForm() {
        editingGoal = nil
        isPresentingGoalForm = false
    }

    func createGoal() async {
        guard let token = AuthenticationManager.shared.accessToken else { return }
        do {
            let goal = try await service.createGoal(accessToken: token, title: newGoalTitle, targetHours: newGoalHours, period: newGoalPeriod)
            isPresentingGoalForm = false
            editingGoal = nil
            if var snapshot = dashboard {
                var goals = snapshot.goals.filter { $0.id != goal.id }
                goals.insert(goal, at: 0)
                snapshot.goals = goals
                dashboard = snapshot
            } else {
                await load()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitGoalForm() async {
        if editingGoal != nil {
            await updateGoal()
        } else {
            await createGoal()
        }
    }

    private func updateGoal() async {
        guard let target = editingGoal, let token = AuthenticationManager.shared.accessToken else { return }
        do {
            let updated = try await service.updateGoal(accessToken: token, goalId: target.id, title: newGoalTitle, targetHours: newGoalHours, period: newGoalPeriod)
            isPresentingGoalForm = false
            editingGoal = nil
            if var snapshot = dashboard {
                snapshot.goals = snapshot.goals.map { $0.id == updated.id ? updated : $0 }
                dashboard = snapshot
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteGoal(_ goal: ProgressGoalItem) async {
        guard let token = AuthenticationManager.shared.accessToken else { return }
        deletingGoalId = goal.id
        defer { deletingGoalId = nil }
        do {
            try await service.deleteGoal(accessToken: token, goalId: goal.id)
            if var snapshot = dashboard {
                snapshot.goals.removeAll { $0.id == goal.id }
                dashboard = snapshot
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
