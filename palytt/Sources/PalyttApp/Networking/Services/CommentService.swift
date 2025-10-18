//
//  CommentService.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation

// MARK: - Protocol

protocol CommentServiceProtocol {
    func getComments(postId: String, page: Int, limit: Int) async throws -> [Comment]
    func addComment(postId: String, content: String, parentCommentId: String?) async throws -> Comment
    func toggleCommentLike(commentId: String) async throws -> (isLiked: Bool, likesCount: Int)
    func getRecentComments(postId: String, limit: Int) async throws -> [Comment]
}

// MARK: - Service Implementation

@MainActor
final class CommentService: CommentServiceProtocol {
    
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }
    
    convenience init(baseURL: URL) {
        let apiClient = APIClient(baseURL: baseURL)
        self.init(apiClient: apiClient)
    }
    
    // MARK: - Get Comments
    
    func getComments(postId: String, page: Int = 1, limit: Int = 20) async throws -> [Comment] {
        print("💬 CommentService: Getting comments for post \(postId) (page \(page))")
        
        let request = GetCommentsRequest(
            postId: postId,
            page: page,
            limit: limit,
            parentCommentId: nil
        )
        
        let response = try await apiClient.request(
            path: "trpc/comments.getComments",
            method: .get,
            parameters: request,
            responseType: GetCommentsResponse.self
        )
        
        print("✅ CommentService: Retrieved \(response.comments.count) comments")
        return response.comments.map { Comment.from(commentDTO: $0) }
    }
    
    // MARK: - Add Comment
    
    func addComment(postId: String, content: String, parentCommentId: String? = nil) async throws -> Comment {
        if let parentId = parentCommentId {
            print("💬 CommentService: Adding reply to comment \(parentId)")
        } else {
            print("💬 CommentService: Adding comment to post \(postId)")
        }
        
        let request = AddCommentRequest(
            postId: postId,
            content: content,
            parentCommentId: parentCommentId
        )
        
        let response = try await apiClient.request(
            path: "trpc/comments.addComment",
            method: .post,
            parameters: request,
            responseType: AddCommentResponse.self
        )
        
        guard response.success else {
            throw APIError.serverError(message: "Failed to add comment")
        }
        
        print("✅ CommentService: Successfully added comment")
        return Comment.from(commentDTO: response.comment)
    }
    
    // MARK: - Toggle Comment Like
    
    func toggleCommentLike(commentId: String) async throws -> (isLiked: Bool, likesCount: Int) {
        print("❤️ CommentService: Toggling like for comment \(commentId)")
        
        let request = ToggleCommentLikeRequest(commentId: commentId)
        
        let response = try await apiClient.request(
            path: "trpc/comments.toggleLike",
            method: .post,
            parameters: request,
            responseType: ToggleCommentLikeResponse.self
        )
        
        guard response.success else {
            throw APIError.serverError(message: "Failed to toggle comment like")
        }
        
        let action = response.isLiked ? "Liked" : "Unliked"
        print("✅ CommentService: \(action) comment (total: \(response.likesCount))")
        return (response.isLiked, response.likesCount)
    }
    
    // MARK: - Get Recent Comments
    
    func getRecentComments(postId: String, limit: Int = 2) async throws -> [Comment] {
        print("💬 CommentService: Getting recent comments for post \(postId)")
        
        let request = GetRecentCommentsRequest(postId: postId, limit: limit)
        
        struct GetRecentCommentsResponse: Decodable {
            let comments: [CommentDTO]
        }
        
        let response = try await apiClient.request(
            path: "trpc/comments.getRecent",
            method: .get,
            parameters: request,
            responseType: GetRecentCommentsResponse.self
        )
        
        print("✅ CommentService: Retrieved \(response.comments.count) recent comments")
        return response.comments.map { Comment.from(commentDTO: $0) }
    }
}

// MARK: - Mock Implementation for Testing

#if DEBUG
final class MockCommentService: CommentServiceProtocol {
    var mockComments: [Comment] = []
    var mockComment: Comment?
    var shouldFail = false
    var mockError: APIError = .networkError(URLError(.notConnectedToInternet))
    var mockIsLiked = false
    var mockLikesCount = 0
    
    func getComments(postId: String, page: Int, limit: Int) async throws -> [Comment] {
        if shouldFail { throw mockError }
        return mockComments
    }
    
    func addComment(postId: String, content: String, parentCommentId: String?) async throws -> Comment {
        if shouldFail { throw mockError }
        return mockComment ?? createMockComment()
    }
    
    func toggleCommentLike(commentId: String) async throws -> (isLiked: Bool, likesCount: Int) {
        if shouldFail { throw mockError }
        return (mockIsLiked, mockLikesCount)
    }
    
    func getRecentComments(postId: String, limit: Int) async throws -> [Comment] {
        if shouldFail { throw mockError }
        return Array(mockComments.prefix(limit))
    }
    
    private func createMockComment() -> Comment {
        return Comment(
            id: UUID(),
            postId: UUID(),
            userId: UUID(),
            author: nil,
            content: "Mock comment"
        )
    }
}
#endif

