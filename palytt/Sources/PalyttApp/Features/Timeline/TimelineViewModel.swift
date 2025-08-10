//
//  TimelineViewModel.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import SwiftUI
import CoreLocation

@MainActor
class TimelineViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var hasMorePosts = true
    @Published var currentFilter: TimelineFilter = .all
    
    private let backendService = BackendService.shared
    private let locationService = LocationBasedFeedService.shared
    private var currentPage = 1
    private let pageSize = 20
    private var allPosts: [Post] = [] // Store all posts for filtering
    
    // MARK: - Public Methods
    
    func loadTimeline() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        currentPage = 1
        
        do {
            let fetchedPosts = try await fetchTimelinePosts()
            posts = fetchedPosts
            allPosts = fetchedPosts
            hasMorePosts = fetchedPosts.count >= pageSize
        } catch {
            errorMessage = error.localizedDescription
            posts = MockData.posts.prefix(10).map { $0 } // Fallback to mock data
            allPosts = posts
        }
        
        isLoading = false
    }
    
    func refreshTimeline() async {
        await loadTimeline()
    }
    
    func loadMorePosts() async {
        guard !isLoadingMore && hasMorePosts else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        do {
            let newPosts = try await fetchTimelinePosts(page: currentPage)
            
            // Add new posts to the collection
            let combinedPosts = allPosts + newPosts
            allPosts = removeDuplicates(from: combinedPosts)
            
            // Apply current filter
            applyFilter(currentFilter)
            
            hasMorePosts = newPosts.count >= pageSize
        } catch {
            errorMessage = error.localizedDescription
            currentPage -= 1 // Revert page increment on error
        }
        
        isLoadingMore = false
    }
    
    func applyFilter(_ filter: TimelineFilter) {
        currentFilter = filter
        posts = filterPosts(allPosts, by: filter)
    }
    
    // MARK: - Private Methods
    
    private func fetchTimelinePosts(page: Int = 1) async throws -> [Post] {
        // This would typically call the backend service
        // For now, we'll simulate with filtered mock data based on timeline preferences
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Get posts based on location preferences if available
        if let userLocation = locationService.userLocation {
            return try await fetchLocationBasedPosts(page: page)
        } else {
            return try await fetchGeneralTimelinePosts(page: page)
        }
    }
    
    private func fetchLocationBasedPosts(page: Int) async throws -> [Post] {
        // Use location service to get smart feed
        await locationService.loadNearbyFeed()
        
        // Convert to Post objects and paginate
        let startIndex = (page - 1) * pageSize
        let endIndex = min(startIndex + pageSize, locationService.nearbyPosts.count)
        
        guard startIndex < locationService.nearbyPosts.count else {
            return []
        }
        
        return Array(locationService.nearbyPosts[startIndex..<endIndex])
    }
    
    private func fetchGeneralTimelinePosts(page: Int) async throws -> [Post] {
        // Use backend service for general timeline
        // For now, use mock data with pagination
        let mockPosts = MockData.posts
        let startIndex = (page - 1) * pageSize
        let endIndex = min(startIndex + pageSize, mockPosts.count)
        
        guard startIndex < mockPosts.count else {
            return []
        }
        
        return Array(mockPosts[startIndex..<endIndex])
    }
    
    private func filterPosts(_ posts: [Post], by filter: TimelineFilter) -> [Post] {
        switch filter {
        case .all:
            return posts.sorted { $0.createdAt > $1.createdAt }
            
        case .following:
            // Filter posts from users the current user follows
            // For now, return all posts (would need backend integration)
            return posts.sorted { $0.createdAt > $1.createdAt }
            
        case .friends:
            // Filter posts from friends only
            // For now, return all posts (would need backend integration)
            return posts.sorted { $0.createdAt > $1.createdAt }
            
        case .nearby:
            // Filter posts by location proximity
            guard let userLocation = locationService.userLocation else {
                return posts.sorted { $0.createdAt > $1.createdAt }
            }
            
            return posts.filter { post in
                guard let postLocation = post.location else { return false }
                
                let postCLLocation = CLLocation(
                    latitude: postLocation.latitude,
                    longitude: postLocation.longitude
                )
                
                let distance = userLocation.distance(from: postCLLocation) / 1000 // Convert to km
                return distance <= locationService.feedPreferences.maxDistance
            }.sorted { $0.createdAt > $1.createdAt }
            
        case .liked:
            // Filter posts that the user has liked
            return posts.filter { $0.isLiked }.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    private func removeDuplicates(from posts: [Post]) -> [Post] {
        var seen = Set<UUID>()
        return posts.filter { post in
            if seen.contains(post.id) {
                return false
            } else {
                seen.insert(post.id)
                return true
            }
        }
    }
    
    // MARK: - Timeline-Specific Actions
    
    func likePost(_ post: Post) async {
        // Optimistically update UI
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index].isLiked.toggle()
            posts[index].likesCount += posts[index].isLiked ? 1 : -1
        }
        
        // Also update in allPosts
        if let index = allPosts.firstIndex(where: { $0.id == post.id }) {
            allPosts[index].isLiked.toggle()
            allPosts[index].likesCount += allPosts[index].isLiked ? 1 : -1
        }
        
        // Call backend service
        do {
            // let response = try await backendService.likePost(postId: post.id.uuidString)
            // Update with actual response if needed
        } catch {
            // Revert optimistic update on error
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].isLiked.toggle()
                posts[index].likesCount += posts[index].isLiked ? 1 : -1
            }
            
            if let index = allPosts.firstIndex(where: { $0.id == post.id }) {
                allPosts[index].isLiked.toggle()
                allPosts[index].likesCount += allPosts[index].isLiked ? 1 : -1
            }
            
            errorMessage = "Failed to like post: \(error.localizedDescription)"
        }
    }
    
    func bookmarkPost(_ post: Post) async {
        // Optimistically update UI
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index].isBookmarked.toggle()
        }
        
        if let index = allPosts.firstIndex(where: { $0.id == post.id }) {
            allPosts[index].isBookmarked.toggle()
        }
        
        // Call backend service
        do {
            // let response = try await backendService.bookmarkPost(postId: post.id.uuidString)
            // Update with actual response if needed
        } catch {
            // Revert optimistic update on error
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].isBookmarked.toggle()
            }
            
            if let index = allPosts.firstIndex(where: { $0.id == post.id }) {
                allPosts[index].isBookmarked.toggle()
            }
            
            errorMessage = "Failed to bookmark post: \(error.localizedDescription)"
        }
    }
    
    func sharePost(_ post: Post) {
        // Implement sharing functionality
        // This would typically open a share sheet or copy link to clipboard
        print("📤 Timeline: Sharing post: \(post.id)")
    }
    
    func reportPost(_ post: Post) async {
        // Implement post reporting
        do {
            // let response = try await backendService.reportPost(postId: post.id.uuidString)
            print("🚨 Timeline: Reported post: \(post.id)")
        } catch {
            errorMessage = "Failed to report post: \(error.localizedDescription)"
        }
    }
}

// MARK: - Extensions
extension TimelineViewModel {
    func getTimeAgoString(for date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else if timeInterval < 604800 {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    func formatDistance(_ distance: Double) -> String {
        if distance < 1.0 {
            return String(format: "%.0f m", distance * 1000)
        } else if distance < 10.0 {
            return String(format: "%.1f km", distance)
        } else {
            return String(format: "%.0f km", distance)
        }
    }
} 