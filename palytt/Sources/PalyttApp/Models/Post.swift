//
//  Post.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation

struct Post: Identifiable, Codable, Equatable {
    let id: UUID
    let convexId: String // Store original Convex document ID for backend calls
    let userId: UUID
    let author: User
    let title: String?
    let caption: String
    let mediaURLs: [URL]
    let shop: Shop?
    let location: Location
    let menuItems: [String]
    let rating: Double?
    let createdAt: Date
    let updatedAt: Date
    var likesCount: Int
    var commentsCount: Int
    var isLiked: Bool
    var isSaved: Bool
    
    // Group gathering integration
    var linkedGatheringId: String? // ID of the gathering this post is linked to
    var gatheringLinkType: GatheringLinkType? // Type of gathering link
    var gatheringHashtag: String? // Auto-populated from gathering
    
    // Mutual friends with current user
    var mutualFriendsCount: Int = 0
    var mutualFriends: [User] = []
    
    init(
        id: UUID = UUID(),
        convexId: String = "",
        userId: UUID,
        author: User,
        title: String? = nil,
        caption: String,
        mediaURLs: [URL],
        shop: Shop? = nil,
        location: Location,
        menuItems: [String] = [],
        rating: Double? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        likesCount: Int = 0,
        commentsCount: Int = 0,
        isLiked: Bool = false,
        isSaved: Bool = false,
        linkedGatheringId: String? = nil,
        gatheringLinkType: GatheringLinkType? = nil,
        gatheringHashtag: String? = nil,
        mutualFriendsCount: Int = 0,
        mutualFriends: [User] = []
    ) {
        self.id = id
        self.convexId = convexId
        self.userId = userId
        self.author = author
        self.title = title
        self.caption = caption
        self.mediaURLs = mediaURLs
        self.shop = shop
        self.location = location
        self.menuItems = menuItems
        self.rating = rating
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.isLiked = isLiked
        self.isSaved = isSaved
        self.linkedGatheringId = linkedGatheringId
        self.gatheringLinkType = gatheringLinkType
        self.gatheringHashtag = gatheringHashtag
        self.mutualFriendsCount = mutualFriendsCount
        self.mutualFriends = mutualFriends
    }
}

// MARK: - Backend Conversion

extension Post {
    /// Convert a BackendPost to Post model
    static func from(
        backendPost: BackendService.BackendPost,
        author: User? = nil
    ) -> Post {
        // Parse dates
        let dateFormatter = ISO8601DateFormatter()
        let createdAt = dateFormatter.date(from: backendPost.createdAt) ?? Date()
        let updatedAt = dateFormatter.date(from: backendPost.updatedAt) ?? Date()
        
        // Convert image URLs and ensure no duplicates
        var mediaURLs: [URL] = []
        var seenURLStrings: Set<String> = []
        
        // Add imageUrls first (multiple images) with deduplication
        for urlString in backendPost.imageUrls {
            if !seenURLStrings.contains(urlString), let url = URL(string: urlString) {
                seenURLStrings.insert(urlString)
                mediaURLs.append(url)
            }
        }
        
        // Add legacy imageUrl if not already included
        if let imageUrl = backendPost.imageUrl,
           !seenURLStrings.contains(imageUrl),
           let url = URL(string: imageUrl) {
            seenURLStrings.insert(imageUrl)
            mediaURLs.append(url)
        }
        
        // Create location from backend location
        let location: Location
        if let backendLocation = backendPost.location {
            location = Location(
                latitude: backendLocation.latitude,
                longitude: backendLocation.longitude,
                address: backendLocation.address,
                city: extractCity(from: backendLocation.address),
                country: "Unknown" // Backend doesn't provide separate country field
            )
        } else {
            // Default location if none provided
            location = Location(
                latitude: 0,
                longitude: 0,
                address: "Unknown Location",
                city: "Unknown",
                country: "Unknown"
            )
        }
        
        // Create shop if we have shop information
        let shop: Shop?
        if !backendPost.shopName.isEmpty {
            // Create default business hours (open 24/7 as placeholder)
            let defaultHours = BusinessHours(
                monday: BusinessHours.DayHours(open: "00:00", close: "23:59", isClosed: false),
                tuesday: BusinessHours.DayHours(open: "00:00", close: "23:59", isClosed: false),
                wednesday: BusinessHours.DayHours(open: "00:00", close: "23:59", isClosed: false),
                thursday: BusinessHours.DayHours(open: "00:00", close: "23:59", isClosed: false),
                friday: BusinessHours.DayHours(open: "00:00", close: "23:59", isClosed: false),
                saturday: BusinessHours.DayHours(open: "00:00", close: "23:59", isClosed: false),
                sunday: BusinessHours.DayHours(open: "00:00", close: "23:59", isClosed: false)
            )
            
            shop = Shop(
                id: UUID(),
                name: backendPost.shopName,
                description: nil,
                location: location,
                phoneNumber: nil,
                website: nil,
                hours: defaultHours,
                cuisineTypes: [],
                drinkTypes: [],
                priceRange: .moderate,
                rating: backendPost.rating ?? 0.0,
                reviewsCount: 0,
                photosCount: 0,
                menu: nil,
                ownerId: nil,
                isVerified: false,
                featuredImageURL: nil
            )
        } else {
            shop = nil
        }
        
        // Create author if not provided
        let postAuthor = author ?? User(
            id: UUID(uuidString: backendPost.authorId) ?? UUID(),
            email: "unknown@example.com",
            username: backendPost.authorDisplayName ?? "user_\(backendPost.authorId.prefix(8))",
            displayName: backendPost.authorDisplayName ?? "Unknown User",
            clerkId: backendPost.authorClerkId
        )
        
        return Post(
            id: UUID(uuidString: backendPost.id) ?? UUID(),
            convexId: backendPost.id, // Preserve original Convex document ID
            userId: UUID(uuidString: backendPost.authorId) ?? UUID(),
            author: postAuthor,
            title: backendPost.foodItem,
            caption: backendPost.description ?? "",
            mediaURLs: mediaURLs,
            shop: shop,
            location: location,
            menuItems: backendPost.tags,
            rating: backendPost.rating,
            createdAt: createdAt,
            updatedAt: updatedAt,
            likesCount: backendPost.likesCount,
            commentsCount: backendPost.commentsCount,
            isLiked: backendPost.isLiked ?? false,
            isSaved: backendPost.isBookmarked ?? false
        )
    }
    
    /// Extract city from address string
    private static func extractCity(from address: String) -> String {
        let components = address.components(separatedBy: ",")
        if components.count >= 2 {
            return components[1].trimmingCharacters(in: .whitespaces)
        }
        return "Unknown"
    }
    
    /// Convert a TRPCPost (from personalized feed) to Post model
    static func from(tRPCPost: BackendService.TRPCPost) -> Post {
        // Parse dates from timestamps
        let createdAt = Date(timeIntervalSince1970: Double(tRPCPost.createdAt) / 1000)
        let updatedAt = Date(timeIntervalSince1970: Double(tRPCPost.updatedAt) / 1000)
        
        // Convert image URLs and ensure no duplicates
        var mediaURLs: [URL] = []
        var seenURLStrings: Set<String> = []
        
        // Add imageUrls first (multiple images) with deduplication
        for urlString in tRPCPost.imageUrls {
            if !seenURLStrings.contains(urlString), let url = URL(string: urlString) {
                seenURLStrings.insert(urlString)
                mediaURLs.append(url)
            }
        }
        
        // Add legacy imageUrl if not already included
        if let imageUrl = tRPCPost.imageUrl,
           !seenURLStrings.contains(imageUrl),
           let url = URL(string: imageUrl) {
            seenURLStrings.insert(imageUrl)
            mediaURLs.append(url)
        }
        
        // Create location from tRPC location data
        let location: Location
        if let locationData = tRPCPost.locationData {
            location = Location(
                latitude: locationData.latitude,
                longitude: locationData.longitude,
                address: locationData.address,
                city: locationData.city ?? extractCity(from: locationData.address),
                state: nil, // TRPCLocation doesn't have state
                country: locationData.country ?? "Unknown"
            )
        } else {
            // Default location if none provided
            location = Location(
                latitude: 0,
                longitude: 0,
                address: "Unknown Location",
                city: "Unknown",
                country: "Unknown"
            )
        }
        
        // Create shop if we have shop information
        let shop: Shop?
        if !tRPCPost.shopName.isEmpty {
            // Create default business hours (open 24/7 as placeholder)
            let defaultHours = BusinessHours(
                monday: BusinessHours.DayHours(open: "00:00", close: "23:59", isClosed: false),
                tuesday: BusinessHours.DayHours(open: "00:00", close: "23:59", isClosed: false),
                wednesday: BusinessHours.DayHours(open: "00:00", close: "23:59", isClosed: false),
                thursday: BusinessHours.DayHours(open: "00:00", close: "23:59", isClosed: false),
                friday: BusinessHours.DayHours(open: "00:00", close: "23:59", isClosed: false),
                saturday: BusinessHours.DayHours(open: "00:00", close: "23:59", isClosed: false),
                sunday: BusinessHours.DayHours(open: "00:00", close: "23:59", isClosed: false)
            )
            
            // Get rating from metadata
            let rating = Double(tRPCPost.metadata["rating"] ?? "0") ?? 0.0
            
            shop = Shop(
                id: UUID(),
                name: tRPCPost.shopName,
                description: nil,
                location: location,
                phoneNumber: nil,
                website: nil,
                hours: defaultHours,
                cuisineTypes: [],
                drinkTypes: [],
                priceRange: .moderate,
                rating: rating,
                reviewsCount: 0,
                photosCount: 0,
                menu: nil,
                ownerId: nil,
                isVerified: false,
                featuredImageURL: nil
            )
        } else {
            shop = nil
        }
        
        // Create author from tRPC author data
        let postAuthor = User(
            id: UUID(),
            email: "unknown@example.com",
            firstName: tRPCPost.author?.firstName,
            lastName: tRPCPost.author?.lastName,
            username: tRPCPost.author?.username ?? "user_\(tRPCPost.userId.prefix(8))",
            displayName: tRPCPost.author?.displayName ?? tRPCPost.author?.username ?? "Unknown User",
            bio: nil,
            avatarURL: tRPCPost.author?.avatarUrl != nil ? URL(string: tRPCPost.author!.avatarUrl!) : nil,
            clerkId: tRPCPost.author?.clerkId ?? tRPCPost.userId
        )
        
        // Get rating from metadata
        let rating = Double(tRPCPost.metadata["rating"] ?? "0") ?? 0.0
        
        return Post(
            id: UUID(),
            convexId: tRPCPost._id, // Preserve original Convex document ID
            userId: UUID(),
            author: postAuthor,
            title: tRPCPost.title,
            caption: tRPCPost.content,
            mediaURLs: mediaURLs,
            shop: shop,
            location: location,
            menuItems: tRPCPost.tags,
            rating: rating > 0 ? rating : nil,
            createdAt: createdAt,
            updatedAt: updatedAt,
            likesCount: tRPCPost.likes,
            commentsCount: tRPCPost.comments,
            isLiked: false, // Will be updated when user interacts
            isSaved: false // Will be updated when user interacts
        )
    }
}

// MARK: - Friends Feed Conversion

extension Post {
    /// Convert a FriendsFeedPost (from friends feed) to Post model
    static func from(friendsFeedPost: BackendService.FriendsFeedPost) -> Post {
        // Parse dates from ISO8601 strings
        let dateFormatter = ISO8601DateFormatter()
        let createdAt = dateFormatter.date(from: friendsFeedPost.createdAt) ?? Date()
        let updatedAt = dateFormatter.date(from: friendsFeedPost.updatedAt) ?? Date()
        
        // Convert image URLs
        var mediaURLs: [URL] = []
        for urlString in friendsFeedPost.imageUrls {
            if let url = URL(string: urlString) {
                mediaURLs.append(url)
            }
        }
        
        // Add legacy imageUrl if not already included
        if let imageUrl = friendsFeedPost.imageUrl,
           !friendsFeedPost.imageUrls.contains(imageUrl),
           let url = URL(string: imageUrl) {
            mediaURLs.insert(url, at: 0)
        }
        
        // Create location from backend location
        let location: Location
        if let backendLocation = friendsFeedPost.location {
            location = Location(
                latitude: backendLocation.latitude,
                longitude: backendLocation.longitude,
                address: backendLocation.address,
                city: extractCity(from: backendLocation.address),
                country: "Unknown"
            )
        } else {
            location = Location(
                latitude: 0,
                longitude: 0,
                address: "Unknown Location",
                city: "Unknown",
                country: "Unknown"
            )
        }
        
        // Create shop if we have shop information
        let shop: Shop?
        if !friendsFeedPost.shopName.isEmpty {
            let defaultHours = BusinessHours(
                monday: BusinessHours.DayHours(open: "00:00", close: "23:59", isClosed: false),
                tuesday: BusinessHours.DayHours(open: "00:00", close: "23:59", isClosed: false),
                wednesday: BusinessHours.DayHours(open: "00:00", close: "23:59", isClosed: false),
                thursday: BusinessHours.DayHours(open: "00:00", close: "23:59", isClosed: false),
                friday: BusinessHours.DayHours(open: "00:00", close: "23:59", isClosed: false),
                saturday: BusinessHours.DayHours(open: "00:00", close: "23:59", isClosed: false),
                sunday: BusinessHours.DayHours(open: "00:00", close: "23:59", isClosed: false)
            )
            
            shop = Shop(
                id: UUID(),
                name: friendsFeedPost.shopName,
                description: nil,
                location: location,
                phoneNumber: nil,
                website: nil,
                hours: defaultHours,
                cuisineTypes: [],
                drinkTypes: [],
                priceRange: .moderate,
                rating: friendsFeedPost.rating ?? 0.0,
                reviewsCount: 0,
                photosCount: 0,
                menu: nil,
                ownerId: nil,
                isVerified: false,
                featuredImageURL: nil
            )
        } else {
            shop = nil
        }
        
        // Create author from friends feed data
        let postAuthor = User(
            id: UUID(uuidString: friendsFeedPost.authorId) ?? UUID(),
            email: "unknown@example.com",
            username: friendsFeedPost.authorUsername ?? "user_\(friendsFeedPost.authorId.prefix(8))",
            displayName: friendsFeedPost.authorDisplayName ?? friendsFeedPost.authorUsername ?? "Unknown User",
            avatarURL: friendsFeedPost.authorAvatarUrl != nil ? URL(string: friendsFeedPost.authorAvatarUrl!) : nil,
            clerkId: friendsFeedPost.authorClerkId
        )
        
        return Post(
            id: UUID(uuidString: friendsFeedPost.id) ?? UUID(),
            convexId: friendsFeedPost.id,
            userId: UUID(uuidString: friendsFeedPost.authorId) ?? UUID(),
            author: postAuthor,
            title: friendsFeedPost.foodItem,
            caption: friendsFeedPost.description ?? "",
            mediaURLs: mediaURLs,
            shop: shop,
            location: location,
            menuItems: friendsFeedPost.tags,
            rating: friendsFeedPost.rating,
            createdAt: createdAt,
            updatedAt: updatedAt,
            likesCount: friendsFeedPost.likesCount,
            commentsCount: friendsFeedPost.commentsCount,
            isLiked: friendsFeedPost.isLiked,
            isSaved: friendsFeedPost.isBookmarked
        )
    }
}

// MARK: - Gathering Link Types

enum GatheringLinkType: String, Codable, CaseIterable {
    case beforeGathering = "before_gathering"
    case duringGathering = "during_gathering"
    case afterGathering = "after_gathering"
    case venueReview = "venue_review"
    case invitation = "invitation"
    case memory = "memory"
    
    var displayName: String {
        switch self {
        case .beforeGathering: return "Getting Ready"
        case .duringGathering: return "Live Updates"
        case .afterGathering: return "Memories"
        case .venueReview: return "Venue Review"
        case .invitation: return "Invitation"
        case .memory: return "Memory"
        }
    }
    
    var icon: String {
        switch self {
        case .beforeGathering: return "clock.arrow.circlepath"
        case .duringGathering: return "dot.radiowaves.left.and.right"
        case .afterGathering: return "heart.fill"
        case .venueReview: return "star.fill"
        case .invitation: return "paperplane.fill"
        case .memory: return "photo.fill"
        }
    }
    
    var color: String {
        switch self {
        case .beforeGathering: return "blue"
        case .duringGathering: return "green"
        case .afterGathering: return "purple"
        case .venueReview: return "orange"
        case .invitation: return "red"
        case .memory: return "pink"
        }
    }
}