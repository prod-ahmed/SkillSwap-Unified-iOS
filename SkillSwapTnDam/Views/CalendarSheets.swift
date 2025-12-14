import SwiftUI

struct CreateEventSheet: View {
    @ObservedObject var viewModel: CalendarViewModel
    let isGoogleConnected: Bool
    let onDismiss: () -> Void
    
    @State private var title = ""
    @State private var description = ""
    @State private var startTime = ""
    @State private var endTime = ""
    @State private var location = ""
    @State private var syncToGoogle = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Informations")) {
                    TextField("Titre *", text: $title)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    TextField("Début (YYYY-MM-DD HH:mm) *", text: $startTime)
                        .keyboardType(.numbersAndPunctuation)
                    
                    TextField("Fin (YYYY-MM-DD HH:mm) *", text: $endTime)
                        .keyboardType(.numbersAndPunctuation)
                    
                    TextField("Lieu", text: $location)
                }
                
                if isGoogleConnected {
                    Section {
                        Toggle("Synchroniser avec Google", isOn: $syncToGoogle)
                    }
                }
            }
            .navigationTitle("Nouvel événement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Créer") {
                        createEvent()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !title.isEmpty && !startTime.isEmpty && !endTime.isEmpty
    }
    
    private func createEvent() {
        viewModel.createEvent(
            title: title,
            description: description.isEmpty ? nil : description,
            startTime: startTime,
            endTime: endTime,
            location: location.isEmpty ? nil : location,
            participants: nil,
            syncToGoogle: syncToGoogle
        ) {
            onDismiss()
        }
    }
}

struct EventDetailSheet: View {
    let eventId: String
    @ObservedObject var viewModel: CalendarViewModel
    let onDismiss: () -> Void
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            if let event = viewModel.selectedEvent {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text(event.title)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            if let desc = event.description {
                                Text(desc)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Divider()
                        
                        // Time
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(Color(hex: "FF6B35"))
                                Text("Horaire")
                                    .fontWeight(.semibold)
                            }
                            
                            Text("\(formatDateTime(event.startTime)) - \(formatDateTime(event.endTime))")
                                .foregroundColor(.gray)
                        }
                        
                        // Location
                        if let location = event.location {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(Color(hex: "FF6B35"))
                                    Text("Lieu")
                                        .fontWeight(.semibold)
                                }
                                
                                Text(location)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Google sync status
                        if event.googleEventId != nil {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.green)
                                Text("Synchronisé avec Google")
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
                .navigationTitle("Détails")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Fermer") {
                            onDismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showDeleteConfirmation = true }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
                .alert("Supprimer l'événement?", isPresented: $showDeleteConfirmation) {
                    Button("Annuler", role: .cancel) { }
                    Button("Supprimer", role: .destructive) {
                        viewModel.deleteEvent(id: eventId) {
                            onDismiss()
                        }
                    }
                }
            } else {
                ProgressView()
                    .onAppear {
                        viewModel.loadEventDetail(id: eventId)
                    }
            }
        }
    }
    
    private func formatDateTime(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        
        if let date = formatter.date(from: dateStr) {
            formatter.dateFormat = "d MMM yyyy, HH:mm"
            formatter.locale = Locale(identifier: "fr_FR")
            return formatter.string(from: date)
        }
        
        return dateStr
    }
}

struct GoogleCalendarSettingsSheet: View {
    @ObservedObject var viewModel: CalendarViewModel
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(viewModel.isGoogleConnected ? .green : .gray)
                        Text(viewModel.isGoogleConnected ? "Connecté" : "Non connecté")
                            .foregroundColor(viewModel.isGoogleConnected ? .green : .gray)
                    }
                    
                    if viewModel.isGoogleConnected {
                        Text("Vos événements sont synchronisés.")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        if viewModel.syncInProgress {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Synchronisation...")
                                    .font(.caption)
                            }
                        }
                    } else {
                        Text("Connectez Google pour synchroniser.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Section {
                    if viewModel.isGoogleConnected {
                        Button(action: {
                            viewModel.syncWithGoogle()
                        }) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Synchroniser maintenant")
                            }
                        }
                        .disabled(viewModel.syncInProgress)
                        
                        Button(action: {
                            viewModel.disconnectGoogleCalendar()
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Déconnecter")
                            }
                            .foregroundColor(.red)
                        }
                    } else {
                        Button(action: {
                            viewModel.getGoogleAuthUrl { url in
                                if let authUrl = URL(string: url) {
                                    UIApplication.shared.open(authUrl)
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "link")
                                Text("Connecter Google Calendar")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Google Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        onDismiss()
                    }
                }
            }
        }
    }
}
