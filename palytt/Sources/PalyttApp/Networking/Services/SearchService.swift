//
//  SearchService.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation

// MARK: - Protocol

protocol SearchServiceProtocol {
    func searchPosts(query: String, limit: Int, offset: Int) async throws -> [Post]
    func searchPlaces(query: String, latitude: Double?, longitude: Double?, radius: Int, limit: Int) async throws -> [Place]
}

// MARK: - Service Implementation

@MainActor
final class SearchService: SearchServiceProtocol {
    
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }
    
    convenience init(baseURL: URL) {
        let apiClient = APIClient(baseURL: baseURL)
        self.init(apiClient: apiClient)
    }
    
    // MARK: - Search Posts
    
    func searchPosts(query: String, limit: Int = 20, offset: Int = 0) async throws -> [Post] {
        print("🔍 SearchService: Searching posts with query: '\(query)'")
        
        let request = SearchPostsRequest(
            query: query,
            limit: limit,
            offset: offset
        )
        
        let response = try await apiClient.request(
            path: "trpc/search.searchPosts",
            method: .get,
            parameters: request,
            responseType: SearchPostsResponse.self
        )
        
        print("✅ SearchService: Found \(response.posts.count) posts")
        return response.posts.map { Post.from(postResponseDTO: $0) }
    }
    
    // MARK: - Search Places
    
    func searchPlaces(
        query: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        radius: Int = 5000,
        limit: Int = 20
    ) async throws -> [Place] {
        print("🔍 SearchService: Searching places with query: '\(query)'")
        
        let request = SearchPlacesRequest(
            query: query,
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            limit: limit
        )
        
        let response = try await apiClient.request(
            path: "trpc/search.searchPlaces",
            method: .get,
            parameters: request,
            responseType: SearchPlacesResponse.self
        )
        
        print("✅ SearchService: Found \(response.places.count) places")
        return response.places.map { Place.from(placeDTO: $0) }
    }
}

// MARK: - Mock Implementation for Testing

#if DEBUG
final class MockSearchService: SearchServiceProtocol {
    var mockPosts: [Post] = []
    var mockPlaces: [Place] = []
    var shouldFail = false
    var mockError: APIError = .networkError(URLError(.notConnectedToInternet))
    
    func searchPosts(query: String, limit: Int, offset: Int) async throws -> [Post] {
        if shouldFail { throw mockError }
        return mockPosts
    }
    
    func searchPlaces(query: String, latitude: Double?, longitude: Double?, radius: Int, limit: Int) async throws -> [Place] {
        if shouldFail { throw mockError }
        return mockPlaces
    }
}
#endif

