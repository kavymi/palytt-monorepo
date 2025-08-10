//
//  LocationManager.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import CoreLocation
import MapKit
import Combine

@MainActor
class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var searchResults: [MKMapItem] = []
    @Published var nearbyRestaurants: [MKMapItem] = []
    @Published var isLoadingLocation = false
    @Published var isSearchingRestaurants = false
    @Published var locationError: String?
    
    private let locationManager = CLLocationManager()
    private var searchCompleter = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 100 // Update every 100 meters
        
        // Configure search completer for restaurants and points of interest
        searchCompleter.resultTypes = [.pointOfInterest]
        searchCompleter.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
    }
    
    // MARK: - Permission Management
    
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationError = "Location access denied. Please enable in Settings."
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
            requestCurrentLocation()
        @unknown default:
            break
        }
    }
    
    private func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        locationManager.startUpdatingLocation()
    }
    
    func requestCurrentLocation() {
        isLoadingLocation = true
        locationError = nil
        locationManager.requestLocation()
    }
    
    // MARK: - Restaurant & Places Search
    
    func searchRestaurantsAndPlaces(_ query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearchingRestaurants = true
        
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = query
        
        // Focus on restaurants and points of interest
        searchRequest.resultTypes = [.pointOfInterest]
        
        // Use current location region if available for better results
        if let currentLocation = currentLocation {
            let region = MKCoordinateRegion(
                center: currentLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05) // Smaller radius for nearby results
            )
            searchRequest.region = region
        }
        
        do {
            let search = MKLocalSearch(request: searchRequest)
            let response = try await search.start()
            
            // Filter results to prioritize restaurants and food-related places
            let filteredResults = response.mapItems.filter { mapItem in
                return isRestaurantOrPlace(mapItem)
            }
            
            await MainActor.run {
                self.searchResults = filteredResults
                self.isSearchingRestaurants = false
            }
        } catch {
            await MainActor.run {
                self.locationError = "Search failed: \(error.localizedDescription)"
                self.searchResults = []
                self.isSearchingRestaurants = false
            }
        }
    }
    
    // MARK: - Nearby Restaurants Discovery
    
    func searchNearbyRestaurants() async {
        guard let currentLocation = currentLocation else {
            await MainActor.run {
                self.locationError = "Current location not available"
            }
            return
        }
        
        isSearchingRestaurants = true
        
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = "restaurants"
        searchRequest.resultTypes = [.pointOfInterest]
        
        // Search in a 2km radius
        let region = MKCoordinateRegion(
            center: currentLocation.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        searchRequest.region = region
        
        do {
            let search = MKLocalSearch(request: searchRequest)
            let response = try await search.start()
            
            // Filter and sort by distance
            let restaurants = response.mapItems
                .filter { isRestaurantOrPlace($0) }
                .sorted { item1, item2 in
                    let distance1 = currentLocation.distance(from: CLLocation(
                        latitude: item1.placemark.coordinate.latitude,
                        longitude: item1.placemark.coordinate.longitude
                    ))
                    let distance2 = currentLocation.distance(from: CLLocation(
                        latitude: item2.placemark.coordinate.latitude,
                        longitude: item2.placemark.coordinate.longitude
                    ))
                    return distance1 < distance2
                }
            
            await MainActor.run {
                self.nearbyRestaurants = Array(restaurants.prefix(20)) // Limit to 20 results
                self.isSearchingRestaurants = false
            }
        } catch {
            await MainActor.run {
                self.locationError = "Failed to find nearby restaurants: \(error.localizedDescription)"
                self.nearbyRestaurants = []
                self.isSearchingRestaurants = false
            }
        }
    }
    
    // MARK: - Filtering Helper
    
    private func isRestaurantOrPlace(_ mapItem: MKMapItem) -> Bool {
        let name = mapItem.name?.lowercased() ?? ""
        
        // Check MKPointOfInterestCategory if available
        if #available(iOS 14.0, *) {
            // Access pointOfInterestCategory from MKMapItem directly
            if let category = mapItem.pointOfInterestCategory {
                let restaurantCategories: [MKPointOfInterestCategory] = [
                    .restaurant,
                    .cafe,
                    .bakery,
                    .brewery,
                    .winery,
                    .foodMarket
                ]
                
                if restaurantCategories.contains(category) {
                    return true
                }
                
                // Also include other points of interest
                let placeCategories: [MKPointOfInterestCategory] = [
                    .store,
                    .museum,
                    .theater,
                    .movieTheater,
                    .nightlife,
                    .park,
                    .amusementPark,
                    .zoo,
                    .aquarium,
                    .library,
                    .school,
                    .university,
                    .hospital,
                    .pharmacy,
                    .gasStation,
                    .atm,
                    .bank,
                    .hotel,
                    .publicTransport
                ]
                
                if placeCategories.contains(category) {
                    return true
                }
            }
        }
        
        // Fallback to name-based filtering for older iOS versions
        let restaurantKeywords = [
            "restaurant", "cafe", "coffee", "bar", "pub", "bistro", "diner", "grill",
            "pizza", "burger", "sandwich", "sushi", "thai", "chinese", "italian",
            "mexican", "indian", "bakery", "brewery", "winery", "food", "kitchen",
            "eatery", "dining", "fast food", "takeaway", "delivery"
        ]
        
        let placeKeywords = [
            "store", "shop", "mall", "market", "center", "plaza", "museum", "gallery",
            "theater", "cinema", "park", "gym", "spa", "hotel", "library", "school",
            "hospital", "pharmacy", "bank", "station", "airport", "zoo", "aquarium"
        ]
        
        let allKeywords = restaurantKeywords + placeKeywords
        
        return allKeywords.contains { keyword in
            name.contains(keyword)
        }
    }
    
    // MARK: - Legacy search method (keeping for backward compatibility)
    
    func searchLocation(_ query: String) async {
        await searchRestaurantsAndPlaces(query)
    }
    
    // MARK: - Convert MKMapItem to Location
    
    func convertToLocation(from mapItem: MKMapItem) -> Location {
        let placemark = mapItem.placemark
        let coordinate = placemark.coordinate
        
        // Use the place name from the mapItem
        let placeName = mapItem.name
        
        // Build address components
        let address = [
            placemark.subThoroughfare,
            placemark.thoroughfare
        ].compactMap { $0 }.joined(separator: " ")
        
        let city = placemark.locality ?? placemark.subAdministrativeArea ?? "Unknown City"
        let state = placemark.administrativeArea
        let country = placemark.country ?? "Unknown Country"
        let postalCode = placemark.postalCode
        
        return Location(
            name: placeName,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            address: address.isEmpty ? mapItem.name ?? "Unknown Address" : address,
            city: city,
            state: state,
            country: country,
            postalCode: postalCode
        )
    }
    
    // MARK: - Distance Helper
    
    func getDistance(to mapItem: MKMapItem) -> String? {
        guard let currentLocation = currentLocation else { return nil }
        
        let itemLocation = CLLocation(
            latitude: mapItem.placemark.coordinate.latitude,
            longitude: mapItem.placemark.coordinate.longitude
        )
        
        let distance = currentLocation.distance(from: itemLocation)
        
        if distance < 1000 {
            return String(format: "%.0f m", distance)
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }
    
    // MARK: - Get Address from Coordinates
    
    func getAddress(from location: CLLocation) async -> Location? {
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            
            // Try to get a meaningful place name
            var placeName: String? = nil
            
            // Try different sources for a place name
            if let areasOfInterest = placemark.areasOfInterest, !areasOfInterest.isEmpty {
                placeName = areasOfInterest.first
            } else if let name = placemark.name, !name.contains(placemark.thoroughfare ?? "") {
                // Use name if it's not just the street address
                placeName = name
            } else if placemark.region is CLCircularRegion {
                // If no specific place name, might be "Current Location" or a generic description
                placeName = nil
            }
            
            let address = [
                placemark.subThoroughfare,
                placemark.thoroughfare
            ].compactMap { $0 }.joined(separator: " ")
            
            let city = placemark.locality ?? placemark.subAdministrativeArea ?? "Unknown City"
            let state = placemark.administrativeArea
            let country = placemark.country ?? "Unknown Country"
            let postalCode = placemark.postalCode
            
            return Location(
                name: placeName ?? "Current Location",
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                address: address.isEmpty ? "Current Location" : address,
                city: city,
                state: state,
                country: country,
                postalCode: postalCode
            )
        } catch {
            locationError = "Failed to get address: \(error.localizedDescription)"
            return nil
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            
            #if os(iOS)
            if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
                startLocationUpdates()
                requestCurrentLocation()
            }
            #elseif os(macOS)
            if authorizationStatus == .authorized || authorizationStatus == .authorizedAlways {
                startLocationUpdates()
                requestCurrentLocation()
            }
            #endif
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            currentLocation = location
            isLoadingLocation = false
            
            // Update search completer region
            searchCompleter.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
            
            // Auto-load nearby restaurants when location is available
            Task {
                await searchNearbyRestaurants()
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            isLoadingLocation = false
            locationError = "Failed to get location: \(error.localizedDescription)"
        }
    }
}