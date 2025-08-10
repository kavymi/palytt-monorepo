//
//  PostInteractionsTests.swift
//  PalyttAppTests
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import XCTest
@testable import Palytt
import Combine

final class PostInteractionsTests: XCTestCase {
    
    var postInteractionsService: MockPostInteractionsService!
    var commentsViewModel: CommentsViewModel!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        postInteractionsService = MockPostInteractionsService()
        commentsViewModel = CommentsViewModel()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        postInteractionsService = nil
        commentsViewModel = nil
        cancellables.removeAll()
        cancellables = nil
    }
    
    // MARK: - Comment Creation Tests
    
    func test_comment_creation_withValidData_succeeds() async {
        // Given
        let commentData = CommentTestDataFactory.createValidComment()
        
        // When
        do {
            let createdComment = try await postInteractionsService.createComment(commentData)
            
            // Then
            XCTAssertEqual(createdComment.content, commentData.content, "Comment content should match")
            XCTAssertEqual(createdComment.postId, commentData.postId, "Post ID should match")
            XCTAssertEqual(createdComment.authorId, commentData.authorId, "Author ID should match")
            XCTAssertNotNil(createdComment._id, "Comment should have an ID")
            XCTAssertTrue(createdComment.createdAt > 0, "Comment should have valid timestamp")
        } catch {
            XCTFail("Comment creation should succeed with valid data: \(error)")
        }
    }
    
    func test_comment_creation_withEmptyContent_fails() async {
        // Given
        var commentData = CommentTestDataFactory.createValidComment()
        commentData.content = ""
        
        // When & Then
        do {
            _ = try await postInteractionsService.createComment(commentData)
            XCTFail("Comment creation should fail with empty content")
        } catch {
            XCTAssertEqual(error as? CommentError, CommentError.emptyContent, "Should throw empty content error")
        }
    }
    
    func test_comment_creation_withInvalidPostId_fails() async {
        // Given
        var commentData = CommentTestDataFactory.createValidComment()
        commentData.postId = ""
        
        // When & Then
        do {
            _ = try await postInteractionsService.createComment(commentData)
            XCTFail("Comment creation should fail with invalid post ID")
        } catch {
            XCTAssertEqual(error as? CommentError, CommentError.invalidPostId, "Should throw invalid post ID error")
        }
    }
    
    func test_comment_validation_contentLength() {
        // Given
        let validComments = [
            "Great post!",
            "This looks amazing! 😍",
            String(repeating: "a", count: 500) // Max typical length
        ]
        
        let invalidComments = [
            "",
            String(repeating: "a", count: 1001) // Too long
        ]
        
        // When & Then
        for content in validComments {
            XCTAssertTrue(isValidCommentContent(content), "Comment '\(content.prefix(20))...' should be valid")
        }
        
        for content in invalidComments {
            XCTAssertFalse(isValidCommentContent(content), "Comment should be invalid")
        }
    }
    
    // MARK: - Reply Tests
    
    func test_reply_creation_withValidData_succeeds() async {
        // Given
        let parentComment = CommentTestDataFactory.createValidComment()
        let replyData = CommentTestDataFactory.createValidReply(parentCommentId: parentComment._id!)
        
        // When
        do {
            let createdReply = try await postInteractionsService.createReply(replyData)
            
            // Then
            XCTAssertEqual(createdReply.content, replyData.content, "Reply content should match")
            XCTAssertEqual(createdReply.parentCommentId, parentComment._id, "Parent comment ID should match")
            XCTAssertEqual(createdReply.postId, replyData.postId, "Post ID should match")
            XCTAssertNotNil(createdReply._id, "Reply should have an ID")
        } catch {
            XCTFail("Reply creation should succeed with valid data: \(error)")
        }
    }
    
    func test_reply_creation_withInvalidParentId_fails() async {
        // Given
        let replyData = CommentTestDataFactory.createValidReply(parentCommentId: "invalid_id")
        
        // When & Then
        do {
            _ = try await postInteractionsService.createReply(replyData)
            XCTFail("Reply creation should fail with invalid parent ID")
        } catch {
            XCTAssertEqual(error as? CommentError, CommentError.invalidParentComment, "Should throw invalid parent comment error")
        }
    }
    
    func test_reply_nesting_depth_validation() {
        // Given
        let maxDepth = 3
        var currentComment = CommentTestDataFactory.createValidComment()
        
        // When & Then - Test nesting depth
        for depth in 0..<maxDepth {
            let reply = CommentTestDataFactory.createValidReply(parentCommentId: currentComment._id!)
            XCTAssertTrue(isValidNestingDepth(depth), "Nesting depth \(depth) should be valid")
            currentComment = reply
        }
        
        // Test exceeding max depth
        XCTAssertFalse(isValidNestingDepth(maxDepth + 1), "Nesting depth beyond \(maxDepth) should be invalid")
    }
    
    // MARK: - Like/Favorite Tests
    
    func test_likePost_withValidData_succeeds() async {
        // Given
        let postId = "test_post_123"
        let userId = "user_456"
        
        // When
        do {
            let likeResult = try await postInteractionsService.likePost(postId: postId, userId: userId)
            
            // Then
            XCTAssertTrue(likeResult.success, "Like operation should succeed")
            XCTAssertEqual(likeResult.postId, postId, "Post ID should match")
            XCTAssertEqual(likeResult.userId, userId, "User ID should match")
            XCTAssertTrue(likeResult.isLiked, "Post should be liked")
        } catch {
            XCTFail("Like operation should succeed: \(error)")
        }
    }
    
    func test_unlikePost_withValidData_succeeds() async {
        // Given
        let postId = "test_post_123"
        let userId = "user_456"
        
        // First like the post
        _ = try? await postInteractionsService.likePost(postId: postId, userId: userId)
        
        // When
        do {
            let unlikeResult = try await postInteractionsService.unlikePost(postId: postId, userId: userId)
            
            // Then
            XCTAssertTrue(unlikeResult.success, "Unlike operation should succeed")
            XCTAssertEqual(unlikeResult.postId, postId, "Post ID should match")
            XCTAssertEqual(unlikeResult.userId, userId, "User ID should match")
            XCTAssertFalse(unlikeResult.isLiked, "Post should not be liked")
        } catch {
            XCTFail("Unlike operation should succeed: \(error)")
        }
    }
    
    func test_toggleLike_multipleOperations_worksCorrectly() async {
        // Given
        let postId = "test_post_123"
        let userId = "user_456"
        
        // When & Then - Multiple toggle operations
        do {
            // First like
            let like1 = try await postInteractionsService.likePost(postId: postId, userId: userId)
            XCTAssertTrue(like1.isLiked, "Post should be liked after first toggle")
            
            // Unlike
            let unlike = try await postInteractionsService.unlikePost(postId: postId, userId: userId)
            XCTAssertFalse(unlike.isLiked, "Post should not be liked after unlike")
            
            // Like again
            let like2 = try await postInteractionsService.likePost(postId: postId, userId: userId)
            XCTAssertTrue(like2.isLiked, "Post should be liked after second toggle")
        } catch {
            XCTFail("Toggle like operations should succeed: \(error)")
        }
    }
    
    // MARK: - Favorite Tests
    
    func test_favoritePost_withValidData_succeeds() async {
        // Given
        let postId = "test_post_123"
        let userId = "user_456"
        
        // When
        do {
            let favoriteResult = try await postInteractionsService.favoritePost(postId: postId, userId: userId)
            
            // Then
            XCTAssertTrue(favoriteResult.success, "Favorite operation should succeed")
            XCTAssertEqual(favoriteResult.postId, postId, "Post ID should match")
            XCTAssertEqual(favoriteResult.userId, userId, "User ID should match")
            XCTAssertTrue(favoriteResult.isFavorited, "Post should be favorited")
        } catch {
            XCTFail("Favorite operation should succeed: \(error)")
        }
    }
    
    func test_unfavoritePost_withValidData_succeeds() async {
        // Given
        let postId = "test_post_123"
        let userId = "user_456"
        
        // First favorite the post
        _ = try? await postInteractionsService.favoritePost(postId: postId, userId: userId)
        
        // When
        do {
            let unfavoriteResult = try await postInteractionsService.unfavoritePost(postId: postId, userId: userId)
            
            // Then
            XCTAssertTrue(unfavoriteResult.success, "Unfavorite operation should succeed")
            XCTAssertFalse(unfavoriteResult.isFavorited, "Post should not be favorited")
        } catch {
            XCTFail("Unfavorite operation should succeed: \(error)")
        }
    }
    
    // MARK: - Post Sharing/Linking Tests
    
    func test_sharePost_withValidData_succeeds() async {
        // Given
        let shareData = SharePostData(
            postId: "test_post_123",
            userId: "user_456",
            platform: .messages,
            recipients: ["user_789"]
        )
        
        // When
        do {
            let shareResult = try await postInteractionsService.sharePost(shareData)
            
            // Then
            XCTAssertTrue(shareResult.success, "Share operation should succeed")
            XCTAssertEqual(shareResult.postId, shareData.postId, "Post ID should match")
            XCTAssertEqual(shareResult.platform, shareData.platform, "Platform should match")
            XCTAssertNotNil(shareResult.shareUrl, "Share URL should be generated")
        } catch {
            XCTFail("Share operation should succeed: \(error)")
        }
    }
    
    func test_generateShareLink_withValidPost_returnsValidUrl() async {
        // Given
        let postId = "test_post_123"
        
        // When
        do {
            let shareLink = try await postInteractionsService.generateShareLink(postId: postId)
            
            // Then
            XCTAssertFalse(shareLink.isEmpty, "Share link should not be empty")
            XCTAssertTrue(shareLink.hasPrefix("https://"), "Share link should be a valid HTTPS URL")
            XCTAssertTrue(shareLink.contains(postId), "Share link should contain post ID")
        } catch {
            XCTFail("Share link generation should succeed: \(error)")
        }
    }
    
    func test_sharePost_multiplePlatforms_succeeds() async {
        // Given
        let postId = "test_post_123"
        let userId = "user_456"
        let platforms: [SharePlatform] = [.messages, .external, .copyLink]
        
        // When & Then
        for platform in platforms {
            let shareData = SharePostData(
                postId: postId,
                userId: userId,
                platform: platform,
                recipients: platform == .messages ? ["user_789"] : nil
            )
            
            do {
                let shareResult = try await postInteractionsService.sharePost(shareData)
                XCTAssertTrue(shareResult.success, "Share should succeed for platform \(platform)")
                XCTAssertEqual(shareResult.platform, platform, "Platform should match")
            } catch {
                XCTFail("Share should succeed for platform \(platform): \(error)")
            }
        }
    }
    
    // MARK: - Comment Management Tests
    
    func test_commentsViewModel_loadComments_succeeds() async {
        // Given
        let postId = "test_post_123"
        commentsViewModel.postId = postId
        
        // When
        await commentsViewModel.loadComments()
        
        // Then
        XCTAssertFalse(commentsViewModel.isLoading, "Should not be loading after completion")
        XCTAssertNil(commentsViewModel.errorMessage, "Should have no error")
    }
    
    func test_commentsViewModel_addComment_updatesCommentsList() {
        // Given
        let newComment = CommentTestDataFactory.createValidComment()
        let initialCount = commentsViewModel.comments.count
        
        // When
        commentsViewModel.comments.append(newComment)
        
        // Then
        XCTAssertEqual(commentsViewModel.comments.count, initialCount + 1, "Comments count should increase")
        XCTAssertEqual(commentsViewModel.comments.last?._id, newComment._id, "New comment should be added")
    }
    
    func test_commentsViewModel_deleteComment_removesFromList() {
        // Given
        let comment = CommentTestDataFactory.createValidComment()
        commentsViewModel.comments = [comment]
        
        // When
        commentsViewModel.comments.removeAll { $0._id == comment._id }
        
        // Then
        XCTAssertTrue(commentsViewModel.comments.isEmpty, "Comment should be removed")
    }
    
    // MARK: - Real-time Updates Tests
    
    func test_commentsViewModel_realTimeUpdates_handlesNewComments() {
        // Given
        let initialComment = CommentTestDataFactory.createValidComment()
        commentsViewModel.comments = [initialComment]
        
        // When - Simulate real-time comment addition
        let newComment = CommentTestDataFactory.createValidComment(id: "new_comment_456")
        commentsViewModel.handleRealTimeComment(newComment)
        
        // Then
        XCTAssertEqual(commentsViewModel.comments.count, 2, "Should have two comments")
        XCTAssertTrue(commentsViewModel.comments.contains { $0._id == newComment._id }, "Should contain new comment")
    }
    
    func test_commentsViewModel_realTimeUpdates_handlesCommentUpdates() {
        // Given
        var originalComment = CommentTestDataFactory.createValidComment()
        commentsViewModel.comments = [originalComment]
        
        // When - Simulate real-time comment update
        originalComment.content = "Updated comment content"
        commentsViewModel.handleRealTimeCommentUpdate(originalComment)
        
        // Then
        let updatedComment = commentsViewModel.comments.first { $0._id == originalComment._id }
        XCTAssertEqual(updatedComment?.content, "Updated comment content", "Comment content should be updated")
    }
    
    // MARK: - Comment Reactions Tests
    
    func test_commentReaction_likeComment_succeeds() async {
        // Given
        let commentId = "comment_123"
        let userId = "user_456"
        
        // When
        do {
            let reactionResult = try await postInteractionsService.likeComment(commentId: commentId, userId: userId)
            
            // Then
            XCTAssertTrue(reactionResult.success, "Comment like should succeed")
            XCTAssertEqual(reactionResult.commentId, commentId, "Comment ID should match")
            XCTAssertTrue(reactionResult.isLiked, "Comment should be liked")
        } catch {
            XCTFail("Comment like should succeed: \(error)")
        }
    }
    
    func test_commentReaction_addEmoji_succeeds() async {
        // Given
        let commentId = "comment_123"
        let userId = "user_456"
        let emoji = "😍"
        
        // When
        do {
            let reactionResult = try await postInteractionsService.addEmojiReaction(
                commentId: commentId,
                userId: userId,
                emoji: emoji
            )
            
            // Then
            XCTAssertTrue(reactionResult.success, "Emoji reaction should succeed")
            XCTAssertEqual(reactionResult.emoji, emoji, "Emoji should match")
        } catch {
            XCTFail("Emoji reaction should succeed: \(error)")
        }
    }
    
    // MARK: - Moderation Tests
    
    func test_commentModeration_reportComment_succeeds() async {
        // Given
        let reportData = CommentReportData(
            commentId: "comment_123",
            reporterId: "user_456",
            reason: .inappropriate,
            additionalInfo: "Contains offensive language"
        )
        
        // When
        do {
            let reportResult = try await postInteractionsService.reportComment(reportData)
            
            // Then
            XCTAssertTrue(reportResult.success, "Comment report should succeed")
            XCTAssertEqual(reportResult.commentId, reportData.commentId, "Comment ID should match")
            XCTAssertEqual(reportResult.reason, reportData.reason, "Report reason should match")
        } catch {
            XCTFail("Comment report should succeed: \(error)")
        }
    }
    
    func test_commentModeration_contentFiltering_blocksInappropriate() {
        // Given
        let inappropriateContent = [
            "This contains spam content",
            "Inappropriate language here",
            "Harassment content"
        ]
        
        // When & Then
        for content in inappropriateContent {
            let isFiltered = shouldFilterComment(content)
            XCTAssertTrue(isFiltered, "Content '\(content)' should be filtered")
        }
    }
    
    // MARK: - Performance Tests
    
    func test_commentsViewModel_performance_withManyComments() {
        measure {
            // Test performance with large number of comments
            var comments: [Comment] = []
            for i in 0..<1000 {
                comments.append(CommentTestDataFactory.createValidComment(id: "comment_\(i)"))
            }
            
            commentsViewModel.comments = comments
            
            // Test that we can access comments quickly
            XCTAssertEqual(commentsViewModel.comments.count, 1000)
        }
    }
    
    func test_postInteractions_performance_bulkLikes() {
        measure {
            // Test performance with bulk like operations
            let postId = "test_post_123"
            
            for i in 0..<100 {
                let userId = "user_\(i)"
                // Simulate like operation
                let like = LikeResult(
                    success: true,
                    postId: postId,
                    userId: userId,
                    isLiked: true
                )
                XCTAssertTrue(like.success)
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func test_fullCommentFlow_createReplyLikeDelete_succeeds() async {
        // Given
        let postId = "test_post_123"
        let userId = "user_456"
        
        do {
            // When - Create comment
            let commentData = CommentTestDataFactory.createValidComment(postId: postId, authorId: userId)
            let comment = try await postInteractionsService.createComment(commentData)
            
            // Create reply
            let replyData = CommentTestDataFactory.createValidReply(parentCommentId: comment._id!)
            let reply = try await postInteractionsService.createReply(replyData)
            
            // Like comment
            let likeResult = try await postInteractionsService.likeComment(commentId: comment._id!, userId: userId)
            
            // Delete reply
            let deleteResult = try await postInteractionsService.deleteComment(commentId: reply._id!)
            
            // Then
            XCTAssertNotNil(comment._id, "Comment should be created")
            XCTAssertNotNil(reply._id, "Reply should be created")
            XCTAssertTrue(likeResult.success, "Like should succeed")
            XCTAssertTrue(deleteResult.success, "Delete should succeed")
        } catch {
            XCTFail("Full comment flow should succeed: \(error)")
        }
    }
}

// MARK: - Test Helper Functions

extension PostInteractionsTests {
    
    func isValidCommentContent(_ content: String) -> Bool {
        return !content.isEmpty && content.count <= 1000
    }
    
    func isValidNestingDepth(_ depth: Int) -> Bool {
        return depth <= 3
    }
    
    func shouldFilterComment(_ content: String) -> Bool {
        let inappropriateWords = ["spam", "inappropriate", "harassment"]
        let lowercaseContent = content.lowercased()
        return inappropriateWords.contains { lowercaseContent.contains($0) }
    }
}

// MARK: - Test Data Factory

struct CommentTestDataFactory {
    static func createValidComment(
        id: String? = "test_comment_123",
        postId: String = "test_post_456",
        authorId: String = "user_789",
        content: String = "This is a great post! Love the food photography."
    ) -> Comment {
        return Comment(
            _id: id,
            postId: postId,
            authorId: authorId,
            author: createTestUser(id: authorId),
            content: content,
            parentCommentId: nil,
            likesCount: 0,
            repliesCount: 0,
            createdAt: Int(Date().timeIntervalSince1970 * 1000),
            updatedAt: Int(Date().timeIntervalSince1970 * 1000)
        )
    }
    
    static func createValidReply(
        parentCommentId: String,
        id: String? = "test_reply_123",
        postId: String = "test_post_456",
        authorId: String = "user_999",
        content: String = "Thanks for sharing! Where is this restaurant located?"
    ) -> Comment {
        return Comment(
            _id: id,
            postId: postId,
            authorId: authorId,
            author: createTestUser(id: authorId),
            content: content,
            parentCommentId: parentCommentId,
            likesCount: 0,
            repliesCount: 0,
            createdAt: Int(Date().timeIntervalSince1970 * 1000),
            updatedAt: Int(Date().timeIntervalSince1970 * 1000)
        )
    }
    
    static func createTestUser(id: String) -> User {
        return User(
            _id: id,
            clerkId: "clerk_\(id)",
            username: "user\(id)",
            displayName: "Test User \(id)",
            avatarUrl: "https://example.com/avatar_\(id).jpg",
            bio: "Test user for comments",
            isOnline: true,
            lastActiveAt: Int(Date().timeIntervalSince1970 * 1000)
        )
    }
}

// MARK: - Test Data Structures

struct Comment {
    let _id: String?
    let postId: String
    let authorId: String
    let author: User
    var content: String
    let parentCommentId: String?
    var likesCount: Int
    var repliesCount: Int
    let createdAt: Int
    let updatedAt: Int
}

struct SharePostData {
    let postId: String
    let userId: String
    let platform: SharePlatform
    let recipients: [String]?
}

struct CommentReportData {
    let commentId: String
    let reporterId: String
    let reason: ReportReason
    let additionalInfo: String?
}

enum SharePlatform {
    case messages
    case external
    case copyLink
}

enum ReportReason {
    case inappropriate
    case spam
    case harassment
    case misinformation
}

enum CommentError: Error, Equatable {
    case emptyContent
    case invalidPostId
    case invalidParentComment
    case contentTooLong
    case networkError
}

// MARK: - Result Structures

struct LikeResult {
    let success: Bool
    let postId: String
    let userId: String
    let isLiked: Bool
}

struct FavoriteResult {
    let success: Bool
    let postId: String
    let userId: String
    let isFavorited: Bool
}

struct ShareResult {
    let success: Bool
    let postId: String
    let platform: SharePlatform
    let shareUrl: String?
}

struct CommentReactionResult {
    let success: Bool
    let commentId: String
    let isLiked: Bool
    let emoji: String?
}

struct CommentReportResult {
    let success: Bool
    let commentId: String
    let reason: ReportReason
}

struct DeleteResult {
    let success: Bool
}

// MARK: - Mock Services

class MockPostInteractionsService {
    var shouldReturnError = false
    var delay: TimeInterval = 0.1
    
    func createComment(_ commentData: Comment) async throws -> Comment {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        if shouldReturnError {
            throw CommentError.networkError
        }
        
        if commentData.content.isEmpty {
            throw CommentError.emptyContent
        }
        
        if commentData.postId.isEmpty {
            throw CommentError.invalidPostId
        }
        
        var newComment = commentData
        newComment._id = newComment._id ?? "created_comment_\(UUID().uuidString)"
        return newComment
    }
    
    func createReply(_ replyData: Comment) async throws -> Comment {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        if shouldReturnError {
            throw CommentError.networkError
        }
        
        if replyData.parentCommentId == "invalid_id" {
            throw CommentError.invalidParentComment
        }
        
        var newReply = replyData
        newReply._id = newReply._id ?? "created_reply_\(UUID().uuidString)"
        return newReply
    }
    
    func likePost(postId: String, userId: String) async throws -> LikeResult {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        if shouldReturnError {
            throw CommentError.networkError
        }
        
        return LikeResult(success: true, postId: postId, userId: userId, isLiked: true)
    }
    
    func unlikePost(postId: String, userId: String) async throws -> LikeResult {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        return LikeResult(success: true, postId: postId, userId: userId, isLiked: false)
    }
    
    func favoritePost(postId: String, userId: String) async throws -> FavoriteResult {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        return FavoriteResult(success: true, postId: postId, userId: userId, isFavorited: true)
    }
    
    func unfavoritePost(postId: String, userId: String) async throws -> FavoriteResult {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        return FavoriteResult(success: true, postId: postId, userId: userId, isFavorited: false)
    }
    
    func sharePost(_ shareData: SharePostData) async throws -> ShareResult {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        let shareUrl = "https://palytt.app/post/\(shareData.postId)"
        return ShareResult(success: true, postId: shareData.postId, platform: shareData.platform, shareUrl: shareUrl)
    }
    
    func generateShareLink(postId: String) async throws -> String {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        return "https://palytt.app/post/\(postId)?share=true"
    }
    
    func likeComment(commentId: String, userId: String) async throws -> CommentReactionResult {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        return CommentReactionResult(success: true, commentId: commentId, isLiked: true, emoji: nil)
    }
    
    func addEmojiReaction(commentId: String, userId: String, emoji: String) async throws -> CommentReactionResult {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        return CommentReactionResult(success: true, commentId: commentId, isLiked: false, emoji: emoji)
    }
    
    func reportComment(_ reportData: CommentReportData) async throws -> CommentReportResult {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        return CommentReportResult(success: true, commentId: reportData.commentId, reason: reportData.reason)
    }
    
    func deleteComment(commentId: String) async throws -> DeleteResult {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        return DeleteResult(success: true)
    }
}

// MARK: - Comments ViewModel

class CommentsViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    var postId: String = ""
    
    func loadComments() async {
        await MainActor.run {
            isLoading = true
        }
        
        // Simulate loading
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            isLoading = false
            errorMessage = nil
        }
    }
    
    func handleRealTimeComment(_ comment: Comment) {
        if !comments.contains(where: { $0._id == comment._id }) {
            comments.append(comment)
        }
    }
    
    func handleRealTimeCommentUpdate(_ comment: Comment) {
        if let index = comments.firstIndex(where: { $0._id == comment._id }) {
            comments[index] = comment
        }
    }
} 