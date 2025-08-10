//
//  UniversalSearchView.swift
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
import CoreLocation

struct UniversalSearchView: View {
    @StateObject private var viewModel = UniversalSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: SearchCategory = .all
    @State private var isSearchActive = false
    
    enum SearchCategory: String, CaseIterable {
        case all = "All"
        case posts = "Posts"
        case places = "Places"
        case people = "People"
        
        var icon: String {
            switch self {
            case .all: return "magnifyingglass"
            case .posts: return "photo.on.rectangle"
            case .places: return "location"
            case .people: return "person.2"
            }
        }
        
        var color: Color {
            switch self {
            case .all: return .purple
            case .posts: return .blue
            case .places: return .shopsPlaces
            case .people: return .orange
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondaryText)
                        .font(.system(size: 16))
                    
                    TextField("Search posts, places, and people...", text: $searchText)
                        .foregroundColor(.primaryText)
                        .font(.system(size: 16))
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            performSearch()
                        }
                        .onChange(of: searchText) { _, newValue in
                            if newValue.isEmpty {
                                viewModel.clearResults()
                                isSearchActive = false
                            } else if newValue.count >= 2 {
                                // Auto-search when user types 2+ characters
                                performSearchWithDelay()
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            viewModel.clearResults()
                            isSearchActive = false
                            HapticManager.shared.impact(.light)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondaryText)
                                .font(.system(size: 16))
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding()
                
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(SearchCategory.allCases, id: \.self) { category in
                            CategoryFilterChip(
                                category: category,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                                if isSearchActive {
                                    performSearch()
                                }
                                HapticManager.shared.impact(.light)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
                
                Divider()
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if !isSearchActive {
                            // Initial state - show suggestions
                            InitialSearchStateView(viewModel: viewModel)
                        } else if viewModel.isSearching {
                            // Loading state
                            SearchLoadingView()
                        } else {
                            // Results
                            SearchResultsView(
                                viewModel: viewModel,
                                selectedCategory: selectedCategory,
                                searchText: searchText
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Search")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryBrand)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryBrand)
                }
                #endif
            }
            .task {
                await viewModel.loadSuggestedContent()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error occurred")
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isSearchActive = true
        Task {
            await viewModel.search(query: searchText, category: selectedCategory)
        }
    }
    
    private func performSearchWithDelay() {
        // Debounce search to avoid too many requests
        viewModel.searchTask?.cancel()
        viewModel.searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
            if !Task.isCancelled {
                await performSearch()
            }
        }
    }
}

// MARK: - Category Filter Chip
struct CategoryFilterChip: View {
    let category: UniversalSearchView.SearchCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : category.color)
                
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : category.color)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? category.color : category.color.opacity(0.1))
            .cornerRadius(20)
        }
    }
}

// MARK: - Initial Search State
struct InitialSearchStateView: View {
    @ObservedObject var viewModel: UniversalSearchViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            // Search illustration
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.primaryBrand.opacity(0.7))
                
                Text("Discover & Connect")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Text("Search for food posts, restaurants, and people to follow")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 40)
            
            Divider()
            
            // Suggested users section
            if !viewModel.suggestedUsers.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Suggested People")
                        .font(.headline)
                        .foregroundColor(.primaryText)
                        .padding(.horizontal)
                    
                    ForEach(viewModel.suggestedUsers.prefix(3), id: \.clerkId) { user in
                        SearchUserRowView(user: user) {
                            Task {
                                await viewModel.sendFriendRequest(to: user)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Search Loading View
struct SearchLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                SearchResultSkeleton()
            }
        }
    }
}

// MARK: - Search Results View
struct SearchResultsView: View {
    @ObservedObject var viewModel: UniversalSearchViewModel
    let selectedCategory: UniversalSearchView.SearchCategory
    let searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            // Posts Results
            if (selectedCategory == .all || selectedCategory == .posts) && !viewModel.postResults.isEmpty {
                SearchSectionView(title: "Posts", icon: "photo.on.rectangle", color: .blue) {
                    ForEach(viewModel.postResults, id: \.id) { post in
                        SearchPostRowView(post: post)
                    }
                }
            }
            
            // Places Results
            if (selectedCategory == .all || selectedCategory == .places) && !viewModel.placeResults.isEmpty {
                SearchSectionView(title: "Places", icon: "location", color: .shopsPlaces) {
                    ForEach(viewModel.placeResults, id: \.id) { place in
                        SearchPlaceRowView(place: place)
                    }
                }
            }
            
            // People Results
            if (selectedCategory == .all || selectedCategory == .people) && !viewModel.userResults.isEmpty {
                SearchSectionView(title: "People", icon: "person.2", color: .orange) {
                    ForEach(viewModel.userResults, id: \.clerkId) { user in
                        SearchUserRowView(user: user) {
                            Task {
                                await viewModel.sendFriendRequest(to: user)
                            }
                        }
                    }
                }
            }
            
            // No results state
            if viewModel.postResults.isEmpty && viewModel.placeResults.isEmpty && viewModel.userResults.isEmpty && !viewModel.isSearching {
                NoResultsView(searchText: searchText)
                    .padding(.top, 40)
            }
        }
    }
}

// MARK: - Search Section View
struct SearchSectionView<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primaryText)
                Spacer()
            }
            
            content
        }
    }
}

// MARK: - Search Result Rows

struct SearchPostRowView: View {
    let post: BackendService.BackendPost
    
    var body: some View {
        HStack(spacing: 12) {
            // Post image
            AsyncImage(url: URL(string: post.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 60, height: 60)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(post.title ?? "Food Post")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                
                Text(post.authorDisplayName ?? "Unknown User")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                
                if let location = post.location {
                    Text(location.address)
                        .font(.caption)
                        .foregroundColor(.tertiaryText)
                        .lineLimit(1)
                }
                
                HStack {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                    Text("\(post.likesCount)")
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                    
                    Image(systemName: "bubble")
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                    Text("\(post.commentsCount)")
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

struct SearchPlaceRowView: View {
    let place: BackendService.PlaceSearchResult
    
    var body: some View {
        HStack(spacing: 12) {
            // Place image or icon
            if let photoUrl = place.photoUrl {
                AsyncImage(url: URL(string: photoUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeIconView
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            } else {
                placeIconView
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                
                Text(place.address)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .lineLimit(2)
                
                HStack {
                    if let rating = place.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    }
                    
                    if let priceLevel = place.priceLevel {
                        Text(String(repeating: "$", count: priceLevel))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.shopsPlaces)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
    
    private var placeIconView: some View {
        Rectangle()
            .fill(LinearGradient.primaryGradient.opacity(0.3))
            .frame(width: 60, height: 60)
            .cornerRadius(8)
            .overlay(
                Image(systemName: "fork.knife")
                    .foregroundColor(.primaryBrand)
                    .font(.title3)
            )
    }
}

struct SearchUserRowView: View {
    let user: BackendUser
    let onAddFriend: () -> Void
    @State private var isLoading = false
    
    var body: some View {
        HStack(spacing: 12) {
            // User avatar
            BackendUserAvatar(user: user, size: 50)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName ?? user.username ?? "Unknown User")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text("@\(user.username ?? "unknown")")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.tertiaryText)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Add friend button
            Button(action: {
                HapticManager.shared.impact(.light)
                isLoading = true
                onAddFriend()
                // Reset loading state after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isLoading = false
                }
            }) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .primaryBrand))
                        .scaleEffect(0.8)
                        .frame(width: 80, height: 32)
                } else {
                    Text("Add Friend")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.primaryBrand)
                        .cornerRadius(16)
                }
            }
            .disabled(isLoading)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - No Results View
struct NoResultsView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No results found")
                .font(.headline)
                .foregroundColor(.secondaryText)
            
            Text("Try searching for different keywords or check your spelling")
                .font(.subheadline)
                .foregroundColor(.tertiaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("Search suggestions:")
                .font(.caption)
                .foregroundColor(.secondaryText)
                .padding(.top, 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• Food items: \"sushi\", \"pizza\", \"coffee\"")
                Text("• Places: \"restaurant near me\", \"cafe\"")
                Text("• People: \"john\", \"@username\"")
            }
            .font(.caption)
            .foregroundColor(.tertiaryText)
        }
    }
}

// MARK: - Search Result Skeleton
struct SearchResultSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Image skeleton
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 60)
                .shimmer(isAnimating: $isAnimating)
            
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 140, height: 16)
                    .shimmer(isAnimating: $isAnimating)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 100, height: 12)
                    .shimmer(isAnimating: $isAnimating)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 12)
                    .shimmer(isAnimating: $isAnimating)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Universal Search View Model
@MainActor
class UniversalSearchViewModel: ObservableObject {
    @Published var postResults: [BackendService.BackendPost] = []
    @Published var placeResults: [BackendService.PlaceSearchResult] = []
    @Published var userResults: [BackendUser] = []
    @Published var suggestedUsers: [BackendUser] = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    
    var searchTask: Task<Void, Never>?
    private let backendService = BackendService.shared
    
    func loadSuggestedContent() async {
        do {
            suggestedUsers = try await backendService.getSuggestedUsers(limit: 5)
        } catch {
            print("❌ Failed to load suggested users: \(error)")
        }
    }
    
    func search(query: String, category: UniversalSearchView.SearchCategory) async {
        searchTask?.cancel()
        
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            clearResults()
            return
        }
        
        isSearching = true
        errorMessage = nil
        
        do {
            switch category {
            case .all:
                async let posts = searchPosts(query: query)
                async let places = searchPlaces(query: query)
                async let users = searchUsers(query: query)
                
                postResults = await posts
                placeResults = await places
                userResults = await users
                
            case .posts:
                postResults = await searchPosts(query: query)
                placeResults = []
                userResults = []
                
            case .places:
                postResults = []
                placeResults = await searchPlaces(query: query)
                userResults = []
                
            case .people:
                postResults = []
                placeResults = []
                userResults = await searchUsers(query: query)
            }
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            print("❌ Search failed: \(error)")
        }
        
        isSearching = false
    }
    
    func searchPosts(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearPostResults()
            return
        }
        
        isSearchingPosts = true
        
        do {
            // Get current location for context if available
            var locationContext: (latitude: Double, longitude: Double)? = nil
            if let location = LocationManager.shared.currentLocation {
                locationContext = (location.coordinate.latitude, location.coordinate.longitude)
            }
            
            // Search posts with location context
            let searchResults = try await backendService.searchPosts(
                query: query,
                latitude: locationContext?.latitude,
                longitude: locationContext?.longitude,
                radius: 25000, // 25km radius
                limit: 20
            )
            
            postResults = searchResults
            print("✅ UniversalSearch: Found \(postResults.count) posts for query: \(query)")
            
        } catch {
            print("❌ UniversalSearch: Error searching posts: \(error)")
            errorMessage = "Failed to search posts: \(error.localizedDescription)"
            postResults = []
        }
        
        isSearchingPosts = false
    }
    
    func searchPlaces(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearPlaceResults()
            return
        }
        
        isSearchingPlaces = true
        
        do {
            // Get current location for better place search results
            var userLatitude: Double? = nil
            var userLongitude: Double? = nil
            
            if let location = LocationManager.shared.currentLocation {
                userLatitude = location.coordinate.latitude
                userLongitude = location.coordinate.longitude
            }
            
            // Search places with user location context
            let searchResults = try await backendService.searchPlaces(
                query: query,
                latitude: userLatitude,
                longitude: userLongitude,
                radius: 50000, // 50km radius for places
                limit: 20
            )
            
            // Convert PlaceSearchResult to Post model for display
            placeResults = searchResults.compactMap { place in
                Post.fromPlaceSearchResult(place)
            }
            
            print("✅ UniversalSearch: Found \(placeResults.count) places for query: \(query)")
            
        } catch {
            print("❌ UniversalSearch: Error searching places: \(error)")
            errorMessage = "Failed to search places: \(error.localizedDescription)"
            placeResults = []
        }
        
        isSearchingPlaces = false
    }
    
    func searchUsers(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearUserResults()
            return
        }
        
        isSearchingUsers = true
        
        do {
            // Enhanced user search with multiple criteria
            let searchResults = try await backendService.searchBackendUsers(
                query: query,
                limit: 20
            )
            
            userResults = searchResults
            print("✅ UniversalSearch: Found \(userResults.count) users for query: \(query)")
            
        } catch {
            print("❌ UniversalSearch: Error searching users: \(error)")
            errorMessage = "Failed to search users: \(error.localizedDescription)"
            userResults = []
        }
        
        isSearchingUsers = false
    }
    
    private func clearPostResults() {
        postResults = []
        isSearchingPosts = false
    }
    
    private func clearPlaceResults() {
        placeResults = []
        isSearchingPlaces = false
    }
    
    private func clearUserResults() {
        userResults = []
        isSearchingUsers = false
    }
    
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
                print("✅ Friend request sent to \(user.username ?? "unknown")")
            } else {
                errorMessage = response.message ?? "Failed to send friend request"
            }
            
        } catch {
            errorMessage = "Failed to send friend request: \(error.localizedDescription)"
            print("❌ Failed to send friend request: \(error)")
        }
    }
    
    func clearResults() {
        postResults = []
        placeResults = []
        userResults = []
    }
    
    func clearError() {
        errorMessage = nil
    }
}

#Preview {
    UniversalSearchView()
} 