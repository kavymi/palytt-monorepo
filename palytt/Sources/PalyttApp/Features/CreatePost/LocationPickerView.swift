//
//  LocationPickerView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import MapKit

struct LocationPickerView: View {
    @Binding var selectedLocation: Location?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager.shared
    @State private var searchText = ""
    @State private var showMap = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var isSearching = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondaryText)
                    
                    TextField("Search for restaurants & places...", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            Task {
                                await searchRestaurantsAndPlaces()
                            }
                        }
                        .onChange(of: searchText) { _, newValue in
                            if newValue.isEmpty {
                                locationManager.searchResults = []
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            locationManager.searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondaryText)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding()
                
                // Current Location Button
                Button(action: useCurrentLocation) {
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.title3)
                            .foregroundColor(.primaryBrand)
                            .frame(width: 40, height: 40)
                            .background(Color.matchaGreen.opacity(0.2))
                            .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Use Current Location")
                                .font(.headline)
                                .foregroundColor(.primaryText)
                            
                            if locationManager.isLoadingLocation {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Getting location...")
                                        .font(.caption)
                                        .foregroundColor(.secondaryText)
                                }
                            } else {
                                Text("Share your exact location")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.tertiaryText)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(16)
                }
                .padding(.horizontal)
                .disabled(locationManager.isLoadingLocation)
                
                Divider()
                    .padding(.vertical)
                
                // Content based on search state
                if isSearching || locationManager.isSearchingRestaurants {
                    VStack {
                        ProgressView()
                        Text(searchText.isEmpty ? "Finding nearby restaurants..." : "Searching...")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !searchText.isEmpty && !locationManager.searchResults.isEmpty {
                    // Search Results
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(locationManager.searchResults, id: \.self) { mapItem in
                                RestaurantResultRow(mapItem: mapItem, locationManager: locationManager) {
                                    selectLocation(mapItem)
                                }
                                
                                if mapItem != locationManager.searchResults.last {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                } else if !searchText.isEmpty && locationManager.searchResults.isEmpty {
                    // No search results
                    VStack(spacing: 16) {
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.tertiaryText)
                        
                        Text("No restaurants found")
                            .font(.headline)
                            .foregroundColor(.secondaryText)
                        
                        Text("Try searching for a different restaurant or place name")
                            .font(.caption)
                            .foregroundColor(.tertiaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !locationManager.nearbyRestaurants.isEmpty {
                    // Nearby Restaurants
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Image(systemName: "fork.knife")
                                    .foregroundColor(.primaryBrand)
                                Text("Nearby Restaurants & Places")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primaryText)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                            
                            LazyVStack(spacing: 0) {
                                ForEach(locationManager.nearbyRestaurants, id: \.self) { mapItem in
                                    RestaurantResultRow(mapItem: mapItem, locationManager: locationManager) {
                                        selectLocation(mapItem)
                                    }
                                    
                                    if mapItem != locationManager.nearbyRestaurants.last {
                                        Divider()
                                            .padding(.horizontal)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.milkTea)
                        
                        Text("Find restaurants & places")
                            .font(.headline)
                            .foregroundColor(.secondaryText)
                        
                        VStack(spacing: 8) {
                            Text("Search for restaurants, cafes, and interesting places")
                                .font(.caption)
                                .foregroundColor(.tertiaryText)
                                .multilineTextAlignment(.center)
                            
                            if locationManager.currentLocation == nil {
                                Text("Enable location to see nearby options")
                                    .font(.caption)
                                    .foregroundColor(.primaryBrand)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
                
                Spacer()
            }
            .background(Color.background)
            .navigationTitle("Add Location")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryBrand)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryBrand)
                }
                #endif
            }
            .alert("Location Error", isPresented: .constant(locationManager.locationError != nil)) {
                Button("OK") {
                    locationManager.locationError = nil
                }
            } message: {
                Text(locationManager.locationError ?? "")
            }
        }
        .sheet(isPresented: $showMap) {
            LocationMapView(
                location: $selectedLocation,
                region: $region,
                onConfirm: {
                    dismiss()
                }
            )
        }
        .onAppear {
            locationManager.requestLocationPermission()
        }
    }
    
    // MARK: - Actions
    
    private func useCurrentLocation() {
        HapticManager.shared.impact(.light)
        locationManager.requestCurrentLocation()
        
        Task {
            // Wait a bit for location to update
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            if let currentLocation = locationManager.currentLocation {
                if let location = await locationManager.getAddress(from: currentLocation) {
                    selectedLocation = location
                    showMapPreview(for: location)
                }
            }
        }
    }
    
    private func searchRestaurantsAndPlaces() async {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        await locationManager.searchRestaurantsAndPlaces(searchText)
        isSearching = false
    }
    
    private func selectLocation(_ mapItem: MKMapItem) {
        HapticManager.shared.impact(.light)
        let location = locationManager.convertToLocation(from: mapItem)
        selectedLocation = location
        showMapPreview(for: location)
    }
    
    private func showMapPreview(for location: Location) {
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: location.latitude,
                longitude: location.longitude
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        showMap = true
    }
}

// MARK: - Restaurant Result Row
struct RestaurantResultRow: View {
    let mapItem: MKMapItem
    let locationManager: LocationManager
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon based on place type
                Image(systemName: iconForPlace)
                    .font(.title2)
                    .foregroundColor(.primaryBrand)
                    .frame(width: 40, height: 40)
                    .background(categoryColor.opacity(0.2))
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(mapItem.name ?? "Unknown Location")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        if let address = formatAddress(from: mapItem.placemark) {
                            Text(address)
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                                .lineLimit(1)
                        }
                        
                        if let distance = locationManager.getDistance(to: mapItem) {
                            Text("• \(distance)")
                                .font(.caption)
                                .foregroundColor(.primaryBrand)
                                .fontWeight(.medium)
                        }
                    }
                    
                    // Category tag
                    if let category = getCategoryName() {
                        Text(category)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(categoryColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(categoryColor.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var iconForPlace: String {
        if #available(iOS 14.0, *) {
            if let category = mapItem.pointOfInterestCategory {
                switch category {
                case .restaurant, .cafe, .bakery:
                    return "fork.knife.circle.fill"
                case .brewery, .winery:
                    return "wineglass.fill"
                case .store, .foodMarket:
                    return "storefront.fill"
                case .museum, .library:
                    return "building.columns.fill"
                case .theater, .movieTheater:
                    return "theatermasks.fill"
                case .park, .amusementPark:
                    return "tree.fill"
                case .hotel:
                    return "bed.double.fill"
                case .hospital:
                    return "cross.case.fill"
                case .school, .university:
                    return "graduationcap.fill"
                case .gasStation:
                    return "fuelpump.fill"
                case .bank, .atm:
                    return "banknote.fill"
                default:
                    return "mappin.circle.fill"
                }
            }
        }
        
        // Fallback for older iOS versions
        let name = mapItem.name?.lowercased() ?? ""
        if name.contains("restaurant") || name.contains("cafe") || name.contains("food") {
            return "fork.knife.circle.fill"
        } else if name.contains("store") || name.contains("shop") {
            return "storefront.fill"
        } else {
            return "mappin.circle.fill"
        }
    }
    
    private var categoryColor: Color {
        if #available(iOS 14.0, *) {
            if let category = mapItem.pointOfInterestCategory {
                switch category {
                case .restaurant, .cafe, .bakery, .brewery, .winery, .foodMarket:
                    return .orange
                case .store:
                    return .blue
                case .museum, .library, .theater, .movieTheater:
                    return .purple
                case .park, .amusementPark, .zoo, .aquarium:
                    return .green
                case .hotel:
                    return .brown
                case .hospital, .pharmacy:
                    return .red
                case .school, .university:
                    return .indigo
                default:
                    return .gray
                }
            }
        }
        return .primaryBrand
    }
    
    private func getCategoryName() -> String? {
        if #available(iOS 14.0, *) {
            if let category = mapItem.pointOfInterestCategory {
                switch category {
                case .restaurant:
                    return "Restaurant"
                case .cafe:
                    return "Cafe"
                case .bakery:
                    return "Bakery"
                case .brewery:
                    return "Brewery"
                case .winery:
                    return "Winery"
                case .foodMarket:
                    return "Food Market"
                case .store:
                    return "Store"
                case .museum:
                    return "Museum"
                case .theater:
                    return "Theater"
                case .movieTheater:
                    return "Cinema"
                case .park:
                    return "Park"
                case .hotel:
                    return "Hotel"
                case .hospital:
                    return "Hospital"
                case .pharmacy:
                    return "Pharmacy"
                case .school:
                    return "School"
                case .university:
                    return "University"
                case .gasStation:
                    return "Gas Station"
                case .bank:
                    return "Bank"
                case .atm:
                    return "ATM"
                default:
                    return "Place"
                }
            }
        }
        return nil
    }
    
    private func formatAddress(from placemark: MKPlacemark) -> String? {
        let components = [
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea
        ].compactMap { $0 }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}

// MARK: - Location Map View
struct LocationMapView: View {
    @Binding var location: Location?
    @Binding var region: MKCoordinateRegion
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: .constant(.region(region))) {
                    if let location = location {
                        Annotation(location.address, coordinate: CLLocationCoordinate2D(
                            latitude: location.latitude,
                            longitude: location.longitude
                        )) {
                            VStack(spacing: 0) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.primaryBrand)
                                
                                Image(systemName: "arrowtriangle.down.fill")
                                    .font(.caption)
                                    .foregroundColor(.primaryBrand)
                                    .offset(y: -5)
                            }
                        }
                    }
                }
                .ignoresSafeArea()
                
                // Location Info Card
                VStack {
                    Spacer()
                    
                    if let location = location {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(location.address)
                                .font(.headline)
                                .foregroundColor(.primaryText)
                            
                            Text(location.formattedAddress)
                                .font(.subheadline)
                                .foregroundColor(.secondaryText)
                            
                            Button(action: {
                                onConfirm()
                            }) {
                                Text("Use This Location")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.primaryBrand)
                                    .cornerRadius(16)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                        .padding()
                    }
                }
            }
            .navigationTitle("Confirm Location")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
                #endif
            }
        }
    }
}

#Preview {
    LocationPickerView(selectedLocation: .constant(nil))
} 