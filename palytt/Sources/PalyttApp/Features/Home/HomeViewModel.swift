//
//  HomeViewModel.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import SwiftUI
import Clerk
import Combine

// MARK: - Supporting Types for Enhanced Combine Implementation

enum FeedType {
    case friends
}

enum LoadingState {
    case idle
    case loading
    case loadingMore
    case refreshing
    case failed(Error)
}

@MainActor
class HomeViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var hasMorePages = true
    @Published var friendsCount: Int = 0  // Track number of friends for empty state
    
    // Computed reactive loading state for enhanced state management
    var loadingState: LoadingState {
        loadingStateSubject.value
    }
    
    // BackendService for friends feed
    private let backendService: BackendService?
    private var currentPage = 1
    private var nextCursor: String?
    private let pageSize = 20
    
    // Enhanced Combine cancellation handling for better performance
    private var cancellables = Set<AnyCancellable>()
    private var loadingTask: Task<Void, Never>?
    
    // Request-specific cancellables for fine-grained control
    private var initialFetchCancellable: AnyCancellable?
    private var paginationCancellable: AnyCancellable?
    private var refreshCancellable: AnyCancellable?
    
    // Publishers for reactive state management
    private let feedTypeSubject = CurrentValueSubject<FeedType, Never>(.friends)
    private let loadingStateSubject = CurrentValueSubject<LoadingState, Never>(.idle)
    
    // Debounced scroll trigger for optimal performance
    private let scrollTriggerSubject = PassthroughSubject<Post, Never>()
    
    // Check if we're running in preview mode
    private var isPreviewMode: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    init() {
        // Check preview mode directly without accessing self
        let isInPreviewMode = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        
        if isInPreviewMode {
            // In preview mode, don't initialize real services
            self.backendService = nil
            // Load mock data for preview
            self.posts = MockData.generatePreviewPosts()
        } else {
            // BackendService for friends feed
            self.backendService = BackendService.shared
        }
        
        // Set up reactive scroll handling with debouncing
        setupReactiveScrollHandling()
        
        // Set up reactive state management
        setupReactiveStateManagement()
    }
    
    // ✅ Add timestamp tracking for smart refresh
    private var lastFetchedAt: Date?
    private let staleDataThreshold: TimeInterval = 300 // 5 minutes
    
    // ✅ Add property to check if data is stale
    var isDataStale: Bool {
        guard let lastFetchedAt = lastFetchedAt else { return true }
        return Date().timeIntervalSince(lastFetchedAt) > staleDataThreshold
    }
    
    
    // MARK: - Enhanced Combine Setup Methods
    
    /// Set up reactive scroll handling with debouncing for optimal performance
    private func setupReactiveScrollHandling() {
        scrollTriggerSubject
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] post in
                self?.performScrollTriggeredLoading(for: post)
            }
            .store(in: &cancellables)
    }
    
    /// Set up reactive state management for coordinated UI updates
    private func setupReactiveStateManagement() {
        // Reactive loading state updates
        loadingStateSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateUILoadingState(for: state)
            }
            .store(in: &cancellables)
        
        // Feed type changes trigger appropriate data loading
        feedTypeSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] feedType in
                self?.handleFeedTypeChange(feedType)
            }
            .store(in: &cancellables)
    }
    
    /// Update UI loading state based on reactive state changes
    private func updateUILoadingState(for state: LoadingState) {
        switch state {
        case .idle:
            isLoading = false
            isLoadingMore = false
            errorMessage = nil
        case .loading:
            isLoading = true
            isLoadingMore = false
            errorMessage = nil
        case .loadingMore:
            isLoading = false
            isLoadingMore = true
            errorMessage = nil
        case .refreshing:
            isLoading = true
            isLoadingMore = false
            errorMessage = nil
        case .failed(let error):
            isLoading = false
            isLoadingMore = false
            errorMessage = error.localizedDescription
        }
    }
    
    /// Handle feed type changes with appropriate data loading strategy
    private func handleFeedTypeChange(_ feedType: FeedType) {
        // Feed type changes no longer needed - we only have friends feed
        // Keeping method for future extensibility
    }
    
    /// Perform scroll-triggered loading with enhanced logic
    private func performScrollTriggeredLoading(for post: Post) {
        // Calculate 70% threshold for seamless infinite scroll
        let threshold = max(3, Int(Double(posts.count) * 0.7))
        let thresholdIndex = posts.count - threshold
        
        if let index = posts.firstIndex(where: { $0.id == post.id }),
           index >= thresholdIndex && !isLoadingMore && hasMorePages {
            print("🔄 HomeViewModel: Reactive loading triggered at 70% threshold (index: \(index), threshold: \(thresholdIndex))")
            loadMorePostsReactive()
        }
    }
    
    // MARK: - Enhanced Data Loading Methods
    
    /// Reactive version of loadMorePosts with better cancellation handling
    private func loadMorePostsReactive() {
        guard !isLoadingMore && hasMorePages && !isLoading else { return }
        
        // Cancel any existing pagination request
        paginationCancellable?.cancel()
        
        loadingStateSubject.send(.loadingMore)
        
        paginationCancellable = createLoadMorePublisher()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        self?.loadingStateSubject.send(.idle)
                    case .failure(let error):
                        self?.loadingStateSubject.send(.failed(error))
                    }
                },
                receiveValue: { [weak self] newPosts in
                    self?.appendNewPosts(newPosts)
                }
            )
    }
    
    /// Create a publisher for loading more posts
    private func createLoadMorePublisher() -> AnyPublisher<[Post], Error> {
        Future<[Post], Error> { [weak self] promise in
            Task {
                do {
                    let posts = try await self?.loadMorePostsAsync() ?? []
                    promise(.success(posts))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Async method for loading more posts (extracted for publisher use)
    private func loadMorePostsAsync() async throws -> [Post] {
        guard let backendService = backendService else { return [] }
        
        let response = try await backendService.getFriendsPosts(
            limit: pageSize,
            cursor: nextCursor
        )
        
        let newPosts = response.posts.compactMap { friendPost -> Post? in
            return Post.from(friendsFeedPost: friendPost)
        }
        
        // Update pagination state
        hasMorePages = response.hasMore
        nextCursor = response.nextCursor
        currentPage += 1
        
        return newPosts
    }
    
    /// Append new posts to the feed with proper state management
    private func appendNewPosts(_ newPosts: [Post]) {
        posts.append(contentsOf: newPosts)
        print("✅ HomeViewModel: Reactively loaded \(newPosts.count) more posts, total: \(posts.count)")
    }
    
    // ✅ Smart fetch that only loads if needed
    func fetchPostsIfNeeded() {
        // Fetch if we have no posts or if data is stale
        if posts.isEmpty || isDataStale {
            fetchPosts()
        }
    }
    
    func fetchPosts() {
        guard !isLoading else { return }
        
        // In preview mode, just use mock data
        if isPreviewMode {
            return
        }
        
        // Check for BackendService (required for friends feed)
        guard backendService != nil else { return }
        
        // Cancel any existing loading task
        loadingTask?.cancel()
        
        // Reset pagination for fresh fetch
        currentPage = 1
        nextCursor = nil
        hasMorePages = true
        
        isLoading = true
        errorMessage = nil
        
        loadingTask = Task {
            await loadFriendsFeed()
        }
    }
    
    /// Load more posts for infinite scroll
    func loadMorePosts() {
        guard !isLoadingMore && hasMorePages && !isLoading else { return }
        
        isLoadingMore = true
        
        // Use separate task for pagination to avoid interfering with main loading
        Task {
            await loadMoreFriendsFeed()
        }
    }
    
    /// Refresh posts without checking loading state - useful for pull-to-refresh or force refresh
    func refreshPosts() {
        // In preview mode, just reload mock data
        if isPreviewMode {
            posts = MockData.generatePreviewPosts()
            return
        }
        
        // Reset pagination
        currentPage = 1
        nextCursor = nil
        hasMorePages = true
        
        isLoading = true
        errorMessage = nil
        
        Task {
            await loadFriendsFeed()
        }
    }
    
    // MARK: - Friends Feed Logic
    
    private func loadFriendsFeed() async {
        do {
            guard let backendService = backendService else {
                self.isLoading = false
                self.errorMessage = "Backend service not available"
                return
            }
            
            print("👥 HomeViewModel: Loading friends feed")
            
            let response = try await backendService.getFriendsPosts(
                limit: pageSize,
                cursor: nil
            )
            
            // Convert to Post objects
            let newPosts = response.posts.compactMap { friendPost -> Post? in
                return Post.from(friendsFeedPost: friendPost)
            }
            
            self.posts = newPosts
            self.hasMorePages = response.hasMore
            self.nextCursor = response.nextCursor
            self.friendsCount = response.friendsCount
            self.isLoading = false
            self.lastFetchedAt = Date()
            
            print("✅ HomeViewModel: Loaded friends feed with \(newPosts.count) posts from \(response.friendsCount) friends")
            
        } catch {
            print("❌ HomeViewModel: Failed to load friends feed: \(error)")
            self.isLoading = false
            self.errorMessage = "Failed to load friends feed: \(error.localizedDescription)"
        }
    }
    
    private func loadMoreFriendsFeed() async {
        do {
            guard let backendService = backendService else {
                self.isLoadingMore = false
                return
            }
            
            let response = try await backendService.getFriendsPosts(
                limit: pageSize,
                cursor: nextCursor
            )
            
            let newPosts = response.posts.compactMap { friendPost -> Post? in
                return Post.from(friendsFeedPost: friendPost)
            }
            
            self.posts.append(contentsOf: newPosts)
            self.hasMorePages = response.hasMore
            self.nextCursor = response.nextCursor
            self.currentPage += 1
            self.isLoadingMore = false
            
            print("✅ HomeViewModel: Loaded \(newPosts.count) more friends posts, total: \(self.posts.count)")
            
        } catch {
            print("❌ HomeViewModel: Failed to load more friends posts: \(error)")
            self.isLoadingMore = false
        }
    }
    
    // MARK: - Helper Methods

    /// Toggle like for a post with optimistic updates
    func toggleLike(for postId: UUID) async {
        // Find the post and update optimistically
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }
        
        let post = posts[index]
        let wasLiked = post.isLiked
        
        // Optimistic update
        posts[index].isLiked.toggle()
        posts[index].likesCount += wasLiked ? -1 : 1
        
        // Add haptic feedback
        HapticManager.shared.impact(.light)
        
        // In preview mode, just keep the optimistic update
        if isPreviewMode {
            return
        }
        
        guard let backendService = backendService else { return }
        
        do {
            // Use convex ID for backend call
            let response = try await backendService.toggleLike(postId: post.convexId)
            
            // Update with server response
            posts[index].isLiked = response.isLiked
            posts[index].likesCount = response.likesCount
            
            // Send notification if user just liked the post (not unliked)
            if !wasLiked && response.isLiked {
                await sendPostLikeNotification(post: post)
                // Play like sound effect
                // SoundManager.shared.playLikeSound()
            }
            
            print("✅ HomeViewModel: Like toggled for post \(postId)")
            
        } catch {
            // Revert optimistic update on error
            posts[index].isLiked = wasLiked
            posts[index].likesCount += wasLiked ? 1 : -1
            
            errorMessage = "Failed to update like: \(error.localizedDescription)"
            print("❌ HomeViewModel: Failed to toggle like: \(error)")
        }
    }
    
    /// Toggle bookmark for a post with optimistic updates
    func toggleBookmark(for postId: UUID) async {
        // Find the post and update optimistically
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }
        
        let post = posts[index]
        let wasBookmarked = post.isSaved
        
        // Optimistic update
        posts[index].isSaved.toggle()
        
        // Add haptic feedback
        HapticManager.shared.impact(.medium)
        
        // In preview mode, just keep the optimistic update
        if isPreviewMode {
            return
        }
        
        guard let backendService = backendService else { return }
        
        do {
            // Use convex ID for backend call
            _ = try await backendService.toggleBookmark(postId: post.convexId)
            
            print("✅ HomeViewModel: Bookmark toggled for post \(postId)")
            
            // Notify other views about bookmark change
            NotificationCenter.default.post(name: NSNotification.Name("BookmarkChanged"), object: nil)
            
        } catch {
            // Revert optimistic update on error
            posts[index].isSaved = wasBookmarked
            
            errorMessage = "Failed to update bookmark: \(error.localizedDescription)"
            print("❌ HomeViewModel: Failed to toggle bookmark: \(error)")
        }
    }
    
    /// Check if we should load more posts (called when near bottom of list)
    /// Uses 70% threshold approach with reactive debouncing for optimal performance
    func checkForMorePosts(currentPost: Post) {
        // Send to reactive scroll trigger with debouncing
        scrollTriggerSubject.send(currentPost)
    }
    
    /// Clear all posts and reset state with enhanced cancellation handling
    func clearPosts() {
        // Cancel any ongoing tasks
        loadingTask?.cancel()
        
        // Cancel specific request types
        initialFetchCancellable?.cancel()
        paginationCancellable?.cancel()
        refreshCancellable?.cancel()
        
        // Clear all general cancellables
        cancellables.removeAll()
        
        // Reset state
        posts.removeAll()
        currentPage = 1
        nextCursor = nil
        hasMorePages = true
        isLoading = false
        isLoadingMore = false
        errorMessage = nil
        lastFetchedAt = nil
        
        // Reset reactive state
        loadingStateSubject.send(.idle)
        feedTypeSubject.send(.friends)
        
        // Re-setup reactive handling after reset
        setupReactiveScrollHandling()
        setupReactiveStateManagement()
    }
    
    private func sendPostLikeNotification(post: Post) async {
        guard let backendService = backendService else { return }
        
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
            
            let _ = try await backendService.createNotification(
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
} 
