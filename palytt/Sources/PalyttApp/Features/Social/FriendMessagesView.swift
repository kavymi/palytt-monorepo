//
//  FriendMessagesView.swift
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

// MARK: - Friend Messages View (Conversation)

struct FriendMessagesView: View {
    let friend: BackendUser
    
    @StateObject private var viewModel = FriendMessagesViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingPostPicker = false
    @Namespace private var bottomID
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            conversationHeader
            
            Divider()
                .background(Color.divider)
            
            // Messages content
            if viewModel.isLoadingConversation && viewModel.sharedPosts.isEmpty {
                loadingView
            } else if viewModel.sharedPosts.isEmpty {
                emptyConversationView
            } else {
                messagesScrollView
            }
            
            // Bottom action bar
            bottomActionBar
        }
        .background(Color.background)
        .navigationBarHidden(true)
        .task {
            await viewModel.loadConversation(with: friend.clerkId)
        }
        .onDisappear {
            viewModel.stopAllSubscriptions()
        }
        .sheet(isPresented: $showingPostPicker) {
            PostSharePickerView { post in
                Task {
                    await viewModel.sharePost(post, with: friend.clerkId)
                }
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    // MARK: - Conversation Header
    
    private var conversationHeader: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: {
                HapticManager.shared.impact(.light)
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primaryText)
            }
            
            // Friend avatar
            if let avatarUrl = friend.avatarUrl, let url = URL(string: avatarUrl) {
                KFImage(url)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.primaryBrand.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(friend.displayName?.prefix(1).uppercased() ?? "?")
                            .font(.headline)
                            .foregroundColor(.primaryBrand)
                    )
            }
            
            // Friend name
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName ?? friend.username ?? "Unknown")
                    .font(.headline)
                    .foregroundColor(.primaryText)
                
                Text("Share posts only")
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.cardBackground)
    }
    
    // MARK: - Messages Scroll View
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    // Info banner
                    postOnlyInfoBanner
                        .padding(.top, 16)
                    
                    ForEach(viewModel.sharedPosts) { sharedPost in
                        let isFromCurrentUser = sharedPost.senderClerkId == Clerk.shared.user?.id
                        
                        SharedPostCard(
                            sharedPost: sharedPost,
                            isFromCurrentUser: isFromCurrentUser,
                            onPostTap: {
                                // Navigate to post detail
                                navigateToPost(postId: sharedPost.postId)
                            }
                        )
                    }
                    
                    // Invisible anchor for scrolling
                    Color.clear
                        .frame(height: 1)
                        .id(bottomID)
                }
                .padding(.bottom, 16)
            }
            .background(Color.background)
            .onChange(of: viewModel.sharedPosts.count) { _, _ in
                withAnimation {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
            .onAppear {
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
        }
    }
    
    // MARK: - Post Only Info Banner
    
    private var postOnlyInfoBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.primaryBrand)
            
            Text("This is a post-sharing conversation. You can only share posts, not send text messages.")
                .font(.caption)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primaryBrand.opacity(0.08))
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - Empty Conversation View
    
    private var emptyConversationView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.primaryBrand.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.primaryBrand)
            }
            
            VStack(spacing: 8) {
                Text("No Shared Posts Yet")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text("Share your favorite posts with \(friend.displayName ?? "this friend")!")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Info text
            postOnlyInfoBanner
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading conversation...")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Bottom Action Bar
    
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.divider)
            
            HStack(spacing: 16) {
                // Share Post Button
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    showingPostPicker = true
                }) {
                    HStack(spacing: 8) {
                        if viewModel.isSendingPost {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        
                        Text("Share a Post")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.primaryBrand)
                    )
                }
                .disabled(viewModel.isSendingPost)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.cardBackground)
        }
    }
    
    // MARK: - Helper Methods
    
    private func navigateToPost(postId: String) {
        // TODO: Implement navigation to post detail
        print("📱 Navigate to post: \(postId)")
        HapticManager.shared.impact(.light)
    }
}

// MARK: - Post Share Picker View

struct PostSharePickerView: View {
    let onPostSelected: (Post) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var myPosts: [Post] = []
    @State private var savedPosts: [Post] = []
    @State private var isLoading = true
    
    private let tabs = ["My Posts", "Saved"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                tabPicker
                
                Divider()
                    .background(Color.divider)
                
                // Content
                TabView(selection: $selectedTab) {
                    myPostsTab
                        .tag(0)
                    
                    savedPostsTab
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .background(Color.background)
            .navigationTitle("Share a Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    }
                    .foregroundColor(.primaryText)
                }
            }
        }
        .task {
            await loadPosts()
        }
    }
    
    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    HapticManager.shared.impact(.light)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tabs[index])
                            .font(.subheadline)
                            .fontWeight(selectedTab == index ? .semibold : .medium)
                            .foregroundColor(selectedTab == index ? .primaryBrand : .secondaryText)
                        
                        Rectangle()
                            .fill(selectedTab == index ? Color.primaryBrand : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var myPostsTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if isLoading {
                    ForEach(0..<3, id: \.self) { _ in
                        PostCardSkeleton()
                    }
                } else if myPosts.isEmpty {
                    emptyState(
                        icon: "photo.on.rectangle",
                        title: "No Posts Yet",
                        message: "Create some posts to share them with friends!"
                    )
                } else {
                    ForEach(myPosts, id: \.id) { post in
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            onPostSelected(post)
                            dismiss()
                        }) {
                            PostSharePreviewCard(post: post)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(Color.background)
    }
    
    private var savedPostsTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if isLoading {
                    ForEach(0..<3, id: \.self) { _ in
                        PostCardSkeleton()
                    }
                } else if savedPosts.isEmpty {
                    emptyState(
                        icon: "bookmark",
                        title: "No Saved Posts",
                        message: "Save posts to share them with friends later!"
                    )
                } else {
                    ForEach(savedPosts, id: \.id) { post in
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            onPostSelected(post)
                            dismiss()
                        }) {
                            PostSharePreviewCard(post: post)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(Color.background)
    }
    
    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 24) {
            Circle()
                .fill(Color.primaryBrand.opacity(0.1))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundColor(.primaryBrand)
                )
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primaryText)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 60)
    }
    
    private func loadPosts() async {
        isLoading = true
        
        do {
            guard let currentUser = Clerk.shared.user else {
                isLoading = false
                return
            }
            
            // Load user's posts
            let backendPosts = try await BackendService.shared.getPostsByUser(userId: currentUser.id)
            await MainActor.run {
                myPosts = backendPosts.map { Post.from(backendPost: $0, author: nil) }
            }
            
            // Load saved/bookmarked posts
            let bookmarkedPosts = try await BackendService.shared.getBookmarkedPosts()
            await MainActor.run {
                savedPosts = bookmarkedPosts.map { Post.from(backendPost: $0, author: nil) }
            }
            
        } catch {
            print("❌ PostSharePickerView: Failed to load posts: \(error)")
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
}

// MARK: - Post Share Preview Card

struct PostSharePreviewCard: View {
    let post: Post
    
    var body: some View {
        HStack(spacing: 12) {
            // Post image
            if let imageUrl = post.mediaURLs.first {
                KFImage(imageUrl)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primaryBrand.opacity(0.2))
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(.primaryBrand)
                    )
            }
            
            // Post info
            VStack(alignment: .leading, spacing: 4) {
                Text(post.title ?? post.caption.prefix(50).description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primaryText)
                    .lineLimit(2)
                
                if let shop = post.shop {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.primaryBrand)
                        
                        Text(shop.name)
                            .font(.caption)
                            .foregroundColor(.primaryBrand)
                            .lineLimit(1)
                    }
                }
                
                Text(post.createdAt.timeAgoDisplay())
                    .font(.caption2)
                    .foregroundColor(.tertiaryText)
            }
            
            Spacer()
            
            // Select indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.tertiaryText)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.divider.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    // Create mock BackendUser using the static from() method
    let mockFriend = BackendUser.from([
        "id": "1",
        "clerkId": "friend123",
        "firstName": "John",
        "lastName": "Doe",
        "username": "johndoe",
        "displayName": "John Doe",
        "name": "John Doe",
        "followerCount": 100,
        "followingCount": 50,
        "postsCount": 25,
        "isVerified": false,
        "isActive": true
    ])!
    
    return FriendMessagesView(friend: mockFriend)
}

