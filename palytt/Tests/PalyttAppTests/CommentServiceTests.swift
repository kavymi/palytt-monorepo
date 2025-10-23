//
//  CommentServiceTests.swift
//  PalyttAppTests
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import XCTest
@testable import PalyttApp

@MainActor
final class CommentServiceTests: XCTestCase {
    
    var sut: CommentService!
    var mockAPIClient: MockAPIClient!
    
    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        sut = CommentService(apiClient: mockAPIClient)
    }
    
    override func tearDown() {
        sut = nil
        mockAPIClient = nil
        super.tearDown()
    }
    
    // MARK: - Get Comments Tests
    
    func testGetComments_Success() async throws {
        // Given
        let mockComments = [createMockCommentDTO(), createMockCommentDTO()]
        let response = GetCommentsResponse(comments: mockComments, total: 2, hasMore: false, nextCursor: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let comments = try await sut.getComments(postId: "post123", page: 1, limit: 20)
        
        // Then
        XCTAssertEqual(comments.count, 2)
        XCTAssertEqual(mockAPIClient.lastRequestPath, "trpc/comments.getComments")
    }
    
    func testGetComments_EmptyResults() async throws {
        // Given
        let response = GetCommentsResponse(comments: [], total: 0, hasMore: false, nextCursor: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let comments = try await sut.getComments(postId: "post123", page: 1, limit: 20)
        
        // Then
        XCTAssertEqual(comments.count, 0)
    }
    
    // MARK: - Add Comment Tests
    
    func testAddComment_Success() async throws {
        // Given
        let mockComment = createMockCommentDTO()
        let response = AddCommentResponse(success: true, comment: mockComment)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let comment = try await sut.addComment(postId: "post123", content: "Great post!", parentCommentId: nil)
        
        // Then
        XCTAssertNotNil(comment)
        XCTAssertEqual(mockAPIClient.lastRequestPath, "trpc/comments.addComment")
    }
    
    func testAddCommentReply_Success() async throws {
        // Given
        let mockComment = createMockCommentDTO()
        let response = AddCommentResponse(success: true, comment: mockComment)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let comment = try await sut.addComment(
            postId: "post123",
            content: "Thanks!",
            parentCommentId: "comment456"
        )
        
        // Then
        XCTAssertNotNil(comment)
    }
    
    // MARK: - Toggle Comment Like Tests
    
    func testToggleCommentLike_Like() async throws {
        // Given
        let response = ToggleCommentLikeResponse(success: true, isLiked: true, likesCount: 1)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let result = try await sut.toggleCommentLike(commentId: "comment123")
        
        // Then
        XCTAssertTrue(result.isLiked)
        XCTAssertEqual(result.likesCount, 1)
    }
    
    func testToggleCommentLike_Unlike() async throws {
        // Given
        let response = ToggleCommentLikeResponse(success: true, isLiked: false, likesCount: 0)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let result = try await sut.toggleCommentLike(commentId: "comment123")
        
        // Then
        XCTAssertFalse(result.isLiked)
        XCTAssertEqual(result.likesCount, 0)
    }
    
    // MARK: - Get Recent Comments Tests
    
    func testGetRecentComments_Success() async throws {
        // Given
        let mockComments = [createMockCommentDTO(), createMockCommentDTO()]
        struct GetRecentCommentsResponse: Codable {
            let comments: [CommentDTO]
        }
        let response = GetRecentCommentsResponse(comments: mockComments)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let comments = try await sut.getRecentComments(postId: "post123", limit: 2)
        
        // Then
        XCTAssertEqual(comments.count, 2)
    }
    
    // MARK: - Helper Methods
    
    private func createMockCommentDTO() -> CommentDTO {
        return CommentDTO(
            id: UUID().uuidString,
            postId: "post123",
            authorId: "user123",
            authorClerkId: "clerk_test",
            content: "Test comment",
            parentCommentId: nil,
            likesCount: 0,
            repliesCount: 0,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            isLiked: false,
            authorUsername: "testuser",
            authorDisplayName: "Test User",
            authorProfileImageUrl: nil
        )
    }
}

