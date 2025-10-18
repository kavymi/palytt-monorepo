//
//  CommentDTO.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation

// MARK: - Comment DTOs

struct CommentDTO: Codable {
    let id: String
    let postId: String
    let authorId: String
    let authorClerkId: String
    let content: String
    let parentCommentId: String?
    let likesCount: Int
    let repliesCount: Int
    let createdAt: String
    let updatedAt: String
    let isLiked: Bool?
    
    // Denormalized author info
    let authorUsername: String?
    let authorDisplayName: String?
    let authorProfileImageUrl: String?
}

// MARK: - Request DTOs

struct GetCommentsRequest: Codable {
    let postId: String
    let page: Int?
    let limit: Int?
    let parentCommentId: String? // For getting replies to a specific comment
}

struct AddCommentRequest: Codable {
    let postId: String
    let content: String
    let parentCommentId: String? // For replies
}

struct ToggleCommentLikeRequest: Codable {
    let commentId: String
}

struct GetRecentCommentsRequest: Codable {
    let postId: String
    let limit: Int?
}

// MARK: - Response DTOs

struct GetCommentsResponse: Codable {
    let comments: [CommentDTO]
    let total: Int
    let hasMore: Bool
    let nextCursor: String?
}

struct AddCommentResponse: Codable {
    let success: Bool
    let comment: CommentDTO
}

struct ToggleCommentLikeResponse: Codable {
    let success: Bool
    let isLiked: Bool
    let likesCount: Int
}

// MARK: - Domain Model Conversion

extension Comment {
    /// Convert backend CommentDTO to domain Comment model
    static func from(commentDTO: CommentDTO) -> Comment {
        // Create author user if we have author info
        let author: User? = {
            guard let username = commentDTO.authorUsername else { return nil }
            return User(
                id: UUID(uuidString: commentDTO.authorId) ?? UUID(),
                convexId: commentDTO.authorId,
                clerkId: commentDTO.authorClerkId,
                username: username,
                displayName: commentDTO.authorDisplayName ?? username,
                email: nil,
                phoneNumber: nil,
                bio: nil,
                profileImageUrl: commentDTO.authorProfileImageUrl.flatMap { URL(string: $0) }
            )
        }()
        
        return Comment(
            id: UUID(uuidString: commentDTO.id) ?? UUID(),
            convexId: commentDTO.id,
            postId: UUID(uuidString: commentDTO.postId) ?? UUID(),
            userId: UUID(uuidString: commentDTO.authorId) ?? UUID(),
            author: author,
            content: commentDTO.content,
            parentCommentId: commentDTO.parentCommentId.flatMap { UUID(uuidString: $0) },
            likesCount: commentDTO.likesCount,
            repliesCount: commentDTO.repliesCount,
            isLiked: commentDTO.isLiked ?? false,
            createdAt: ISO8601DateFormatter().date(from: commentDTO.createdAt) ?? Date(),
            updatedAt: ISO8601DateFormatter().date(from: commentDTO.updatedAt) ?? Date()
        )
    }
}

