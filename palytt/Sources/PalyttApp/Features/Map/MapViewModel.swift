//
//  MapViewModel.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import MapKit
import SwiftUI
import CoreLocation

@MainActor
class MapViewModel: ObservableObject {
    @Published var mapPosts: [MapPostAnnotation] = []
    @Published var userOwnPosts: [MapPostAnnotation] = []
    @Published var clusteredAnnotations: [ClusterAnnotation] = []
    @Published var heatMapData: [HeatMapPoint] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Enhanced Filter properties - Phase 1 UX Enhancement
    @Published var selectedTimeframe: String = "All Time"
    @Published var showFollowingOnly = false
    @Published var showFriendsOnly = false
    @Published var showAllUsers = true
    @Published var maxDistance: Double = 50.0 // km
    @Published var timeFilter: TimeFilter = .allTime
    @Published var selectedCategories: Set<FoodCategory> = []
    @Published var priceRange: ClosedRange<Double> = 1.0...4.0
    @Published var minimumRating: Double = 0.0
    @Published var showHeatMap = false
    @Published var enableClustering = true
    @Published var clusterRadius: Double = 100.0 // meters
    
    // Real-time features
    @Published var liveLocationEnabled = false
    @Published var nearbyFriends: [NearbyFriend] = []
    @Published var lastUpdateTime = Date()
    @Published var currentUserLocation: CLLocationCoordinate2D?
    
    private let backendService = BackendService.shared
    private let locationManager = CLLocationManager()
    private var locationDelegate: LocationManagerDelegate?
    private var allPosts: [BackendService.FollowingPost] = []
    private var allUserPosts: [BackendService.BackendPost] = []
    private var currentUserId: String?
    private var refreshTimer: Timer?
    private var userFriends: Set<String> = [] // Cache of user's friend IDs
    
    init() {
        setupLocationManager()
        setupRealTimeUpdates()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: - Location Management
    
    private func setupLocationManager() {
        locationDelegate = LocationManagerDelegate(viewModel: self)
        locationManager.delegate = locationDelegate
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Request location permissions
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        
        if locationManager.authorizationStatus == .authorizedWhenInUse ||
           locationManager.authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    func updateUserLocation(_ coordinate: CLLocationCoordinate2D) {
        currentUserLocation = coordinate
        
        // Refresh posts with new location-based filtering
        Task {
            await processAndDisplayPosts()
        }
    }
    
    // MARK: - Core Data Loading
    
    func loadFollowingPosts(for userId: String) async {
        currentUserId = userId
        isLoading = true
        errorMessage = nil
        
        do {
            let followingPosts = try await backendService.getFollowingPosts(userId: userId)
            
            // Store posts for filtering and processing
            allPosts = followingPosts
            
            // Load user's friends list for filtering
            await loadUserFriends(userId: userId)
            
            // Process and display posts
            await processAndDisplayPosts()
            
        } catch {
            errorMessage = "Failed to load posts: \(error.localizedDescription)"
            print("❌ Error loading following posts: \(error)")
        }
        
        isLoading = false
        lastUpdateTime = Date()
    }
    
    func loadUserPosts(for userId: String) async {
        currentUserId = userId
        isLoading = true
        errorMessage = nil
        
        do {
            let userPosts = try await backendService.getPostsByUser(userId: userId)
            
            // Store posts for filtering
            allUserPosts = userPosts
            
            // Process and display posts
            await processAndDisplayPosts()
            
        } catch {
            errorMessage = "Failed to load user posts: \(error.localizedDescription)"
            print("❌ Error loading user posts: \(error)")
        }
        
        isLoading = false
        lastUpdateTime = Date()
    }
    
    private func loadUserFriends(userId: String) async {
        do {
            // Note: This assumes there's a friends endpoint in BackendService
            // You may need to implement this method in BackendService
            let friends = try await backendService.getFriends(userId: userId)
            userFriends = Set(friends.map { $0.id.uuidString })
        } catch {
            print("⚠️ Could not load friends list: \(error)")
            // Continue without friends filtering
        }
    }
    
    // MARK: - Enhanced Processing & Display
    
    private func processAndDisplayPosts() async {
        // Apply filters first
        let filteredPosts = await applyAdvancedFilters()
        
        // Convert to annotations
        let annotations = convertToAnnotations(filteredPosts)
        
        // Apply clustering if enabled
        if enableClustering {
            clusteredAnnotations = createClusters(from: annotations)
            mapPosts = annotations.filter { !isInCluster($0, clusters: clusteredAnnotations) }
        } else {
            mapPosts = annotations
            clusteredAnnotations = []
        }
        
        // Generate heat map data if enabled
        if showHeatMap {
            heatMapData = generateHeatMapData(from: annotations)
        } else {
            heatMapData = []
        }
        
        print("✅ MapViewModel: Processed \(annotations.count) posts, \(clusteredAnnotations.count) clusters")
    }
    
    // MARK: - Advanced Filtering
    
    private func applyAdvancedFilters() async -> [BackendService.FollowingPost] {
        return allPosts.filter { post in
            // User type filter
            if showFollowingOnly {
                // All posts from getFollowingPosts are from following users by default
                // No additional filtering needed
            } else if showFriendsOnly {
                // Check if post author is in user's friends list
                let authorId = post.author?.clerkId ?? post.userId
                guard !authorId.isEmpty,
                      userFriends.contains(authorId) else {
                    return false
                }
            } else if !showAllUsers {
                // If none of the filters are selected, show no posts
                return false
            }
            
            // Distance filter
            guard passesDistanceFilter(post) else { return false }
            
            // Time filter
            guard passesTimeFilter(post) else { return false }
            
            // Category filter
            guard passesCategoryFilter(post) else { return false }
            
            // Rating filter
            guard passesRatingFilter(post) else { return false }
            
            // Price filter (if available)
            guard passesPriceFilter(post) else { return false }
            
            return true
        }
    }
    
    private func passesDistanceFilter(_ post: BackendService.FollowingPost) -> Bool {
        // If no user location or max distance is unlimited, pass all posts
        guard let userLocation = currentUserLocation,
              maxDistance < 1000 else { return true }
        
        guard let locationData = post.locationData else { return false }
        
        let postLocation = CLLocationCoordinate2D(
            latitude: locationData.latitude,
            longitude: locationData.longitude
        )
        
        let distance = userLocation.distance(to: postLocation) / 1000.0 // Convert to km
        return distance <= maxDistance
    }
    
    private func passesTimeFilter(_ post: BackendService.FollowingPost) -> Bool {
        let postDate = Date(timeIntervalSince1970: TimeInterval(post.createdAt) / 1000)
        return passesTimeFilter(date: postDate)
    }
    
    private func passesCategoryFilter(_ post: BackendService.FollowingPost) -> Bool {
        // If no categories selected, show all
        if selectedCategories.isEmpty { return true }
        
        // Check if post tags match any selected categories
        let postTags = Set(post.tags?.map { $0.lowercased() } ?? [])
        let selectedCategoryStrings = Set(selectedCategories.map { $0.rawValue.lowercased() })
        
        return !postTags.isDisjoint(with: selectedCategoryStrings)
    }
    
    private func passesRatingFilter(_ post: BackendService.FollowingPost) -> Bool {
        guard minimumRating > 0.0 else { return true }
        
        if let rating = post.metadata.rating {
            return Double(rating) >= minimumRating
        }
        return false // If no rating and minimum required, exclude
    }
    
    private func passesPriceFilter(_ post: BackendService.FollowingPost) -> Bool {
        // Price filtering not available in current metadata structure
        // TODO: Add price level to metadata schema if needed
        return true // Include all posts for now
    }
    
    // MARK: - Consolidated Filter Helpers
    
    private func passesTimeFilter(date: Date) -> Bool {
        let now = Date()
        
        switch timeFilter {
        case .today:
            return Calendar.current.isDate(date, inSameDayAs: now)
        case .thisWeek:
            let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
            return date >= oneWeekAgo
        case .thisMonth:
            let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
            return date >= oneMonthAgo
        case .allTime:
            return true
        }
    }
    
    // MARK: - User Posts Filtering (for profile view)
    
    private func applyFiltersToUserPosts() -> [BackendService.BackendPost] {
        return allUserPosts.filter { post in
            // Distance filter
            guard passesDistanceFilterForUserPost(post) else { return false }
            
            // Time filter
            guard passesTimeFilterForUserPost(post) else { return false }
            
            // Category filter
            guard passesCategoryFilterForUserPost(post) else { return false }
            
            return true
        }
    }
    
    private func passesDistanceFilterForUserPost(_ post: BackendService.BackendPost) -> Bool {
        guard let userLocation = currentUserLocation,
              maxDistance < 1000,
              let location = post.location else { return true }
        
        let postLocation = CLLocationCoordinate2D(
            latitude: location.latitude,
            longitude: location.longitude
        )
        
        let distance = userLocation.distance(to: postLocation) / 1000.0 // Convert to km
        return distance <= maxDistance
    }
    
    private func passesTimeFilterForUserPost(_ post: BackendService.BackendPost) -> Bool {
        let dateFormatter = ISO8601DateFormatter()
        guard let postDate = dateFormatter.date(from: post.createdAt) else {
            return true // If date parsing fails, include the post
        }
        
        return passesTimeFilter(date: postDate)
    }
    
    private func passesCategoryFilterForUserPost(_ post: BackendService.BackendPost) -> Bool {
        // If no categories selected, show all
        if selectedCategories.isEmpty { return true }
        
        // Check if post tags match any selected categories
        let postTags = Set(post.tags.map { $0.lowercased() })
        let selectedCategoryStrings = Set(selectedCategories.map { $0.rawValue.lowercased() })
        
        return !postTags.isDisjoint(with: selectedCategoryStrings)
    }
    
    // MARK: - Clustering Algorithm
    
    private func createClusters(from annotations: [MapPostAnnotation]) -> [ClusterAnnotation] {
        var clusters: [ClusterAnnotation] = []
        var processedAnnotations: Set<String> = []
        
        for annotation in annotations {
            guard !processedAnnotations.contains(annotation.id) else { continue }
            
            // Find nearby annotations within cluster radius
            let nearbyAnnotations = annotations.filter { other in
                guard annotation.id != other.id else { return false }
                guard !processedAnnotations.contains(other.id) else { return false }
                let distance = annotation.coordinate.distance(to: other.coordinate)
                return distance <= clusterRadius
            }
            
            if nearbyAnnotations.count >= 1 { // Cluster if 2+ posts nearby
                var clusterAnnotations = nearbyAnnotations
                clusterAnnotations.append(annotation)
                
                // Mark all as processed
                for clustered in clusterAnnotations {
                    processedAnnotations.insert(clustered.id)
                }
                
                // Calculate cluster center using weighted average
                let totalWeight = Double(clusterAnnotations.count)
                let centerLat = clusterAnnotations.map { $0.coordinate.latitude }.reduce(0, +) / totalWeight
                let centerLon = clusterAnnotations.map { $0.coordinate.longitude }.reduce(0, +) / totalWeight
                
                let cluster = ClusterAnnotation(
                    id: UUID().uuidString,
                    coordinate: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                    annotations: clusterAnnotations,
                    count: clusterAnnotations.count
                )
                
                clusters.append(cluster)
            }
        }
        
        return clusters
    }
    
    private func isInCluster(_ annotation: MapPostAnnotation, clusters: [ClusterAnnotation]) -> Bool {
        return clusters.contains { cluster in
            cluster.annotations.contains { $0.id == annotation.id }
        }
    }
    
    // MARK: - Heat Map Generation
    
    private func generateHeatMapData(from annotations: [MapPostAnnotation]) -> [HeatMapPoint] {
        // Group annotations by approximate location (grid-based)
        var locationGroups: [String: [MapPostAnnotation]] = [:]
        
        for annotation in annotations {
            // Create a grid key (rounded to ~100m precision)
            let latKey = Int(annotation.coordinate.latitude * 1000) // ~111m precision
            let lonKey = Int(annotation.coordinate.longitude * 1000)
            let gridKey = "\(latKey),\(lonKey)"
            
            locationGroups[gridKey, default: []].append(annotation)
        }
        
        // Convert to heat map points
        return locationGroups.compactMap { (key, annotations) in
            guard !annotations.isEmpty else { return nil }
            
            let avgLat = annotations.map { $0.coordinate.latitude }.reduce(0, +) / Double(annotations.count)
            let avgLon = annotations.map { $0.coordinate.longitude }.reduce(0, +) / Double(annotations.count)
            
            // Calculate intensity based on post count and engagement
            let postCount = annotations.count
            let totalLikes = annotations.map { $0.likesCount }.reduce(0, +)
            let totalComments = annotations.map { $0.commentsCount }.reduce(0, +)
            
            let intensity = calculateHeatMapIntensity(
                postCount: postCount,
                totalLikes: totalLikes,
                totalComments: totalComments
            )
            
            return HeatMapPoint(
                coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                intensity: intensity,
                postCount: postCount,
                radius: max(50.0, Double(postCount) * 25.0) // Scale radius with post count
            )
        }
    }
    
    private func calculateHeatMapIntensity(postCount: Int, totalLikes: Int, totalComments: Int) -> Double {
        // Weighted calculation: posts (40%), likes (35%), comments (25%)
        let postWeight = Double(postCount) * 0.4
        let likeWeight = Double(totalLikes) * 0.35
        let commentWeight = Double(totalComments) * 0.25
        
        let rawIntensity = postWeight + likeWeight + commentWeight
        
        // Normalize to 0.0-1.0 range with improved scaling
        return min(1.0, rawIntensity / 100.0)
    }
    
    // MARK: - Real-time Features
    
    private func setupRealTimeUpdates() {
        // Auto-refresh every 2 minutes if live updates enabled
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 120.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                guard self.liveLocationEnabled else { return }
                await self.refreshPosts()
            }
        }
    }
    
    func enableLiveUpdates() {
        liveLocationEnabled = true
        
        // Start location updates if authorized
        if locationManager.authorizationStatus == .authorizedWhenInUse ||
           locationManager.authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
        
        Task {
            await refreshPosts()
        }
    }
    
    func disableLiveUpdates() {
        liveLocationEnabled = false
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - Helper Functions
    
    func refreshPosts() async {
        guard let userId = currentUserId else { return }
        await loadFollowingPosts(for: userId)
    }
    
    func refreshUserPosts() async {
        guard let userId = currentUserId else { return }
        await loadUserPosts(for: userId)
    }
    
    func applyFilters() async {
        await processAndDisplayPosts()
    }
    
    func resetFilters() {
        selectedTimeframe = "All Time"
        showFollowingOnly = false
        showFriendsOnly = false
        showAllUsers = true
        maxDistance = 50.0
        timeFilter = .allTime
        selectedCategories = []
        priceRange = 1.0...4.0
        minimumRating = 0.0
        
        Task {
            await processAndDisplayPosts()
        }
    }
    
    func toggleHeatMap() {
        showHeatMap.toggle()
        Task {
            await processAndDisplayPosts()
        }
    }
    
    func toggleClustering() {
        enableClustering.toggle()
        Task {
            await processAndDisplayPosts()
        }
    }
    
    // MARK: - Data Conversion Methods
    
    private func convertToAnnotations(_ posts: [BackendService.FollowingPost]) -> [MapPostAnnotation] {
        return posts.compactMap { post -> MapPostAnnotation? in
            guard let locationData = post.locationData else { return nil }
            
            return MapPostAnnotation(
                id: post._id ?? UUID().uuidString,
                coordinate: CLLocationCoordinate2D(
                    latitude: locationData.latitude,
                    longitude: locationData.longitude
                ),
                title: post.title,
                authorDisplayName: post.author?.displayName ?? post.author?.username,
                authorAvatarUrl: post.author?.avatarUrl,
                imageUrl: post.imageUrls?.first ?? post.imageUrl,
                locationString: post.location ?? locationData.address,
                likesCount: post.likes,
                commentsCount: post.comments,
                originalPost: convertToPost(from: post)
            )
        }
    }
    
    private func convertToPost(from followingPost: BackendService.FollowingPost) -> Post {
        // Convert the backend FollowingPost to our local Post model
        let author = User(
            id: UUID(),
            email: "", // Not available in following post
            firstName: followingPost.author?.displayName?.components(separatedBy: " ").first,
            lastName: followingPost.author?.displayName?.components(separatedBy: " ").dropFirst().joined(separator: " "),
            username: followingPost.author?.username ?? "unknown",
            bio: nil,
            avatarURL: followingPost.author?.avatarUrl != nil ? URL(string: followingPost.author!.avatarUrl!) : nil,
            clerkId: followingPost.author?.clerkId ?? followingPost.userId
        )
        
        let location = followingPost.locationData.map { locationData in
            Location(
                latitude: locationData.latitude,
                longitude: locationData.longitude,
                address: locationData.address,
                city: locationData.city ?? "",
                state: nil,
                country: locationData.country ?? ""
            )
        } ?? Location.mockCafe
        
        let mediaURLs: [URL] = (followingPost.imageUrls ?? [followingPost.imageUrl].compactMap { $0 })
            .compactMap { URL(string: $0) }
        
        return Post(
            id: UUID(),
            convexId: followingPost._id ?? "",
            userId: UUID(),
            author: author,
            title: followingPost.title,
            caption: followingPost.content,
            mediaURLs: mediaURLs,
            shop: nil,
            location: location,
            menuItems: followingPost.tags ?? [],
            rating: followingPost.metadata.rating != nil ? Double(followingPost.metadata.rating!) : nil,
            createdAt: Date(timeIntervalSince1970: TimeInterval(followingPost.createdAt) / 1000),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(followingPost.updatedAt) / 1000),
            likesCount: followingPost.likes,
            commentsCount: followingPost.comments,
            isLiked: false, // Not available from following posts API
            isSaved: false  // Not available from following posts API
        )
    }
    
    private func convertToPost(from backendPost: BackendService.BackendPost) -> Post {
        // Convert the backend BackendPost to our local Post model
        let displayName = backendPost.authorDisplayName ?? "Unknown User"
        let nameComponents = displayName.components(separatedBy: " ")
        
        let author = User(
            id: UUID(),
            email: "", // Not available in backend post
            firstName: nameComponents.first,
            lastName: nameComponents.dropFirst().joined(separator: " "),
            username: displayName,
            bio: nil,
            avatarURL: nil, // Not available in backend post
            clerkId: backendPost.authorClerkId
        )
        
        let location = backendPost.location.map { backendLocation in
            Location(
                latitude: backendLocation.latitude,
                longitude: backendLocation.longitude,
                address: backendLocation.address,
                city: backendLocation.city ?? "",
                state: nil,
                country: backendLocation.country ?? ""
            )
        } ?? Location.mockCafe
        
        let mediaURLs: [URL] = (backendPost.imageUrls.isEmpty ? [backendPost.imageUrl].compactMap { $0 } : backendPost.imageUrls)
            .compactMap { URL(string: $0) }
        
        // Parse dates from strings with improved error handling
        let dateFormatter = ISO8601DateFormatter()
        let createdAt = dateFormatter.date(from: backendPost.createdAt) ?? Date()
        let updatedAt = dateFormatter.date(from: backendPost.updatedAt) ?? Date()
        
        return Post(
            id: UUID(),
            convexId: backendPost.id,
            userId: UUID(),
            author: author,
            title: backendPost.title,
            caption: backendPost.description ?? backendPost.content,
            mediaURLs: mediaURLs,
            shop: nil,
            location: location,
            menuItems: backendPost.tags,
            rating: (backendPost.rating != nil && backendPost.rating! > 0) ? backendPost.rating : nil,
            createdAt: createdAt,
            updatedAt: updatedAt,
            likesCount: backendPost.likesCount,
            commentsCount: backendPost.commentsCount,
            isLiked: false, // Would need to check user's likes
            isSaved: false  // Would need to check user's saves
        )
    }
}

// MARK: - Location Manager Delegate

private class LocationManagerDelegate: NSObject, CLLocationManagerDelegate {
    weak var viewModel: MapViewModel?
    
    init(viewModel: MapViewModel) {
        self.viewModel = viewModel
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            viewModel?.updateUserLocation(location.coordinate)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⚠️ Location manager failed with error: \(error)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            print("⚠️ Location access denied")
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
}

// MARK: - Enhanced Model Structures

// Model for map annotations
struct MapPostAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let authorDisplayName: String?
    let authorAvatarUrl: String?
    let imageUrl: String?
    let locationString: String
    let likesCount: Int
    let commentsCount: Int
    let originalPost: Post
}

extension MapPostAnnotation: Equatable {
    static func == (lhs: MapPostAnnotation, rhs: MapPostAnnotation) -> Bool {
        lhs.id == rhs.id
    }
}

extension MapPostAnnotation: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Model for clustered annotations
struct ClusterAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let annotations: [MapPostAnnotation]
    let count: Int
    
    var averageRating: Double? {
        let ratings = annotations.compactMap { $0.originalPost.rating }
        guard !ratings.isEmpty else { return nil }
        return ratings.reduce(0, +) / Double(ratings.count)
    }
    
    var totalEngagement: Int {
        return annotations.map { $0.likesCount + $0.commentsCount }.reduce(0, +)
    }
    
    var dominantCategory: FoodCategory? {
        let categories = annotations.flatMap { $0.originalPost.menuItems }
        let categoryCounts = Dictionary(grouping: categories) { $0.lowercased() }
        
        let mostCommon = categoryCounts.max { $0.value.count < $1.value.count }?.key
        return mostCommon.flatMap { categoryString in
            FoodCategory.allCases.first { $0.rawValue.lowercased() == categoryString }
        }
    }
}

// Model for heat map data points
struct HeatMapPoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let intensity: Double // 0.0 to 1.0
    let postCount: Int
    let radius: Double // in meters
    
    var color: Color {
        // Color gradient based on intensity
        let hue = max(0.0, 0.3 - (intensity * 0.3)) // Red (0.0) to Yellow (0.3)
        return Color(hue: hue, saturation: 0.8, brightness: 0.9, opacity: 0.6)
    }
    
    var displayRadius: Double {
        // Scale radius based on intensity for better visualization
        return radius * (0.5 + intensity * 0.5)
    }
}

// Model for nearby friends
struct NearbyFriend: Identifiable {
    let id = UUID()
    let user: User
    let coordinate: CLLocationCoordinate2D
    let distance: Double // in meters
    let lastActive: Date
    
    var isActiveRecently: Bool {
        Date().timeIntervalSince(lastActive) < 300 // 5 minutes
    }
}

// MARK: - CLLocationCoordinate2D Extensions

extension CLLocationCoordinate2D {
    func distance(to other: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return location1.distance(from: location2)
    }
    
    func isValid() -> Bool {
        return CLLocationCoordinate2DIsValid(self)
    }
} 