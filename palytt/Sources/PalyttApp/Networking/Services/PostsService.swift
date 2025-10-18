//
//  PostsService.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation

/// Protocol for posts service
protocol PostsServiceProtocol {
    func getPosts(page: Int, limit: Int) async throws -> [Post]
    func getPostsByUser(userId: String) async throws -> [Post]
    func getBookmarkedPosts() async throws -> [Post]
    func createPost(_ request: CreatePostRequest) async throws -> Post
    func toggleLike(postId: String) async throws -> LikeResponse
    func toggleBookmark(postId: String) async throws -> BookmarkResponse
    func getPostLikes(postId: String, limit: Int, cursor: String?) async throws -> PostLikesDTO
}

/// Service for managing posts
final class PostsService: PostsServiceProtocol {
    
    // MARK: - Properties
    
    private let apiClient: APIClientProtocol
    
    // MARK: - Initialization
    
    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }
    
    // Convenience initializer with default client
    convenience init(baseURL: URL) {
        let client = APIClient(baseURL: baseURL)
        self.init(apiClient: client)
    }
    
    // MARK: - Public Methods
    
    /// Get recent posts
    /// - Parameters:
    ///   - page: Page number (1-based)
    ///   - limit: Number of posts per page
    /// - Returns: Array of posts
    /// - Throws: APIError if request fails
    func getPosts(page: Int = 1, limit: Int = 20) async throws -> [Post] {
        let request = GetPostsRequest(page: page, limit: limit)
        
        let response: GetPostsResponse = try await apiClient.call(
            procedure: "posts.getRecentPosts",
            input: request,
            method: .get
        )
        
        return response.posts.map { $0.toPost() }
    }
    
    /// Get posts by a specific user
    /// - Parameter userId: User ID to fetch posts for
    /// - Returns: Array of user's posts
    /// - Throws: APIError if request fails
    func getPostsByUser(userId: String) async throws -> [Post] {
        struct Request: Codable {
            let userId: String
        }
        
        let request = Request(userId: userId)
        
        let response: [PostDTO] = try await apiClient.call(
            procedure: "posts.getByUser",
            input: request,
            method: .get
        )
        
        return response.map { $0.toPost() }
    }
    
    /// Get bookmarked posts for current user
    /// - Returns: Array of bookmarked posts
    /// - Throws: APIError if request fails
    func getBookmarkedPosts() async throws -> [Post] {
        let response: [PostDTO] = try await apiClient.call(
            procedure: "posts.getBookmarked",
            method: .get
        )
        
        return response.map { $0.toPost() }
    }
    
    /// Create a new post
    /// - Parameter request: Post creation data
    /// - Returns: Created post
    /// - Throws: APIError if request fails
    func createPost(_ request: CreatePostRequest) async throws -> Post {
        struct CreateResponse: Codable {
            let success: Bool
            let post: PostDTO
        }
        
        let response: CreateResponse = try await apiClient.call(
            procedure: "posts.create",
            input: request,
            method: .post
        )
        
        guard response.success else {
            throw APIError.serverError(statusCode: 500, message: "Failed to create post")
        }
        
        return response.post.toPost()
    }
    
    /// Toggle like on a post
    /// - Parameter postId: Post ID to like/unlike
    /// - Returns: Updated like status
    /// - Throws: APIError if request fails
    func toggleLike(postId: String) async throws -> LikeResponse {
        struct Request: Codable {
            let postId: String
        }
        
        let request = Request(postId: postId)
        
        return try await apiClient.call(
            procedure: "posts.toggleLike",
            input: request,
            method: .post
        )
    }
    
    /// Toggle bookmark on a post
    /// - Parameter postId: Post ID to bookmark/unbookmark
    /// - Returns: Updated bookmark status
    /// - Throws: APIError if request fails
    func toggleBookmark(postId: String) async throws -> BookmarkResponse {
        struct Request: Codable {
            let postId: String
        }
        
        let request = Request(postId: postId)
        
        return try await apiClient.call(
            procedure: "posts.toggleBookmark",
            input: request,
            method: .post
        )
    }
    
    /// Get users who liked a post
    /// - Parameters:
    ///   - postId: Post ID
    ///   - limit: Maximum number of users to return
    ///   - cursor: Pagination cursor
    /// - Returns: Users who liked the post
    /// - Throws: APIError if request fails
    func getPostLikes(
        postId: String,
        limit: Int = 20,
        cursor: String? = nil
    ) async throws -> PostLikesDTO {
        struct Request: Codable {
            let postId: String
            let limit: Int
            let cursor: String?
        }
        
        let request = Request(
            postId: postId,
            limit: limit,
            cursor: cursor
        )
        
        return try await apiClient.call(
            procedure: "posts.getLikes",
            input: request,
            method: .get
        )
    }
}

// MARK: - Testing Support

#if DEBUG
/// Mock posts service for testing
final class MockPostsService: PostsServiceProtocol {
    var shouldFail = false
    var mockError: APIError?
    var mockPosts: [Post] = []
    var mockLikeResponse = LikeResponse(success: true, isLiked: true, likesCount: 1)
    var mockBookmarkResponse = BookmarkResponse(success: true, isBookmarked: true)
    
    func getPosts(page: Int, limit: Int) async throws -> [Post] {
        if shouldFail {
            throw mockError ?? APIError.unknown(NSError(domain: "MockPostsService", code: -1))
        }
        return mockPosts
    }
    
    func getPostsByUser(userId: String) async throws -> [Post] {
        if shouldFail {
            throw mockError ?? APIError.unknown(NSError(domain: "MockPostsService", code: -1))
        }
        return mockPosts
    }
    
    func getBookmarkedPosts() async throws -> [Post] {
        if shouldFail {
            throw mockError ?? APIError.unknown(NSError(domain: "MockPostsService", code: -1))
        }
        return mockPosts
    }
    
    func createPost(_ request: CreatePostRequest) async throws -> Post {
        if shouldFail {
            throw mockError ?? APIError.unknown(NSError(domain: "MockPostsService", code: -1))
        }
        return mockPosts.first ?? Post(
            id: UUID(),
            userId: UUID(),
            author: User(id: UUID(), email: "test@test.com", username: "test", displayName: "Test"),
            caption: request.description ?? "",
            mediaURLs: [],
            location: Location(latitude: 0, longitude: 0, address: "", city: "", country: "")
        )
    }
    
    func toggleLike(postId: String) async throws -> LikeResponse {
        if shouldFail {
            throw mockError ?? APIError.unknown(NSError(domain: "MockPostsService", code: -1))
        }
        return mockLikeResponse
    }
    
    func toggleBookmark(postId: String) async throws -> BookmarkResponse {
        if shouldFail {
            throw mockError ?? APIError.unknown(NSError(domain: "MockPostsService", code: -1))
        }
        return mockBookmarkResponse
    }
    
    func getPostLikes(postId: String, limit: Int, cursor: String?) async throws -> PostLikesDTO {
        if shouldFail {
            throw mockError ?? APIError.unknown(NSError(domain: "MockPostsService", code: -1))
        }
        return PostLikesDTO(users: [], total: 0, hasMore: false)
    }
}
#endif

