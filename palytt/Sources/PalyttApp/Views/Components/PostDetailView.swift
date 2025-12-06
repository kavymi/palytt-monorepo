//
//  PostDetailView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Kingfisher
import MapKit
import Clerk

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Post Detail View
struct PostDetailView: View {
    let post: Post
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = PostDetailViewModel()
    @State private var selectedImageIndex = 0
    @State private var showingComments = false
    @State private var showingMap = false
    @State private var showingShareSheet = false
    @State private var commentText = ""
    @State private var isLiked = false
    @State private var isSaved = false
    @State private var likesCount = 0
    @State private var showingImageViewer = false
    @State private var scrollOffset: CGFloat = 0
    @State private var comments: [Comment] = []
    @State private var showReplyField: UUID? = nil
    @State private var showingShopDetail = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.background.ignoresSafeArea()
                
                // Main Content
                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 0) {
                            // Image Gallery with parallax effect
                            ImageGalleryView()
                                .offset(y: scrollOffset > 0 ? -scrollOffset * 0.5 : 0)
                            
                            // Content Card
                            VStack(spacing: 0) {
                                // Post Content
                                PostContentView()
                                
                                // Engagement Section
                                EngagementStatsView()
                                
                                // Action Buttons
                                ActionButtonsView()
                                
                                // Comments Section
                                CommentsFullView()
                                
                                // Bottom padding for safe area
                                Color.clear.frame(height: 100)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.cardBackground)
                                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: -10)
                            )
                            .offset(y: -24)
                        }
                        .background(
                            GeometryReader { scrollGeometry in
                                Color.clear
                                    .preference(key: ScrollOffsetPreferenceKey.self, 
                                              value: scrollGeometry.frame(in: .named("scroll")).minY)
                            }
                        )
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            scrollOffset = value
                        }
                    }
                }
                
                // Floating Header
                VStack {
                    HStack {
                        Button(action: { 
                            HapticManager.shared.impact(.light)
                            dismiss() 
                        }) {
                            Circle()
                                .fill(Color.cardBackground.opacity(0.9))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primaryText)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        }
                        
                        Spacer()
                        
                        Menu {
                            Button(action: { showingShareSheet = true }) {
                                Label("Share Post", systemImage: "square.and.arrow.up")
                            }
                            
                            Button(action: { viewModel.reportPost(post.id) }) {
                                Label("Report Post", systemImage: "flag")
                            }
                            
                            if post.author.clerkId == appState.currentUser?.clerkId {
                                Divider()
                                Button(role: .destructive, action: { viewModel.deletePost(post.id) }) {
                                    Label("Delete Post", systemImage: "trash")
                                }
                            }
                        } label: {
                            Circle()
                                .fill(Color.cardBackground.opacity(0.9))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primaryText)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 50)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingComments) {
            CommentsView(post: post) { newCount in
                // Update the comment count in the UI
                viewModel.updateCommentCount(newCount)
            }
        }
        .sheet(isPresented: $showingMap) {
            LocationDetailView(location: post.location)
        }
        .fullScreenCover(isPresented: $showingImageViewer) {
            ImageViewerView(
                images: post.mediaURLs,
                selectedIndex: $selectedImageIndex,
                isPresented: $showingImageViewer
            )
        }
        .onAppear {
            setupInitialState()
            viewModel.loadPostDetails(post.id)
        }
        .task {
            print("🗨️ PostDetailView: Loading comments for post: \(post.id)")
            await viewModel.loadComments(for: post)
        }
    }
    
    // MARK: - Image Gallery View
    @ViewBuilder
    private func ImageGalleryView() -> some View {
        ZStack {
            if !post.mediaURLs.isEmpty {
                TabView(selection: $selectedImageIndex) {
                    ForEach(Array(post.mediaURLs.enumerated()), id: \.offset) { index, imageURL in
                        KFImage(imageURL)
                            .placeholder {
                                Rectangle()
                                    .fill(LinearGradient.primaryGradient.opacity(0.2))
                                    .overlay(
                                        VStack {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(1.2)
                                            
                                            Text("Loading...")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .padding(.top, 8)
                                        }
                                    )
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 450)
                            .clipped()
                            .onTapGesture {
                                HapticManager.shared.impact(.light)
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    selectedImageIndex = index
                                }
                                showingImageViewer = true
                            }
                            .scaleEffect(selectedImageIndex == index ? 1.0 : 0.95)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: selectedImageIndex)
                            .tag(index)
                    }
                }
                .frame(height: 450)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.4), value: selectedImageIndex)
                
                // Custom Page Indicator
                if post.mediaURLs.count > 1 {
                    VStack {
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Spacer()
                            ForEach(0..<post.mediaURLs.count, id: \.self) { index in
                                Circle()
                                    .fill(selectedImageIndex == index ? Color.white : Color.white.opacity(0.4))
                                    .frame(width: selectedImageIndex == index ? 10 : 8, height: selectedImageIndex == index ? 10 : 8)
                                    .scaleEffect(selectedImageIndex == index ? 1.2 : 1.0)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: selectedImageIndex)
                            }
                            Spacer()
                        }
                        .padding(.bottom, 20)
                    }
                }
                
                // Image Counter
                if post.mediaURLs.count > 1 {
                    VStack {
                        HStack {
                            Spacer()
                            
                            Text("\(selectedImageIndex + 1)/\(post.mediaURLs.count)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.6))
                                        .background(.ultraThinMaterial)
                                )
                                .padding(.trailing, 20)
                                .padding(.top, 60)
                        }
                        
                        Spacer()
                    }
                }
            } else {
                Rectangle()
                    .fill(LinearGradient.primaryGradient.opacity(0.3))
                    .frame(height: 450)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.system(size: 50))
                                .foregroundColor(.primaryBrand)
                            
                            Text("No Image")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.primaryBrand)
                        }
                    )
            }
        }
    }
    
    // MARK: - Post Content View
    @ViewBuilder
    private func PostContentView() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Author Info
            HStack(spacing: 16) {
                AsyncImage(url: post.author.avatarURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(LinearGradient.primaryGradient)
                        .overlay(
                            Text(post.author.displayName.prefix(1))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(post.author.displayName)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primaryText)
                        
                        if post.author.clerkId == appState.currentUser?.clerkId {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 14))
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(.tertiaryText)
                        
                        Text(post.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                }
                
                Spacer()
                
                if post.author.clerkId != appState.currentUser?.clerkId {
                    Button(action: { 
                        HapticManager.shared.impact(.light)
                        viewModel.toggleFollow(user: post.author) 
                    }) {
                        Text(viewModel.isFollowing ? "Following" : "Follow")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(viewModel.isFollowing ? 
                                          LinearGradient(colors: [Color.gray.opacity(0.15)], startPoint: .leading, endPoint: .trailing) : 
                                          LinearGradient.primaryGradient
                                    )
                            )
                            .foregroundColor(viewModel.isFollowing ? .primaryText : .white)
                            .overlay(
                                Capsule()
                                    .stroke(viewModel.isFollowing ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                    }
                    .scaleEffect(viewModel.isFollowing ? 0.95 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isFollowing)
                }
            }
            
            // Post Title
            if let title = post.title, !title.isEmpty {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
            }
            
            // Post Caption with tappable mentions
            if !post.caption.isEmpty {
                MentionText(
                    text: post.caption,
                    mentions: post.mentions,
                    font: .body,
                    textColor: .primaryText,
                    lineLimit: nil
                )
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
            }
            
            // Menu Items/Tags
            if !post.menuItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(post.menuItems, id: \.self) { item in
                            Text(item)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.primaryBrand.opacity(0.12))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.primaryBrand.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .foregroundColor(.primaryBrand)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.horizontal, -24)
            }
            
            // Rating & Stats
            HStack(spacing: 16) {
                // Rating
                if let rating = post.rating {
                    HStack(spacing: 6) {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                    .foregroundColor(.warning)
                                    .font(.system(size: 14))
                            }
                        }
                        
                        Text(String(format: "%.1f", rating))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.primaryText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.warning.opacity(0.1))
                    )
                }
                
                Spacer()
            }
            
            // Location
            LocationButton()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
    
    // MARK: - Location Button
    @ViewBuilder
    private func LocationButton() -> some View {
        Button(action: { 
            HapticManager.shared.impact(.light)
            // If shop exists, show shop detail, otherwise show map
            if post.shop != nil {
                showingShopDetail = true
            } else {
                showingMap = true
            }
        }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.primaryBrand.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: post.shop != nil ? "storefront.fill" : "location.fill")
                            .foregroundColor(.primaryBrand)
                            .font(.system(size: 16, weight: .semibold))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    // Show shop name if available, otherwise show address
                    if let shop = post.shop {
                        Text(shop.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                            .lineLimit(1)
                        
                        Text(post.location.address)
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                            .lineLimit(1)
                    } else {
                        Text(post.location.address)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                            .lineLimit(1)
                        
                        Text("\(post.location.city), \(post.location.country)")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.tertiaryText)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .sheet(isPresented: $showingShopDetail) {
            if let shop = post.shop {
                NavigationStack {
                    ShopDetailView(shop: shop)
                }
            }
        }
    }
    
    // MARK: - Engagement Stats View
    @ViewBuilder
    private func EngagementStatsView() -> some View {
        HStack(spacing: 20) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 14))
                Text("\(likesCount)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
            }
            
            HStack(spacing: 6) {
                Image(systemName: "bubble")
                    .foregroundColor(.primaryBrand)
                    .font(.system(size: 14))
                Text("\(viewModel.comments.count)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
    
    // MARK: - Action Buttons View
    @ViewBuilder
    private func ActionButtonsView() -> some View {
        HStack(spacing: 16) {
            // Like Button
            Button(action: { 
                HapticManager.shared.impact(.light)
                toggleLike() 
            }) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .foregroundColor(isLiked ? .red : .primaryText)
                    .font(.system(size: 20, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(isLiked ? Color.red.opacity(0.1) : Color.gray.opacity(0.08))
                )
                .scaleEffect(isLiked ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLiked)
            }
            
            // Comment Button
            Button(action: { 
                HapticManager.shared.impact(.light)
                // Scroll to comments section instead of showing sheet
                withAnimation(.easeInOut(duration: 0.5)) {
                    // This will be handled by the scroll view
                }
            }) {
                Image(systemName: "bubble.left")
                    .foregroundColor(.primaryBrand)
                    .font(.system(size: 20, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.primaryBrand.opacity(0.1))
                )
            }
            
            // Save Button
            Button(action: { 
                HapticManager.shared.impact(.light)
                toggleSave() 
            }) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .foregroundColor(isSaved ? .primaryBrand : .primaryText)
                    .font(.system(size: 20, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(isSaved ? Color.primaryBrand.opacity(0.1) : Color.gray.opacity(0.08))
                )
                .scaleEffect(isSaved ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSaved)
            }
            
            Spacer()
            
            // Share Button
            Button(action: { 
                HapticManager.shared.impact(.light)
                showingShareSheet = true 
            }) {
                Circle()
                    .fill(Color.gray.opacity(0.08))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.primaryText)
                            .font(.system(size: 16, weight: .semibold))
                    )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    // MARK: - Comments Full View
    @ViewBuilder
    private func CommentsFullView() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Divider with spacing
            Divider()
                .padding(.horizontal, 24)
                .padding(.top, 8)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Comments")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                    .padding(.horizontal, 24)
                
                // Comment Input Field
                PostCommentInputView(
                    commentText: $commentText,
                    onSubmit: {
                        submitComment()
                    }
                )
                
                // Comments List
                if viewModel.comments.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 40))
                            .foregroundColor(.secondaryText)
                        
                        Text("No comments yet")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                        
                        Text("Be the first to share your thoughts!")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.comments, id: \.id) { comment in
                            CommentRowView(
                                comment: comment,
                                onLikeComment: { comment in
                                    await likeComment(comment)
                                },
                                onReply: { comment in
                                    showReplyField = comment.id
                                }
                            )
                            .padding(.horizontal, 24)
                        }
                    }
                }
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Helper Methods
    private func setupInitialState() {
        isLiked = post.isLiked
        isSaved = post.isSaved
        likesCount = post.likesCount
    }
    
    private func toggleLike() {
        withAnimation(.spring(response: 0.3)) {
            isLiked.toggle()
            likesCount += isLiked ? 1 : -1
        }
        
        HapticManager.shared.impact(.light)
        
        Task {
            await viewModel.toggleLike(for: post)
        }
    }
    
    private func toggleSave() {
        withAnimation(.spring(response: 0.3)) {
            isSaved.toggle()
        }
        
        HapticManager.shared.impact(.light)
        
        Task {
            await viewModel.toggleSave(for: post)
        }
    }
    
    private func submitComment() {
        guard !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        HapticManager.shared.impact(.light)
        
        Task {
            await viewModel.submitComment(for: post, text: commentText)
            await MainActor.run {
                commentText = ""
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func likeComment(_ comment: Comment) async {
        do {
            let _ = try await BackendService.shared.toggleCommentLike(
                commentId: comment.id.uuidString
            )
            
            // Update the comment in our local state
            await MainActor.run {
                if let index = comments.firstIndex(where: { $0.id == comment.id }) {
                    // Update the local comment with new like status
                    var updatedComment = comments[index]
                    updatedComment.isLiked.toggle()
                    updatedComment.likesCount += updatedComment.isLiked ? 1 : -1
                    comments[index] = updatedComment
                }
                HapticManager.shared.impact(.light)
            }
        } catch {
            print("❌ Failed to like comment: \(error)")
        }
    }
    
    private func submitReply(to parentComment: Comment, content: String) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        do {
            let reply = try await BackendService.shared.submitComment(
                postId: post.id.uuidString,
                content: content
            )
            
            await MainActor.run {
                if let reply = reply {
                    comments.append(reply)
                    comments.sort { $0.createdAt < $1.createdAt }
                    showReplyField = nil
                    HapticManager.shared.impact(.light)
                }
            }
        } catch {
            print("❌ Failed to submit reply: \(error)")
        }
    }
}

// MARK: - Post Comment Input View
struct PostCommentInputView: View {
    @Binding var commentText: String
    let onSubmit: () -> Void
    @FocusState private var isCommentFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(LinearGradient.primaryGradient)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                )
            
            HStack(spacing: 8) {
                TextField("Add a comment...", text: $commentText, axis: .vertical)
                    .font(.subheadline)
                    .focused($isCommentFieldFocused)
                    .lineLimit(1...4)
                
                if !commentText.isEmpty {
                    Button(action: onSubmit) {
                        Circle()
                            .fill(LinearGradient.primaryGradient)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "arrow.up")
                                    .foregroundColor(.white)
                                    .font(.system(size: 14, weight: .bold))
                            )
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isCommentFieldFocused ? Color.primaryBrand : Color.clear, lineWidth: 2)
                    )
            )
        }
        .padding(.horizontal, 24)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: commentText.isEmpty)
    }
}

// MARK: - Comment Row View
struct CommentRowView: View {
    let comment: Comment
    let onLikeComment: (Comment) async -> Void
    let onReply: (Comment) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            UserAvatar(user: comment.author, size: 40)
            
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(comment.author.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                        
                        Text(comment.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.tertiaryText)
                    }
                    
                    Text(comment.text)
                        .font(.subheadline)
                        .foregroundColor(.primaryText)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.06))
                )
                
                // Comment Actions
                HStack(spacing: 16) {
                    Button(action: {
                        Task {
                            await onLikeComment(comment)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                                .foregroundColor(comment.isLiked ? .red : .secondaryText)
                                .font(.caption)
                            
                            if comment.likesCount > 0 {
                                Text("\(comment.likesCount)")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                        }
                    }
                    
                    Button(action: {
                        onReply(comment)
                    }) {
                        Text("Reply")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    
                    Spacer()
                }
                .padding(.leading, 16)
            }
            
            Spacer()
        }
    }
}

// MARK: - Image Viewer
struct ImageViewerView: View {
    let images: [URL]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $selectedIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, imageURL in
                    KFImage(imageURL)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .automatic))
            
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.title2)
                            .padding()
                    }
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Location Detail View
struct LocationDetailView: View {
    let location: Location
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Map {
                Annotation(location.address, coordinate: CLLocationCoordinate2D(
                    latitude: location.latitude,
                    longitude: location.longitude
                )) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                        .font(.title)
                }
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Note: Comment struct and CommentsView are defined in CommentsView.swift

// MARK: - Post Detail View Model
@MainActor
class PostDetailViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var isFollowing = false
    @Published var isLoading = false
    
    func loadPostDetails(_ postId: UUID) {
        // TODO: Load additional post details if needed
    }
    
    func loadComments(for post: Post) async {
        do {
            // Use the Convex ID for backend calls
            let convexPostId = post.convexId
            
            // Load comments from Convex
            let commentsResponse = try await BackendService.shared.getComments(postId: convexPostId)
            let loadedComments = commentsResponse.comments.map { backendComment in
                Comment.from(backendComment) // Use the improved conversion method
            }
            
            await MainActor.run {
                self.comments = loadedComments
            }
        } catch {
            print("Error loading comments: \(error)")
            await MainActor.run {
                self.comments = []
            }
        }
    }
    
    func toggleLike(for post: Post) async {
        do {
            // Call backend to toggle like using Convex ID
            let convexPostId = post.convexId
            let result = try await BackendService.shared.toggleLike(postId: convexPostId)
            print("✅ Post like toggled successfully: \(result)")
            
            // Send notification if user just liked the post (not unliked)
            if result.isLiked {
                await sendPostLikeNotification(post: post)
                // Play like sound effect
                // SoundManager.shared.playLikeSound()
            }
            
            // Update local post state
            await MainActor.run {
                // Update the likes count in UI if we have reference to the post
                // This would ideally be handled by the parent view model
            }
            
        } catch {
            print("❌ Error toggling post like: \(error)")
        }
    }
    
    private func sendPostLikeNotification(post: Post) async {
        do {
            // Get current user info
            guard let currentUser = Clerk.shared.user?.id else {
                print("⚠️ Could not get current user for post like notification")
                return
            }
            
            // Don't send notification if user liked their own post
            if post.author.clerkId == currentUser {
                return
            }
            
            let _ = try await BackendService.shared.createNotification(
                recipientId: post.author.clerkId ?? "",
                senderId: currentUser,
                type: "post_like",
                title: "Post Liked",
                message: "Someone liked your post",
                metadata: [
                    "postId": post.convexId
                ]
            )
        } catch {
            print("⚠️ Failed to send post like notification: \(error)")
        }
    }
    
    func toggleSave(for post: Post) async {
        do {
            // Call backend to toggle save using Convex ID
            let convexPostId = post.convexId
            let result = try await BackendService.shared.toggleBookmark(postId: convexPostId)
            print("✅ Post save toggled successfully: \(result)")
            
            // Notify SavedView to refresh
            NotificationCenter.default.post(name: NSNotification.Name("BookmarkChanged"), object: nil)
        } catch {
            print("❌ Error toggling post save: \(error)")
        }
    }
    
    func toggleFollow(user: User) {
        // TODO: Toggle follow on backend
        isFollowing.toggle()
    }
    
    func reportPost(_ postId: UUID) {
        // TODO: Report post
    }
    
    func deletePost(_ postId: UUID) {
        // TODO: Delete post
    }
    
    func submitComment(for post: Post, text: String) async {
        do {
            // Use Convex ID for backend calls
            let convexPostId = post.convexId
            
            print("🗨️ Submitting comment for post: \(convexPostId)")
            
            // Call Convex addComment mutation
            let response = try await BackendService.shared.addComment(
                postId: convexPostId,
                content: text
            )
            
            print("✅ Comment submitted successfully: \(response.comment.content)")
            
            // Reload all comments to get the latest state
            await loadComments(for: post)
            
        } catch {
            print("❌ Error submitting comment: \(error)")
        }
    }
    
    func updateCommentCount(_ newCount: Int) {
        // Update the local comment count - this will trigger UI updates
        // Note: In a real app, you might want to trigger a refresh of the post data
        print("📝 Comment count updated to: \(newCount)")
    }
}

#Preview {
    NavigationStack {
        PostDetailView(post: MockData.generatePreviewPosts().first!)
            .environmentObject(MockAppState())
    }
} 