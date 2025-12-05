//
//  FriendsView.swift
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

// MARK: - Unified Friends View

struct FriendsView: View {
    @StateObject private var viewModel = FriendsViewViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: FriendsTab = .friends
    @State private var searchText = ""
    @State private var showingFilters = false
    @State private var searchFilters = SearchFilters()
    @State private var showingActivityFeed = false
    @FocusState private var isSearchFocused: Bool
    @State private var searchDebounceTask: Task<Void, Never>?
    @Namespace private var tabAnimation
    
    enum FriendsTab: String, CaseIterable {
        case friends = "Friends"
        case requests = "Requests"
        case discover = "Discover"
        
        var icon: String {
            switch self {
            case .friends: return "person.2.fill"
            case .requests: return "person.badge.clock.fill"
            case .discover: return "person.badge.plus"
            }
        }
        
        var emptyIcon: String {
            switch self {
            case .friends: return "person.2"
            case .requests: return "person.2.badge.gearshape"
            case .discover: return "magnifyingglass"
            }
        }
        
        var emptyTitle: String {
            switch self {
            case .friends: return "No Friends Yet"
            case .requests: return "No Friend Requests"
            case .discover: return "Find New Friends"
            }
        }
        
        var emptyMessage: String {
            switch self {
            case .friends: return "Connect with people to see them here"
            case .requests: return "When people send you friend requests, they'll appear here"
            case .discover: return "Search for users or check out suggestions"
            }
        }
    }
    
    struct SearchFilters {
        var onlyVerified = false
        var maxDistance: Double = 50.0
        var includeNearby = false
        var dietaryPreferences: [String] = []
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar (only show in discover tab or when searching)
                if selectedTab == .discover || !searchText.isEmpty {
                    searchBar
                }
                
                // Tab Selector
                tabSelector
                
                // Content
                contentView
            }
            .background(Color.appBackground)
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Activity Feed button - real-time friend activity via Convex
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        showingActivityFeed = true
                    }) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primaryBrand)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
            }
            .sheet(isPresented: $showingActivityFeed) {
                ActivityFeedView()
            }
            .sheet(isPresented: $showingFilters) {
                FriendsSearchFiltersView(filters: $searchFilters, onApply: {
                    if !searchText.isEmpty {
                        performSearch()
                    }
                })
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
        .task {
            await loadInitialData()
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondaryText)
                    .font(.system(size: 16))
                
                TextField("Search users...", text: $searchText)
                    .foregroundColor(.primaryText)
                    .font(.system(size: 16))
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        performSearch()
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        viewModel.clearSearch()
                        HapticManager.shared.impact(.light)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondaryText)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.cardBackground)
            .cornerRadius(20)
            
            // Filters Button
            Button(action: {
                showingFilters = true
                HapticManager.shared.impact(.light)
            }) {
                Image(systemName: hasActiveFilters ? "line.horizontal.3.decrease.circle.fill" : "line.horizontal.3.decrease.circle")
                    .foregroundColor(hasActiveFilters ? .primaryBrand : .secondaryText)
                    .font(.system(size: 20))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .onChange(of: searchText) { _, newValue in
            searchDebounceTask?.cancel()
            
            if newValue.isEmpty {
                viewModel.clearSearch()
            } else {
                searchDebounceTask = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if !Task.isCancelled && searchText == newValue {
                        performSearch()
                    }
                }
            }
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(FriendsTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                    HapticManager.shared.impact(.light)
                    loadTabData(for: tab)
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14))
                            
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                            
                            // Badge for requests
                            if tab == .requests && viewModel.pendingRequestsCount > 0 {
                                Text("\(viewModel.pendingRequestsCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundColor(selectedTab == tab ? .primaryBrand : .secondaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        
                        // Indicator
                        Rectangle()
                            .fill(selectedTab == tab ? Color.primaryBrand : Color.clear)
                            .frame(height: 3)
                            .cornerRadius(1.5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 8)
        .background(Color.appBackground)
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .friends:
            friendsContent
        case .requests:
            requestsContent
        case .discover:
            discoverContent
        }
    }
    
    // MARK: - Friends Content
    
    private var friendsContent: some View {
        Group {
            if viewModel.isLoadingFriends && viewModel.friends.isEmpty {
                loadingView(message: "Loading friends...")
            } else if viewModel.friends.isEmpty && !viewModel.isLoadingFriends {
                emptyStateView(for: .friends)
            } else {
                List {
                    ForEach(viewModel.friends, id: \.clerkId) { user in
                        FriendRowView(
                            user: user,
                            presenceStatus: viewModel.getPresenceStatus(for: user.clerkId)
                        )
                        .listRowBackground(Color.cardBackground)
                        .listRowSeparatorTint(Color.divider)
                    }
                    
                    if viewModel.hasMoreFriends && !viewModel.isLoadingFriends {
                        loadMoreButton {
                            Task { await viewModel.loadMoreFriends() }
                        }
                    } else if viewModel.isLoadingFriends {
                        loadingIndicator
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    await viewModel.refreshFriends()
                }
            }
        }
    }
    
    // MARK: - Requests Content
    
    private var requestsContent: some View {
        Group {
            if viewModel.isLoadingRequests && viewModel.friendRequests.isEmpty {
                loadingView(message: "Loading requests...")
            } else if viewModel.friendRequests.isEmpty && !viewModel.isLoadingRequests {
                emptyStateView(for: .requests)
            } else {
                List {
                    ForEach(viewModel.friendRequests, id: \._id) { request in
                        FriendRequestRowView(
                            request: request,
                            onAccept: {
                                Task { await viewModel.acceptRequest(request._id) }
                            },
                            onDecline: {
                                Task { await viewModel.rejectRequest(request._id) }
                            }
                        )
                        .listRowBackground(Color.cardBackground)
                        .listRowSeparatorTint(Color.divider)
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    await viewModel.refreshRequests()
                }
            }
        }
    }
    
    // MARK: - Discover Content
    
    private var discoverContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Discover Sub-tabs
                discoverSubTabs
                
                Divider()
                    .padding(.vertical, 8)
                
                // Content based on discover sub-tab
                switch viewModel.discoverTab {
                case .suggested:
                    suggestedUsersContent
                case .contacts:
                    ContactsSyncView()
                case .search:
                    searchResultsContent
                }
            }
        }
    }
    
    private var discoverSubTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(FriendsViewViewModel.DiscoverTab.allCases, id: \.self) { tab in
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        viewModel.discoverTab = tab
                        if tab == .suggested && viewModel.suggestedUsers.isEmpty {
                            Task { await viewModel.loadSuggestedUsers() }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14))
                            Text(tab.title)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(viewModel.discoverTab == tab ? .white : .secondaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(viewModel.discoverTab == tab ? Color.primaryBrand : Color.cardBackground)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    private var suggestedUsersContent: some View {
        LazyVStack(spacing: 12) {
            if viewModel.isLoadingSuggested {
                ForEach(0..<5, id: \.self) { _ in
                    UserRowSkeleton()
                }
            } else if viewModel.suggestedUsers.isEmpty {
                EmptyStateView(
                    icon: "person.2",
                    title: "No Suggestions",
                    message: "Check back later for friend suggestions"
                )
                .padding(.top, 60)
            } else {
                ForEach(viewModel.suggestedUsers, id: \.user.userId) { suggestion in
                    EnhancedAddFriendUserRowView(
                        suggestion: suggestion,
                        buttonText: "Add Friend",
                        buttonAction: {
                            Task { await viewModel.sendFriendRequest(to: suggestion.user) }
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private var searchResultsContent: some View {
        LazyVStack(spacing: 12) {
            if viewModel.isSearching {
                ForEach(0..<3, id: \.self) { _ in
                    UserRowSkeleton()
                }
            } else if searchText.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.milkTea)
                    
                    Text("Search for users")
                        .font(.headline)
                        .foregroundColor(.secondaryText)
                    
                    Text("Enter a username or display name to find users")
                        .font(.subheadline)
                        .foregroundColor(.tertiaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 60)
            } else if viewModel.searchResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 40))
                        .foregroundColor(.milkTea)
                    
                    Text("No users found")
                        .font(.headline)
                        .foregroundColor(.secondaryText)
                    
                    Text("Try searching with a different username")
                        .font(.subheadline)
                        .foregroundColor(.tertiaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 60)
            } else {
                ForEach(viewModel.searchResults, id: \.userId) { user in
                    AddFriendUserRowView(
                        user: user,
                        buttonText: "Add Friend",
                        buttonAction: {
                            Task { await viewModel.sendFriendRequest(to: user) }
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - Helper Views
    
    private func loadingView(message: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func emptyStateView(for tab: FriendsTab) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.primaryBrand.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: tab.emptyIcon)
                    .font(.system(size: 40))
                    .foregroundColor(.primaryBrand)
            }
            
            VStack(spacing: 8) {
                Text(tab.emptyTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text(tab.emptyMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            if tab == .friends {
                Button(action: {
                    withAnimation {
                        selectedTab = .discover
                    }
                    HapticManager.shared.impact(.medium)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                        Text("Find Friends")
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.primaryBrand)
                    .cornerRadius(25)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadMoreButton(action: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            Button("Load More", action: action)
                .font(.subheadline)
                .foregroundColor(.primaryBrand)
            Spacer()
        }
        .listRowBackground(Color.clear)
    }
    
    private var loadingIndicator: some View {
        HStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Spacer()
        }
        .listRowBackground(Color.clear)
    }
    
    // MARK: - Helper Methods
    
    private var hasActiveFilters: Bool {
        searchFilters.onlyVerified ||
        searchFilters.includeNearby ||
        !searchFilters.dietaryPreferences.isEmpty
    }
    
    private func loadInitialData() async {
        guard let userId = appState.currentUser?.clerkId else { return }
        await viewModel.loadInitialData(userId: userId)
    }
    
    private func loadTabData(for tab: FriendsTab) {
        guard let userId = appState.currentUser?.clerkId else { return }
        Task {
            switch tab {
            case .friends:
                if viewModel.friends.isEmpty {
                    await viewModel.loadFriends(for: userId)
                }
            case .requests:
                if viewModel.friendRequests.isEmpty {
                    await viewModel.loadFriendRequests(for: userId)
                }
            case .discover:
                if viewModel.suggestedUsers.isEmpty {
                    await viewModel.loadSuggestedUsers()
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            viewModel.clearSearch()
            return
        }
        
        viewModel.discoverTab = .search
        selectedTab = .discover
        Task {
            await viewModel.searchUsers(query: searchText, filters: searchFilters)
        }
    }
}

// MARK: - Unified Friends ViewModel

@MainActor
class FriendsViewViewModel: ObservableObject {
    // Friends
    @Published var friends: [BackendUser] = []
    @Published var friendPresence: [String: PresenceStatus] = [:] // clerkId -> status
    @Published var isLoadingFriends = false
    @Published var hasMoreFriends = true
    
    // Friend Requests
    @Published var friendRequests: [BackendService.FriendRequest] = []
    @Published var isLoadingRequests = false
    @Published var pendingRequestsCount = 0
    
    // Discover
    @Published var suggestedUsers: [EnhancedUserSuggestion] = []
    @Published var searchResults: [BackendUser] = []
    @Published var isLoadingSuggested = false
    @Published var isSearching = false
    @Published var discoverTab: DiscoverTab = .suggested
    
    // General
    @Published var errorMessage: String?
    
    private let backendService = BackendService.shared
    private var currentUserId: String = ""
    private var friendsPage = 1
    private let pageSize = 20
    
    /// Get presence status for a specific friend
    func getPresenceStatus(for clerkId: String) -> PresenceStatus {
        // First check our local cache
        if let status = friendPresence[clerkId] {
            return status
        }
        
        // Then check PresenceService's online friends
        if let presence = PresenceService.shared.onlineFriends[clerkId] {
            return presence.status
        }
        
        return .offline
    }
    
    /// Subscribe to presence updates for all friends using Convex
    private func subscribeToFriendsPresence() {
        let friendClerkIds = friends.compactMap { $0.clerkId }
        guard !friendClerkIds.isEmpty else { return }
        
        // Subscribe via BackendService (which uses PresenceService internally)
        BackendService.shared.subscribeToFriendPresence(friendIds: friendClerkIds)
        
        // Load initial presence data
        Task {
            let presenceData = await BackendService.shared.getBatchPresence(clerkIds: friendClerkIds)
            await MainActor.run {
                self.friendPresence = presenceData
            }
        }
        
        print("🟢 FriendsViewViewModel: Subscribed to presence for \(friendClerkIds.count) friends")
    }
    
    enum DiscoverTab: CaseIterable {
        case suggested, contacts, search
        
        var title: String {
            switch self {
            case .suggested: return "Suggested"
            case .contacts: return "Contacts"
            case .search: return "Search"
            }
        }
        
        var icon: String {
            switch self {
            case .suggested: return "person.2"
            case .contacts: return "person.crop.rectangle.stack"
            case .search: return "magnifyingglass"
            }
        }
    }
    
    // MARK: - Initial Data Loading
    
    func loadInitialData(userId: String) async {
        currentUserId = userId
        
        // Load friends and requests in parallel
        async let friendsTask: () = loadFriends(for: userId)
        async let requestsTask: () = loadFriendRequests(for: userId)
        
        await friendsTask
        await requestsTask
    }
    
    // MARK: - Friends
    
    func loadFriends(for userId: String) async {
        currentUserId = userId
        friendsPage = 1
        hasMoreFriends = true
        isLoadingFriends = true
        errorMessage = nil
        
        do {
            let friendsData = try await backendService.getFriends(userId: userId, limit: pageSize)
            friends = friendsData
            hasMoreFriends = friendsData.count == pageSize
            
            // Subscribe to presence for all friends via Convex
            subscribeToFriendsPresence()
            
        } catch {
            errorMessage = "Failed to load friends: \(error.localizedDescription)"
            print("❌ Error loading friends: \(error)")
        }
        
        isLoadingFriends = false
    }
    
    func refreshFriends() async {
        await loadFriends(for: currentUserId)
    }
    
    func loadMoreFriends() async {
        guard hasMoreFriends && !isLoadingFriends else { return }
        
        friendsPage += 1
        isLoadingFriends = true
        
        do {
            let newFriends = try await backendService.getFriends(userId: currentUserId, limit: pageSize)
            friends.append(contentsOf: newFriends)
            hasMoreFriends = newFriends.count == pageSize
        } catch {
            errorMessage = "Failed to load more friends: \(error.localizedDescription)"
            friendsPage -= 1
            print("❌ Error loading more friends: \(error)")
        }
        
        isLoadingFriends = false
    }
    
    // MARK: - Friend Requests
    
    func loadFriendRequests(for userId: String) async {
        guard !userId.isEmpty else {
            errorMessage = "Please sign in to view friend requests"
            return
        }
        
        currentUserId = userId
        isLoadingRequests = true
        errorMessage = nil
        
        do {
            let requests = try await backendService.getPendingFriendRequests(userId: userId)
            friendRequests = requests
            pendingRequestsCount = requests.count
        } catch {
            errorMessage = "Failed to load friend requests: \(error.localizedDescription)"
            print("❌ Error loading friend requests: \(error)")
        }
        
        isLoadingRequests = false
    }
    
    func refreshRequests() async {
        await loadFriendRequests(for: currentUserId)
    }
    
    func acceptRequest(_ requestId: String) async {
        errorMessage = nil
        
        do {
            _ = try await backendService.acceptFriendRequest(requestId: requestId)
            friendRequests.removeAll { $0._id == requestId }
            pendingRequestsCount = max(0, pendingRequestsCount - 1)
            HapticManager.shared.haptic(.success)
            
            // Refresh friends list since we added a new friend
            await refreshFriends()
        } catch {
            errorMessage = "Failed to accept friend request: \(error.localizedDescription)"
            HapticManager.shared.haptic(.error)
            print("❌ Error accepting friend request: \(error)")
        }
    }
    
    func rejectRequest(_ requestId: String) async {
        errorMessage = nil
        
        do {
            _ = try await backendService.rejectFriendRequest(requestId: requestId)
            friendRequests.removeAll { $0._id == requestId }
            pendingRequestsCount = max(0, pendingRequestsCount - 1)
            HapticManager.shared.haptic(.selection)
        } catch {
            errorMessage = "Failed to reject friend request: \(error.localizedDescription)"
            HapticManager.shared.haptic(.error)
            print("❌ Error rejecting friend request: \(error)")
        }
    }
    
    // MARK: - Discover / Suggestions
    
    func loadSuggestedUsers() async {
        isLoadingSuggested = true
        errorMessage = nil
        
        do {
            let response = try await backendService.getFriendSuggestions(limit: 20, excludeRequested: true)
            suggestedUsers = response.suggestions.map { suggestion in
                let user = BackendUser(
                    id: suggestion.id,
                    userId: nil,
                    clerkId: suggestion.clerkId,
                    email: nil,
                    firstName: nil,
                    lastName: nil,
                    username: suggestion.username,
                    displayName: suggestion.name,
                    bio: suggestion.bio,
                    avatarUrl: suggestion.profileImage,
                    role: nil,
                    appleId: nil,
                    googleId: nil,
                    dietaryPreferences: nil,
                    followersCount: suggestion.followerCount,
                    followingCount: 0,
                    postsCount: 0,
                    isVerified: false,
                    isActive: true,
                    createdAt: 0,
                    updatedAt: 0
                )
                return EnhancedUserSuggestion(
                    user: user,
                    mutualFriendsCount: suggestion.mutualFriendsCount,
                    connectionReason: suggestion.connectionReason
                )
            }
        } catch {
            errorMessage = "Failed to load suggested users: \(error.localizedDescription)"
            print("❌ Failed to load suggested users: \(error)")
        }
        
        isLoadingSuggested = false
    }
    
    // MARK: - Search
    
    func searchUsers(query: String, filters: FriendsView.SearchFilters) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        errorMessage = nil
        
        do {
            let users = try await backendService.searchBackendUsers(query: query, limit: 20)
            
            // Apply filters
            var filteredUsers = users
            
            if filters.onlyVerified {
                filteredUsers = filteredUsers.filter { $0.isVerified }
            }
            
            if !filters.dietaryPreferences.isEmpty {
                filteredUsers = filteredUsers.filter { user in
                    guard let userPreferences = user.dietaryPreferences else { return false }
                    return !Set(filters.dietaryPreferences).isDisjoint(with: Set(userPreferences))
                }
            }
            
            searchResults = filteredUsers
        } catch {
            errorMessage = "Failed to search users: \(error.localizedDescription)"
            searchResults = []
            print("❌ Failed to search users: \(error)")
        }
        
        isSearching = false
    }
    
    func clearSearch() {
        searchResults = []
        isSearching = false
    }
    
    // MARK: - Friend Request Actions
    
    func sendFriendRequest(to user: BackendUser) async {
        guard let currentUser = Clerk.shared.user else {
            errorMessage = "You must be logged in to send friend requests"
            return
        }
        
        do {
            let response = try await backendService.sendFriendRequest(
                senderId: currentUser.id,
                receiverId: user.clerkId
            )
            
            if response.success {
                HapticManager.shared.impact(.success)
                // Remove from suggestions if present
                suggestedUsers.removeAll { $0.user.clerkId == user.clerkId }
                print("✅ Friend request sent to \(user.username ?? "unknown")")
            } else {
                errorMessage = response.message ?? "Failed to send friend request"
            }
        } catch {
            errorMessage = "Failed to send friend request: \(error.localizedDescription)"
            print("❌ Failed to send friend request: \(error)")
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Search Filters View

struct FriendsSearchFiltersView: View {
    typealias SearchFilters = FriendsView.SearchFilters
    @Binding var filters: SearchFilters
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let dietaryOptions = [
        "Vegetarian", "Vegan", "Gluten-Free", "Dairy-Free",
        "Keto", "Paleo", "Halal", "Kosher"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("User Preferences") {
                    Toggle("Verified users only", isOn: $filters.onlyVerified)
                        .toggleStyle(SwitchToggleStyle(tint: .primaryBrand))
                }
                
                Section("Location") {
                    Toggle("Include nearby users", isOn: $filters.includeNearby)
                        .toggleStyle(SwitchToggleStyle(tint: .primaryBrand))
                    
                    if filters.includeNearby {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Maximum distance: \(Int(filters.maxDistance)) km")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            
                            Slider(value: $filters.maxDistance, in: 1...100, step: 1)
                                .tint(.primaryBrand)
                        }
                    }
                }
                
                Section("Dietary Preferences") {
                    ForEach(dietaryOptions, id: \.self) { option in
                        HStack {
                            Text(option)
                            Spacer()
                            if filters.dietaryPreferences.contains(option) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.primaryBrand)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if filters.dietaryPreferences.contains(option) {
                                filters.dietaryPreferences.removeAll { $0 == option }
                            } else {
                                filters.dietaryPreferences.append(option)
                            }
                            HapticManager.shared.impact(.light)
                        }
                    }
                }
                
                Section {
                    Button("Clear All Filters") {
                        filters = SearchFilters()
                        HapticManager.shared.impact(.medium)
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Search Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                        HapticManager.shared.impact(.medium)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryBrand)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    FriendsView()
        .environmentObject(MockAppState())
}



