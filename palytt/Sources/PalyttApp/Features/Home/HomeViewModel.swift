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

enum FeedType: String, CaseIterable {
    case friends = "Friends"
    case forYou = "For You"
    
    var icon: String {
        switch self {
        case .friends: return "person.2.fill"
        case .forYou: return "sparkles"
        }
    }
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
    @Published var forYouPosts: [Post] = []  // Separate array for "For You" feed
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var hasMorePages = true
    @Published var hasMoreForYouPages = true  // Pagination for "For You" feed
    @Published var friendsCount: Int = 0  // Track number of friends for empty state
    @Published var selectedFeedType: FeedType = .friends  // Current feed type selection
    
    // Computed property to get current feed posts based on selection
    var currentPosts: [Post] {
        switch selectedFeedType {
        case .friends: return posts
        case .forYou: return forYouPosts
        }
    }
    
    var currentHasMorePages: Bool {
        switch selectedFeedType {
        case .friends: return hasMorePages
        case .forYou: return hasMoreForYouPages
        }
    }
    
    // Computed reactive loading state for enhanced state management
    var loadingState: LoadingState {
        loadingStateSubject.value
    }
    
    // BackendService for friends feed
    private let backendService: BackendService?
    private var currentPage = 1
    private var nextCursor: String?
    private var forYouNextCursor: String?  // Separate cursor for "For You" pagination
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
    /// Note: This is called from the Combine subscriber, so we don't call it directly from switchFeedType
    private func handleFeedTypeChange(_ feedType: FeedType) {
        // Only fetch if the feed is empty - don't block on isLoading to allow tab switching
        switch feedType {
        case .friends:
            if posts.isEmpty {
                fetchPosts()
            }
        case .forYou:
            if forYouPosts.isEmpty {
                fetchForYouPosts()
            }
        }
    }
    
    /// Switch feed type immediately and load data if needed
    /// This is the primary entry point for tab switching - must be responsive
    func switchFeedType(to feedType: FeedType) {
        // Allow switching even to the same feed type for responsiveness
        // The actual data loading will be handled by handleFeedTypeChange
        guard selectedFeedType != feedType else { return }
        
        // Update the published property immediately for instant UI response
        selectedFeedType = feedType
        
        // Notify the Combine subscriber which will handle data loading
        feedTypeSubject.send(feedType)
        
        // Note: We don't call handleFeedTypeChange directly here anymore
        // The Combine subscriber will call it, avoiding double-triggering
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
        // In preview mode, data is already loaded
        if isPreviewMode {
            return
        }
        
        // Check if we have an active session
        let hasSession = Clerk.shared.session != nil
        
        if !hasSession {
            print("⏳ HomeViewModel: Waiting for authentication before fetching posts")
            return
        }
        
        // Fetch if we have no posts or if data is stale
        if posts.isEmpty || isDataStale {
            print("📱 HomeViewModel: Fetching posts (isEmpty: \(posts.isEmpty), isStale: \(isDataStale))")
            fetchPosts()
        } else {
            print("✅ HomeViewModel: Posts already loaded and fresh, skipping fetch")
        }
    }
    
    // MARK: - Session-Aware Fetch with Retry Logic
    
    /// Fetch posts when Clerk session is ready, with exponential backoff retry
    /// This handles the race condition when auth state changes before session is fully initialized
    func fetchPostsWhenReady(maxRetries: Int = 5) {
        // In preview mode, data is already loaded
        if isPreviewMode {
            return
        }
        
        // Cancel any existing session wait task
        sessionWaitTask?.cancel()
        
        // Set loading state immediately for UX
        isLoading = true
        
        sessionWaitTask = Task { [weak self] in
            guard let self = self else { return }
            
            for attempt in 0..<maxRetries {
                // Check if task was cancelled
                if Task.isCancelled { return }
                
                // Check if session is ready
                if Clerk.shared.session != nil {
                    print("🔐 HomeViewModel: Session ready on attempt \(attempt + 1), fetching posts")
                    await MainActor.run {
                        // Reset isLoading before calling fetchPosts to avoid the guard check
                        self.isLoading = false
                        self.fetchPosts()
                    }
                    return
                }
                
                // Exponential backoff: 200ms, 400ms, 600ms, 800ms, 1000ms
                let delayMs = UInt64(200_000_000 * (attempt + 1))
                print("⏳ HomeViewModel: Waiting for session, attempt \(attempt + 1)/\(maxRetries)")
                try? await Task.sleep(nanoseconds: delayMs)
            }
            
            // Final attempt after all retries
            if !Task.isCancelled {
                print("⚠️ HomeViewModel: Session not ready after \(maxRetries) attempts, attempting fetch anyway")
                await MainActor.run {
                    // Reset isLoading before calling fetchPosts to avoid the guard check
                    self.isLoading = false
                    // Try to fetch anyway - backend will handle auth errors
                    self.fetchPosts()
                }
            }
        }
    }
    
    // Task for session wait with retry
    private var sessionWaitTask: Task<Void, Never>?
    
    func fetchPosts() {
        guard !isLoading else { return }
        
        // In preview mode, just use mock data
        if isPreviewMode {
            return
        }
        
        // Check for BackendService (required for friends feed)
        guard backendService != nil else { return }
        
        // ✅ Check for Clerk session before attempting to fetch
        // This prevents 401 errors when Clerk isn't fully initialized yet
        guard Clerk.shared.session != nil else {
            print("⏳ HomeViewModel: fetchPosts called but no Clerk session, deferring to fetchPostsWhenReady")
            fetchPostsWhenReady()
            return
        }
        
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
        let hasMore = selectedFeedType == .friends ? hasMorePages : hasMoreForYouPages
        guard !isLoadingMore && hasMore && !isLoading else { return }
        
        isLoadingMore = true
        
        // Use separate task for pagination to avoid interfering with main loading
        Task {
            switch selectedFeedType {
            case .friends:
                await loadMoreFriendsFeed()
            case .forYou:
                await loadMoreForYouFeed()
            }
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
    
    // MARK: - "For You" Discovery Feed
    
    /// Fetch "For You" discovery posts - location-based and engagement-weighted
    func fetchForYouPosts() {
        guard !isLoading else { return }
        
        // In preview mode, use mock data
        if isPreviewMode {
            forYouPosts = MockData.generateTrendingPosts()
            return
        }
        
        guard backendService != nil else { return }
        
        // Reset pagination
        forYouNextCursor = nil
        hasMoreForYouPages = true
        
        isLoading = true
        errorMessage = nil
        
        Task {
            await loadForYouFeed()
        }
    }
    
    private func loadForYouFeed() async {
        do {
            guard let backendService = backendService else {
                self.isLoading = false
                self.errorMessage = "Backend service not available"
                return
            }
            
            print("✨ HomeViewModel: Loading 'For You' discovery feed")
            
            // Get user's location for location-based recommendations
            let locationManager = LocationManager.shared
            let userLocation = locationManager.currentLocation
            
            let response = try await backendService.getForYouPosts(
                limit: pageSize,
                cursor: nil,
                latitude: userLocation?.coordinate.latitude,
                longitude: userLocation?.coordinate.longitude
            )
            
            // Convert to Post objects
            let newPosts = response.posts.compactMap { post -> Post? in
                return Post.from(forYouPost: post)
            }
            
            self.forYouPosts = newPosts
            self.hasMoreForYouPages = response.hasMore
            self.forYouNextCursor = response.nextCursor
            self.isLoading = false
            
            print("✅ HomeViewModel: Loaded 'For You' feed with \(newPosts.count) posts")
            
        } catch {
            print("❌ HomeViewModel: Failed to load 'For You' feed: \(error)")
            self.isLoading = false
            // Fall back to trending posts on error
            await loadFallbackTrendingPosts()
        }
    }
    
    private func loadMoreForYouFeed() async {
        do {
            guard let backendService = backendService else {
                self.isLoadingMore = false
                return
            }
            
            let locationManager = LocationManager.shared
            let userLocation = locationManager.currentLocation
            
            let response = try await backendService.getForYouPosts(
                limit: pageSize,
                cursor: forYouNextCursor,
                latitude: userLocation?.coordinate.latitude,
                longitude: userLocation?.coordinate.longitude
            )
            
            let newPosts = response.posts.compactMap { post -> Post? in
                return Post.from(forYouPost: post)
            }
            
            self.forYouPosts.append(contentsOf: newPosts)
            self.hasMoreForYouPages = response.hasMore
            self.forYouNextCursor = response.nextCursor
            self.isLoadingMore = false
            
            print("✅ HomeViewModel: Loaded \(newPosts.count) more 'For You' posts, total: \(self.forYouPosts.count)")
            
        } catch {
            print("❌ HomeViewModel: Failed to load more 'For You' posts: \(error)")
            self.isLoadingMore = false
        }
    }
    
    /// Fallback to local trending posts if API fails
    private func loadFallbackTrendingPosts() async {
        // Use mock trending data as fallback
        self.forYouPosts = MockData.generateTrendingPosts()
        self.hasMoreForYouPages = false
        print("⚠️ HomeViewModel: Using fallback trending posts")
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
        sessionWaitTask?.cancel()
        
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
