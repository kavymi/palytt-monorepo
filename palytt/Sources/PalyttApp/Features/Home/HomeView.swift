//
//  HomeView.swift
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
#if !targetEnvironment(simulator)
#if !targetEnvironment(simulator)
// import ConvexMobile // temporarily disabled
#endif
#endif

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showNotifications = false
    
    @ObservedObject private var notificationService = PalyttNotificationService.shared
    private let backendService = BackendService.shared
    // @StateObject private var realtimeService = RealtimeService.shared
    // @StateObject private var analyticsService = AnalyticsService.shared
    // @StateObject private var offlineManager = OfflineSupportManager.shared
    // @StateObject private var performanceOptimizer = PerformanceOptimizer.shared
    
    // Use the AppState's homeViewModel instead of creating a new one
    private var viewModel: HomeViewModel {
        appState.homeViewModel
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Feed Status Indicator
                    if viewModel.isUsingPersonalizedFeed, let feedStats = viewModel.feedStats {
                        FeedStatusIndicatorView(feedStats: feedStats)
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                    
                    // Simple connection status indicator
                    if !backendService.isAPIHealthy {
                        HStack(spacing: 8) {
                            Image(systemName: "wifi.slash")
                                .foregroundColor(.red)
                            Text("Connection issues detected")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.1))
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }
                    // Real-time updates feed (temporarily disabled)
                    // if !realtimeService.liveUpdates.isEmpty || !offlineManager.isOffline {
                    //     VStack(spacing: 12) {
                    //         // Offline indicator
                    //         if offlineManager.isOffline {
                    //             OfflineIndicatorView()
                    //                 .padding(.horizontal)
                    //         }
                    //         
                    //         // Live updates feed
                    //         LiveUpdatesFeedView()
                    //             .padding(.horizontal)
                    //     }
                    //     .padding(.bottom, 8)
                    // }
                    
                    // Main content
                    if viewModel.isLoading && viewModel.posts.isEmpty {
                        // Initial loading skeleton
                        ForEach(0..<3, id: \.self) { _ in
                            PostCardSkeleton()
                                .padding(.horizontal)
                        }
                    } else if viewModel.posts.isEmpty && !viewModel.isLoading {
                        // Empty state
                        EmptyFeedView()
                    } else {
                        // Posts grid
                        ForEach(viewModel.posts, id: \.id) { post in
                            PostCard(
                                post: post,
                                onLike: { postId in
                                    Task {
                                        await viewModel.toggleLike(for: postId)
                                        
                                        // Track analytics and real-time update (temporarily disabled)
                                        // analyticsService.trackUserAction(.postLike, properties: ["postId": postId])
                                        
                                        // let liveUpdate = LiveUpdate(
                                        //     id: UUID().uuidString,
                                        //     type: .newLike,
                                        //     data: ["postId": postId, "userId": "current_user"],
                                        //     timestamp: Date()
                                        // )
                                        // await realtimeService.sendLiveUpdate(liveUpdate)
                                    }
                                },
                                onBookmark: { postId in
                                    Task {
                                        await viewModel.toggleBookmark(for: postId)
                                        
                                        // Track analytics (temporarily disabled)
                                        // analyticsService.trackUserAction(.postShare, properties: ["postId": postId, "action": "bookmark"])
                                    }
                                },
                                onBookmarkNavigate: {
                                    // Add haptic feedback
                                    HapticManager.shared.impact(.medium)
                                    appState.selectedTab = .saved
                                    
                                    // Track navigation (temporarily disabled)
                                    // analyticsService.trackUserAction(.profileView, properties: ["destination": "saved"])
                                }
                            )
                            .padding(.horizontal)
                            .onAppear {
                                // Optimized infinite scroll with 70% threshold
                                viewModel.checkForMorePosts(currentPost: post)
                                
                                // Cache post for offline support (temporarily disabled)
                                // Task {
                                //     await offlineManager.cachePost(post)
                                // }
                            }
                            .transition(.slide.combined(with: .opacity))
                        }
                        
                        // Loading more indicator
                        if viewModel.isLoadingMore {
                            LoadingMoreView()
                                .padding(.vertical)
                        }
                        
                        // End of content indicator
                        if !viewModel.hasMorePages && !viewModel.posts.isEmpty {
                            EndOfContentView()
                                .padding(.vertical)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color.appBackground)
            .animation(.easeInOut(duration: 0.3), value: viewModel.posts.count)
            .refreshable {
                // Pull-to-refresh functionality with haptic feedback
                HapticManager.shared.impact(.light)
                
                // let startTime = Date()
                viewModel.refreshPosts()
                
                // Track refresh performance (temporarily disabled)
                // let refreshTime = Date().timeIntervalSince(startTime) * 1000 // Convert to milliseconds
                // analyticsService.trackPerformanceMetric(PerformanceMetric(
                //     name: "feed_refresh_time",
                //     value: refreshTime,
                //     unit: "ms"
                // ))
                
                // Track user action (temporarily disabled)
                // analyticsService.trackUserAction(.searchPerformed, properties: ["type": "refresh"])
            }
            .onAppear {
                // ✅ Smart refresh: fetch posts if empty or if data is stale (5+ minutes old)
                viewModel.fetchPostsIfNeeded()
                
                // Track screen view for analytics (temporarily disabled)
                // analyticsService.trackScreenView("Home Feed")
                
                // Start real-time connection (temporarily disabled)
                // Task {
                //     await realtimeService.connect()
                //     await realtimeService.subscribeToUpdates(for: [
                //         .newPost, .newLike, .newComment, .newFollower
                //     ])
                // }
                
                // Optimize for launch if first time (temporarily disabled)
                // Task {
                //     await performanceOptimizer.optimizeForLaunch()
                // }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NewPostCreated"))) { _ in
                // Refresh posts when a new post is created
                viewModel.refreshPosts()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserPostsUpdated"))) { _ in
                // Refresh posts when user posts are updated
                viewModel.refreshPosts()
            }
            // ✅ Refresh when app becomes active from background (if data is stale)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                if viewModel.isDataStale {
                    viewModel.fetchPosts()
                }
            }
            // ✅ Refresh when home tab is selected (if data is stale)
            .onChange(of: appState.selectedTab) { oldValue, newValue in
                if newValue == .home && viewModel.isDataStale {
                    viewModel.fetchPosts()
                }
            }
            // .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RealtimeLiveUpdate"))) { notification in
            //     // Handle real-time live updates (temporarily disabled)
            //     if let liveUpdate = notification.object as? LiveUpdate {
            //         switch liveUpdate.type {
            //         case .newPost:
            //             // Refresh posts for new content
            //             viewModel.refreshPosts()
            //         case .newLike, .newComment:
            //             // Could update specific post metrics here
            //             break
            //         default:
            //             break
            //         }
            //     }
            // }
            .navigationTitle("All posts & places")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        showNotifications = true
                        
                        // Track analytics (temporarily disabled)
                        // analyticsService.trackUserAction(.profileView, properties: ["section": "notifications"])
                    }) {
                        ZStack {
                            Image(systemName: "bell")
                                .font(.system(size: 18))
                                .foregroundColor(.appPrimaryText)
                            
                            // Notification badge
                            if notificationService.unreadCount > 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
                    .environmentObject(appState)
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { 
                    viewModel.errorMessage = nil 
                }
                Button("Retry") { 
                    viewModel.fetchPosts() 
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Feed Status Indicator

struct FeedStatusIndicatorView: View {
    let feedStats: HomeViewModel.FeedStats
    
    var body: some View {
        HStack(spacing: 12) {
            // Personalized Feed Icon
            Image(systemName: "location.fill.viewfinder")
                .foregroundColor(.primaryBrand)
                .font(.system(size: 16, weight: .medium))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Personalized Feed")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                HStack(spacing: 16) {
                    if feedStats.fromFollowed > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                                .foregroundColor(.primaryBrand)
                            Text("\(feedStats.fromFollowed) from followed")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    }
                    
                    if feedStats.fromNearby > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundColor(.success)
                            Text("\(feedStats.fromNearby) nearby")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    }
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            // 25 mile radius indicator
            VStack(alignment: .trailing, spacing: 2) {
                Text("25mi")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primaryBrand)
                Text("radius")
                    .font(.caption2)
                    .foregroundColor(.tertiaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primaryBrand.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primaryBrand.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// MARK: - Supporting Views

struct EmptyFeedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.milkTea)
            
            VStack(spacing: 8) {
                Text("No posts yet")
                    .font(.headline)
                    .foregroundColor(.appSecondaryText)
                
                Text("Be the first to share something delicious!")
                    .font(.subheadline)
                    .foregroundColor(.appTertiaryText)
                    .multilineTextAlignment(.center)
            }
            
            // Encouraging action
            Button(action: {
                HapticManager.shared.impact(.medium)
                // Navigate to create post - you might want to trigger this via AppState
            }) {
                Label("Share Your Food", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient.primaryGradient
                    )
                    .cornerRadius(25)
            }
        }
        .padding(.top, 100)
        .frame(maxWidth: .infinity)
    }
}

struct LoadingMoreView: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(.milkTea)
            
            Text("Loading more posts...")
                .font(.caption)
                .foregroundColor(.appSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct EndOfContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.milkTea)
            
            Text("You're all caught up!")
                .font(.caption)
                .foregroundColor(.appSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .opacity(0.7)
    }
}

// MARK: - SwiftUI Previews
#Preview("Home Feed - Standard") {
    HomeView()
        .environmentObject(MockAppState())
}

#Preview("Home Feed - Empty State") {
    let mockState = MockAppState()
    mockState.homeViewModel.posts = []
    
    return HomeView()
        .environmentObject(mockState)
}

#Preview("Home Feed - Loading") {
    let mockState = MockAppState()
    mockState.homeViewModel.isLoading = true
    
    return HomeView()
        .environmentObject(mockState)
}

#Preview("Home Feed - Trending Only") {
    let mockState = MockAppState()
    mockState.homeViewModel.posts = Array(MockData.generateTrendingPosts())
    
    return HomeView()
        .environmentObject(mockState)
}

#Preview("Home Feed - Recent Posts") {
    let mockState = MockAppState()
    mockState.homeViewModel.posts = Array(MockData.generateRecentPosts())
    
    return HomeView()
        .environmentObject(mockState)
}

#Preview("Home Feed - Dark Mode") {
    HomeView()
        .environmentObject(MockAppState())
        .preferredColorScheme(.dark)
}

