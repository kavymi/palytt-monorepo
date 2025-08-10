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
                
                // Get author info for the new comment
                var author: User?
                var currentUserClerkId: String?
                
                do {
                    let backendAuthor = try await backendService.getUserByClerkId(
                        clerkId: response.comment.authorClerkId
                    )
                    author = backendAuthor.toUser()
                    currentUserClerkId = backendAuthor.clerkId
                } catch {
                    print("⚠️ Failed to get author info for new comment: \(error)")
                }
                
                // Add the new comment to the list
                let newComment = Comment.from(response.comment, author: author)
                comments.append(newComment)
                
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
    @State private var isReplying: Comment? = nil
    @State private var mentionSuggestions: [User] = []
    @FocusState private var isTextFieldFocused: Bool

    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                contentView
                CommentInputView(
                    text: $newComment,
                    isReplying: $isReplying,
                    isFocused: $isTextFieldFocused,
                    mentionSuggestions: mentionSuggestions,
                    onMentionSearch: { query in
                        Task {
                            await searchUsers(query: query)
                        }
                    },
                    onMentionSelected: onMentionSelected,
                    onSend: {
                        guard !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        
                        viewModel.postComment(
                            text: newComment,
                            replyTo: isReplying
                        ) { success in
                            if success {
                                // Notify parent with updated comment count
                                onCommentAdded?(viewModel.comments.count)
                            }
                        }
                        
                        newComment = ""
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
                                // Empty state with logo
                                VStack(spacing: 20) {
                                    Image("palytt-logo")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 60, height: 60)
                                        .opacity(0.6)
                                    
                                    VStack(spacing: 8) {
                                        Text("No comments yet")
                                            .font(.headline)
                                            .foregroundColor(.primaryText)
                                        
                                        Text("Be the first to share your thoughts!")
                                            .font(.subheadline)
                                            .foregroundColor(.warmAccentText)
                                            .multilineTextAlignment(.center)
                                    }
                                }
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
        
        private func onMentionSelected(_ user: User) {
            // Handle mention selection (replace @mention text in comment)
            print("Selected mention: @\(user.username)")
        }
        
                        // TODO: Fix scope issue with mentionSuggestions
        private func searchUsers(query: String) async {
            // Temporarily disabled until scope issue is resolved
            print("User search requested for: \(query)")
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

// MARK: - Comment Row
struct CommentRow: View {
    let comment: Comment
    var isReply: Bool = false
    let onReply: () -> Void
    let onLike: () -> Void
    
    @State private var isLiked: Bool = false
    @State private var showMenu = false
    
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
                
                // Comment Text
                Text(comment.text)
                    .font(isReply ? .caption : .subheadline)
                    .foregroundColor(.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Actions
                HStack(spacing: 16) {
                    // Like Button
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
    }
}

// MARK: - Comment Input View
struct CommentInputView: View {
    @Binding var text: String
    @Binding var isReplying: Comment?
    @FocusState.Binding var isFocused: Bool
    let mentionSuggestions: [User]
    let onMentionSearch: (String) -> Void
    let onMentionSelected: (User) -> Void
    let onSend: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            replyIndicatorView
            inputFieldView
        }
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
            mentionSuggestionsView
            commentInputRow
        }
    }
    
    @ViewBuilder
    private var mentionSuggestionsView: some View {
        if !mentionSuggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(mentionSuggestions) { user in
                        Button(action: {
                            onMentionSelected(user)
                        }) {
                            Text("@\(user.username)")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color.cardBackground)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
    
    @ViewBuilder
    private var commentInputRow: some View {
        HStack(spacing: 12) {
            TextField("Add a comment...", text: $text, axis: .vertical)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .focused($isFocused)
                .onChange(of: text) { oldValue, newValue in
                    if newValue.contains("@") {
                        let mentionQuery = String(newValue.split(separator: "@").last ?? "")
                        if !mentionQuery.isEmpty {
                            onMentionSearch(mentionQuery)
                        }
                    }
                }
            
            sendButton
        }
        .padding()
        .background(Color.gray.opacity(0.1))
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
    
    private func updateTextWithMention(_ user: User) {
        // This will be handled by MentionTextEditor, but we can add additional logic here if needed
    }
}

#Preview {
    CommentsView(post: MockData.generatePreviewPosts()[0], onCommentAdded: nil)
        .environmentObject(MockAppState())
} 