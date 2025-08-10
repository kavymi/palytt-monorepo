//
//  EnhancedSearchView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Speech
import Vision

// MARK: - Enhanced Search View

struct EnhancedSearchView: View {
    @StateObject private var viewModel = EnhancedSearchViewModel()
    @State private var searchText = ""
    @State private var selectedSearchType: SearchType = .all
    @State private var showVoiceSearch = false
    @State private var showVisualSearch = false
    @State private var showFilters = false
    @State private var isListening = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Enhanced Search Bar
                enhancedSearchBar
                
                // Search Type Selector
                searchTypeSelector
                
                // Quick Filters
                if selectedSearchType != .visual {
                    quickFiltersView
                }
                
                // Search Results
                searchResultsView
            }
            .background(Color.appBackground)
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showVisualSearch) {
                VisualSearchView { searchResults in
                    viewModel.visualSearchResults = searchResults
                    selectedSearchType = .visual
                }
            }
            .sheet(isPresented: $showFilters) {
                SearchFiltersView(filters: $viewModel.filters) { newFilters in
                    viewModel.filters = newFilters
                    Task {
                        await viewModel.performSearch(query: searchText, type: selectedSearchType)
                    }
                }
            }
        }
        .task {
            await viewModel.loadTrendingContent()
            await viewModel.loadPersonalizedRecommendations()
        }
        .onChange(of: searchText) { newText in
            if !newText.isEmpty {
                Task {
                    await viewModel.performSearch(query: newText, type: selectedSearchType)
                }
            } else {
                viewModel.clearSearchResults()
            }
        }
        .onChange(of: selectedSearchType) { newType in
            if !searchText.isEmpty {
                Task {
                    await viewModel.performSearch(query: searchText, type: newType)
                }
            }
        }
    }
    
    // MARK: - Enhanced Search Bar
    
    private var enhancedSearchBar: some View {
        HStack(spacing: 12) {
            // Main Search Field
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondaryText)
                
                TextField("Search food, places, people...", text: $searchText)
                    .textFieldStyle(.plain)
                    .submitLabel(.search)
                    .onSubmit {
                        Task {
                            await viewModel.performSearch(query: searchText, type: selectedSearchType)
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        viewModel.clearSearchResults()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondaryText)
                    }
                }
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Voice Search Button
            Button(action: {
                HapticManager.shared.impact(.medium)
                startVoiceSearch()
            }) {
                Image(systemName: isListening ? "mic.fill" : "mic")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isListening ? .red : .primaryBrand)
                    .frame(width: 44, height: 44)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
                    .scaleEffect(isListening ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isListening)
            }
            
            // Visual Search Button
            Button(action: {
                HapticManager.shared.impact(.medium)
                showVisualSearch = true
            }) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primaryBrand)
                    .frame(width: 44, height: 44)
                    .background(LinearGradient.primaryGradient.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Search Type Selector
    
    private var searchTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(SearchType.allCases, id: \.self) { type in
                    SearchTypeChip(
                        type: type,
                        isSelected: selectedSearchType == type,
                        count: viewModel.getResultCount(for: type)
                    ) {
                        HapticManager.shared.impact(.light)
                        selectedSearchType = type
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Quick Filters
    
    private var quickFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Filter Button
                Button(action: { showFilters = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.caption)
                        Text("Filters")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.primaryBrand)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.primaryBrand.opacity(0.1))
                    .cornerRadius(16)
                }
                
                // Quick Filter Chips
                ForEach(QuickFilter.allCases, id: \.self) { filter in
                    QuickFilterChip(
                        filter: filter,
                        isSelected: viewModel.filters.quickFilters.contains(filter)
                    ) {
                        viewModel.toggleQuickFilter(filter)
                        if !searchText.isEmpty {
                            Task {
                                await viewModel.performSearch(query: searchText, type: selectedSearchType)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Search Results
    
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if searchText.isEmpty {
                    defaultContent
                } else if viewModel.isLoading {
                    loadingContent
                } else {
                    searchResults
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
    
    private var defaultContent: some View {
        VStack(spacing: 20) {
            // Trending Section
            if !viewModel.trendingContent.isEmpty {
                TrendingSectionView(content: viewModel.trendingContent) { item in
                    // Handle trending item tap
                    searchText = item.searchTerm
                }
            }
            
            // Personalized Recommendations
            if !viewModel.personalizedRecommendations.isEmpty {
                PersonalizedRecommendationsView(recommendations: viewModel.personalizedRecommendations) { recommendation in
                    // Handle recommendation tap
                    searchText = recommendation.searchTerm
                }
            }
            
            // Recent Searches
            if !viewModel.recentSearches.isEmpty {
                RecentSearchesView(searches: viewModel.recentSearches) { search in
                    searchText = search
                }
            }
        }
    }
    
    private var loadingContent: some View {
        VStack(spacing: 12) {
            ForEach(0..<5, id: \.self) { _ in
                SearchResultSkeleton()
            }
        }
    }
    
    private var searchResults: some View {
        VStack(spacing: 16) {
            // Search Stats
            if viewModel.hasResults {
                HStack {
                    Text("Found \(viewModel.totalResults) results")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    Spacer()
                    
                    if !searchText.isEmpty {
                        Button("Save Search") {
                            viewModel.saveSearch(searchText)
                        }
                        .font(.caption)
                        .foregroundColor(.primaryBrand)
                    }
                }
            }
            
            // Results by Type
            switch selectedSearchType {
            case .all:
                allSearchResults
            case .posts:
                postsSearchResults
            case .people:
                peopleSearchResults
            case .places:
                placesSearchResults
            case .visual:
                visualSearchResults
            }
        }
    }
    
    private var allSearchResults: some View {
        VStack(spacing: 16) {
            // Top Posts
            if !viewModel.searchResults.posts.isEmpty {
                SearchSectionView(title: "Posts", items: Array(viewModel.searchResults.posts.prefix(3))) { post in
                    PostSearchResultCard(post: post)
                } seeAllAction: {
                    selectedSearchType = .posts
                }
            }
            
            // Top People
            if !viewModel.searchResults.people.isEmpty {
                SearchSectionView(title: "People", items: Array(viewModel.searchResults.people.prefix(3))) { user in
                    UserSearchResultCard(user: user)
                } seeAllAction: {
                    selectedSearchType = .people
                }
            }
            
            // Top Places
            if !viewModel.searchResults.places.isEmpty {
                SearchSectionView(title: "Places", items: Array(viewModel.searchResults.places.prefix(3))) { place in
                    PlaceSearchResultCard(place: place)
                } seeAllAction: {
                    selectedSearchType = .places
                }
            }
        }
    }
    
    private var postsSearchResults: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.searchResults.posts, id: \.id) { post in
                PostSearchResultCard(post: post)
            }
        }
    }
    
    private var peopleSearchResults: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.searchResults.people, id: \.id) { user in
                UserSearchResultCard(user: user)
            }
        }
    }
    
    private var placesSearchResults: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.searchResults.places, id: \.id) { place in
                PlaceSearchResultCard(place: place)
            }
        }
    }
    
    private var visualSearchResults: some View {
        VStack(spacing: 16) {
            if !viewModel.visualSearchResults.isEmpty {
                Text("Similar Food Items")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.visualSearchResults, id: \.id) { result in
                        VisualSearchResultCard(result: result)
                    }
                }
            } else {
                EmptyStateView(
                    icon: "camera.viewfinder",
                    title: "No Visual Search Results",
                    description: "Try taking a photo of food to find similar dishes and restaurants."
                )
            }
        }
    }
    
    // MARK: - Voice Search
    
    private func startVoiceSearch() {
        // Implementation for voice search using Speech framework
        // This would request permissions and start speech recognition
        
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            requestSpeechAuthorization()
            return
        }
        
        // Start listening animation
        withAnimation(.easeInOut(duration: 0.1)) {
            isListening = true
        }
        
        // Simulate voice recognition (in real app, implement actual speech recognition)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.1)) {
                isListening = false
            }
            
            // Mock voice search result
            searchText = "pizza near me"
        }
    }
    
    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            // Handle authorization result
        }
    }
}

// MARK: - Search Type Chip

struct SearchTypeChip: View {
    let type: SearchType
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.caption)
                
                Text(type.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if count > 0 && isSelected {
                    Text("\(count)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(8)
                }
            }
            .foregroundColor(isSelected ? .white : .primaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? LinearGradient.primaryGradient : 
                          AnyShapeStyle(Color.gray.opacity(0.1)))
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Quick Filter Chip

struct QuickFilterChip: View {
    let filter: QuickFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                }
                
                Text(filter.title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.primaryBrand : Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Search Result Cards

struct PostSearchResultCard: View {
    let post: Post
    
    var body: some View {
        HStack(spacing: 12) {
            // Post Image
            if let imageURL = post.mediaURLs.first {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Post Info
            VStack(alignment: .leading, spacing: 4) {
                Text(post.caption ?? "Food Post")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primaryText)
                    .lineLimit(2)
                
                Text("by @\(post.author.username)")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                        Text("\(post.likesCount)")
                            .font(.caption2)
                            .foregroundColor(.secondaryText)
                    }
                    
                    if let shop = post.shop {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text(shop.name)
                                .font(.caption2)
                                .foregroundColor(.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct UserSearchResultCard: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 12) {
            UserAvatar(user: user, size: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primaryText)
                
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.tertiaryText)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Button("Follow") {
                // Handle follow action
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.primaryBrand)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.primaryBrand.opacity(0.1))
            .cornerRadius(16)
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct PlaceSearchResultCard: View {
    let place: SearchPlace
    
    var body: some View {
        HStack(spacing: 12) {
            // Place Image
            AsyncImage(url: place.imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient.primaryGradient.opacity(0.3))
                    .overlay(
                        Image(systemName: "building.2.fill")
                            .foregroundColor(.primaryBrand)
                    )
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Place Info
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primaryText)
                
                Text(place.cuisine)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", place.rating))
                            .font(.caption2)
                            .foregroundColor(.secondaryText)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text(place.distance)
                            .font(.caption2)
                            .foregroundColor(.secondaryText)
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct VisualSearchResultCard: View {
    let result: VisualSearchResult
    
    var body: some View {
        HStack(spacing: 12) {
            // Result Image
            AsyncImage(url: result.imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Result Info
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primaryText)
                
                Text(result.description)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .lineLimit(2)
                
                HStack(spacing: 4) {
                    Text("\(Int(result.confidence * 100))% match")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    if let restaurant = result.restaurant {
                        Text("at \(restaurant)")
                            .font(.caption2)
                            .foregroundColor(.secondaryText)
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Data Models

enum SearchType: String, CaseIterable {
    case all = "all"
    case posts = "posts"
    case people = "people"
    case places = "places"
    case visual = "visual"
    
    var title: String {
        switch self {
        case .all: return "All"
        case .posts: return "Posts"
        case .people: return "People"
        case .places: return "Places"
        case .visual: return "Visual"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .posts: return "photo"
        case .people: return "person.2"
        case .places: return "location"
        case .visual: return "camera.viewfinder"
        }
    }
}

enum QuickFilter: String, CaseIterable {
    case nearMe = "nearMe"
    case trending = "trending"
    case friends = "friends"
    case newPlaces = "newPlaces"
    case topRated = "topRated"
    
    var title: String {
        switch self {
        case .nearMe: return "Near Me"
        case .trending: return "Trending"
        case .friends: return "Friends"
        case .newPlaces: return "New Places"
        case .topRated: return "Top Rated"
        }
    }
}

struct SearchResults {
    var posts: [Post] = []
    var people: [User] = []
    var places: [SearchPlace] = []
}

struct SearchPlace: Identifiable {
    let id = UUID()
    let name: String
    let cuisine: String
    let rating: Double
    let distance: String
    let imageURL: URL?
}

struct VisualSearchResult: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let confidence: Double
    let imageURL: URL?
    let restaurant: String?
}

struct TrendingItem: Identifiable {
    let id = UUID()
    let title: String
    let searchTerm: String
    let imageURL: URL?
    let trendingScore: Int
}

struct PersonalizedRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let searchTerm: String
    let reason: String
    let imageURL: URL?
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EnhancedSearchView()
    }
} 