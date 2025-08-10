//
//  LocationFeedSettingsView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import CoreLocation

struct LocationFeedSettingsView: View {
    @StateObject private var locationService = LocationBasedFeedService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingLocationPermissionAlert = false
    @State private var currentLocationName = "Loading..."
    
    var body: some View {
        NavigationStack {
            Form {
                // Current Location Section
                Section("Current Location") {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.primaryBrand)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Location")
                                .font(.body)
                                .foregroundColor(.primaryText)
                            
                            Text(currentLocationName)
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            requestLocationUpdate()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.primaryBrand)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Location Permission Section
                Section("Location Permission") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: locationService.userLocation != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(locationService.userLocation != nil ? .green : .red)
                            
                            Text("Location Access")
                                .font(.body)
                                .foregroundColor(.primaryText)
                            
                            Spacer()
                            
                            Text(locationService.userLocation != nil ? "Enabled" : "Disabled")
                                .font(.caption)
                                .foregroundColor(locationService.userLocation != nil ? .green : .red)
                                .fontWeight(.semibold)
                        }
                        
                        if locationService.userLocation == nil {
                            Button("Enable Location Access") {
                                showingLocationPermissionAlert = true
                            }
                            .font(.subheadline)
                            .foregroundColor(.primaryBrand)
                        }
                        
                        Text("Location access is required to show nearby posts and provide personalized recommendations.")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    .padding(.vertical, 8)
                }
                
                // Distance Categories Section
                Section("Distance Categories") {
                    VStack(spacing: 12) {
                        ForEach(LocationBasedFeedService.DistanceCategory.allCases, id: \.self) { category in
                            DistanceCategoryRow(category: category)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Location-Based Features Section
                Section("Location-Based Features") {
                    FeatureRow(
                        icon: "mappin.and.ellipse",
                        title: "Smart Location Feed",
                        description: "Shows posts based on your location and preferences",
                        isEnabled: true
                    )
                    
                    FeatureRow(
                        icon: "bell.badge.fill",
                        title: "Nearby Notifications",
                        description: "Get notified when friends post nearby",
                        isEnabled: locationService.feedPreferences.enableLocationNotifications
                    )
                    
                    FeatureRow(
                        icon: "location.magnifyingglass",
                        title: "Distance Sorting",
                        description: "Sort posts by distance from your location",
                        isEnabled: locationService.feedPreferences.sortBy == .distance
                    )
                }
                
                // Privacy Section
                Section("Privacy") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "shield.fill")
                                .foregroundColor(.green)
                            
                            Text("Your Privacy")
                                .font(.body)
                                .foregroundColor(.primaryText)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            PrivacyPoint(text: "Your exact location is never shared with other users")
                            PrivacyPoint(text: "Location data is used only for feed personalization")
                            PrivacyPoint(text: "You can disable location features at any time")
                            PrivacyPoint(text: "Location data is processed securely and encrypted")
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Debug Section (only in development)
                #if DEBUG
                Section("Debug Information") {
                    if let location = locationService.userLocation {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Latitude: \(location.coordinate.latitude, specifier: "%.6f")")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            
                            Text("Longitude: \(location.coordinate.longitude, specifier: "%.6f")")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            
                            Text("Accuracy: \(location.horizontalAccuracy, specifier: "%.1f")m")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    } else {
                        Text("No location data available")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                }
                #endif
            }
            .navigationTitle("Location Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Location Permission Required", isPresented: $showingLocationPermissionAlert) {
                Button("Settings") {
                    openAppSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("To use location-based features, please enable location access in Settings.")
            }
            .task {
                await updateCurrentLocationName()
            }
        }
        .background(Color.background)
    }
    
    private func requestLocationUpdate() {
        locationService.requestLocationPermission()
        locationService.startLocationUpdates()
        
        Task {
            await updateCurrentLocationName()
        }
    }
    
    private func updateCurrentLocationName() async {
        guard let location = locationService.userLocation else {
            currentLocationName = "Location not available"
            return
        }
        
        do {
            let address = try await locationService.reverseGeocodeLocation(location)
            await MainActor.run {
                currentLocationName = address
            }
        } catch {
            await MainActor.run {
                currentLocationName = "Unable to determine location"
            }
        }
    }
    
    private func openAppSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - Distance Category Row
struct DistanceCategoryRow: View {
    let category: LocationBasedFeedService.DistanceCategory
    
    var body: some View {
        HStack {
            Image(systemName: category.icon)
                .foregroundColor(.primaryBrand)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.body)
                    .foregroundColor(.primaryText)
                
                Text(distanceDescription)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var distanceDescription: String {
        switch category {
        case .nearby:
            return "Within 1 km"
        case .walking:
            return "1-5 km away"
        case .cycling:
            return "5-15 km away"
        case .driving:
            return "15-50 km away"
        case .farAway:
            return "50+ km away"
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isEnabled ? .primaryBrand : .secondaryText)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primaryText)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
            
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isEnabled ? .green : .secondaryText)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Privacy Point
struct PrivacyPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
                .padding(.top, 2)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
    }
}

// MARK: - Preview
#Preview {
    LocationFeedSettingsView()
        .environmentObject(LocationBasedFeedService.shared)
} 