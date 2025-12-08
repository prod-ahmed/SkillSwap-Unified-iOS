import SwiftUI
import MapKit
import CoreLocation

struct SessionsPourVousView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SessionsPourVousViewModel()
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.sessionMode == .inPerson {
                    mapView
                } else {
                    listView
                }
            }
            .navigationTitle("Sessions pour vous")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.white)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.toggleViewMode()
                    } label: {
                        Image(systemName: viewModel.viewMode == .list ? "map" : "list.bullet")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarBackground(Color.orange, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                locationManager.requestLocation()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await viewModel.loadSessions(userLocation: locationManager.location?.coordinate)
            }
            .onAppear {
                updateMapRegion()
            }
            .onChange(of: viewModel.inPersonRecommendations.count) { _ in
                updateMapRegion()
            }
            .onChange(of: viewModel.recommendationCoordinates.count) { _ in
                updateMapRegion()
            }
        }
    }
    
    // MARK: - List View
    private var listView: some View {
        ScrollView {
            VStack(spacing: 20) {
                yellowBanner
                sessionModeToggle
                interestsSection
                
                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 50)
                } else if viewModel.filteredRecommendations.isEmpty {
                    emptyStateView
                } else {
                    ForEach(viewModel.filteredRecommendations) { recommendation in
                        RecommendationCardView(recommendation: recommendation, viewModel: viewModel)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange.opacity(0.5))
            Text("Aucune session disponible")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Revenez plus tard pour découvrir de nouvelles sessions")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 50)
    }
    
    // MARK: - Map View
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.8065, longitude: 10.1815),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    private var mapView: some View {
        ZStack {
            Map(coordinateRegion: $mapRegion, annotationItems: mapAnnotations) { annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
                    Button {
                        viewModel.selectRecommendation(annotation.recommendation)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(Color.green, lineWidth: 2)
                                )
                            
                            Circle()
                                .fill(Color.orange.opacity(0.2))
                                .frame(width: 40, height: 40)
                            
                            Text(annotation.initial)
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    sessionModeToggle
                        .padding(.horizontal)
                    
                    if viewModel.sessionMode == .inPerson {
                        HStack(spacing: 12) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.orange)
                                Text("Tunis, Tunisie")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(8)
                            
                            Text("\(viewModel.inPersonRecommendations.count) session(s) à proximité")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
                .background(Color.white.opacity(0.9))
                
                Spacer()
                
                if let selectedRecommendation = viewModel.selectedRecommendation {
                    RecommendationDetailCard(recommendation: selectedRecommendation, viewModel: viewModel)
                        .padding()
                }
            }
        }
    }
    
    // MARK: - Components
    private var yellowBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sessions pour vous")
                    .font(.headline)
                    .foregroundColor(.black)
                Text("Recommandations: \(viewModel.filteredRecommendations.count)")
                    .font(.subheadline)
                    .foregroundColor(.black.opacity(0.6))
                Text("\(viewModel.filteredRecommendations.count) session(s) disponible(s)")
                    .font(.subheadline)
                    .foregroundColor(.black.opacity(0.6))
            }
            Spacer()
            Image(systemName: "hand.thumbsup.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)
        }
        .padding()
        .background(Color(hex: "FFD54F"))
        .cornerRadius(12)
    }
    
    private var sessionModeToggle: some View {
        HStack(spacing: 0) {
            Button {
                viewModel.setSessionMode(.online, userLocation: locationManager.location?.coordinate)
            } label: {
                HStack {
                    Image(systemName: "video.fill")
                    Text("En ligne")
                }
                .font(.subheadline)
                .foregroundColor(viewModel.sessionMode == .online ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.sessionMode == .online ? Color.orange : Color.white)
            }
            
            Button {
                viewModel.setSessionMode(.inPerson, userLocation: locationManager.location?.coordinate)
            } label: {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                    Text("En personne")
                }
                .font(.subheadline)
                .foregroundColor(viewModel.sessionMode == .inPerson ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.sessionMode == .inPerson ? Color.orange : Color.white)
            }
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Basées sur vos intérêts")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if let currentUser = AuthenticationManager.shared.currentUser {
                        ForEach(currentUser.skillsLearn ?? [], id: \.self) { skill in
                            InterestChip(text: skill, color: .orange)
                        }
                    }
                }
            }
        }
    }
    
    private var region: MKCoordinateRegion {
        if let firstRecommendation = viewModel.inPersonRecommendations.first,
           let coordinate = viewModel.recommendationCoordinates[firstRecommendation.id] {
            return MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        } else if let location = locationManager.location {
            return MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        } else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.8065, longitude: 10.1815),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
    }
    
    private var mapAnnotations: [RecommendationAnnotation] {
        viewModel.inPersonRecommendations.compactMap { recommendation in
            guard let coordinate = viewModel.recommendationCoordinates[recommendation.id] else {
                return nil
            }
            return RecommendationAnnotation(
                id: recommendation.id,
                coordinate: coordinate,
                recommendation: recommendation,
                initial: recommendation.initials
            )
        }
    }
    
    private func updateMapRegion() {
        mapRegion = region
    }
}

// MARK: - Recommendation Card View
struct RecommendationCardView: View {
    let recommendation: Recommendation
    let viewModel: SessionsPourVousViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(recommendation.initials)
                            .font(.title2)
                            .foregroundColor(.orange)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(recommendation.mentorName)\(recommendation.age > 0 ? ", \(recommendation.age)" : "")")
                        .font(.headline)
                    
                    HStack {
                        ForEach(recommendation.skills.prefix(2), id: \.self) { skill in
                            Text(skill.trimmingCharacters(in: .whitespacesAndNewlines))
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            Text(recommendation.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack(spacing: 16) {
                Label(recommendation.distance, systemImage: "location.fill")
                    .font(.caption)
                Label(String(format: "%.1f/5", recommendation.rating), systemImage: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
                Text(recommendation.lastActive)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(recommendation.sessionsCount) sessions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "clock")
                Text(recommendation.availability)
            }
            .font(.subheadline)
            .foregroundColor(.green)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
            
            HStack(spacing: 12) {
                Button(action: {}) {
                    Text("Voir profil")
                        .font(.headline)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.orange, lineWidth: 1)
                        )
                }
                
                Button(action: {}) {
                    Text("Réserver")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(25)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Recommendation Detail Card
struct RecommendationDetailCard: View {
    let recommendation: Recommendation
    let viewModel: SessionsPourVousViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(recommendation.initials)
                            .font(.title2)
                            .foregroundColor(.orange)
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(recommendation.mentorName)
                        .font(.headline)
                    
                    if !recommendation.distance.isEmpty {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(recommendation.distance)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Button {
                    viewModel.clearSelection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
            }
            
            HStack {
                Text("Online")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .cornerRadius(4)
            }
            
            HStack {
                ForEach(recommendation.skills.prefix(1), id: \.self) { skill in
                    Text(skill.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
            }
            
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.green)
                Text(recommendation.availability)
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            
            HStack(spacing: 12) {
                Button(action: {}) {
                    Text("Voir profil")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange, lineWidth: 1)
                        )
                }
                
                Button(action: {}) {
                    Text("Réserver")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(12)
                }
            }
            
            Button {
                viewModel.clearSelection()
            } label: {
                Text("Fermer")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Supporting Views
struct InterestChip: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color)
            .cornerRadius(20)
    }
}

// MARK: - Map Annotation
struct RecommendationAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let recommendation: Recommendation
    let initial: String
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
    }
}

// MARK: - Preview
struct SessionsPourVousView_Previews: PreviewProvider {
    static var previews: some View {
        SessionsPourVousView()
    }
}
