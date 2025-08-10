//
//  Location.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import CoreLocation

struct Location: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String?
    let latitude: Double
    let longitude: Double
    let address: String
    let city: String
    let state: String?
    let country: String
    let postalCode: String?
    
    init(
        id: UUID = UUID(),
        name: String? = nil,
        latitude: Double,
        longitude: Double,
        address: String,
        city: String,
        state: String? = nil,
        country: String,
        postalCode: String? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.city = city
        self.state = state
        self.country = country
        self.postalCode = postalCode
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var displayName: String {
        if let name = name {
            return name
        } else if !city.isEmpty && !country.isEmpty {
            return "\(city), \(country)"
        } else if !address.isEmpty {
            return address
        } else {
            return "Unknown Location"
        }
    }
    
    var formattedAddress: String {
        var components = [address]
        if let state = state {
            components.append("\(city), \(state)")
        } else {
            components.append(city)
        }
        components.append(country)
        return components.joined(separator: ", ")
    }
}

// MARK: - Mock Data
extension Location {
    static let mockCafe = Location(
        latitude: 37.7749,
        longitude: -122.4194,
        address: "123 Coffee Street, San Francisco, CA",
        city: "San Francisco",
        state: "CA",
        country: "USA"
    )
    
    static let mockRestaurant = Location(
        latitude: 40.7128,
        longitude: -74.0060,
        address: "456 Food Avenue, New York, NY",
        city: "New York",
        state: "NY",
        country: "USA"
    )
} 