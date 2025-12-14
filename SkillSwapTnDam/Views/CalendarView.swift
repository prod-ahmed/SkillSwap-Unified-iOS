import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var currentMonth = Date()
    @State private var selectedDate: Date?
    @State private var showCreateDialog = false
    @State private var showGoogleSettings = false
    @State private var showEventDetail = false
    @State private var selectedEventId: String?
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Messages
                    if let error = viewModel.errorMessage {
                        MessageBanner(message: error, type: .error) {
                            viewModel.clearMessages()
                        }
                    }
                    
                    if let success = viewModel.successMessage {
                        MessageBanner(message: success, type: .success) {
                            viewModel.clearMessages()
                        }
                    }
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            // Month Navigation
                            MonthHeaderView(
                                currentMonth: $currentMonth,
                                onPreviousMonth: {
                                    currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                                    loadMonth()
                                },
                                onNextMonth: {
                                    currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                                    loadMonth()
                                }
                            )
                            
                            // Calendar Grid
                            CalendarGridView(
                                currentMonth: currentMonth,
                                events: viewModel.events,
                                selectedDate: $selectedDate
                            )
                            .padding(.horizontal)
                            
                            Divider()
                                .padding(.vertical, 8)
                            
                            // Events List
                            if viewModel.isLoading {
                                ProgressView()
                                    .padding()
                            } else {
                                let displayEvents = getDisplayEvents()
                                
                                if displayEvents.isEmpty {
                                    VStack(spacing: 8) {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 48))
                                            .foregroundColor(.gray)
                                        Text("Aucun événement")
                                            .foregroundColor(.gray)
                                    }
                                    .padding(32)
                                } else {
                                    LazyVStack(spacing: 12) {
                                        ForEach(displayEvents) { event in
                                            EventCardView(event: event) {
                                                selectedEventId = event.id
                                                showEventDetail = true
                                            }
                                        }
                                    }
                                    .padding()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Calendrier")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: { showGoogleSettings = true }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(viewModel.isGoogleConnected ? .green : .white)
                        }
                        
                        Button(action: { showCreateDialog = true }) {
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .toolbarBackground(Color(hex: "FF6B35"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(isPresented: $showCreateDialog) {
            CreateEventSheet(
                viewModel: viewModel,
                isGoogleConnected: viewModel.isGoogleConnected,
                onDismiss: { showCreateDialog = false }
            )
        }
        .sheet(isPresented: $showGoogleSettings) {
            GoogleCalendarSettingsSheet(
                viewModel: viewModel,
                onDismiss: { showGoogleSettings = false }
            )
        }
        .sheet(isPresented: $showEventDetail) {
            if let eventId = selectedEventId {
                EventDetailSheet(
                    eventId: eventId,
                    viewModel: viewModel,
                    onDismiss: { showEventDetail = false }
                )
            }
        }
        .onAppear {
            loadMonth()
            viewModel.checkGoogleCalendarStatus()
        }
    }
    
    private func loadMonth() {
        let components = Calendar.current.dateComponents([.year, .month], from: currentMonth)
        if let year = components.year, let month = components.month {
            viewModel.loadEventsForMonth(year: year, month: month - 1)
        }
    }
    
    private func getDisplayEvents() -> [CalendarEvent] {
        if let date = selectedDate {
            return viewModel.getEventsForDate(date)
        }
        return viewModel.events
    }
}

// MARK: - Message Banner

struct MessageBanner: View {
    let message: String
    let type: MessageType
    let onDismiss: () -> Void
    
    enum MessageType {
        case error, success
        
        var color: Color {
            switch self {
            case .error: return Color(UIColor.systemRed).opacity(0.1)
            case .success: return Color(UIColor.systemGreen).opacity(0.1)
            }
        }
        
        var textColor: Color {
            switch self {
            case .error: return .red
            case .success: return .green
            }
        }
    }
    
    var body: some View {
        HStack {
            Text(message)
                .foregroundColor(type.textColor)
                .font(.subheadline)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(type.textColor)
            }
        }
        .padding()
        .background(type.color)
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - Month Header

struct MonthHeaderView: View {
    @Binding var currentMonth: Date
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onPreviousMonth) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Text(monthYearString)
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            Button(action: onNextMonth) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.primary)
            }
        }
        .padding()
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: currentMonth).capitalized
    }
}

// MARK: - Calendar Grid

struct CalendarGridView: View {
    let currentMonth: Date
    let events: [CalendarEvent]
    @Binding var selectedDate: Date?
    
    private let daysOfWeek = ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"]
    
    var body: some View {
        VStack(spacing: 8) {
            // Days of week
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar days
            let days = generateCalendarDays()
            let weeks = days.chunked(into: 7)
            
            ForEach(weeks.indices, id: \.self) { weekIndex in
                HStack(spacing: 0) {
                    ForEach(weeks[weekIndex].indices, id: \.self) { dayIndex in
                        if let day = weeks[weekIndex][dayIndex] {
                            DayCell(
                                day: day,
                                hasEvents: hasEvents(for: day.date),
                                isSelected: isSelected(day.date),
                                isToday: isToday(day.date),
                                isCurrentMonth: day.isCurrentMonth
                            ) {
                                selectedDate = day.date
                            }
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
    }
    
    private func generateCalendarDays() -> [CalendarDay?] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        
        guard let firstDayOfMonth = calendar.date(from: components) else { return [] }
        guard let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth) else { return [] }
        
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let offsetDays = (firstWeekday + 5) % 7
        
        var days: [CalendarDay?] = Array(repeating: nil, count: offsetDays)
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(CalendarDay(date: date, day: day, isCurrentMonth: true))
            }
        }
        
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    private func hasEvents(for date: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        return events.contains { $0.startTime.hasPrefix(dateStr) }
    }
    
    private func isSelected(_ date: Date) -> Bool {
        guard let selected = selectedDate else { return false }
        return Calendar.current.isDate(date, inSameDayAs: selected)
    }
    
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}

struct CalendarDay {
    let date: Date
    let day: Int
    let isCurrentMonth: Bool
}

struct DayCell: View {
    let day: CalendarDay
    let hasEvents: Bool
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let onClick: () -> Void
    
    var body: some View {
        Button(action: onClick) {
            VStack(spacing: 2) {
                Text("\(day.day)")
                    .font(.subheadline)
                    .foregroundColor(textColor)
                    .fontWeight(isToday || isSelected ? .bold : .regular)
                
                if hasEvents {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 6, height: 6)
                } else {
                    Color.clear
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(backgroundColor)
            .clipShape(Circle())
        }
        .padding(2)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color(hex: "FF6B35")
        } else if isToday {
            return Color(hex: "FF6B35").opacity(0.2)
        }
        return .clear
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if !isCurrentMonth {
            return .gray.opacity(0.5)
        }
        return .primary
    }
    
    private var dotColor: Color {
        isSelected ? .white : Color(hex: "FF6B35")
    }
}

// MARK: - Event Card

struct EventCardView: View {
    let event: CalendarEvent
    let onClick: () -> Void
    
    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color(hex: "FF6B35"))
                    .frame(width: 4)
                    .cornerRadius(2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(timeString)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if let location = event.location {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                            Text(location)
                                .font(.caption)
                        }
                        .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                if event.googleEventId != nil {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        
        if let date = formatter.date(from: event.startTime) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        
        return String(event.startTime.suffix(5))
    }
}

// MARK: - Helper Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
