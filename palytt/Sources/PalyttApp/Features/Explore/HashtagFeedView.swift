//
//  HashtagFeedView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI

// MARK: - Hashtag Feed View

/// A view that displays all posts and comments containing a specific hashtag
struct HashtagFeedView: View {
    let hashtag: String
    
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: HashtagFeedViewModel
    
    init(hashtag: String) {
        self.hashtag = hashtag
        self._viewModel = StateObject(wrappedValue: HashtagFeedViewModel(hashtag: hashtag))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Hashtag Header
                    hashtagHeader
                    
                    // Content
                    if viewModel.isLoading && viewModel.posts.isEmpty {
                        loadingView
                    } else if viewModel.posts.isEmpty && !viewModel.isLoading {
                        emptyStateView
                    } else {
                        postsList
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primaryText)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("#\(hashtag)")
                        .font(.headline)
                        .fontWeight(.bold)
                }
            }
            .task {
                await viewModel.loadPosts()
            }
            .refreshable {
                await viewModel.refreshPosts()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var hashtagHeader: some View {
        VStack(spacing: 16) {
            // Large hashtag display
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.primaryBrand, Color.primaryBrand.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Text("#")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Stats
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(viewModel.posts.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                    Text("Posts")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading posts...")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "number.square")
                .font(.system(size: 48))
                .foregroundColor(.secondaryText)
            
            Text("No posts yet")
                .font(.headline)
                .foregroundColor(.primaryText)
            
            Text("Be the first to post with #\(hashtag)")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var postsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.posts) { post in
                    PostCardView(post: post)
                        .environmentObject(appState)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    
                    Divider()
                        .padding(.horizontal)
                }
                
                // Load more indicator
                if viewModel.hasMorePosts {
                    ProgressView()
                        .padding()
                        .onAppear {
                            Task {
                                await viewModel.loadMorePosts()
                            }
                        }
                }
            }
        }
    }
}

// MARK: - Hashtag Feed ViewModel

@MainActor
class HashtagFeedViewModel: ObservableObject {
    let hashtag: String
    
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMorePosts = true
    
    private let backendService = BackendService.shared
    private var currentPage = 0
    private let pageSize = 20
    
    init(hashtag: String) {
        self.hashtag = hashtag
    }
    
    func loadPosts() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedPosts = try await backendService.searchPostsByHashtag(
                hashtag: hashtag,
                limit: pageSize,
                offset: 0
            )
            
            posts = fetchedPosts
            hasMorePosts = fetchedPosts.count >= pageSize
            currentPage = 1
        } catch {
            print("❌ HashtagFeedViewModel: Failed to load posts: \(error)")
            errorMessage = "Failed to load posts"
        }
        
        isLoading = false
    }
    
    func refreshPosts() async {
        currentPage = 0
        await loadPosts()
    }
    
    func loadMorePosts() async {
        guard !isLoading, hasMorePosts else { return }
        
        isLoading = true
        
        do {
            let fetchedPosts = try await backendService.searchPostsByHashtag(
                hashtag: hashtag,
                limit: pageSize,
                offset: currentPage * pageSize
            )
            
            posts.append(contentsOf: fetchedPosts)
            hasMorePosts = fetchedPosts.count >= pageSize
            currentPage += 1
        } catch {
            print("❌ HashtagFeedViewModel: Failed to load more posts: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Post Card View (Simplified for Hashtag Feed)

struct PostCardView: View {
    let post: Post
    @EnvironmentObject var appState: AppState
    @State private var showPostDetail = false
    
    var body: some View {
        Button(action: { showPostDetail = true }) {
            HStack(alignment: .top, spacing: 12) {
                // Post thumbnail
                if let firstImage = post.mediaURLs.first {
                    AsyncImage(url: firstImage) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .failure:
                            placeholderImage
                        case .empty:
                            ProgressView()
                                .frame(width: 80, height: 80)
                        @unknown default:
                            placeholderImage
                        }
                    }
                } else {
                    placeholderImage
                }
                
                // Post info
                VStack(alignment: .leading, spacing: 6) {
                    // Author
                    HStack(spacing: 6) {
                        UserAvatar(user: post.author, size: 24)
                        
                        Text(post.author.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primaryText)
                        
                        Spacer()
                        
                        Text(post.createdAt.timeAgoDisplay())
                            .font(.caption)
                            .foregroundColor(.tertiaryText)
                    }
                    
                    // Title/Caption
                    if let title = post.title, !title.isEmpty {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                            .lineLimit(1)
                    }
                    
                    Text(post.caption)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                    
                    // Stats
                    HStack(spacing: 16) {
                        Label("\(post.likesCount)", systemImage: "heart")
                        Label("\(post.commentsCount)", systemImage: "bubble.right")
                    }
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showPostDetail) {
            PostDetailView(post: post)
                .environmentObject(appState)
        }
    }
    
    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.2))
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            )
    }
}

// MARK: - Preview

#Preview {
    HashtagFeedView(hashtag: "foodie")
        .environmentObject(AppState())
}

