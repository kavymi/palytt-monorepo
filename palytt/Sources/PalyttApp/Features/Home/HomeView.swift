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
    
    @ObservedObject private var notificationService = NotificationService.shared
    private let backendService = BackendService.shared
    // @StateObject private var realtimeService = RealtimeService.shared
    // @StateObject private var analyticsService = AnalyticsService.shared
    // @StateObject private var offlineManager = OfflineSupportManager.shared
    // @StateObject private var performanceOptimizer = PerformanceOptimizer.shared
    
    // Use the AppState's homeViewModel instead of creating a new one
    private var viewModel: HomeViewModel {
        appState.homeViewModel
    }
    
    @ViewBuilder
    private var feedStatusSection: some View {
        // Friends feed doesn't need a status indicator - it's the default and only feed
        EmptyView()
    }
    
    @ViewBuilder
    private var connectionStatusSection: some View {
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
    }
    
    @ViewBuilder
    private var mainContentSection: some View {
        if (viewModel.isLoading && viewModel.posts.isEmpty) || (!appState.isAuthenticated && viewModel.posts.isEmpty) {
            // Initial loading skeleton - show while loading OR while waiting for auth
            ForEach(0..<3, id: \.self) { _ in
                PostCardSkeleton()
                    .padding(.horizontal)
            }
        } else if viewModel.posts.isEmpty && !viewModel.isLoading && appState.isAuthenticated {
            // Empty state - only show when authenticated and not loading
            EmptyFeedView()
        } else {
            // Posts grid
            ForEach(viewModel.posts, id: \.id) { post in
                PostCard(
                    post: post,
                    onLike: { postId in
                        Task {
                            await viewModel.toggleLike(for: postId)
                        }
                    },
                    onBookmark: { postId in
                        Task {
                            await viewModel.toggleBookmark(for: postId)
                        }
                    },
                    onBookmarkNavigate: {
                        HapticManager.shared.impact(.medium)
                        appState.selectedTab = .profile
                    }
                )
                .padding(.horizontal)
                .onAppear {
                    viewModel.checkForMorePosts(currentPost: post)
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
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    feedStatusSection
                    connectionStatusSection
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
                    mainContentSection
                }
                .padding(.vertical, 4)
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
                
                // Track user action
                // AnalyticsManager.shared.trackFeatureUsed("home_refresh", context: ["trigger": "pull_to_refresh"])
            }
            .onAppear {
                // ✅ Always attempt to fetch posts on first appear
                // If authenticated, fetch immediately
                // If not authenticated yet, show loading and wait for auth
                if appState.isAuthenticated {
                    // User is already authenticated - fetch posts if needed
                    viewModel.fetchPostsIfNeeded()
                } else if viewModel.posts.isEmpty {
                    // Not authenticated yet - show loading state
                    // The onChange handler will trigger fetch when auth is ready
                    viewModel.isLoading = true
                }
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
            // ✅ Refresh when user authentication state changes (e.g., after Clerk loads)
            .onChange(of: appState.isAuthenticated) { oldValue, newValue in
                if newValue {
                    // User just became authenticated - fetch posts immediately
                    print("🔐 HomeView: User authenticated, fetching posts")
                    viewModel.fetchPosts()
                } else if !newValue {
                    // User logged out - clear posts
                    viewModel.clearPosts()
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
            .navigationTitle("Palytt")
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

// MARK: - Supporting Views

struct EmptyFeedView: View {
    @EnvironmentObject var appState: AppState
    @State private var showFindFriends = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Friendly illustration
            ZStack {
                Circle()
                    .fill(Color.primaryBrand.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "person.2.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.primaryBrand)
            }
            
            VStack(spacing: 12) {
                Text("See what your friends are eating")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text("Add friends to see their food discoveries here")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Find Friends CTA
            Button(action: {
                HapticManager.shared.impact(.medium)
                showFindFriends = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Find Friends")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    LinearGradient.primaryGradient
                )
                .cornerRadius(25)
            }
            
            // Secondary action - Invite friends
            Button(action: {
                HapticManager.shared.impact(.light)
                // Could trigger invite flow
            }) {
                Text("Invite friends to Palytt")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primaryBrand)
            }
            .padding(.top, 8)
        }
        .padding(.top, 80)
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showFindFriends) {
            AddFriendsView()
        }
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

