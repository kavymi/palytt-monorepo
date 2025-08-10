//
//  List.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation

struct SavedList: Identifiable, Codable, Equatable {
    let id: String
    var convexId: String?
    var name: String
    let description: String?
    let coverImageURL: URL?
    let userId: String
    var postIds: [String]
    var isPrivate: Bool
    let createdAt: Date
    var updatedAt: Date
    
    init(
        id: String = UUID().uuidString,
        convexId: String? = nil,
        name: String,
        description: String? = nil,
        coverImageURL: URL? = nil,
        userId: String,
        postIds: [String] = [],
        isPrivate: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.convexId = convexId
        self.name = name
        self.description = description
        self.coverImageURL = coverImageURL
        self.userId = userId
        self.postIds = postIds
        self.isPrivate = isPrivate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var postCount: Int {
        postIds.count
    }
} 