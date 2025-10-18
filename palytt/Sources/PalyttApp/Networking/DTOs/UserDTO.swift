//
//  UserDTO.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation

// MARK: - User DTOs

/// Response DTO representing a user from the backend
struct UserDTO: Codable {
    let id: String
    let clerkId: String
    let username: String?
    let displayName: String?
    let email: String?
    let phoneNumber: String?
    let bio: String?
    let profileImageUrl: String?
    let isPrivate: Bool?
    let isVerified: Bool?
    let followersCount: Int?
    let followingCount: Int?
    let postsCount: Int?
    let friendsCount: Int?
    let createdAt: String?
    let updatedAt: String?
    
    // Social media links
    let instagramHandle: String?
    let twitterHandle: String?
    let tikTokHandle: String?
    
    // Additional profile info
    let location: String?
    let website: String?
    let dateOfBirth: String?
    
    // Apple/Google auth
    let appleId: String?
    let googleId: String?
}

// MARK: - Request DTOs

struct UpdateUserRequest: Codable {
    let username: String?
    let displayName: String?
    let bio: String?
    let profileImageUrl: String?
    let isPrivate: Bool?
    let phoneNumber: String?
    let location: String?
    let website: String?
    let dateOfBirth: String?
    let instagramHandle: String?
    let twitterHandle: String?
    let tikTokHandle: String?
}

struct UpsertUserRequest: Codable {
    let clerkId: String
    let username: String?
    let displayName: String?
    let email: String?
    let phoneNumber: String?
    let profileImageUrl: String?
    let appleId: String?
    let googleId: String?
}

struct CheckAvailabilityRequest: Codable {
    let value: String
}

struct SearchUsersRequest: Codable {
    let query: String
    let limit: Int?
    let offset: Int?
}

// MARK: - Response DTOs

struct UpdateUserResponse: Codable {
    let success: Bool
    let user: UserDTO
}

struct UpsertUserResponse: Codable {
    let success: Bool
    let user: UserDTO
    let isNewUser: Bool?
}

struct CheckAvailabilityResponse: Codable {
    let available: Bool
    let message: String?
}

struct SearchUsersResponse: Codable {
    let users: [UserDTO]
    let total: Int
    let hasMore: Bool
}

struct SuggestedUsersResponse: Codable {
    let users: [UserDTO]
    let reasons: [String: String]? // userId -> reason
}

// MARK: - Domain Model Conversion

extension User {
    /// Convert backend UserDTO to domain User model
    static func from(userDTO: UserDTO) -> User {
        return User(
            id: UUID(uuidString: userDTO.id) ?? UUID(),
            convexId: userDTO.id,
            clerkId: userDTO.clerkId,
            username: userDTO.username ?? "user_\(userDTO.clerkId.prefix(8))",
            displayName: userDTO.displayName ?? userDTO.username ?? "Unknown User",
            email: userDTO.email,
            phoneNumber: userDTO.phoneNumber,
            bio: userDTO.bio,
            profileImageUrl: userDTO.profileImageUrl.flatMap { URL(string: $0) },
            isPrivate: userDTO.isPrivate ?? false,
            isVerified: userDTO.isVerified ?? false,
            followersCount: userDTO.followersCount ?? 0,
            followingCount: userDTO.followingCount ?? 0,
            postsCount: userDTO.postsCount ?? 0,
            friendsCount: userDTO.friendsCount ?? 0,
            instagramHandle: userDTO.instagramHandle,
            twitterHandle: userDTO.twitterHandle,
            tikTokHandle: userDTO.tikTokHandle,
            location: userDTO.location,
            website: userDTO.website.flatMap { URL(string: $0) },
            dateOfBirth: userDTO.dateOfBirth.flatMap { ISO8601DateFormatter().date(from: $0) },
            createdAt: userDTO.createdAt.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date(),
            updatedAt: userDTO.updatedAt.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
        )
    }
    
    /// Convert domain User model to UserDTO (for requests that need full user)
    func toDTO() -> UserDTO {
        return UserDTO(
            id: self.convexId ?? self.id.uuidString,
            clerkId: self.clerkId ?? "",
            username: self.username,
            displayName: self.displayName,
            email: self.email,
            phoneNumber: self.phoneNumber,
            bio: self.bio,
            profileImageUrl: self.profileImageUrl?.absoluteString,
            isPrivate: self.isPrivate,
            isVerified: self.isVerified,
            followersCount: self.followersCount,
            followingCount: self.followingCount,
            postsCount: self.postsCount,
            friendsCount: self.friendsCount,
            createdAt: ISO8601DateFormatter().string(from: self.createdAt),
            updatedAt: ISO8601DateFormatter().string(from: self.updatedAt),
            instagramHandle: self.instagramHandle,
            twitterHandle: self.twitterHandle,
            tikTokHandle: self.tikTokHandle,
            location: self.location,
            website: self.website?.absoluteString,
            dateOfBirth: self.dateOfBirth.map { ISO8601DateFormatter().string(from: $0) },
            appleId: nil,
            googleId: nil
        )
    }
}

