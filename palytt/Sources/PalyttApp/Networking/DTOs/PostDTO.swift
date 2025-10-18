//
//  PostDTO.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation

// MARK: - Location DTO

struct LocationDTO: Codable {
    let latitude: Double
    let longitude: Double
    let address: String
    let name: String?
}

// MARK: - Post Response DTO

struct PostDTO: Codable {
    let id: String
    let authorId: String
    let authorClerkId: String
    let shopId: String?
    let shopName: String
    let foodItem: String
    let description: String?
    let rating: Double?
    let imageUrl: String?
    let imageUrls: [String]
    let tags: [String]
    let location: LocationDTO?
    let isPublic: Bool
    let likesCount: Int
    let commentsCount: Int
    let createdAt: String
    let updatedAt: String
    let isLiked: Bool?
    let isBookmarked: Bool?
    
    // Author information (if included)
    let authorDisplayName: String?
    let authorUsername: String?
    let authorAvatarUrl: String?
}

// MARK: - Create Post Request DTO

struct CreatePostRequest: Codable {
    let shopName: String
    let foodItem: String
    let description: String?
    let rating: Double
    let imageUrl: String?
    let imageUrls: [String]
    let tags: [String]
    let location: LocationDTO?
    let isPublic: Bool
}

// MARK: - Get Posts Request DTO

struct GetPostsRequest: Codable {
    let page: Int
    let limit: Int
}

// MARK: - Get Posts Response DTO

struct GetPostsResponse: Codable {
    let posts: [PostDTO]
    let total: Int?
    let page: Int?
    let hasMore: Bool?
}

// MARK: - Like/Bookmark Response DTO

struct LikeResponse: Codable {
    let success: Bool
    let isLiked: Bool
    let likesCount: Int
}

struct BookmarkResponse: Codable {
    let success: Bool
    let isBookmarked: Bool
}

// MARK: - Post Likes Response DTO

struct PostLikesDTO: Codable {
    let users: [UserDTO]
    let total: Int
    let hasMore: Bool
}

// MARK: - User DTO (simplified for post responses)

struct UserDTO: Codable {
    let id: String
    let clerkId: String
    let username: String?
    let name: String?
    let displayName: String?
    let profileImage: String?
    let bio: String?
}

// MARK: - Conversion Extensions

extension PostDTO {
    /// Convert PostDTO to Post model
    func toPost() -> Post {
        // Parse dates
        let dateFormatter = ISO8601DateFormatter()
        let createdAt = dateFormatter.date(from: self.createdAt) ?? Date()
        let updatedAt = dateFormatter.date(from: self.updatedAt) ?? Date()
        
        // Convert image URLs and ensure no duplicates
        var mediaURLs: [URL] = []
        var seenURLStrings: Set<String> = []
        
        // Add imageUrls first with deduplication
        for urlString in self.imageUrls {
            if !seenURLStrings.contains(urlString), let url = URL(string: urlString) {
                seenURLStrings.insert(urlString)
                mediaURLs.append(url)
            }
        }
        
        // Add legacy imageUrl if not already included
        if let imageUrl = self.imageUrl,
           !seenURLStrings.contains(imageUrl),
           let url = URL(string: imageUrl) {
            seenURLStrings.insert(imageUrl)
            mediaURLs.append(url)
        }
        
        // Create location
        let location: Location
        if let locationData = self.location {
            location = Location(
                latitude: locationData.latitude,
                longitude: locationData.longitude,
                address: locationData.address,
                city: extractCity(from: locationData.address),
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
        if !self.shopName.isEmpty {
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
                name: self.shopName,
                description: nil,
                location: location,
                phoneNumber: nil,
                website: nil,
                hours: defaultHours,
                cuisineTypes: [],
                drinkTypes: [],
                priceRange: .moderate,
                rating: self.rating ?? 0.0,
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
        
        // Create author
        let author = User(
            id: UUID(uuidString: self.authorId) ?? UUID(),
            email: "unknown@example.com",
            username: self.authorUsername ?? "user_\(self.authorId.prefix(8))",
            displayName: self.authorDisplayName,
            avatarURL: self.authorAvatarUrl != nil ? URL(string: self.authorAvatarUrl!) : nil,
            clerkId: self.authorClerkId
        )
        
        return Post(
            id: UUID(uuidString: self.id) ?? UUID(),
            convexId: self.id,
            userId: UUID(uuidString: self.authorId) ?? UUID(),
            author: author,
            title: self.shopName,
            caption: self.description ?? self.foodItem,
            mediaURLs: mediaURLs,
            shop: shop,
            location: location,
            menuItems: [self.foodItem],
            rating: self.rating,
            createdAt: createdAt,
            updatedAt: updatedAt,
            likesCount: self.likesCount,
            commentsCount: self.commentsCount,
            isLiked: self.isLiked ?? false,
            isSaved: self.isBookmarked ?? false
        )
    }
    
    /// Extract city from address string
    private func extractCity(from address: String) -> String {
        let components = address.components(separatedBy: ",")
        if components.count >= 2 {
            return components[1].trimmingCharacters(in: .whitespaces)
        }
        return "Unknown"
    }
}

extension CreatePostRequest {
    /// Create request from Post model
    static func from(post: Post) -> CreatePostRequest {
        return CreatePostRequest(
            shopName: post.shop?.name ?? post.title ?? "",
            foodItem: post.menuItems.first ?? "",
            description: post.caption,
            rating: post.rating ?? 5.0,
            imageUrl: post.mediaURLs.first?.absoluteString,
            imageUrls: post.mediaURLs.map { $0.absoluteString },
            tags: post.menuItems,
            location: LocationDTO(
                latitude: post.location.latitude,
                longitude: post.location.longitude,
                address: post.location.address,
                name: post.shop?.name
            ),
            isPublic: true
        )
    }
}

