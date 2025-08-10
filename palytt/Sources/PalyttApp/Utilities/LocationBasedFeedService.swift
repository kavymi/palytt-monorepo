//
//  LocationBasedFeedService.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import CoreLocation
import SwiftUI

// MARK: - Location-Based Feed Service
@MainActor
class LocationBasedFeedService: ObservableObject {
    static let shared = LocationBasedFeedService()
    
    @Published var nearbyPosts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userLocation: CLLocation?
    @Published var feedPreferences = FeedPreferences()
    
    private let locationManager = CLLocationManager()
    private let backendService = BackendService.shared
    private let geocoder = CLGeocoder()
    
    // MARK: - Distance Categories
    enum DistanceCategory: String, CaseIterable {
        case nearby = "nearby"        // < 1 km
        case walking = "walking"      // 1-5 km
        case cycling = "cycling"      // 5-15 km
        case driving = "driving"      // 15-50 km
        case farAway = "far_away"     // > 50 km
        
        var displayName: String {
            switch self {
            case .nearby: return "Nearby"
            case .walking: return "Walking Distance"
            case .cycling: return "Cycling Distance"
            case .driving: return "Driving Distance"
            case .farAway: return "Far Away"
            }
        }
        
        var maxDistance: Double {
            switch self {
            case .nearby: return 1000       // 1 km
            case .walking: return 5000      // 5 km
            case .cycling: return 15000     // 15 km
            case .driving: return 50000     // 50 km
            case .farAway: return Double.infinity
            }
        }
        
        var icon: String {
            switch self {
            case .nearby: return "location.fill"
            case .walking: return "figure.walk"
            case .cycling: return "bicycle"
            case .driving: return "car.fill"
            case .farAway: return "globe"
            }
        }
    }
    
    // MARK: - Feed Preferences
    struct FeedPreferences: Codable {
        var isLocationEnabled: Bool = true
        var maxDistance: Double = 10000 // 10 km
        var preferredCategories: Set<String> = []
        var autoRefresh: Bool = true
        var refreshInterval: TimeInterval = 300 // 5 minutes
        var showTimestamps: Bool = true
        var groupByLocation: Bool = false
        var includeRecentVisits: Bool = true
        var privacyMode: PrivacyMode = .public
        
        enum PrivacyMode: String, CaseIterable, Codable {
            case `private` = "private"
            case friends = "friends"
            case `public` = "public"
            
            var displayName: String {
                switch self {
                case .private: return "Private"
                case .friends: return "Friends Only"
                case .public: return "Public"
                }
            }
        }
    }
    
    private init() {
        setupLocationManager()
        loadPreferences()
    }
    
    // MARK: - Public Methods
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocationUpdates() {
        guard feedPreferences.isLocationEnabled else { return }
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    func loadLocationBasedFeed() async {
        guard let location = userLocation, feedPreferences.isLocationEnabled else {
            await loadGeneralFeed()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Use existing getPosts method and filter locally
            let postsResponse = try await backendService.getPosts(limit: 100)
            let backendPosts = postsResponse.posts
            
            // Convert BackendPost to Post if needed, or work with BackendPost directly
            // For now, let's assume we need to work with the existing structure
            // This is a placeholder implementation that should be replaced with proper backend support
            let posts = backendPosts.compactMap { backendPost -> Post? in
                // Convert BackendPost to Post here
                // This is a simplified conversion - you might need to adjust based on your actual models
                return nil // Placeholder for now
            }
            
            nearbyPosts = filterAndSortPosts(posts, relativeTo: location)
        } catch {
            errorMessage = "Failed to load location-based feed: \(error.localizedDescription)"
            // Fallback to general feed
            await loadGeneralFeed()
        }
        
        isLoading = false
    }
    
    func categorizePostsByDistance(_ posts: [Post], relativeTo location: CLLocation) -> [DistanceCategory: [Post]] {
        var categorized: [DistanceCategory: [Post]] = [:]
        
        for post in posts {
            guard let postLocation = post.location?.toCLLocation() else { continue }
            let distance = location.distance(from: postLocation)
            
            for category in DistanceCategory.allCases {
                if distance <= category.maxDistance {
                    categorized[category, default: []].append(post)
                    break
                }
            }
        }
        
        return categorized
    }
    
    func updatePreferences(_ newPreferences: FeedPreferences) {
        feedPreferences = newPreferences
        savePreferences()
        
        // Reload feed with new preferences
        Task {
            await loadLocationBasedFeed()
        }
    }
    
    func getLocationName(for location: CLLocation) async -> String? {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                var components: [String] = []
                
                if let name = placemark.name { components.append(name) }
                if let locality = placemark.locality { components.append(locality) }
                if let administrativeArea = placemark.administrativeArea { components.append(administrativeArea) }
                
                return components.isEmpty ? nil : components.joined(separator: ", ")
            }
        } catch {
            print("Geocoding error: \(error)")
        }
        return nil
    }
    
    // MARK: - Private Methods
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 100 // Update every 100 meters
    }
    
    private func filterAndSortPosts(_ posts: [Post], relativeTo location: CLLocation) -> [Post] {
        var filteredPosts = posts
        
        // Filter by distance
        filteredPosts = filteredPosts.filter { post in
            guard let postLocation = post.location?.toCLLocation() else { return false }
            let distance = location.distance(from: postLocation)
            return distance <= feedPreferences.maxDistance
        }
        
        // Filter by categories if specified
        if !feedPreferences.preferredCategories.isEmpty {
            filteredPosts = filteredPosts.filter { post in
                guard let metadata = post.metadata else { return false }
                return feedPreferences.preferredCategories.contains(metadata.category ?? "")
            }
        }
        
        // Sort by distance (closest first)
        filteredPosts.sort { post1, post2 in
            guard let location1 = post1.location?.toCLLocation(),
                  let location2 = post2.location?.toCLLocation() else {
                return false
            }
            
            let distance1 = location.distance(from: location1)
            let distance2 = location.distance(from: location2)
            return distance1 < distance2
        }
        
        return filteredPosts
    }
    
    private func loadGeneralFeed() async {
        // Fallback to regular feed when location is not available
        isLoading = true
        
        do {
            let postsResponse = try await backendService.getPosts(limit: 50)
            // For now, set empty array until proper conversion is implemented
            nearbyPosts = []
        } catch {
            errorMessage = "Failed to load feed: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func savePreferences() {
        if let data = try? JSONEncoder().encode(feedPreferences) {
            UserDefaults.standard.set(data, forKey: "LocationFeedPreferences")
        }
    }
    
    private func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: "LocationFeedPreferences"),
           let preferences = try? JSONDecoder().decode(FeedPreferences.self, from: data) {
            feedPreferences = preferences
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationBasedFeedService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
        
        // Auto-refresh feed if enabled
        if feedPreferences.autoRefresh {
            Task {
                await loadLocationBasedFeed()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
        errorMessage = "Location error: \(error.localizedDescription)"
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            feedPreferences.isLocationEnabled = false
            Task {
                await loadGeneralFeed()
            }
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}

// MARK: - Location Extension
extension Location {
    func toCLLocation() -> CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
} 