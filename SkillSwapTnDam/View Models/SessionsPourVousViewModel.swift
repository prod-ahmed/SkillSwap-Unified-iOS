import Foundation
import CoreLocation
import MapKit

@MainActor
class SessionsPourVousViewModel: ObservableObject {
    @Published var recommendations: [Recommendation] = []
    @Published var recommendationCoordinates: [String: CLLocationCoordinate2D] = [:]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedRecommendation: Recommendation?
    @Published var viewMode: ViewMode = .list
    @Published var sessionMode: SessionMode = .online
    @Published var currentLocation: CLLocationCoordinate2D?
    
    private let service = SessionService.shared
    private let geocoder = CLGeocoder()
    
    enum ViewMode {
        case list
        case map
    }
    
    enum SessionMode: String {
        case online = "online"
        case inPerson = "in-person"
    }
    
    var filteredRecommendations: [Recommendation] {
        return recommendations
    }
    
    var inPersonRecommendations: [Recommendation] {
        filteredRecommendations.filter { !$0.distance.isEmpty && $0.distance != "0 km" }
    }
    
    func loadSessions(userLocation: CLLocationCoordinate2D? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let recommendations = try await service.fetchRecommendations()
            print("✅ Loaded \(recommendations.count) recommendations")
            self.recommendations = recommendations
            
            await geocodeRecommendations(recommendations, userLocation: userLocation)
        } catch {
            print("❌ Error loading recommendations: \(error.localizedDescription)")
            errorMessage = "Impossible de charger les recommandations: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func geocodeRecommendations(_ recommendations: [Recommendation], userLocation: CLLocationCoordinate2D?) async {
        let baseCoordinate = userLocation ?? CLLocationCoordinate2D(latitude: 36.8065, longitude: 10.1815)
        
        for (index, recommendation) in recommendations.enumerated() {
            var foundCoordinate: CLLocationCoordinate2D?
            
            if let userLoc = userLocation {
                if let distanceKm = parseDistance(recommendation.distance) {
                    let angle = Double(index) * (2.0 * .pi / Double(max(recommendations.count, 1)))
                    foundCoordinate = coordinateAtDistance(from: userLoc, distanceKm: distanceKm, bearing: angle)
                }
            }
            
            if foundCoordinate == nil {
                var searchQueries: [String] = []
                
                if recommendation.description.contains("Esprit") {
                    searchQueries.append("Esprit, Zone Industrielle Chotrana II, Tunis")
                }
                if recommendation.description.contains("Zone Industrielle") {
                    searchQueries.append("Zone Industrielle Chotrana, Tunis")
                }
                searchQueries.append("\(recommendation.mentorName), Tunis, Tunisie")
                
                for searchQuery in searchQueries {
                    let request = MKLocalSearch.Request()
                    request.naturalLanguageQuery = searchQuery
                    request.region = MKCoordinateRegion(
                        center: baseCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
                    )
                    
                    let search = MKLocalSearch(request: request)
                    do {
                        let response = try await search.start()
                        if let firstItem = response.mapItems.first {
                            foundCoordinate = firstItem.placemark.coordinate
                            break
                        }
                    } catch {
                        continue
                    }
                }
            }
            
            if foundCoordinate == nil {
                let offsetLat = Double(index) * 0.015
                let offsetLon = Double(index) * 0.015
                foundCoordinate = CLLocationCoordinate2D(
                    latitude: baseCoordinate.latitude + offsetLat,
                    longitude: baseCoordinate.longitude + offsetLon
                )
            }
            
            recommendationCoordinates[recommendation.id] = foundCoordinate ?? baseCoordinate
        }
    }
    
    private func parseDistance(_ distanceString: String) -> Double? {
        let cleaned = distanceString.replacingOccurrences(of: " km", with: "")
            .replacingOccurrences(of: "km", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }
    
    private func coordinateAtDistance(from start: CLLocationCoordinate2D, distanceKm: Double, bearing: Double) -> CLLocationCoordinate2D {
        let earthRadiusKm: Double = 6371.0
        let lat1 = start.latitude * .pi / 180.0
        let lon1 = start.longitude * .pi / 180.0
        let bearingRad = bearing
        
        let lat2 = asin(sin(lat1) * cos(distanceKm / earthRadiusKm) +
                        cos(lat1) * sin(distanceKm / earthRadiusKm) * cos(bearingRad))
        let lon2 = lon1 + atan2(sin(bearingRad) * sin(distanceKm / earthRadiusKm) * cos(lat1),
                                cos(distanceKm / earthRadiusKm) - sin(lat1) * sin(lat2))
        
        return CLLocationCoordinate2D(
            latitude: lat2 * 180.0 / .pi,
            longitude: lon2 * 180.0 / .pi
        )
    }
    
    func toggleViewMode() {
        viewMode = viewMode == .list ? .map : .list
    }
    
    func setSessionMode(_ mode: SessionMode, userLocation: CLLocationCoordinate2D? = nil) {
        sessionMode = mode
        if mode == .inPerson {
            viewMode = .map
        } else {
            viewMode = .list
        }
        Task {
            await loadSessions(userLocation: userLocation)
        }
    }
    
    func selectRecommendation(_ recommendation: Recommendation) {
        selectedRecommendation = recommendation
    }
    
    func clearSelection() {
        selectedRecommendation = nil
    }
}
