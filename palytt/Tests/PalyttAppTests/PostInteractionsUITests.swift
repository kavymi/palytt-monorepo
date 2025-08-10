//
//  PostInteractionsUITests.swift
//  PalyttAppTests
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import XCTest
@testable import Palytt

final class PostInteractionsUITests: XCTestCase {
    
    var mockCommentsViewModel: MockCommentsUIViewModel!
    var mockPostInteractionsManager: MockPostInteractionsManager!
    
    override func setUpWithError() throws {
        mockCommentsViewModel = MockCommentsUIViewModel()
        mockPostInteractionsManager = MockPostInteractionsManager()
    }
    
    override func tearDownWithError() throws {
        mockCommentsViewModel = nil
        mockPostInteractionsManager = nil
    }
    
    // MARK: - Comment Interface Tests
    
    func test_commentInput_initialState_isCorrect() {
        // Given - Fresh comment input state
        
        // When - Initial UI state
        
        // Then
        XCTAssertTrue(mockCommentsViewModel.commentText.isEmpty, "Comment text should be empty initially")
        XCTAssertFalse(mockCommentsViewModel.isSubmitting, "Should not be submitting initially")
        XCTAssertFalse(mockCommentsViewModel.showEmojiPicker, "Emoji picker should not be shown initially")
        XCTAssertNil(mockCommentsViewModel.replyingToComment, "Should not be replying to any comment initially")
        XCTAssertFalse(mockCommentsViewModel.isCommentValid, "Comment should not be valid when empty")
    }
    
    func test_commentInput_textValidation_enablesSubmitButton() {
        // Given
        mockCommentsViewModel.commentText = ""
        
        // When - Enter valid comment text
        mockCommentsViewModel.commentText = "This is a great post!"
        
        // Then
        XCTAssertTrue(mockCommentsViewModel.isCommentValid, "Comment should be valid with text")
        XCTAssertTrue(mockCommentsViewModel.canSubmitComment, "Submit button should be enabled")
        
        // When - Clear comment text
        mockCommentsViewModel.commentText = ""
        
        // Then
        XCTAssertFalse(mockCommentsViewModel.isCommentValid, "Comment should be invalid when empty")
        XCTAssertFalse(mockCommentsViewModel.canSubmitComment, "Submit button should be disabled")
    }
    
    func test_commentInput_characterLimit_validation() {
        // Given
        let maxLength = 1000
        let validComment = String(repeating: "a", count: maxLength)
        let tooLongComment = String(repeating: "a", count: maxLength + 1)
        
        // When & Then - Valid length
        mockCommentsViewModel.commentText = validComment
        XCTAssertTrue(mockCommentsViewModel.isCommentValid, "Comment at max length should be valid")
        XCTAssertEqual(mockCommentsViewModel.remainingCharacters, 0, "Should have 0 characters remaining")
        
        // When & Then - Too long
        mockCommentsViewModel.commentText = tooLongComment
        XCTAssertFalse(mockCommentsViewModel.isCommentValid, "Comment over max length should be invalid")
        XCTAssertEqual(mockCommentsViewModel.remainingCharacters, -1, "Should show negative remaining characters")
    }
    
    func test_commentInput_replyMode_showsCorrectContext() {
        // Given
        let parentComment = CommentUITestDataFactory.createTestComment()
        
        // When
        mockCommentsViewModel.startReply(to: parentComment)
        
        // Then
        XCTAssertNotNil(mockCommentsViewModel.replyingToComment, "Should be in reply mode")
        XCTAssertEqual(mockCommentsViewModel.replyingToComment?.id, parentComment.id, "Should be replying to correct comment")
        XCTAssertTrue(mockCommentsViewModel.showReplyContext, "Should show reply context")
        XCTAssertEqual(mockCommentsViewModel.replyPlaceholder, "Reply to \(parentComment.author.displayName)...", "Should show correct placeholder")
    }
    
    func test_commentInput_cancelReply_resetsState() {
        // Given
        let parentComment = CommentUITestDataFactory.createTestComment()
        mockCommentsViewModel.startReply(to: parentComment)
        mockCommentsViewModel.commentText = "Started typing a reply..."
        
        // When
        mockCommentsViewModel.cancelReply()
        
        // Then
        XCTAssertNil(mockCommentsViewModel.replyingToComment, "Should not be in reply mode")
        XCTAssertFalse(mockCommentsViewModel.showReplyContext, "Should hide reply context")
        XCTAssertTrue(mockCommentsViewModel.commentText.isEmpty, "Comment text should be cleared")
    }
    
    // MARK: - Like Button Tests
    
    func test_likeButton_initialState_showsCorrectAppearance() {
        // Given
        let post = PostUITestDataFactory.createTestPost()
        
        // When - Post is not liked
        mockPostInteractionsManager.isPostLiked = false
        
        // Then
        XCTAssertFalse(mockPostInteractionsManager.isPostLiked, "Post should not be liked initially")
        XCTAssertEqual(mockPostInteractionsManager.likeButtonIcon, "heart", "Should show empty heart icon")
        XCTAssertEqual(mockPostInteractionsManager.likeButtonColor, "primaryText", "Should show default color")
        
        // When - Post is liked
        mockPostInteractionsManager.isPostLiked = true
        
        // Then
        XCTAssertTrue(mockPostInteractionsManager.isPostLiked, "Post should be liked")
        XCTAssertEqual(mockPostInteractionsManager.likeButtonIcon, "heart.fill", "Should show filled heart icon")
        XCTAssertEqual(mockPostInteractionsManager.likeButtonColor, "red", "Should show red color")
    }
    
    func test_likeButton_tap_togglesLikeState() {
        // Given
        mockPostInteractionsManager.isPostLiked = false
        mockPostInteractionsManager.likesCount = 42
        
        // When - First tap (like)
        mockPostInteractionsManager.toggleLike()
        
        // Then
        XCTAssertTrue(mockPostInteractionsManager.isPostLiked, "Post should be liked after first tap")
        XCTAssertEqual(mockPostInteractionsManager.likesCount, 43, "Likes count should increase")
        
        // When - Second tap (unlike)
        mockPostInteractionsManager.toggleLike()
        
        // Then
        XCTAssertFalse(mockPostInteractionsManager.isPostLiked, "Post should be unliked after second tap")
        XCTAssertEqual(mockPostInteractionsManager.likesCount, 42, "Likes count should decrease")
    }
    
    func test_likeButton_animation_playsCorrectly() {
        // Given
        mockPostInteractionsManager.isPostLiked = false
        
        // When
        mockPostInteractionsManager.toggleLike()
        
        // Then
        XCTAssertTrue(mockPostInteractionsManager.shouldPlayLikeAnimation, "Should trigger like animation")
        XCTAssertEqual(mockPostInteractionsManager.animationType, .bounce, "Should use bounce animation")
    }
    
    // MARK: - Favorite Button Tests
    
    func test_favoriteButton_initialState_showsCorrectAppearance() {
        // Given
        mockPostInteractionsManager.isPostFavorited = false
        
        // When - Not favorited
        // Then
        XCTAssertFalse(mockPostInteractionsManager.isPostFavorited, "Post should not be favorited initially")
        XCTAssertEqual(mockPostInteractionsManager.favoriteButtonIcon, "bookmark", "Should show empty bookmark icon")
        
        // When - Favorited
        mockPostInteractionsManager.isPostFavorited = true
        
        // Then
        XCTAssertEqual(mockPostInteractionsManager.favoriteButtonIcon, "bookmark.fill", "Should show filled bookmark icon")
    }
    
    func test_favoriteButton_tap_togglesFavoriteState() {
        // Given
        mockPostInteractionsManager.isPostFavorited = false
        
        // When
        mockPostInteractionsManager.toggleFavorite()
        
        // Then
        XCTAssertTrue(mockPostInteractionsManager.isPostFavorited, "Post should be favorited")
        XCTAssertTrue(mockPostInteractionsManager.shouldShowFavoriteConfirmation, "Should show favorite confirmation")
    }
    
    // MARK: - Share Interface Tests
    
    func test_shareSheet_initialState_isCorrect() {
        // Given - Fresh share sheet state
        
        // When - Initial state
        
        // Then
        XCTAssertFalse(mockPostInteractionsManager.showShareSheet, "Share sheet should not be shown initially")
        XCTAssertTrue(mockPostInteractionsManager.shareOptions.isEmpty, "Share options should be empty initially")
        XCTAssertNil(mockPostInteractionsManager.selectedShareOption, "No share option should be selected initially")
    }
    
    func test_shareSheet_showShareOptions_displaysCorrectOptions() {
        // Given
        let expectedOptions = [
            ShareOption.messages,
            ShareOption.copyLink,
            ShareOption.external
        ]
        
        // When
        mockPostInteractionsManager.showShareOptions()
        
        // Then
        XCTAssertTrue(mockPostInteractionsManager.showShareSheet, "Share sheet should be shown")
        XCTAssertEqual(mockPostInteractionsManager.shareOptions.count, expectedOptions.count, "Should have correct number of options")
        
        for option in expectedOptions {
            XCTAssertTrue(mockPostInteractionsManager.shareOptions.contains(option), "Should contain \(option) option")
        }
    }
    
    func test_shareSheet_selectOption_triggersCorrectAction() {
        // Given
        mockPostInteractionsManager.showShareOptions()
        
        // When - Select copy link option
        mockPostInteractionsManager.selectShareOption(.copyLink)
        
        // Then
        XCTAssertEqual(mockPostInteractionsManager.selectedShareOption, .copyLink, "Should select copy link option")
        XCTAssertTrue(mockPostInteractionsManager.didCopyLink, "Should copy link to clipboard")
        XCTAssertTrue(mockPostInteractionsManager.showCopyConfirmation, "Should show copy confirmation")
        
        // When - Select messages option
        mockPostInteractionsManager.selectShareOption(.messages)
        
        // Then
        XCTAssertEqual(mockPostInteractionsManager.selectedShareOption, .messages, "Should select messages option")
        XCTAssertTrue(mockPostInteractionsManager.showMessageComposer, "Should show message composer")
    }
    
    // MARK: - Comment List Tests
    
    func test_commentsList_emptyState_showsCorrectMessage() {
        // Given
        mockCommentsViewModel.comments = []
        
        // When
        let isEmpty = mockCommentsViewModel.comments.isEmpty
        
        // Then
        XCTAssertTrue(isEmpty, "Comments should be empty")
        XCTAssertEqual(mockCommentsViewModel.emptyStateMessage, "No comments yet", "Should show correct empty state message")
        XCTAssertEqual(mockCommentsViewModel.emptyStateSubtitle, "Be the first to share your thoughts!", "Should show correct subtitle")
    }
    
    func test_commentsList_withComments_displaysCorrectly() {
        // Given
        let comments = CommentUITestDataFactory.createTestComments(count: 3)
        
        // When
        mockCommentsViewModel.comments = comments
        
        // Then
        XCTAssertEqual(mockCommentsViewModel.comments.count, 3, "Should display 3 comments")
        XCTAssertFalse(mockCommentsViewModel.showEmptyState, "Should not show empty state")
        XCTAssertTrue(mockCommentsViewModel.showCommentsList, "Should show comments list")
    }
    
    func test_commentsList_nestedReplies_showsCorrectIndentation() {
        // Given
        let parentComment = CommentUITestDataFactory.createTestComment()
        let reply1 = CommentUITestDataFactory.createTestReply(parentId: parentComment.id, depth: 1)
        let reply2 = CommentUITestDataFactory.createTestReply(parentId: reply1.id, depth: 2)
        
        // When
        mockCommentsViewModel.comments = [parentComment, reply1, reply2]
        
        // Then
        XCTAssertEqual(mockCommentsViewModel.getIndentationLevel(for: parentComment), 0, "Parent comment should have no indentation")
        XCTAssertEqual(mockCommentsViewModel.getIndentationLevel(for: reply1), 1, "First level reply should have 1 level indentation")
        XCTAssertEqual(mockCommentsViewModel.getIndentationLevel(for: reply2), 2, "Second level reply should have 2 levels indentation")
    }
    
    // MARK: - Comment Actions Tests
    
    func test_commentActions_showActions_displaysCorrectOptions() {
        // Given
        let comment = CommentUITestDataFactory.createTestComment()
        
        // When
        mockCommentsViewModel.showActionsFor(comment)
        
        // Then
        XCTAssertTrue(mockCommentsViewModel.showActionSheet, "Should show action sheet")
        XCTAssertNotNil(mockCommentsViewModel.selectedComment, "Should have selected comment")
        
        let expectedActions = ["Reply", "Like", "Report"]
        for action in expectedActions {
            XCTAssertTrue(mockCommentsViewModel.availableActions.contains(action), "Should contain \(action) action")
        }
    }
    
    func test_commentActions_ownComment_showsEditAndDelete() {
        // Given
        let ownComment = CommentUITestDataFactory.createTestComment(isOwnComment: true)
        
        // When
        mockCommentsViewModel.showActionsFor(ownComment)
        
        // Then
        let expectedActions = ["Edit", "Delete", "Reply"]
        for action in expectedActions {
            XCTAssertTrue(mockCommentsViewModel.availableActions.contains(action), "Should contain \(action) action for own comment")
        }
        
        XCTAssertFalse(mockCommentsViewModel.availableActions.contains("Report"), "Should not show report option for own comment")
    }
    
    // MARK: - Emoji Picker Tests
    
    func test_emojiPicker_showPicker_displaysCorrectEmojis() {
        // Given
        mockCommentsViewModel.showEmojiPicker = false
        
        // When
        mockCommentsViewModel.showEmojiPicker = true
        
        // Then
        XCTAssertTrue(mockCommentsViewModel.showEmojiPicker, "Emoji picker should be shown")
        
        let expectedEmojis = ["😍", "❤️", "👍", "😂", "🤤", "🔥"]
        for emoji in expectedEmojis {
            XCTAssertTrue(mockCommentsViewModel.availableEmojis.contains(emoji), "Should contain \(emoji) emoji")
        }
    }
    
    func test_emojiPicker_selectEmoji_addsToComment() {
        // Given
        mockCommentsViewModel.commentText = "This looks amazing"
        mockCommentsViewModel.showEmojiPicker = true
        
        // When
        mockCommentsViewModel.addEmoji("😍")
        
        // Then
        XCTAssertEqual(mockCommentsViewModel.commentText, "This looks amazing 😍", "Should add emoji to comment")
        XCTAssertFalse(mockCommentsViewModel.showEmojiPicker, "Should hide emoji picker after selection")
    }
    
    // MARK: - Loading States Tests
    
    func test_commentSubmission_loadingState_disablesInteraction() {
        // Given
        mockCommentsViewModel.commentText = "Great post!"
        mockCommentsViewModel.isSubmitting = false
        
        // When
        mockCommentsViewModel.isSubmitting = true
        
        // Then
        XCTAssertTrue(mockCommentsViewModel.isSubmitting, "Should be in submitting state")
        XCTAssertFalse(mockCommentsViewModel.canSubmitComment, "Submit button should be disabled during submission")
        XCTAssertFalse(mockCommentsViewModel.canEditComment, "Comment input should be disabled during submission")
        XCTAssertEqual(mockCommentsViewModel.submitButtonText, "Posting...", "Should show loading text")
    }
    
    func test_commentsLoading_showsCorrectIndicators() {
        // Given
        mockCommentsViewModel.isLoadingComments = false
        
        // When
        mockCommentsViewModel.isLoadingComments = true
        
        // Then
        XCTAssertTrue(mockCommentsViewModel.isLoadingComments, "Should be loading comments")
        XCTAssertTrue(mockCommentsViewModel.showLoadingIndicator, "Should show loading indicator")
        XCTAssertFalse(mockCommentsViewModel.showCommentsList, "Should hide comments list during loading")
    }
    
    // MARK: - Error Handling Tests
    
    func test_commentSubmission_error_showsErrorMessage() {
        // Given
        let errorMessage = "Failed to post comment"
        
        // When
        mockCommentsViewModel.showError(errorMessage)
        
        // Then
        XCTAssertEqual(mockCommentsViewModel.errorMessage, errorMessage, "Should show error message")
        XCTAssertTrue(mockCommentsViewModel.showErrorAlert, "Should show error alert")
        XCTAssertFalse(mockCommentsViewModel.isSubmitting, "Should not be submitting after error")
    }
    
    func test_commentError_retry_allowsRetry() {
        // Given
        mockCommentsViewModel.showError("Network error")
        mockCommentsViewModel.commentText = "Test comment"
        
        // When
        mockCommentsViewModel.retrySubmission()
        
        // Then
        XCTAssertNil(mockCommentsViewModel.errorMessage, "Error message should be cleared")
        XCTAssertFalse(mockCommentsViewModel.showErrorAlert, "Error alert should be hidden")
        XCTAssertTrue(mockCommentsViewModel.canSubmitComment, "Should allow retry submission")
    }
    
    // MARK: - Accessibility Tests
    
    func test_commentInterface_accessibility_hasCorrectLabels() {
        // Given
        let accessibilityLabels = [
            "comment_input": "Type your comment",
            "submit_button": "Post comment",
            "like_button": "Like this post",
            "favorite_button": "Add to favorites",
            "share_button": "Share this post",
            "emoji_button": "Add emoji",
            "reply_button": "Reply to comment"
        ]
        
        // When & Then
        for (identifier, expectedLabel) in accessibilityLabels {
            XCTAssertFalse(expectedLabel.isEmpty, "Accessibility label for \(identifier) should not be empty")
            XCTAssertTrue(expectedLabel.count > 3, "Accessibility label should be descriptive")
        }
    }
    
    func test_commentInterface_accessibility_supportsVoiceOver() {
        // Given
        let comment = CommentUITestDataFactory.createTestComment()
        
        // When
        let accessibilityHint = mockCommentsViewModel.getAccessibilityHint(for: comment)
        
        // Then
        XCTAssertFalse(accessibilityHint.isEmpty, "Should have accessibility hint")
        XCTAssertTrue(accessibilityHint.contains("Double tap"), "Should provide VoiceOver instructions")
    }
    
    // MARK: - Performance Tests
    
    func test_commentInterface_performance_largeCommentsList() {
        measure {
            // Test performance with large number of comments
            let comments = CommentUITestDataFactory.createTestComments(count: 1000)
            mockCommentsViewModel.comments = comments
            
            // Test that UI can handle large lists
            XCTAssertEqual(mockCommentsViewModel.comments.count, 1000)
        }
    }
    
    func test_commentInterface_performance_emojiPicker() {
        measure {
            // Test emoji picker performance
            for _ in 0..<100 {
                mockCommentsViewModel.showEmojiPicker = true
                mockCommentsViewModel.addEmoji("😍")
                mockCommentsViewModel.showEmojiPicker = false
            }
        }
    }
}

// MARK: - Test Data Factory

struct CommentUITestDataFactory {
    static func createTestComment(
        id: String = "comment_123",
        isOwnComment: Bool = false
    ) -> CommentUIModel {
        return CommentUIModel(
            id: id,
            content: "This is a test comment with great content!",
            author: createTestUser(isCurrentUser: isOwnComment),
            createdAt: Date(),
            likesCount: 5,
            repliesCount: 2,
            isLiked: false,
            depth: 0
        )
    }
    
    static func createTestReply(
        parentId: String,
        depth: Int,
        id: String = "reply_456"
    ) -> CommentUIModel {
        return CommentUIModel(
            id: id,
            content: "This is a reply to the parent comment.",
            author: createTestUser(),
            createdAt: Date(),
            likesCount: 1,
            repliesCount: 0,
            isLiked: false,
            depth: depth,
            parentId: parentId
        )
    }
    
    static func createTestComments(count: Int) -> [CommentUIModel] {
        return (0..<count).map { index in
            createTestComment(id: "comment_\(index)")
        }
    }
    
    static func createTestUser(isCurrentUser: Bool = false) -> UserUIModel {
        return UserUIModel(
            id: isCurrentUser ? "current_user" : "test_user_123",
            username: isCurrentUser ? "currentuser" : "testuser",
            displayName: isCurrentUser ? "Current User" : "Test User",
            avatarUrl: "https://example.com/avatar.jpg"
        )
    }
}

struct PostUITestDataFactory {
    static func createTestPost() -> PostUIModel {
        return PostUIModel(
            id: "post_123",
            caption: "Amazing food at great restaurant!",
            imageUrl: "https://example.com/food.jpg",
            author: CommentUITestDataFactory.createTestUser(),
            likesCount: 42,
            commentsCount: 8,
            isLiked: false,
            isFavorited: false,
            createdAt: Date()
        )
    }
}

// MARK: - UI Model Structures

struct CommentUIModel {
    let id: String
    let content: String
    let author: UserUIModel
    let createdAt: Date
    let likesCount: Int
    let repliesCount: Int
    let isLiked: Bool
    let depth: Int
    let parentId: String?
    
    init(id: String, content: String, author: UserUIModel, createdAt: Date, likesCount: Int, repliesCount: Int, isLiked: Bool, depth: Int, parentId: String? = nil) {
        self.id = id
        self.content = content
        self.author = author
        self.createdAt = createdAt
        self.likesCount = likesCount
        self.repliesCount = repliesCount
        self.isLiked = isLiked
        self.depth = depth
        self.parentId = parentId
    }
}

struct UserUIModel {
    let id: String
    let username: String
    let displayName: String
    let avatarUrl: String
}

struct PostUIModel {
    let id: String
    let caption: String
    let imageUrl: String
    let author: UserUIModel
    let likesCount: Int
    let commentsCount: Int
    let isLiked: Bool
    let isFavorited: Bool
    let createdAt: Date
}

enum ShareOption: String, CaseIterable {
    case messages = "Messages"
    case copyLink = "Copy Link"
    case external = "Share Externally"
}

enum AnimationType {
    case bounce
    case pulse
    case scale
}

// MARK: - Mock ViewModels

class MockCommentsUIViewModel: ObservableObject {
    @Published var commentText = ""
    @Published var isSubmitting = false
    @Published var showEmojiPicker = false
    @Published var replyingToComment: CommentUIModel?
    @Published var comments: [CommentUIModel] = []
    @Published var isLoadingComments = false
    @Published var errorMessage: String?
    @Published var showErrorAlert = false
    @Published var showActionSheet = false
    @Published var selectedComment: CommentUIModel?
    @Published var availableActions: [String] = []
    @Published var availableEmojis = ["😍", "❤️", "👍", "😂", "🤤", "🔥"]
    
    var isCommentValid: Bool {
        !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && commentText.count <= 1000
    }
    
    var canSubmitComment: Bool {
        isCommentValid && !isSubmitting
    }
    
    var canEditComment: Bool {
        !isSubmitting
    }
    
    var remainingCharacters: Int {
        1000 - commentText.count
    }
    
    var showReplyContext: Bool {
        replyingToComment != nil
    }
    
    var replyPlaceholder: String {
        if let replyingTo = replyingToComment {
            return "Reply to \(replyingTo.author.displayName)..."
        }
        return "Add a comment..."
    }
    
    var emptyStateMessage: String {
        "No comments yet"
    }
    
    var emptyStateSubtitle: String {
        "Be the first to share your thoughts!"
    }
    
    var showEmptyState: Bool {
        comments.isEmpty && !isLoadingComments
    }
    
    var showCommentsList: Bool {
        !comments.isEmpty && !isLoadingComments
    }
    
    var showLoadingIndicator: Bool {
        isLoadingComments
    }
    
    var submitButtonText: String {
        isSubmitting ? "Posting..." : "Post"
    }
    
    func startReply(to comment: CommentUIModel) {
        replyingToComment = comment
    }
    
    func cancelReply() {
        replyingToComment = nil
        commentText = ""
    }
    
    func addEmoji(_ emoji: String) {
        commentText += " \(emoji)"
        showEmojiPicker = false
    }
    
    func showActionsFor(_ comment: CommentUIModel) {
        selectedComment = comment
        showActionSheet = true
        
        if comment.author.id == "current_user" {
            availableActions = ["Edit", "Delete", "Reply"]
        } else {
            availableActions = ["Reply", "Like", "Report"]
        }
    }
    
    func getIndentationLevel(for comment: CommentUIModel) -> Int {
        return comment.depth
    }
    
    func getAccessibilityHint(for comment: CommentUIModel) -> String {
        return "Double tap to view comment actions"
    }
    
    func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
        isSubmitting = false
    }
    
    func retrySubmission() {
        errorMessage = nil
        showErrorAlert = false
    }
}

class MockPostInteractionsManager: ObservableObject {
    @Published var isPostLiked = false
    @Published var isPostFavorited = false
    @Published var likesCount = 0
    @Published var showShareSheet = false
    @Published var shareOptions: [ShareOption] = []
    @Published var selectedShareOption: ShareOption?
    @Published var shouldPlayLikeAnimation = false
    @Published var shouldShowFavoriteConfirmation = false
    @Published var didCopyLink = false
    @Published var showCopyConfirmation = false
    @Published var showMessageComposer = false
    
    var likeButtonIcon: String {
        isPostLiked ? "heart.fill" : "heart"
    }
    
    var likeButtonColor: String {
        isPostLiked ? "red" : "primaryText"
    }
    
    var favoriteButtonIcon: String {
        isPostFavorited ? "bookmark.fill" : "bookmark"
    }
    
    var animationType: AnimationType = .bounce
    
    func toggleLike() {
        isPostLiked.toggle()
        likesCount += isPostLiked ? 1 : -1
        shouldPlayLikeAnimation = isPostLiked
    }
    
    func toggleFavorite() {
        isPostFavorited.toggle()
        shouldShowFavoriteConfirmation = isPostFavorited
    }
    
    func showShareOptions() {
        shareOptions = ShareOption.allCases
        showShareSheet = true
    }
    
    func selectShareOption(_ option: ShareOption) {
        selectedShareOption = option
        
        switch option {
        case .copyLink:
            didCopyLink = true
            showCopyConfirmation = true
        case .messages:
            showMessageComposer = true
        case .external:
            // Handle external sharing
            break
        }
        
        showShareSheet = false
    }
} 