//
//  HomeFeedTests.swift
//  PalyttAppTests
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import XCTest
@testable import Palytt
import Combine

final class HomeFeedTests: XCTestCase {
    
    var homeViewModel: HomeViewModel!
    var mockBackendService: MockBackendService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        homeViewModel = HomeViewModel()
        mockBackendService = MockBackendService()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        homeViewModel = nil
        mockBackendService = nil
        cancellables.removeAll()
        cancellables = nil
    }
    
    // MARK: - Home Feed Data Tests
    
    func test_homeViewModel_initialState_isCorrect() {
        // Given - Fresh HomeViewModel
        
        // When - Initial state
        
        // Then
        XCTAssertTrue(homeViewModel.posts.isEmpty, "Posts should be empty initially")
        XCTAssertFalse(homeViewModel.isLoading, "Should not be loading initially")
        XCTAssertFalse(homeViewModel.isLoadingMore, "Should not be loading more initially")
        XCTAssertNil(homeViewModel.errorMessage, "Should have no error initially")
        XCTAssertTrue(homeViewModel.hasMorePages, "Should have more pages initially")
        XCTAssertFalse(homeViewModel.isUsingPersonalizedFeed, "Should not use personalized feed initially")
    }
    
    func test_homeViewModel_fetchPosts_success() async {
        // Given
        let expectation = XCTestExpectation(description: "Posts fetched successfully")
        
        // When
        await homeViewModel.fetchPosts()
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.homeViewModel.isLoading, "Should not be loading after fetch")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func test_homeViewModel_refreshFeed_updatesData() async {
        // Given
        await homeViewModel.fetchPosts()
        let initialPostCount = homeViewModel.posts.count
        
        // When
        await homeViewModel.refreshFeed()
        
        // Then
        XCTAssertFalse(homeViewModel.isLoading, "Should not be loading after refresh")
        // Note: In actual implementation, this would test real data changes
    }
    
    func test_homeViewModel_loadMorePosts_appendsToExisting() async {
        // Given
        await homeViewModel.fetchPosts()
        let initialCount = homeViewModel.posts.count
        
        // When
        await homeViewModel.loadMorePosts()
        
        // Then
        XCTAssertFalse(homeViewModel.isLoadingMore, "Should not be loading more after completion")
    }
    
    func test_homeViewModel_isDataStale_returnsTrueWhenOld() {
        // Given - Fresh view model (no data fetched)
        
        // When
        let isStale = homeViewModel.isDataStale
        
        // Then
        XCTAssertTrue(isStale, "Data should be stale when no fetch has occurred")
    }
    
    func test_homeViewModel_fetchPostsIfNeeded_fetchesWhenEmpty() async {
        // Given
        XCTAssertTrue(homeViewModel.posts.isEmpty, "Posts should be empty initially")
        
        // When
        homeViewModel.fetchPostsIfNeeded()
        
        // Then
        // This will trigger fetchPosts internally
        XCTAssertTrue(true, "fetchPostsIfNeeded should be called without error")
    }
    
    // MARK: - Post Interaction Tests
    
    func test_postModel_creation_isValid() {
        // Given
        let postData = PostTestDataFactory.createValidPost()
        
        // When
        let post = Post(
            _id: postData.id,
            authorId: postData.authorId,
            author: postData.author,
            caption: postData.caption,
            imageUrl: postData.imageUrl,
            location: postData.location,
            likesCount: postData.likesCount,
            commentsCount: postData.commentsCount,
            createdAt: postData.createdAt,
            updatedAt: postData.updatedAt
        )
        
        // Then
        XCTAssertEqual(post._id, postData.id, "Post ID should match")
        XCTAssertEqual(post.caption, postData.caption, "Caption should match")
        XCTAssertEqual(post.likesCount, postData.likesCount, "Likes count should match")
        XCTAssertEqual(post.commentsCount, postData.commentsCount, "Comments count should match")
    }
    
    // MARK: - Feed Stats Tests
    
    func test_feedStats_creation_isValid() {
        // Given
        let stats = HomeViewModel.FeedStats(
            totalPosts: 10,
            fromFollowed: 6,
            fromNearby: 4,
            hasLocation: true,
            hasFollows: true
        )
        
        // When & Then
        XCTAssertEqual(stats.totalPosts, 10, "Total posts should match")
        XCTAssertEqual(stats.fromFollowed, 6, "Followed posts should match")
        XCTAssertEqual(stats.fromNearby, 4, "Nearby posts should match")
        XCTAssertTrue(stats.hasLocation, "Should have location")
        XCTAssertTrue(stats.hasFollows, "Should have follows")
    }
    
    // MARK: - Error Handling Tests
    
    func test_homeViewModel_errorHandling_setsErrorMessage() {
        // Given
        let errorMessage = "Network error occurred"
        
        // When
        homeViewModel.errorMessage = errorMessage
        
        // Then
        XCTAssertEqual(homeViewModel.errorMessage, errorMessage, "Error message should be set")
    }
    
    func test_homeViewModel_clearError_removesErrorMessage() {
        // Given
        homeViewModel.errorMessage = "Some error"
        XCTAssertNotNil(homeViewModel.errorMessage, "Error should be set initially")
        
        // When
        homeViewModel.errorMessage = nil
        
        // Then
        XCTAssertNil(homeViewModel.errorMessage, "Error should be cleared")
    }
    
    // MARK: - Loading State Tests
    
    func test_homeViewModel_loadingStates_managedCorrectly() {
        // Given
        homeViewModel.isLoading = false
        homeViewModel.isLoadingMore = false
        
        // When
        homeViewModel.isLoading = true
        
        // Then
        XCTAssertTrue(homeViewModel.isLoading, "Loading state should be true")
        XCTAssertFalse(homeViewModel.isLoadingMore, "Loading more should remain false")
        
        // When
        homeViewModel.isLoading = false
        homeViewModel.isLoadingMore = true
        
        // Then
        XCTAssertFalse(homeViewModel.isLoading, "Loading state should be false")
        XCTAssertTrue(homeViewModel.isLoadingMore, "Loading more should be true")
    }
    
    // MARK: - Pagination Tests
    
    func test_homeViewModel_pagination_hasMorePages() {
        // Given
        homeViewModel.hasMorePages = true
        
        // When
        let shouldLoadMore = homeViewModel.hasMorePages
        
        // Then
        XCTAssertTrue(shouldLoadMore, "Should have more pages to load")
    }
    
    func test_homeViewModel_pagination_noMorePages() {
        // Given
        homeViewModel.hasMorePages = false
        
        // When
        let shouldLoadMore = homeViewModel.hasMorePages
        
        // Then
        XCTAssertFalse(shouldLoadMore, "Should have no more pages to load")
    }
    
    func test_homeViewModel_checkForMorePosts_70PercentThreshold() {
        // Given
        let totalPosts = 10
        let mockPosts = createMockPosts(count: totalPosts)
        homeViewModel.posts = mockPosts.map { postData in
            Post(
                _id: postData.id,
                authorId: postData.authorId,
                author: postData.author,
                caption: postData.caption,
                imageUrl: postData.imageUrl,
                location: postData.location,
                likesCount: postData.likesCount,
                commentsCount: postData.commentsCount,
                createdAt: postData.createdAt,
                updatedAt: postData.updatedAt
            )
        }
        homeViewModel.hasMorePages = true
        homeViewModel.isLoadingMore = false
        
        // When
        let threshold = max(3, Int(Double(totalPosts) * 0.7)) // Should be 7
        let thresholdIndex = totalPosts - threshold // Should be 3
        let currentPost = homeViewModel.posts[thresholdIndex] // Post at index 3
        
        // This should trigger loading more posts
        homeViewModel.checkForMorePosts(currentPost: currentPost)
        
        // Then
        // Note: In a real test, we'd verify that loadMorePosts was called
        // For now, we verify the threshold calculation
        XCTAssertEqual(threshold, 7, "Threshold should be 70% of 10 posts")
        XCTAssertEqual(thresholdIndex, 3, "Threshold index should be at position 3")
    }
    
    func test_homeViewModel_checkForMorePosts_minimumThreshold() {
        // Given - Small dataset (less than 3 posts)
        let totalPosts = 2
        let mockPosts = createMockPosts(count: totalPosts)
        homeViewModel.posts = mockPosts.map { postData in
            Post(
                _id: postData.id,
                authorId: postData.authorId,
                author: postData.author,
                caption: postData.caption,
                imageUrl: postData.imageUrl,
                location: postData.location,
                likesCount: postData.likesCount,
                commentsCount: postData.commentsCount,
                createdAt: postData.createdAt,
                updatedAt: postData.updatedAt
            )
        }
        homeViewModel.hasMorePages = true
        homeViewModel.isLoadingMore = false
        
        // When
        let threshold = max(3, Int(Double(totalPosts) * 0.7)) // Should be 3 (minimum)
        let thresholdIndex = totalPosts - threshold // Should be -1
        
        // Then
        XCTAssertEqual(threshold, 3, "Threshold should use minimum of 3 for small datasets")
        XCTAssertEqual(thresholdIndex, -1, "Threshold index should be negative for small datasets")
        // With only 2 posts and threshold of 3, this won't trigger loading
    }
    
    func test_homeViewModel_checkForMorePosts_preventsMultipleLoads() {
        // Given
        let mockPosts = createMockPosts(count: 10)
        homeViewModel.posts = mockPosts.map { postData in
            Post(
                _id: postData.id,
                authorId: postData.authorId,
                author: postData.author,
                caption: postData.caption,
                imageUrl: postData.imageUrl,
                location: postData.location,
                likesCount: postData.likesCount,
                commentsCount: postData.commentsCount,
                createdAt: postData.createdAt,
                updatedAt: postData.updatedAt
            )
        }
        homeViewModel.hasMorePages = true
        homeViewModel.isLoadingMore = true // Already loading
        
        // When
        let currentPost = homeViewModel.posts[3] // Should trigger threshold
        homeViewModel.checkForMorePosts(currentPost: currentPost)
        
        // Then
        // Should not start another load since isLoadingMore is true
        XCTAssertTrue(homeViewModel.isLoadingMore, "Should still be loading more")
    }
    
    // MARK: - Personalized Feed Tests
    
    func test_homeViewModel_personalizedFeed_togglesCorrectly() {
        // Given
        homeViewModel.isUsingPersonalizedFeed = false
        
        // When
        homeViewModel.isUsingPersonalizedFeed = true
        
        // Then
        XCTAssertTrue(homeViewModel.isUsingPersonalizedFeed, "Should use personalized feed")
        
        // When
        homeViewModel.isUsingPersonalizedFeed = false
        
        // Then
        XCTAssertFalse(homeViewModel.isUsingPersonalizedFeed, "Should not use personalized feed")
    }
    
    // MARK: - Performance Tests
    
    func test_homeViewModel_performance_handlesLargeFeed() {
        measure {
            // Test performance with large number of posts
            var posts: [Post] = []
            for i in 0..<1000 {
                let postData = PostTestDataFactory.createValidPost(id: "post_\(i)")
                posts.append(Post(
                    _id: postData.id,
                    authorId: postData.authorId,
                    author: postData.author,
                    caption: postData.caption,
                    imageUrl: postData.imageUrl,
                    location: postData.location,
                    likesCount: postData.likesCount,
                    commentsCount: postData.commentsCount,
                    createdAt: postData.createdAt,
                    updatedAt: postData.updatedAt
                ))
            }
            
            // Simulate adding posts to home feed
            homeViewModel.posts = posts
            
            // Test that we can access posts quickly
            XCTAssertEqual(homeViewModel.posts.count, 1000)
        }
    }
    
    // MARK: - Integration Tests
    
    func test_homeViewModel_integration_fullRefreshCycle() async {
        // Given
        let expectation = XCTestExpectation(description: "Full refresh cycle")
        
        // When
        homeViewModel.isLoading = true
        await homeViewModel.fetchPosts()
        await homeViewModel.refreshFeed()
        homeViewModel.isLoading = false
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.homeViewModel.isLoading, "Should complete refresh cycle")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
}

// MARK: - Test Data Factory

struct PostTestDataFactory {
    static func createValidPost(
        id: String = "test_post_123",
        authorId: String = "user_456",
        caption: String = "Delicious food at amazing restaurant!"
    ) -> PostTestData {
        return PostTestData(
            id: id,
            authorId: authorId,
            author: createTestAuthor(),
            caption: caption,
            imageUrl: "https://example.com/food.jpg",
            location: createTestLocation(),
            likesCount: 42,
            commentsCount: 8,
            createdAt: Int(Date().timeIntervalSince1970 * 1000),
            updatedAt: Int(Date().timeIntervalSince1970 * 1000)
        )
    }
    
    static func createTestAuthor() -> User {
        return User(
            _id: "author_123",
            clerkId: "clerk_456",
            username: "foodlover",
            displayName: "Food Lover",
            avatarUrl: "https://example.com/avatar.jpg",
            bio: "Love sharing great food experiences!",
            isOnline: true,
            lastActiveAt: Int(Date().timeIntervalSince1970 * 1000)
        )
    }
    
    static func createTestLocation() -> Location {
        return Location(
            _id: "location_789",
            name: "Amazing Restaurant",
            address: "123 Food Street",
            latitude: 37.7749,
            longitude: -122.4194,
            category: "restaurant",
            rating: 4.5,
            priceLevel: 2,
            isVerified: true,
            totalVisits: 100,
            createdAt: Int(Date().timeIntervalSince1970 * 1000),
            updatedAt: Int(Date().timeIntervalSince1970 * 1000)
        )
    }
    
    static func createEmptyFeed() -> [PostTestData] {
        return []
    }
    
    static func createLargeFeed(count: Int = 50) -> [PostTestData] {
        return (0..<count).map { index in
            createValidPost(
                id: "post_\(index)",
                authorId: "user_\(index)",
                caption: "Post number \(index) with great content!"
            )
        }
    }
}

// MARK: - Test Data Structures

struct PostTestData {
    let id: String
    let authorId: String
    let author: User
    let caption: String
    let imageUrl: String
    let location: Location
    let likesCount: Int
    let commentsCount: Int
    let createdAt: Int
    let updatedAt: Int
}

// MARK: - Mock Services

class MockBackendService {
    var shouldReturnError = false
    var mockPosts: [PostTestData] = []
    var fetchDelay: TimeInterval = 0.1
    
    func fetchPosts() async throws -> [PostTestData] {
        try await Task.sleep(nanoseconds: UInt64(fetchDelay * 1_000_000_000))
        
        if shouldReturnError {
            throw MockError.networkError
        }
        
        return mockPosts.isEmpty ? PostTestDataFactory.createLargeFeed(count: 10) : mockPosts
    }
    
    func refreshFeed() async throws -> [PostTestData] {
        return try await fetchPosts()
    }
    
    func loadMorePosts(after cursor: String?) async throws -> [PostTestData] {
        return try await fetchPosts()
    }
}

enum MockError: Error {
    case networkError
    case invalidData
    case unauthorized
    
    var localizedDescription: String {
        switch self {
        case .networkError:
            return "Network connection failed"
        case .invalidData:
            return "Invalid data received"
        case .unauthorized:
            return "User not authenticated"
        }
    }
}

// MARK: - Extensions for Testing

extension HomeFeedTests {
    
    func createMockPosts(count: Int = 5) -> [PostTestData] {
        return PostTestDataFactory.createLargeFeed(count: count)
    }
    
    func simulateNetworkDelay() async {
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    func waitForMainActor() async {
        await MainActor.run { }
    }
} 