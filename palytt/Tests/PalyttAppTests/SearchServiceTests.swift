//
//  SearchServiceTests.swift
//  PalyttAppTests
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import XCTest
@testable import PalyttApp

@MainActor
final class SearchServiceTests: XCTestCase {
    
    var sut: SearchService!
    var mockAPIClient: MockAPIClient!
    
    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        sut = SearchService(apiClient: mockAPIClient)
    }
    
    override func tearDown() {
        sut = nil
        mockAPIClient = nil
        super.tearDown()
    }
    
    // MARK: - Search Posts Tests
    
    func testSearchPosts_Success() async throws {
        // Given
        let mockPosts = [createMockPostDTO(), createMockPostDTO()]
        let response = SearchPostsResponse(posts: mockPosts, total: 2, hasMore: false)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let posts = try await sut.searchPosts(query: "pizza", limit: 20, offset: 0)
        
        // Then
        XCTAssertEqual(posts.count, 2)
        XCTAssertEqual(mockAPIClient.lastRequestPath, "trpc/search.searchPosts")
    }
    
    func testSearchPosts_EmptyResults() async throws {
        // Given
        let response = SearchPostsResponse(posts: [], total: 0, hasMore: false)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let posts = try await sut.searchPosts(query: "nonexistent", limit: 20, offset: 0)
        
        // Then
        XCTAssertEqual(posts.count, 0)
    }
    
    // MARK: - Search Places Tests
    
    func testSearchPlaces_Success() async throws {
        // Given
        let mockPlaces = [createMockPlaceDTO(), createMockPlaceDTO()]
        let response = SearchPlacesResponse(places: mockPlaces, total: 2)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let places = try await sut.searchPlaces(query: "restaurant", latitude: 37.7749, longitude: -122.4194, radius: 5000, limit: 20)
        
        // Then
        XCTAssertEqual(places.count, 2)
        XCTAssertEqual(mockAPIClient.lastRequestPath, "trpc/search.searchPlaces")
    }
    
    func testSearchPlaces_WithoutLocation() async throws {
        // Given
        let mockPlaces = [createMockPlaceDTO()]
        let response = SearchPlacesResponse(places: mockPlaces, total: 1)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let places = try await sut.searchPlaces(query: "coffee", latitude: nil, longitude: nil, radius: 5000, limit: 20)
        
        // Then
        XCTAssertEqual(places.count, 1)
    }
    
    // MARK: - Helper Methods
    
    private func createMockPostDTO() -> PostResponseDTO {
        return PostResponseDTO(
            id: UUID().uuidString,
            authorId: "user123",
            authorClerkId: "clerk_test",
            shopId: nil,
            shopName: "Test Shop",
            foodItem: "Test Food",
            description: "Test Description",
            rating: 4.5,
            imageUrl: nil,
            imageUrls: [],
            tags: ["tag1"],
            location: nil,
            isPublic: true,
            likesCount: 0,
            commentsCount: 0,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
    
    private func createMockPlaceDTO() -> PlaceDTO {
        return PlaceDTO(
            id: UUID().uuidString,
            name: "Test Restaurant",
            address: "123 Test St",
            city: "San Francisco",
            state: "CA",
            country: "USA",
            latitude: 37.7749,
            longitude: -122.4194,
            phoneNumber: nil,
            website: nil,
            rating: 4.5,
            priceLevel: 2,
            categories: ["restaurant"],
            postsCount: 5,
            distance: nil
        )
    }
}

