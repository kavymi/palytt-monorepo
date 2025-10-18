//
//  SearchDTO.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation

// MARK: - Place DTOs

struct PlaceDTO: Codable {
    let id: String
    let name: String
    let address: String
    let city: String?
    let state: String?
    let country: String?
    let latitude: Double
    let longitude: Double
    let phoneNumber: String?
    let website: String?
    let rating: Double?
    let priceLevel: Int?
    let categories: [String]?
    let postsCount: Int?
    let distance: Double? // Distance in meters (if location provided in search)
}

// MARK: - Search Request DTOs

struct SearchPostsRequest: Codable {
    let query: String
    let limit: Int?
    let offset: Int?
}

struct SearchPlacesRequest: Codable {
    let query: String
    let latitude: Double?
    let longitude: Double?
    let radius: Int? // in meters
    let limit: Int?
}

// MARK: - Search Response DTOs

struct SearchPostsResponse: Codable {
    let posts: [PostResponseDTO]
    let total: Int
    let hasMore: Bool
}

struct SearchPlacesResponse: Codable {
    let places: [PlaceDTO]
    let total: Int
}

// MARK: - Domain Model Conversion

extension Place {
    /// Convert backend PlaceDTO to domain Place model
    static func from(placeDTO: PlaceDTO) -> Place {
        return Place(
            id: UUID(uuidString: placeDTO.id) ?? UUID(),
            convexId: placeDTO.id,
            name: placeDTO.name,
            address: placeDTO.address,
            city: placeDTO.city,
            state: placeDTO.state,
            country: placeDTO.country,
            latitude: placeDTO.latitude,
            longitude: placeDTO.longitude,
            phoneNumber: placeDTO.phoneNumber,
            website: placeDTO.website.flatMap { URL(string: $0) },
            rating: placeDTO.rating,
            priceLevel: placeDTO.priceLevel,
            categories: placeDTO.categories ?? [],
            postsCount: placeDTO.postsCount ?? 0
        )
    }
}

// Domain model (if Place doesn't exist yet)
struct Place: Identifiable {
    let id: UUID
    let convexId: String?
    let name: String
    let address: String
    let city: String?
    let state: String?
    let country: String?
    let latitude: Double
    let longitude: Double
    let phoneNumber: String?
    let website: URL?
    let rating: Double?
    let priceLevel: Int?
    let categories: [String]
    let postsCount: Int
}

