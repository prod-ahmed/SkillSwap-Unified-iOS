import Foundation
import Combine

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var events: [CalendarEvent] = []
    @Published var selectedEvent: CalendarEvent?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    @Published var isGoogleConnected = false
    @Published var syncInProgress = false
    
    private let service = CalendarService.shared
    
    // MARK: - Event CRUD
    
    func loadEvents(startDate: String? = nil, endDate: String? = nil) {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                events = try await service.getEvents(startDate: startDate, endDate: endDate)
            } catch {
                errorMessage = "Erreur de chargement: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    func loadEventsForMonth(year: Int, month: Int) {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month + 1
        components.day = 1
        
        guard let firstDay = calendar.date(from: components) else { return }
        guard let lastDay = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: firstDay) else { return }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let startDate = formatter.string(from: firstDay)
        let endDate = formatter.string(from: lastDay)
        
        loadEvents(startDate: startDate, endDate: endDate)
    }
    
    func loadEventDetail(id: String) {
        Task {
            isLoading = true
            
            do {
                selectedEvent = try await service.getEvent(id: id)
            } catch {
                errorMessage = "Erreur: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    func createEvent(
        title: String,
        description: String?,
        startTime: String,
        endTime: String,
        location: String?,
        participants: [String]?,
        sessionId: String? = nil,
        reminder: Int = 15,
        isAllDay: Bool = false,
        syncToGoogle: Bool = false,
        onSuccess: @escaping () -> Void = {}
    ) {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let request = CreateEventRequest(
                    title: title,
                    description: description,
                    startTime: startTime,
                    endTime: endTime,
                    location: location,
                    participants: participants,
                    sessionId: sessionId,
                    reminder: reminder,
                    isAllDay: isAllDay,
                    syncToGoogle: syncToGoogle
                )
                
                let created = try await service.createEvent(request: request)
                events.append(created)
                successMessage = "Événement créé"
                onSuccess()
            } catch {
                errorMessage = "Création échouée: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    func updateEvent(
        id: String,
        title: String? = nil,
        description: String? = nil,
        startTime: String? = nil,
        endTime: String? = nil,
        location: String? = nil,
        status: String? = nil,
        onSuccess: @escaping () -> Void = {}
    ) {
        Task {
            isLoading = true
            
            do {
                let request = UpdateEventRequest(
                    title: title,
                    description: description,
                    startTime: startTime,
                    endTime: endTime,
                    location: location,
                    status: status
                )
                
                let updated = try await service.updateEvent(id: id, request: request)
                
                if let index = events.firstIndex(where: { $0.id == id }) {
                    events[index] = updated
                }
                selectedEvent = updated
                successMessage = "Événement mis à jour"
                onSuccess()
            } catch {
                errorMessage = "Mise à jour échouée: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    func deleteEvent(id: String, onSuccess: @escaping () -> Void = {}) {
        Task {
            isLoading = true
            
            do {
                try await service.deleteEvent(id: id)
                events.removeAll { $0.id == id }
                successMessage = "Événement supprimé"
                onSuccess()
            } catch {
                errorMessage = "Suppression échouée: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    // MARK: - Participants
    
    func addParticipant(eventId: String, userId: String) {
        Task {
            do {
                let updated = try await service.addParticipant(eventId: eventId, userId: userId)
                
                if let index = events.firstIndex(where: { $0.id == eventId }) {
                    events[index] = updated
                }
                selectedEvent = updated
                successMessage = "Participant ajouté"
            } catch {
                errorMessage = "Erreur: \(error.localizedDescription)"
            }
        }
    }
    
    func removeParticipant(eventId: String, userId: String) {
        Task {
            do {
                let updated = try await service.removeParticipant(eventId: eventId, userId: userId)
                
                if let index = events.firstIndex(where: { $0.id == eventId }) {
                    events[index] = updated
                }
                selectedEvent = updated
                successMessage = "Participant retiré"
            } catch {
                errorMessage = "Erreur: \(error.localizedDescription)"
            }
        }
    }
    
    func respondToInvite(eventId: String, response: String) {
        Task {
            do {
                let updated = try await service.respondToInvite(eventId: eventId, response: response)
                
                if let index = events.firstIndex(where: { $0.id == eventId }) {
                    events[index] = updated
                }
                
                successMessage = response == "accepted" ? "Invitation acceptée" : "Invitation refusée"
            } catch {
                errorMessage = "Erreur: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Google Calendar
    
    func checkGoogleCalendarStatus() {
        Task {
            do {
                isGoogleConnected = try await service.checkGoogleCalendarStatus()
            } catch {
                isGoogleConnected = false
            }
        }
    }
    
    func getGoogleAuthUrl(completion: @escaping (String) -> Void) {
        Task {
            do {
                let url = try await service.getGoogleAuthUrl()
                completion(url)
            } catch {
                errorMessage = "Erreur: \(error.localizedDescription)"
            }
        }
    }
    
    func handleGoogleCallback(code: String, redirectUri: String? = nil, onSuccess: @escaping () -> Void = {}) {
        Task {
            isLoading = true
            
            do {
                try await service.handleGoogleCallback(code: code, redirectUri: redirectUri)
                isGoogleConnected = true
                successMessage = "Google Calendar connecté"
                onSuccess()
            } catch {
                errorMessage = "Connexion échouée: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    func syncWithGoogle(bidirectional: Bool = true) {
        Task {
            syncInProgress = true
            
            do {
                let synced = try await service.syncWithGoogle(bidirectional: bidirectional)
                successMessage = "Synchronisé: \(synced) événements"
                loadEvents()
            } catch {
                errorMessage = "Sync échouée: \(error.localizedDescription)"
            }
            
            syncInProgress = false
        }
    }
    
    func disconnectGoogleCalendar() {
        Task {
            do {
                try await service.disconnectGoogleCalendar()
                isGoogleConnected = false
                successMessage = "Google Calendar déconnecté"
            } catch {
                errorMessage = "Erreur: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Helpers
    
    func getEventsForDate(_ date: Date) -> [CalendarEvent] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        
        return events.filter { $0.startTime.hasPrefix(dateStr) }
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
    
    func clearSelectedEvent() {
        selectedEvent = nil
    }
}
