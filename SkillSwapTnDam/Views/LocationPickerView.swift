import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var address: String
    @Binding var coordinate: CLLocationCoordinate2D?
    
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedResult: MKMapItem?
    @State private var isSearching: Bool = false
    @State private var searchError: String?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.8065, longitude: 10.1815),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var selectedPin: IdentifiableCoordinate?
    @StateObject private var locationFetcher = LocationFetcher()
    
    private var hasSelection: Bool {
        selectedPin != nil
    }
    
    private var selectedAddress: String {
        guard let selectedResult = selectedResult else { return "" }
        let placemark = selectedResult.placemark
        var addressComponents: [String] = []
        
        if let name = placemark.name {
            addressComponents.append(name)
        }
        if let thoroughfare = placemark.thoroughfare {
            addressComponents.append(thoroughfare)
        }
        if let subThoroughfare = placemark.subThoroughfare {
            addressComponents.append(subThoroughfare)
        }
        if let locality = placemark.locality {
            addressComponents.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            addressComponents.append(administrativeArea)
        }
        if let country = placemark.country {
            addressComponents.append(country)
        }
        
        return addressComponents.joined(separator: ", ")
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerText
                    searchField
                    
                    if !searchResults.isEmpty {
                        searchResultsList
                    }
                    
                    if let selectedResult = selectedResult {
                        selectedAddressCard(result: selectedResult)
                    }
                    
                    mapSection
                    actionButtons
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Sélectionner un lieu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
            .onAppear {
                if !address.isEmpty {
                    searchText = address
                }
                if let coordinate {
                    selectedPin = IdentifiableCoordinate(coordinate: coordinate)
                    region.center = coordinate
                }
            }
            .onReceive(locationFetcher.$currentLocation) { location in
                guard let location else { return }
                
                let geocoder = CLGeocoder()
                geocoder.reverseGeocodeLocation(location) { placemarks, error in
                    DispatchQueue.main.async {
                        let mkPlacemark: MKPlacemark
                        if let clPlacemark = placemarks?.first {
                            mkPlacemark = MKPlacemark(placemark: clPlacemark)
                        } else {
                            mkPlacemark = MKPlacemark(coordinate: location.coordinate)
                        }
                        
                        let mapItem = MKMapItem(placemark: mkPlacemark)
                        
                        withAnimation {
                            region.center = location.coordinate
                        }
                        selectedPin = IdentifiableCoordinate(coordinate: location.coordinate)
                        selectedResult = mapItem
                    }
                }
            }
        }
    }
    
    private var headerText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Trouver l'adresse via la carte")
                .font(.headline)
            Text("Utilisez la recherche pour remplir automatiquement le lieu de rencontre.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var searchField: some View {
        VStack(spacing: 8) {
            TextField("Rechercher une adresse", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
            
            Button(action: performSearch) {
                if isSearching {
                    HStack {
                        ProgressView()
                            .progressViewStyle(.circular)
                        Text("Recherche...")
                    }
                } else {
                    Text("Rechercher")
                }
            }
            .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
            .buttonStyle(.borderedProminent)
            .tint(Color.orange)
            .frame(maxWidth: .infinity)
        }
    }
    
    private var searchResultsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Résultats de recherche")
                .font(.headline)
                .padding(.horizontal, 4)
            
            ForEach(Array(searchResults.enumerated()), id: \.offset) { index, result in
                searchResultCard(result: result, index: index)
            }
        }
    }
    
    private func searchResultCard(result: MKMapItem, index: Int) -> some View {
        let placemark = result.placemark
        let addressString = formatAddress(from: placemark)
        
        return Button {
            selectResult(result)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(addressString)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    Text(String(format: "Lat: %.6f", placemark.coordinate.latitude))
                    Text("/")
                    Text(String(format: "Lon: %.6f", placemark.coordinate.longitude))
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedResult == result ? Color.orange.opacity(0.1) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedResult == result ? Color.orange : Color.gray.opacity(0.2), lineWidth: selectedResult == result ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func selectedAddressCard(result: MKMapItem) -> some View {
        let placemark = result.placemark
        let addressString = formatAddress(from: placemark)
        
        return VStack(alignment: .leading, spacing: 8) {
            Text("Adresse sélectionnée")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(addressString)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            HStack {
                Text(String(format: "Lat: %.6f", placemark.coordinate.latitude))
                Text("/")
                Text(String(format: "Lon: %.6f", placemark.coordinate.longitude))
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange, lineWidth: 2)
        )
    }
    
    private var mapSection: some View {
        Map(coordinateRegion: $region, annotationItems: annotations) { pin in
            MapAnnotation(coordinate: pin.coordinate) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title)
                    .foregroundColor(.orange)
                    .shadow(radius: 4)
            }
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button("Ma position") {
                    locationFetcher.requestLocation()
                }
                .buttonStyle(MapActionButtonStyle(icon: "location.fill"))
                
                Button("Effacer") {
                    withAnimation {
                        selectedPin = nil
                        selectedResult = nil
                        searchResults = []
                        searchText = ""
                        coordinate = nil
                    }
                }
                .buttonStyle(MapActionButtonStyle(icon: "xmark.circle"))
            }
            
            HStack(spacing: 12) {
                Button("Annuler") {
                    dismiss()
                }
                .buttonStyle(MapSecondaryButtonStyle())
                
                Button("Confirmer") {
                    if let selectedResult = selectedResult {
                        address = selectedAddress
                        coordinate = selectedResult.placemark.coordinate
                    } else if !searchText.isEmpty {
                        address = searchText
                    }
                    dismiss()
                }
                .disabled(!hasSelection)
                .buttonStyle(MapPrimaryButtonStyle(enabled: hasSelection))
            }
        }
    }
    
    private func performSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        isSearching = true
        searchError = nil
        searchResults = []
        selectedResult = nil
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                if let error {
                    searchError = error.localizedDescription
                    return
                }
                
                guard let response = response, !response.mapItems.isEmpty else {
                    searchError = "Adresse introuvable."
                    return
                }
                
                searchResults = response.mapItems
            }
        }
    }
    
    private func selectResult(_ result: MKMapItem) {
        selectedResult = result
        selectedPin = IdentifiableCoordinate(coordinate: result.placemark.coordinate)
        
        withAnimation {
            region.center = result.placemark.coordinate
            region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        }
    }
    
    private func formatAddress(from placemark: MKPlacemark) -> String {
        var addressComponents: [String] = []
        
        if let name = placemark.name {
            addressComponents.append(name)
        }
        if let thoroughfare = placemark.thoroughfare {
            addressComponents.append(thoroughfare)
        }
        if let subThoroughfare = placemark.subThoroughfare {
            addressComponents.append(subThoroughfare)
        }
        if let locality = placemark.locality {
            addressComponents.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            addressComponents.append(administrativeArea)
        }
        if let country = placemark.country {
            addressComponents.append(country)
        }
        
        return addressComponents.joined(separator: ", ")
    }
}

private struct IdentifiableCoordinate: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

private extension LocationPickerView {
    var annotations: [IdentifiableCoordinate] {
        guard let selectedPin else { return [] }
        return [selectedPin]
    }
}

private final class LocationFetcher: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?
    private let manager = CLLocationManager()
    
    override init() {
        super.init()
        manager.delegate = self
    }
    
    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error.localizedDescription)
    }
}

// MARK: - Button Styles
private struct MapActionButtonStyle: ButtonStyle {
    let icon: String
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Image(systemName: icon)
            configuration.label
        }
        .font(.subheadline.weight(.semibold))
        .foregroundColor(.orange)
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.1))
        )
        .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct MapPrimaryButtonStyle: ButtonStyle {
    let enabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(enabled ? Color.orange : Color.gray)
            )
            .opacity(enabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed && enabled ? 0.98 : 1)
    }
}

private struct MapSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.orange)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.orange, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
