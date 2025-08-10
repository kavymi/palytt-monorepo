//
//  EnhancedSearchViewModel.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import SwiftUI
import Combine

// MARK: - Enhanced Search View Model

@MainActor
class EnhancedSearchViewModel: ObservableObject {
    @Published var searchResults = SearchResults()
    @Published var visualSearchResults: [VisualSearchResult] = []
    @Published var trendingContent: [TrendingItem] = []
    @Published var personalizedRecommendations: [PersonalizedRecommendation] = []
    @Published var recentSearches: [String] = []
    @Published var isLoading = false
    @Published var filters = SearchFilters()
    
    private let backendService = BackendService.shared
    private var searchCancellable: AnyCancellable?
    private let maxRecentSearches = 10
    
    var hasResults: Bool {
        !searchResults.posts.isEmpty || !searchResults.people.isEmpty || !searchResults.places.isEmpty || !visualSearchResults.isEmpty
    }
    
    var totalResults: Int {
        searchResults.posts.count + searchResults.people.count + searchResults.places.count + visualSearchResults.count
    }
    
    init() {
        loadRecentSearches()
    }
    
    // MARK: - Public Methods
    
    func performSearch(query: String, type: SearchType) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearSearchResults()
            return
        }
        
        isLoading = true
        
        // Cancel previous search
        searchCancellable?.cancel()
        
        // Debounce search
        searchCancellable = Just(query)
            .delay(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] searchQuery in
                Task {
                    await self?.executeSearch(query: searchQuery, type: type)
                }
            }
    }
    
    func clearSearchResults() {
        searchResults = SearchResults()
        visualSearchResults = []
        isLoading = false
    }
    
    func getResultCount(for type: SearchType) -> Int {
        switch type {
        case .all:
            return totalResults
        case .posts:
            return searchResults.posts.count
        case .people:
            return searchResults.people.count
        case .places:
            return searchResults.places.count
        case .visual:
            return visualSearchResults.count
        }
    }
    
    func toggleQuickFilter(_ filter: QuickFilter) {
        if filters.quickFilters.contains(filter) {
            filters.quickFilters.remove(filter)
        } else {
            filters.quickFilters.insert(filter)
        }
    }
    
    func saveSearch(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, !recentSearches.contains(trimmedQuery) else { return }
        
        recentSearches.insert(trimmedQuery, at: 0)
        
        // Keep only the most recent searches
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }
        
        saveRecentSearches()
    }
    
    func loadTrendingContent() async {
        // Load trending content from backend or generate mock data
        await generateMockTrendingContent()
    }
    
    func loadPersonalizedRecommendations() async {
        // Load personalized recommendations based on user behavior
        await generateMockPersonalizedRecommendations()
    }
    
    // MARK: - Private Methods
    
    private func executeSearch(query: String, type: SearchType) async {
        defer { isLoading = false }
        
        do {
            // Apply filters to search
            let filteredQuery = applyFiltersToQuery(query)
            
            switch type {
            case .all:
                async let posts = searchPosts(query: filteredQuery)
                async let people = searchPeople(query: filteredQuery)
                async let places = searchPlaces(query: filteredQuery)
                
                let (postsResult, peopleResult, placesResult) = await (posts, people, places)
                
                searchResults = SearchResults(
                    posts: postsResult,
                    people: peopleResult,
                    places: placesResult
                )
                
            case .posts:
                searchResults.posts = await searchPosts(query: filteredQuery)
                
            case .people:
                searchResults.people = await searchPeople(query: filteredQuery)
                
            case .places:
                searchResults.places = await searchPlaces(query: filteredQuery)
                
            case .visual:
                // Visual search results are handled separately
                break
            }
            
            // Save successful search
            saveSearch(query)
            
        } catch {
            print("❌ Search error: \(error)")
            // Handle search error
        }
    }
    
    private func searchPosts(query: String) async -> [Post] {
        do {
            // In real implementation, this would use backend search
            let backendPosts = try await backendService.searchPosts(query: query, filters: filters)
            return backendPosts.map { Post.from(backendPost: $0) }
        } catch {
            print("❌ Post search error: \(error)")
            return []
        }
    }
    
    private func searchPeople(query: String) async -> [User] {
        do {
            // In real implementation, this would use backend search
            let backendUsers = try await backendService.searchUsers(query: query, filters: filters)
            return backendUsers.map { $0.toUser() }
        } catch {
            print("❌ People search error: \(error)")
            return []
        }
    }
    
    private func searchPlaces(query: String) async -> [SearchPlace] {
        // Mock implementation - in real app, this would search restaurants/places
        return generateMockPlaces(for: query)
    }
    
    private func applyFiltersToQuery(_ query: String) -> String {
        var filteredQuery = query
        
        // Apply quick filters
        for filter in filters.quickFilters {
            switch filter {
            case .nearMe:
                filteredQuery += " location:nearby"
            case .trending:
                filteredQuery += " trending:true"
            case .friends:
                filteredQuery += " source:friends"
            case .newPlaces:
                filteredQuery += " new:true"
            case .topRated:
                filteredQuery += " rating:high"
            }
        }
        
        // Apply advanced filters
        if let cuisine = filters.cuisine {
            filteredQuery += " cuisine:\(cuisine)"
        }
        
        if let priceRange = filters.priceRange {
            filteredQuery += " price:\(priceRange.rawValue)"
        }
        
        if filters.distance > 0 {
            filteredQuery += " distance:\(filters.distance)mi"
        }
        
        return filteredQuery
    }
    
    private func loadRecentSearches() {
        if let data = UserDefaults.standard.data(forKey: "recent_searches"),
           let searches = try? JSONDecoder().decode([String].self, from: data) {
            recentSearches = searches
        }
    }
    
    private func saveRecentSearches() {
        if let data = try? JSONEncoder().encode(recentSearches) {
            UserDefaults.standard.set(data, forKey: "recent_searches")
        }
    }
    
    // MARK: - Mock Data Generation
    
    private func generateMockTrendingContent() async {
        // Simulate API delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        trendingContent = [
            TrendingItem(
                title: "Ramen Bowls",
                searchTerm: "ramen",
                imageURL: nil,
                trendingScore: 95
            ),
            TrendingItem(
                title: "Bubble Tea",
                searchTerm: "bubble tea",
                imageURL: nil,
                trendingScore: 88
            ),
            TrendingItem(
                title: "Sushi Restaurants",
                searchTerm: "sushi",
                imageURL: nil,
                trendingScore: 82
            ),
            TrendingItem(
                title: "Vegan Options",
                searchTerm: "vegan",
                imageURL: nil,
                trendingScore: 78
            )
        ]
    }
    
    private func generateMockPersonalizedRecommendations() async {
        // Simulate API delay
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        personalizedRecommendations = [
            PersonalizedRecommendation(
                title: "Italian Restaurants Near You",
                description: "Based on your recent activity",
                searchTerm: "italian restaurant",
                reason: "You liked similar posts",
                imageURL: nil
            ),
            PersonalizedRecommendation(
                title: "Coffee Shops",
                description: "Popular in your area",
                searchTerm: "coffee",
                reason: "Trending near you",
                imageURL: nil
            ),
            PersonalizedRecommendation(
                title: "Healthy Food Options",
                description: "Matching your dietary preferences",
                searchTerm: "healthy food",
                reason: "Based on your profile",
                imageURL: nil
            )
        ]
    }
    
    private func generateMockPlaces(for query: String) -> [SearchPlace] {
        // Mock places data
        return [
            SearchPlace(
                name: "Mario's Italian Kitchen",
                cuisine: "Italian",
                rating: 4.5,
                distance: "0.3 mi",
                imageURL: nil
            ),
            SearchPlace(
                name: "Sushi Zen",
                cuisine: "Japanese",
                rating: 4.7,
                distance: "0.5 mi",
                imageURL: nil
            ),
            SearchPlace(
                name: "The Local Bistro",
                cuisine: "American",
                rating: 4.2,
                distance: "0.8 mi",
                imageURL: nil
            )
        ]
    }
}

// MARK: - Search Filters

struct SearchFilters {
    var quickFilters: Set<QuickFilter> = []
    var cuisine: String?
    var priceRange: PriceRange?
    var distance: Double = 0 // in miles
    var rating: Double = 0
    var dietary: [DietaryPreference] = []
    var sortBy: SortOption = .relevance
    
    enum PriceRange: String, CaseIterable {
        case budget = "$"
        case moderate = "$$"
        case expensive = "$$$"
        case luxury = "$$$$"
        
        var title: String {
            switch self {
            case .budget: return "Budget ($)"
            case .moderate: return "Moderate ($$)"
            case .expensive: return "Expensive ($$$)"
            case .luxury: return "Luxury ($$$$)"
            }
        }
    }
    
    enum SortOption: String, CaseIterable {
        case relevance = "relevance"
        case distance = "distance"
        case rating = "rating"
        case newest = "newest"
        case popular = "popular"
        
        var title: String {
            switch self {
            case .relevance: return "Relevance"
            case .distance: return "Distance"
            case .rating: return "Rating"
            case .newest: return "Newest"
            case .popular: return "Most Popular"
            }
        }
    }
}

// MARK: - Backend Service Extensions

extension BackendService {
    func searchPosts(query: String, filters: SearchFilters) async throws -> [BackendPost] {
        // Mock implementation - in real app, this would call search API
        return []
    }
    
    func searchUsers(query: String, filters: SearchFilters) async throws -> [BackendUser] {
        // Call the actual user search function from the backend
        do {
            let searchResults = try await self.callConvexFunction(
                functionName: "users:search",
                args: [
                    "query": query,
                    "limit": 20,
                    "offset": 0
                ]
            )
            
            // Parse the response into BackendUser objects
            if let usersData = searchResults["data"] as? [[String: Any]] {
                return usersData.compactMap { userData in
                    // Convert dictionary to BackendUser
                    BackendUser.from(userData)
                }
            }
            
            return []
        } catch {
            print("❌ User search error: \(error)")
            return []
        }
    }
}

// MARK: - Supporting Views

struct SearchSectionView<T, Content: View>: View {
    let title: String
    let items: [T]
    let content: (T) -> Content
    let seeAllAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                Button("See All") {
                    seeAllAction()
                }
                .font(.subheadline)
                .foregroundColor(.primaryBrand)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(items.indices, id: \.self) { index in
                    content(items[index])
                }
            }
        }
    }
}

struct TrendingSectionView: View {
    let content: [TrendingItem]
    let onItemTap: (TrendingItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trending Now")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(content) { item in
                        TrendingItemCard(item: item) {
                            onItemTap(item)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct TrendingItemCard: View {
    let item: TrendingItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient.primaryGradient.opacity(0.3))
                        .frame(width: 80, height: 80)
                    
                    if let imageURL = item.imageURL {
                        AsyncImage(url: imageURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "photo")
                                .foregroundColor(.primaryBrand)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: "flame.fill")
                            .font(.title2)
                            .foregroundColor(.primaryBrand)
                    }
                }
                
                Text(item.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 90)
        }
        .buttonStyle(.plain)
    }
}

struct PersonalizedRecommendationsView: View {
    let recommendations: [PersonalizedRecommendation]
    let onRecommendationTap: (PersonalizedRecommendation) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended For You")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            
            LazyVStack(spacing: 8) {
                ForEach(recommendations.prefix(3)) { recommendation in
                    RecommendationCard(recommendation: recommendation) {
                        onRecommendationTap(recommendation)
                    }
                }
            }
        }
    }
}

struct RecommendationCard: View {
    let recommendation: PersonalizedRecommendation
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient.primaryGradient.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundColor(.primaryBrand)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText)
                    
                    Text(recommendation.description)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    Text(recommendation.reason)
                        .font(.caption2)
                        .foregroundColor(.tertiaryText)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            .padding(12)
            .background(Color.cardBackground)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

struct RecentSearchesView: View {
    let searches: [String]
    let onSearchTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Searches")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            
            LazyVStack(spacing: 6) {
                ForEach(searches.prefix(5), id: \.self) { search in
                    Button(action: { onSearchTap(search) }) {
                        HStack(spacing: 12) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            
                            Text(search)
                                .font(.subheadline)
                                .foregroundColor(.primaryText)
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct SearchResultSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonLoader(cornerRadius: 8)
                .frame(width: 60, height: 60)
            
            VStack(alignment: .leading, spacing: 6) {
                SkeletonLoader()
                    .frame(width: 180, height: 16)
                
                SkeletonLoader()
                    .frame(width: 120, height: 12)
                
                SkeletonLoader()
                    .frame(width: 100, height: 12)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
} 