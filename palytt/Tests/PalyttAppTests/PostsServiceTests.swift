//
//  PostsServiceTests.swift
//  PalyttAppTests
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import XCTest
@testable import PalyttApp

@MainActor
final class PostsServiceTests: XCTestCase {
    
    var sut: PostsService!
    var mockAPIClient: MockAPIClient!
    
    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        sut = PostsService(apiClient: mockAPIClient)
    }
    
    override func tearDown() {
        sut = nil
        mockAPIClient = nil
        super.tearDown()
    }
    
    // MARK: - getPosts Tests
    
    func testGetPosts_Success() async throws {
        // Given
        let mockPostDTO = createMockPostDTO()
        let mockResponse = GetPostsResponse(
            posts: [mockPostDTO],
            total: 1,
            page: 1,
            hasMore: false
        )
        mockAPIClient.mockResponseData = try JSONEncoder().encode(mockResponse)
        
        // When
        let posts = try await sut.getPosts(page: 1, limit: 20)
        
        // Then
        XCTAssertEqual(posts.count, 1)
        XCTAssertEqual(posts.first?.caption, mockPostDTO.description)
    }
    
    func testGetPosts_Failure() async {
        // Given
        mockAPIClient.shouldFail = true
        mockAPIClient.mockError = .networkError(URLError(.notConnectedToInternet))
        
        // When/Then
        do {
            _ = try await sut.getPosts(page: 1, limit: 20)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - createPost Tests
    
    func testCreatePost_Success() async throws {
        // Given
        let request = CreatePostRequest(
            shopName: "Test Shop",
            foodItem: "Test Item",
            description: "Test Description",
            rating: 4.5,
            imageUrl: nil,
            imageUrls: ["https://example.com/image.jpg"],
            tags: ["tag1", "tag2"],
            location: LocationDTO(
                latitude: 37.7749,
                longitude: -122.4194,
                address: "123 Test St",
                name: "Test Location"
            ),
            isPublic: true
        )
        
        let mockPostDTO = createMockPostDTO()
        let mockResponse = CreatePostResponse(success: true, post: mockPostDTO)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(mockResponse)
        
        // When
        let post = try await sut.createPost(request)
        
        // Then
        XCTAssertNotNil(post)
        XCTAssertEqual(post.caption, mockPostDTO.description)
    }
    
    // MARK: - toggleLike Tests
    
    func testToggleLike_Success() async throws {
        // Given
        let mockResponse = LikeResponse(
            success: true,
            isLiked: true,
            likesCount: 10
        )
        mockAPIClient.mockResponseData = try JSONEncoder().encode(mockResponse)
        
        // When
        let response = try await sut.toggleLike(postId: "test-post-id")
        
        // Then
        XCTAssertTrue(response.success)
        XCTAssertTrue(response.isLiked)
        XCTAssertEqual(response.likesCount, 10)
    }
    
    // MARK: - toggleBookmark Tests
    
    func testToggleBookmark_Success() async throws {
        // Given
        let mockResponse = BookmarkResponse(
            success: true,
            isBookmarked: true
        )
        mockAPIClient.mockResponseData = try JSONEncoder().encode(mockResponse)
        
        // When
        let response = try await sut.toggleBookmark(postId: "test-post-id")
        
        // Then
        XCTAssertTrue(response.success)
        XCTAssertTrue(response.isBookmarked)
    }
    
    // MARK: - Helper Methods
    
    private func createMockPostDTO() -> PostDTO {
        return PostDTO(
            id: "test-post-id",
            authorId: "test-author-id",
            authorClerkId: "test-clerk-id",
            shopId: nil,
            shopName: "Test Shop",
            foodItem: "Test Food",
            description: "Test Description",
            rating: 4.5,
            imageUrl: nil,
            imageUrls: ["https://example.com/image.jpg"],
            tags: ["tag1", "tag2"],
            location: LocationDTO(
                latitude: 37.7749,
                longitude: -122.4194,
                address: "123 Test St",
                name: "Test Location"
            ),
            isPublic: true,
            likesCount: 0,
            commentsCount: 0,
            createdAt: "2025-10-19T12:00:00.000Z",
            updatedAt: "2025-10-19T12:00:00.000Z",
            isLiked: false,
            isBookmarked: false,
            authorDisplayName: "Test User",
            authorUsername: "testuser",
            authorAvatarUrl: nil
        )
    }
    
    private struct CreatePostResponse: Codable {
        let success: Bool
        let post: PostDTO
    }
}

// MARK: - HomeViewModel Tests

@MainActor
final class HomeViewModelTests: XCTestCase {
    
    var sut: HomeViewModel!
    var mockPostsService: MockPostsService!
    
    override func setUp() {
        super.setUp()
        mockPostsService = MockPostsService()
        sut = HomeViewModel(postsService: mockPostsService)
    }
    
    override func tearDown() {
        sut = nil
        mockPostsService = nil
        super.tearDown()
    }
    
    func testFetchPosts_Success() async {
        // Given
        let mockPost = createMockPost()
        mockPostsService.mockPosts = [mockPost]
        
        // When
        sut.fetchPosts()
        try? await Task.sleep(nanoseconds: 100_000_000) // Wait for async operation
        
        // Then
        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(sut.posts.count, 1)
        XCTAssertNil(sut.errorMessage)
    }
    
    func testFetchPosts_Failure() async {
        // Given
        mockPostsService.shouldFail = true
        mockPostsService.mockError = .networkError(URLError(.notConnectedToInternet))
        
        // When
        sut.fetchPosts()
        try? await Task.sleep(nanoseconds: 100_000_000) // Wait for async operation
        
        // Then
        XCTAssertFalse(sut.isLoading)
        XCTAssertNotNil(sut.errorMessage)
    }
    
    private func createMockPost() -> Post {
        return Post(
            id: UUID(),
            userId: UUID(),
            author: User(
                id: UUID(),
                email: "test@test.com",
                username: "testuser",
                displayName: "Test User"
            ),
            caption: "Test Caption",
            mediaURLs: [],
            location: Location(
                latitude: 0,
                longitude: 0,
                address: "Test Address",
                city: "Test City",
                country: "Test Country"
            )
        )
    }
}

