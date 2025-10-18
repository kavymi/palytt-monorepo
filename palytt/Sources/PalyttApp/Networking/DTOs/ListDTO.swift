//
//  ListDTO.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation

// MARK: - List DTOs

struct ListDTO: Codable {
    let id: String
    let userId: String
    let name: String
    let description: String?
    let isPrivate: Bool
    let postsCount: Int
    let createdAt: String
    let updatedAt: String
    
    // Optional: Include posts if requested
    let posts: [PostResponseDTO]?
}

// MARK: - Request DTOs

struct CreateListRequest: Codable {
    let name: String
    let description: String?
    let isPrivate: Bool
}

struct GetUserListsRequest: Codable {
    let userId: String
}

struct UpdateListRequest: Codable {
    let listId: String
    let name: String?
    let description: String?
    let isPrivate: Bool?
}

struct DeleteListRequest: Codable {
    let listId: String
}

struct AddPostToListRequest: Codable {
    let listId: String
    let postId: String
}

struct RemovePostFromListRequest: Codable {
    let listId: String
    let postId: String
}

// MARK: - Response DTOs

struct CreateListResponse: Codable {
    let success: Bool
    let list: ListDTO
}

struct GetUserListsResponse: Codable {
    let lists: [ListDTO]
    let total: Int
}

struct UpdateListResponse: Codable {
    let success: Bool
    let list: ListDTO
}

struct DeleteListResponse: Codable {
    let success: Bool
    let message: String?
}

struct AddPostToListResponse: Codable {
    let success: Bool
    let message: String?
}

struct RemovePostFromListResponse: Codable {
    let success: Bool
    let message: String?
}

// MARK: - Domain Model Conversion

extension PostList {
    /// Convert backend ListDTO to domain PostList model
    static func from(listDTO: ListDTO) -> PostList {
        return PostList(
            id: UUID(uuidString: listDTO.id) ?? UUID(),
            convexId: listDTO.id,
            userId: UUID(uuidString: listDTO.userId) ?? UUID(),
            name: listDTO.name,
            description: listDTO.description,
            isPrivate: listDTO.isPrivate,
            postsCount: listDTO.postsCount,
            posts: listDTO.posts?.map { Post.from(postResponseDTO: $0) } ?? [],
            createdAt: ISO8601DateFormatter().date(from: listDTO.createdAt) ?? Date(),
            updatedAt: ISO8601DateFormatter().date(from: listDTO.updatedAt) ?? Date()
        )
    }
}

// Domain model (if PostList doesn't exist yet)
struct PostList: Identifiable {
    let id: UUID
    let convexId: String?
    let userId: UUID
    let name: String
    let description: String?
    let isPrivate: Bool
    let postsCount: Int
    let posts: [Post]
    let createdAt: Date
    let updatedAt: Date
}

