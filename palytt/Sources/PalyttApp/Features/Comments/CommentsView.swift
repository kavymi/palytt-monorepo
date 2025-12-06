//
//  CommentsView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Kingfisher
import Clerk

// MARK: - Comment Model
struct Comment: Identifiable {
    let id: UUID
    let postId: UUID
    let author: User
    let text: String
    let createdAt: Date
    var likesCount: Int
    var isLiked: Bool
    var replies: [Comment]
    
    // Create from backend comment
    static func from(_ backendComment: BackendService.BackendComment, author: User? = nil) -> Comment {
        // Convert Unix timestamp to Date
        let createdAt = Date(timeIntervalSince1970: backendComment.createdAt / 1000)
        
        // Create author if not provided, use backend author data if available
        let commentAuthor: User
        if let providedAuthor = author {
            commentAuthor = providedAuthor
        } else if let backendAuthor = backendComment.author {
            // Convert backend author to User model
            commentAuthor = User(
                id: UUID(uuidString: backendAuthor._id ?? "") ?? UUID(),
                email: backendAuthor.email ?? "unknown@example.com",
                firstName: backendAuthor.firstName,
                lastName: backendAuthor.lastName,
                username: backendAuthor.username ?? "user_\(backendComment.authorId.prefix(8))",
                displayName: backendAuthor.displayName ?? backendAuthor.username ?? "Unknown User",
                bio: backendAuthor.bio,
                avatarURL: backendAuthor.avatarUrl != nil ? URL(string: backendAuthor.avatarUrl!) : nil,
                clerkId: backendAuthor.clerkId ?? backendComment.authorClerkId
            )
        } else {
            // Fallback if no author info available
            commentAuthor = User(
                id: UUID(uuidString: backendComment.authorId) ?? UUID(),
                email: "unknown@example.com",
                username: "user_\(backendComment.authorId.prefix(8))",
                displayName: "Unknown User",
                clerkId: backendComment.authorClerkId
            )
        }
        
        return Comment(
            id: UUID(uuidString: backendComment.id) ?? UUID(),
            postId: UUID(uuidString: backendComment.postId) ?? UUID(),
            author: commentAuthor,
            text: backendComment.content,
            createdAt: createdAt,
            likesCount: backendComment.likes, // Now we have this from backend
            isLiked: false, // Backend doesn't provide user-specific like status yet
            replies: backendComment.replies?.map { Comment.from($0) } ?? [] // Handle nested replies
        )
    }
}

// MARK: - Comments View Model
@MainActor
class CommentsViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var isPosting = false
    @Published var errorMessage: String?
    
    private let backendService = BackendService.shared
    private var currentPage = 1
    private var hasMorePages = true
    private var postConvexId: String? // Store convex ID instead of UUID
    
    func loadComments(for post: Post) async {
        guard !isLoading else { return }
        
        postConvexId = post.convexId // Store convex ID for backend calls
        isLoading = true
        currentPage = 1
        hasMorePages = true
        errorMessage = nil
        
        do {
            let response = try await backendService.getComments(
                postId: post.convexId, // Use Convex document ID instead of UUID
                page: currentPage,
                limit: 20
            )
            
            // Convert backend comments to frontend comments
            var convertedComments: [Comment] = []
            for backendComment in response.comments {
                // Try to get author information
                var author: User?
                do {
                    let backendAuthor = try await backendService.getUserByClerkId(clerkId: backendComment.authorClerkId)
                    author = backendAuthor.toUser()
                } catch {
                    print("⚠️ Failed to get author info for comment: \(error)")
                }
                
                let comment = Comment.from(backendComment, author: author)
                convertedComments.append(comment)
            }
            
            comments = convertedComments
            hasMorePages = response.pagination.page < response.pagination.totalPages
            
        } catch {
            print("❌ Failed to load comments: \(error)")
            errorMessage = error.localizedDescription
            
            // Fall back to empty state
            comments = []
        }
        
        isLoading = false
    }
    
    func postComment(
        text: String, 
        replyTo: Comment?, 
        mentionedUsernames: [String] = [],
        completion: @escaping (Bool) -> Void = { _ in }
    ) {
        guard let postConvexId = postConvexId, !text.isEmpty else { 
            completion(false)
            return 
        }
        
        isPosting = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await backendService.addComment(
                    postId: postConvexId,
                    content: text,
                    parentCommentId: replyTo?.id.uuidString
                )
                
                // The backend now returns author info in the response
                // Comment.from() will use the embedded author data
                let newComment = Comment.from(response.comment)
                comments.append(newComment)
                
                // Get current user's clerkId for notifications
                let currentUserClerkId = response.comment.authorClerkId
                
                // Send notifications
                await sendCommentNotifications(
                    commentId: response.comment.id,
                    text: text,
                    postId: postConvexId,
                    replyTo: replyTo,
                    mentionedUsernames: mentionedUsernames,
                    currentUserClerkId: currentUserClerkId
                )
                
                await MainActor.run {
                    completion(true)
                    // Play comment success sound
                    // SoundManager.shared.playCommentSound()
                }
                
            } catch {
                print("❌ Failed to post comment: \(error)")
                errorMessage = "Failed to post comment"
                await MainActor.run {
                    completion(false)
                }
            }
            
            isPosting = false
        }
    }
    
    private func sendCommentNotifications(
        commentId: String,
        text: String,
        postId: String,
        replyTo: Comment?,
        mentionedUsernames: [String],
        currentUserClerkId: String?
    ) async {
        guard let currentUserClerkId = currentUserClerkId else { return }
        
        // 1. Notify post owner about new comment (if not commenting on own post)
        do {
            // Get post details to find post owner
            let posts = try await backendService.getPostsByUser(userId: currentUserClerkId)
            if let currentPost = posts.first(where: { $0.id == postId }), 
               currentPost.userId != currentUserClerkId {
                
                let _ = try await backendService.createNotification(
                    recipientId: currentPost.userId,
                    senderId: currentUserClerkId,
                    type: "post_comment",
                    title: "New Comment",
                    message: "Someone commented on your post",
                    metadata: [
                        "postId": postId,
                        "commentId": commentId
                    ]
                )
            }
        } catch {
            print("⚠️ Failed to send post comment notification: \(error)")
        }
        
        // 2. Notify mentioned users
        for username in mentionedUsernames {
            do {
                let users = try await backendService.searchUsers(query: username, limit: 1)
                if let mentionedUser = users.first(where: { $0.username == username }),
                   mentionedUser.clerkId != currentUserClerkId {
                    
                    let _ = try await backendService.createNotification(
                        recipientId: mentionedUser.clerkId,
                        senderId: currentUserClerkId,
                        type: "post_comment",
                        title: "You were mentioned",
                        message: "You were mentioned in a comment",
                        metadata: [
                            "postId": postId,
                            "commentId": commentId
                        ]
                    )
                }
            } catch {
                print("⚠️ Failed to send mention notification for @\(username): \(error)")
            }
        }
        
        // 3. Notify user being replied to (if different from post owner and not self)
        if let replyTo = replyTo, replyTo.author.clerkId != currentUserClerkId {
            do {
                let _ = try await backendService.createNotification(
                    recipientId: replyTo.author.clerkId ?? "",
                    senderId: currentUserClerkId,
                    type: "post_comment",
                    title: "Reply to your comment",
                    message: "Someone replied to your comment",
                    metadata: [
                        "postId": postId,
                        "commentId": commentId,
                        "parentCommentId": replyTo.id.uuidString
                    ]
                )
            } catch {
                print("⚠️ Failed to send reply notification: \(error)")
            }
        }
    }
    
    func toggleLike(_ comment: Comment) {
        // Update UI optimistically
        let wasLiked = comment.isLiked
        if let index = comments.firstIndex(where: { $0.id == comment.id }) {
            comments[index].isLiked.toggle()
            comments[index].likesCount += comments[index].isLiked ? 1 : -1
            
            // Call backend to persist the like
            Task {
                do {
                    // Convert UUID back to string for backend call
                    let commentId = comment.id.uuidString
                    let response = try await backendService.toggleCommentLike(commentId: commentId)
                    
                    // Update with actual backend response
                    await MainActor.run {
                        if let index = comments.firstIndex(where: { $0.id == comment.id }) {
                            comments[index].isLiked = response.isLiked
                            comments[index].likesCount = response.likesCount
                        }
                    }
                    
                    // Send notification if user just liked the comment (not unliked)
                    if !wasLiked && response.isLiked {
                        await sendCommentLikeNotification(comment: comment)
                        // Play like sound effect for comments
                        // SoundManager.shared.playLikeSound()
                    }
                    
                } catch {
                    print("❌ Failed to toggle comment like: \(error)")
                    // Revert optimistic update on error
                    await MainActor.run {
                        if let index = comments.firstIndex(where: { $0.id == comment.id }) {
                            comments[index].isLiked.toggle()
                            comments[index].likesCount += comments[index].isLiked ? 1 : -1
                        }
                    }
                }
            }
        } else {
            // Check in replies
            for i in comments.indices {
                if let replyIndex = comments[i].replies.firstIndex(where: { $0.id == comment.id }) {
                    comments[i].replies[replyIndex].isLiked.toggle()
                    comments[i].replies[replyIndex].likesCount += comments[i].replies[replyIndex].isLiked ? 1 : -1
                    
                    // Call backend for reply like
                    Task {
                        do {
                            let commentId = comment.id.uuidString
                            let response = try await backendService.toggleCommentLike(commentId: commentId)
                            
                            await MainActor.run {
                                if let replyIndex = comments[i].replies.firstIndex(where: { $0.id == comment.id }) {
                                    comments[i].replies[replyIndex].isLiked = response.isLiked
                                    comments[i].replies[replyIndex].likesCount = response.likesCount
                                }
                            }
                        } catch {
                            print("❌ Failed to toggle reply like: \(error)")
                            // Revert optimistic update on error
                            await MainActor.run {
                                if let replyIndex = comments[i].replies.firstIndex(where: { $0.id == comment.id }) {
                                    comments[i].replies[replyIndex].isLiked.toggle()
                                    comments[i].replies[replyIndex].likesCount += comments[i].replies[replyIndex].isLiked ? 1 : -1
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func sendCommentLikeNotification(comment: Comment) async {
        do {
            // Get current user info
            guard let currentUser = Clerk.shared.user?.id else {
                print("⚠️ Could not get current user for comment like notification")
                return
            }
            
            // Don't send notification if user liked their own comment
            if comment.author.clerkId == currentUser {
                return
            }
            
            let _ = try await backendService.createNotification(
                recipientId: comment.author.clerkId ?? "",
                senderId: currentUser,
                type: "comment_like",
                title: "Comment Liked",
                message: "Someone liked your comment",
                metadata: [
                    "commentId": comment.id.uuidString,
                    "postId": comment.postId.uuidString
                ]
            )
        } catch {
            print("⚠️ Failed to send comment like notification: \(error)")
        }
    }
}

struct CommentsView: View {
    let post: Post
    let onCommentAdded: ((Int) -> Void)? // Callback to update comment count
    @StateObject private var viewModel = CommentsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var newComment = ""
    @State private var mentions: [Mention] = []
    @State private var isReplying: Comment? = nil
    @FocusState private var isTextFieldFocused: Bool

    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                contentView
                CommentInputView(
                    text: $newComment,
                    mentions: $mentions,
                    isReplying: $isReplying,
                    isFocused: $isTextFieldFocused,
                    onSend: {
                        guard !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        
                        // Extract mentioned usernames from mentions array
                        let mentionedUsernames = mentions
                            .filter { $0.type == .user }
                            .map { $0.text }
                        
                        viewModel.postComment(
                            text: newComment,
                            replyTo: isReplying,
                            mentionedUsernames: mentionedUsernames
                        ) { success in
                            if success {
                                // Notify parent with updated comment count
                                onCommentAdded?(viewModel.comments.count)
                            }
                        }
                        
                        newComment = ""
                        mentions = []
                        isReplying = nil
                        isTextFieldFocused = false
                    }
                )
            }
            .navigationTitle("Comments")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Done") { dismiss() }
            )
            .task {
                await viewModel.loadComments(for: post)
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        // Comments List
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Post Summary
                    PostSummaryView(post: post)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Comments
                    if viewModel.comments.isEmpty && viewModel.isLoading {
                        // Show skeleton loaders while loading comments
                        CommentsSectionSkeleton()
                    } else if viewModel.comments.isEmpty {
                        // Empty state with engaging prompts
                        EmptyCommentsView(onTap: {
                            isTextFieldFocused = true
                        })
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .padding()
                    } else {
                        ForEach(viewModel.comments) { comment in
                            CommentRow(
                                comment: comment,
                                onReply: { 
                                    isReplying = comment
                                    isTextFieldFocused = true
                                },
                                onLike: { viewModel.toggleLike(comment) }
                            )
                            .padding(.horizontal)
                            .id(comment.id)
                            
                            // Replies
                            if !comment.replies.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(comment.replies) { reply in
                                        CommentRow(
                                            comment: reply,
                                            isReply: true,
                                            onReply: { 
                                                isReplying = comment
                                                isTextFieldFocused = true
                                            },
                                            onLike: { viewModel.toggleLike(reply) }
                                        )
                                        .padding(.leading, 44)
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        
                        // Show skeleton for loading more comments
                        if viewModel.isLoading && !viewModel.comments.isEmpty {
                            VStack(spacing: 16) {
                                CommentSkeletonRow()
                                CommentSkeletonRow()
                            }
                            .padding(.vertical)
                        }
                    }
                }
                .padding(.vertical)
            }
            .onChange(of: viewModel.comments.count) { oldValue, newValue in
                if let lastComment = viewModel.comments.last {
                    withAnimation {
                        proxy.scrollTo(lastComment.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
}

// MARK: - Post Summary View
struct PostSummaryView: View {
    let post: Post
    
    var body: some View {
        HStack(spacing: 12) {
            // Author Avatar
            UserAvatar(user: post.author, size: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(post.author.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(post.caption)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
}

// MARK: - Comment Reaction Types
enum CommentReactionType: String, CaseIterable {
    case fire = "fire"
    case love = "love"
    case laugh = "laugh"
    case sad = "sad"
    case wow = "wow"
    
    var emoji: String {
        switch self {
        case .fire: return "🔥"
        case .love: return "❤️"
        case .laugh: return "😂"
        case .sad: return "😢"
        case .wow: return "😮"
        }
    }
}

// MARK: - Comment Row
struct CommentRow: View {
    let comment: Comment
    var isReply: Bool = false
    let onReply: () -> Void
    let onLike: () -> Void
    
    @State private var isLiked: Bool = false
    @State private var showMenu = false
    @State private var showReactionPicker = false
    @State private var selectedReaction: CommentReactionType? = nil
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Avatar
            UserAvatar(user: comment.author, size: isReply ? 28 : 36)
            
            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack(spacing: 8) {
                    Text(comment.author.displayName)
                        .font(isReply ? .caption : .subheadline)
                        .fontWeight(.medium)
                    
                    // Timestamp
                    Text(comment.createdAt.timeAgoDisplay())
                        .font(.caption2)
                        .foregroundColor(.tertiaryText)
                    
                    Spacer()
                    
                    Menu {
                        Button(action: {}) {
                            Label("Report", systemImage: "flag")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundColor(.tertiaryText)
                    }
                }
                
                // Comment Text with @mentions and #hashtags highlighted
                MentionText(
                    text: comment.text,
                    font: isReply ? .caption : .subheadline,
                    textColor: .primaryText,
                    lineLimit: nil
                )
                .fixedSize(horizontal: false, vertical: true)
                
                // Actions with Reactions
                HStack(spacing: 12) {
                    // Reaction Button (long press for picker, tap for like)
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isLiked.toggle()
                            onLike()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.caption)
                                .foregroundColor(isLiked ? .red : .secondaryText)
                                .scaleEffect(isLiked ? 1.2 : 1.0)
                            
                            if comment.likesCount > 0 {
                                Text("\(comment.likesCount)")
                                    .font(.caption2)
                                    .foregroundColor(.secondaryText)
                                    .contentTransition(.numericText())
                            }
                        }
                    }
                    .scaleEffect(isLiked ? 1.1 : 1.0)
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .onEnded { _ in
                                HapticManager.shared.impact(.medium)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showReactionPicker = true
                                }
                            }
                    )
                    
                    // Quick Reaction Buttons (shown on long press)
                    if showReactionPicker {
                        HStack(spacing: 8) {
                            ForEach(CommentReactionType.allCases, id: \.self) { reaction in
                                Button(action: {
                                    HapticManager.shared.impact(.light)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        selectedReaction = reaction
                                        showReactionPicker = false
                                    }
                                    // TODO: Call backend to toggle reaction
                                }) {
                                    Text(reaction.emoji)
                                        .font(.system(size: 20))
                                        .scaleEffect(selectedReaction == reaction ? 1.3 : 1.0)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.cardBackground)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Reply Button
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        onReply()
                    }) {
                        Text("Reply")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                }
                .padding(.top, 4)
            }
        }
        .onAppear {
            isLiked = comment.isLiked
        }
        .onTapGesture {
            // Dismiss reaction picker when tapping elsewhere
            if showReactionPicker {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    showReactionPicker = false
                }
            }
        }
    }
}

// MARK: - Comment Input View
struct CommentInputView: View {
    @Binding var text: String
    @Binding var mentions: [Mention]
    @Binding var isReplying: Comment?
    @FocusState.Binding var isFocused: Bool
    let onSend: () -> Void
    
    @StateObject private var viewModel = CommentInputViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            replyIndicatorView
            inputFieldView
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showSuggestions)
    }
    
    @ViewBuilder
    private var replyIndicatorView: some View {
        if let replyingTo = isReplying {
            HStack {
                Text("Replying to \(replyingTo.author.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                
                Spacer()
                
                Button(action: { 
                    HapticManager.shared.impact(.light)
                    isReplying = nil 
                    text = ""
                    mentions = []
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.tertiaryText)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
        }
    }
    
    @ViewBuilder
    private var inputFieldView: some View {
        VStack(spacing: 0) {
            // Autocomplete suggestions for @mentions and #hashtags
            if viewModel.showSuggestions && !viewModel.suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.suggestions) { suggestion in
                            CommentMentionChip(suggestion: suggestion) {
                                insertMention(suggestion)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(Color.cardBackground)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            commentInputRow
        }
    }
    
    @ViewBuilder
    private var commentInputRow: some View {
        HStack(spacing: 12) {
            // Text field with mention/hashtag detection
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text("Add a comment... @mention or #hashtag")
                        .font(.subheadline)
                        .foregroundColor(.tertiaryText)
                        .padding(.horizontal, 12)
                }
                
                TextField("", text: $text, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.subheadline)
                    .lineLimit(1...4)
                    .padding(12)
                    .focused($isFocused)
                    .onChange(of: text) { oldValue, newValue in
                        handleTextChange(oldValue: oldValue, newValue: newValue)
                    }
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(20)
            
            sendButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.cardBackground)
    }
    
    @ViewBuilder
    private var sendButton: some View {
        Button(action: {
            HapticManager.shared.impact(.medium)
            onSend()
        }) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 18))
                .foregroundColor(text.isEmpty ? .tertiaryText : .primaryBrand)
                .rotationEffect(.degrees(-45))
                .scaleEffect(text.isEmpty ? 1.0 : 1.1)
                .animation(.spring(response: 0.3), value: text.isEmpty)
        }
        .disabled(text.isEmpty)
    }
    
    // MARK: - Private Methods
    
    private func handleTextChange(oldValue: String, newValue: String) {
        let cursorPosition = newValue.count
        
        if let context = MentionDetector.getCurrentMentionContext(text: newValue, cursorPosition: cursorPosition) {
            viewModel.currentContext = context
            
            if context.isSearchable {
                viewModel.showSuggestions = true
                Task {
                    await viewModel.searchSuggestions(context: context)
                }
            } else {
                viewModel.showSuggestions = false
            }
        } else {
            viewModel.showSuggestions = false
            viewModel.currentContext = nil
        }
        
        // Update mentions array based on text changes
        updateMentionsForTextChange(oldValue: oldValue, newValue: newValue)
    }
    
    private func insertMention(_ suggestion: MentionSuggestion) {
        guard let context = viewModel.currentContext else { return }
        
        let triggerPosition = context.triggerPosition
        let currentPosition = text.count
        
        let mentionText = suggestion.type.prefix + suggestion.displayText
        
        let startIndex = text.index(text.startIndex, offsetBy: triggerPosition)
        let endIndex = text.index(text.startIndex, offsetBy: min(currentPosition, text.count))
        
        text.replaceSubrange(startIndex..<endIndex, with: mentionText + " ")
        
        let newMention = Mention(
            type: suggestion.type,
            text: suggestion.displayText,
            targetId: suggestion.targetId,
            range: MentionRange(
                start: triggerPosition,
                end: triggerPosition + mentionText.count
            )
        )
        
        mentions.append(newMention)
        
        viewModel.showSuggestions = false
        viewModel.currentContext = nil
        viewModel.suggestions = []
        
        HapticManager.shared.impact(.light)
    }
    
    private func updateMentionsForTextChange(oldValue: String, newValue: String) {
        if newValue.count < oldValue.count {
            mentions.removeAll { mention in
                let mentionEnd = mention.range.end
                let mentionStart = mention.range.start
                return mentionEnd > newValue.count || mentionStart >= newValue.count
            }
        }
    }
}

// MARK: - Comment Input View Model
@MainActor
class CommentInputViewModel: ObservableObject {
    @Published var suggestions: [MentionSuggestion] = []
    @Published var showSuggestions = false
    @Published var isSearching = false
    @Published var currentContext: MentionContext?
    
    private let backendService = BackendService.shared
    private var searchTask: Task<Void, Never>?
    
    func searchSuggestions(context: MentionContext) async {
        searchTask?.cancel()
        
        searchTask = Task {
            isSearching = true
            
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms debounce
            
            guard !Task.isCancelled else { return }
            
            if context.isHashtag {
                await searchHashtags(query: context.query)
            } else {
                await searchUsersAndPlaces(query: context.query)
            }
            
            isSearching = false
        }
    }
    
    private func searchUsersAndPlaces(query: String) async {
        var newSuggestions: [MentionSuggestion] = []
        
        // Search users
        do {
            let users = try await backendService.searchUsers(query: query, limit: 5)
            let userSuggestions = users.map { user in
                MentionSuggestion(
                    id: user.clerkId,
                    type: .user,
                    displayText: user.username ?? "user",
                    subtitle: user.displayName,
                    avatarURL: user.avatarUrl != nil ? URL(string: user.avatarUrl!) : nil,
                    targetId: user.clerkId
                )
            }
            newSuggestions.append(contentsOf: userSuggestions)
        } catch {
            print("❌ CommentInput: Failed to search users: \(error)")
        }
        
        // Search places
        do {
            let places = try await backendService.searchPlaces(query: query, latitude: nil, longitude: nil, limit: 3)
            let placeSuggestions = places.map { place in
                MentionSuggestion(
                    id: place.placeId ?? UUID().uuidString,
                    type: .place,
                    displayText: place.name,
                    subtitle: place.address,
                    avatarURL: nil,
                    targetId: place.placeId ?? UUID().uuidString
                )
            }
            newSuggestions.append(contentsOf: placeSuggestions)
        } catch {
            print("❌ CommentInput: Failed to search places: \(error)")
        }
        
        suggestions = newSuggestions
    }
    
    private func searchHashtags(query: String) async {
        // Common food-related hashtags for suggestions
        let commonHashtags = [
            "foodie", "foodporn", "yummy", "delicious", "tasty",
            "breakfast", "lunch", "dinner", "brunch", "snack",
            "coffee", "tea", "dessert", "healthy", "vegan",
            "glutenfree", "organic", "homemade", "restaurant", "cafe",
            "instafood", "foodlover", "foodgasm", "eeeeeats", "foodstagram"
        ]
        
        let matchingHashtags = commonHashtags.filter {
            $0.lowercased().hasPrefix(query.lowercased())
        }
        
        suggestions = matchingHashtags.prefix(5).map { tag in
            MentionSuggestion.hashtag(tag: tag)
        }
    }
}

// MARK: - Comment Mention Chip
struct CommentMentionChip: View {
    let suggestion: MentionSuggestion
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                // Icon or avatar
                if let avatarURL = suggestion.avatarURL {
                    AsyncImage(url: avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(suggestion.type.color.opacity(0.2))
                            .overlay(
                                Image(systemName: suggestion.type.icon)
                                    .font(.caption2)
                                    .foregroundColor(suggestion.type.color)
                            )
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(suggestion.type.color.opacity(0.2))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: suggestion.type.icon)
                                .font(.caption2)
                                .foregroundColor(suggestion.type.color)
                        )
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(suggestion.type.prefix + suggestion.displayText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText)
                    
                    if let subtitle = suggestion.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundColor(.secondaryText)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.gray.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(suggestion.type.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Empty Comments View
struct EmptyCommentsView: View {
    let onTap: () -> Void
    
    // Engagement prompts that rotate
    private let prompts: [(title: String, subtitle: String, icon: String)] = [
        ("Start the conversation", "Share your experience or ask a question", "bubble.left.and.bubble.right"),
        ("Be the first to comment!", "Your thoughts could spark a great discussion", "sparkles"),
        ("What do you think?", "Join the conversation and share your opinion", "text.bubble"),
        ("Share your take", "Help others by sharing your perspective", "lightbulb")
    ]
    
    @State private var currentPromptIndex = 0
    
    private var currentPrompt: (title: String, subtitle: String, icon: String) {
        prompts[currentPromptIndex % prompts.count]
    }
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            onTap()
        }) {
            VStack(spacing: 16) {
                // Animated icon
                ZStack {
                    Circle()
                        .fill(Color.primaryBrand.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: currentPrompt.icon)
                        .font(.system(size: 32))
                        .foregroundColor(.primaryBrand)
                }
                
                VStack(spacing: 8) {
                    Text(currentPrompt.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                    
                    Text(currentPrompt.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Call-to-action hint
                HStack(spacing: 4) {
                    Image(systemName: "hand.tap")
                        .font(.caption)
                    Text("Tap to comment")
                        .font(.caption)
                }
                .foregroundColor(.tertiaryText)
                .padding(.top, 8)
            }
            .padding(.vertical, 24)
        }
        .buttonStyle(.plain)
        .onAppear {
            // Randomly select a prompt for variety
            currentPromptIndex = Int.random(in: 0..<prompts.count)
        }
    }
}

#Preview("Empty Comments") {
    EmptyCommentsView(onTap: {})
        .padding()
}

#Preview {
    CommentsView(post: MockData.generatePreviewPosts()[0], onCommentAdded: nil)
        .environmentObject(MockAppState())
} 