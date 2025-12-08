import Foundation

@MainActor
class SessionsViewModel: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = SessionService.shared

    func loadSessions() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await service.fetchSessions()
            sessions = result
        } catch {
            errorMessage = "Failed to load sessions: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    func postponeSession(sessionId: String) async {
        do {
            _ = try await service.updateSessionStatus(sessionId: sessionId, status: "reportee")
            await loadSessions()
        } catch {
            errorMessage = "Erreur lors du report de la session: \(error.localizedDescription)"
        }
    }
    
    func proposeReschedule(sessionId: String, newDate: Date, newTime: Date, note: String?) async {
        do {
            let updated = try await service.proposeReschedule(sessionId: sessionId, newDate: newDate, newTime: newTime, note: note)
            replaceSession(updated)
        } catch {
            errorMessage = "Impossible de proposer un nouvel horaire: \(error.localizedDescription)"
        }
    }
    
    func respondToReschedule(sessionId: String, decision: RescheduleDecision) async {
        do {
            let updated = try await service.respondToReschedule(sessionId: sessionId, decision: decision)
            replaceSession(updated)
        } catch {
            errorMessage = "Réponse impossible: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Compatibility methods for EntityDetailViews
    func session(withId id: String) -> Session? {
        sessions.first { $0.id == id }
    }
    
    func updateStatus(for session: Session, to status: SessionStatus) async throws {
        _ = try await service.updateSessionStatus(sessionId: session.id, status: status.rawValue)
        await loadSessions()
    }
    
    func requestReschedule(for session: Session, to date: Date, message: String?) async throws {
        _ = try await service.proposeReschedule(sessionId: session.id, newDate: date, newTime: date, note: message)
        await loadSessions()
    }
    
    private func replaceSession(_ updated: Session) {
        if let index = sessions.firstIndex(where: { $0.id == updated.id }) {
            sessions[index] = updated
        } else {
            sessions.append(updated)
        }
    }
}
