//
//  TRPCTypes.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  Type-safe tRPC types matching the backend API.
//

import Foundation

// MARK: - tRPC Procedure Types

/// Marker protocol for tRPC queries (GET requests)
protocol TRPCQuery {}

/// Marker protocol for tRPC mutations (POST requests)
protocol TRPCMutation {}

// MARK: - tRPC Response Wrapper

/// Generic tRPC response wrapper
struct TRPCResponseWrapper<T: Decodable>: Decodable {
    let result: TRPCResultWrapper<T>?
    let error: TRPCErrorWrapper?
    
    struct TRPCResultWrapper<Data: Decodable>: Decodable {
        let data: Data?
    }
    
    struct TRPCErrorWrapper: Decodable {
        let message: String
        let code: Int?
        let data: TRPCErrorData?
        
        struct TRPCErrorData: Decodable {
            let code: String?
            let httpStatus: Int?
        }
    }
}

// MARK: - Common Response Types

/// Paginated response with cursor
struct PaginatedResponse<T: Decodable>: Decodable {
    let items: [T]
    let nextCursor: String?
}

/// Simple success response
struct SuccessResponse: Decodable {
    let success: Bool
    let count: Int?
    let message: String?
}

// MARK: - Notification Types

/// Notification type enum matching backend
enum NotificationType: String, Codable, CaseIterable {
    case postLike = "POST_LIKE"
    case comment = "COMMENT"
    case commentLike = "COMMENT_LIKE"
    case follow = "FOLLOW"
    case friendRequest = "FRIEND_REQUEST"
    case friendAccepted = "FRIEND_ACCEPTED"
    case friendPost = "FRIEND_POST"
    case message = "MESSAGE"
    case postMention = "POST_MENTION"
    case general = "GENERAL"
}

/// Message type enum matching backend
enum TRPCMessageType: String, Codable, CaseIterable {
    case text = "TEXT"
    case image = "IMAGE"
    case video = "VIDEO"
    case audio = "AUDIO"
    case file = "FILE"
    case postShare = "POST_SHARE"
    case placeShare = "PLACE_SHARE"
    case linkShare = "LINK_SHARE"
}

/// Chatroom type enum matching backend
enum TRPCChatroomType: String, Codable {
    case direct = "DIRECT"
    case group = "GROUP"
}

/// Friend status enum matching backend
enum TRPCFriendStatus: String, Codable {
    case pending = "PENDING"
    case accepted = "ACCEPTED"
    case blocked = "BLOCKED"
}

/// Friend request filter type
enum FriendRequestFilterType: String, Codable {
    case sent
    case received
    case all
}

// MARK: - User Types

/// Backend user response
struct TRPCUser: Decodable {
    let id: String
    let clerkId: String
    let username: String?
    let name: String?
    let email: String?
    let bio: String?
    let profileImage: String?
    let website: String?
    let followerCount: Int?
    let followingCount: Int?
    let postsCount: Int?
    let createdAt: String?
    let updatedAt: String?
}

/// Minimal user info for includes
struct TRPCUserInfo: Decodable {
    let id: String
    let clerkId: String
    let username: String?
    let name: String?
    let profileImage: String?
    let bio: String?
}

// MARK: - Post Types

/// Backend post response
struct TRPCPost: Decodable {
    let id: String
    let userId: String
    let title: String?
    let caption: String?
    let mediaUrls: [String]?
    let rating: Double?
    let menuItems: [String]?
    let createdAt: String?
    let updatedAt: String?
    let locationName: String?
    let locationAddress: String?
    let locationCity: String?
    let locationState: String?
    let locationCountry: String?
    let locationPostalCode: String?
    let locationLatitude: Double?
    let locationLongitude: Double?
    let likesCount: Int?
    let commentsCount: Int?
    let savesCount: Int?
    let viewsCount: Int?
    let isPublic: Bool?
    let isDeleted: Bool?
    let author: TRPCUserInfo?
}

// MARK: - Friend Types

/// Backend friend response
struct TRPCFriend: Decodable {
    let id: String
    let senderId: String
    let receiverId: String
    let status: TRPCFriendStatus
    let createdAt: String
    let updatedAt: String
    let sender: TRPCUserInfo?
    let receiver: TRPCUserInfo?
}

/// Friend user with friendship info
struct TRPCFriendUser: Decodable {
    let id: String
    let clerkId: String
    let username: String?
    let name: String?
    let profileImage: String?
    let bio: String?
    let friendshipId: String?
    let friendsSince: String?
}

/// Friend suggestion
struct TRPCFriendSuggestion: Decodable {
    let id: String
    let clerkId: String
    let username: String?
    let name: String?
    let profileImage: String?
    let bio: String?
    let followerCount: Int?
    let mutualFriendsCount: Int
    let connectionReason: String
}

// MARK: - Follow Types

/// Backend follow response
struct TRPCFollow: Decodable {
    let id: String
    let followerId: String
    let followingId: String
    let createdAt: String
    let follower: TRPCUserInfo?
    let following: TRPCUserInfo?
}

/// Following user with follow info
struct TRPCFollowUser: Decodable {
    let id: String
    let clerkId: String
    let username: String?
    let name: String?
    let profileImage: String?
    let bio: String?
    let followerCount: Int?
    let followingCount: Int?
    let postsCount: Int?
    let followedAt: String?
}

/// Follow stats
struct TRPCFollowStats: Decodable {
    let followerCount: Int
    let followingCount: Int
    let postsCount: Int
}

// MARK: - Comment Types

/// Backend comment response
struct TRPCComment: Decodable {
    let id: String
    let postId: String
    let authorId: String
    let content: String
    let createdAt: String
    let updatedAt: String
    let author: TRPCUserInfo?
    let post: TRPCPostPreview?
}

/// Post preview for comment responses
struct TRPCPostPreview: Decodable {
    let id: String
    let caption: String?
    let mediaUrls: [String]?
}

// MARK: - Message Types

/// Backend chatroom response
struct TRPCChatroom: Decodable {
    let id: String
    let type: TRPCChatroomType
    let name: String?
    let description: String?
    let imageUrl: String?
    let lastMessageAt: String?
    let createdAt: String
    let updatedAt: String
    let participants: [TRPCChatroomParticipant]?
    let messages: [TRPCMessage]?
    let lastMessage: TRPCMessage?
    let unreadCount: Int?
    let otherParticipants: [TRPCUserInfo]?
    
    private enum CodingKeys: String, CodingKey {
        case id, type, name, description, imageUrl, lastMessageAt, createdAt, updatedAt
        case participants, messages, lastMessage, unreadCount, otherParticipants
        case _count
    }
    
    struct CountWrapper: Decodable {
        let messages: Int?
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(TRPCChatroomType.self, forKey: .type)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        lastMessageAt = try container.decodeIfPresent(String.self, forKey: .lastMessageAt)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        participants = try container.decodeIfPresent([TRPCChatroomParticipant].self, forKey: .participants)
        messages = try container.decodeIfPresent([TRPCMessage].self, forKey: .messages)
        lastMessage = try container.decodeIfPresent(TRPCMessage.self, forKey: .lastMessage)
        otherParticipants = try container.decodeIfPresent([TRPCUserInfo].self, forKey: .otherParticipants)
        
        if let countWrapper = try? container.decodeIfPresent(CountWrapper.self, forKey: ._count) {
            unreadCount = countWrapper?.messages
        } else {
            unreadCount = try container.decodeIfPresent(Int.self, forKey: .unreadCount)
        }
    }
}

/// Backend chatroom participant
struct TRPCChatroomParticipant: Decodable {
    let id: String
    let chatroomId: String
    let userId: String
    let isAdmin: Bool
    let joinedAt: String
    let leftAt: String?
    let lastReadAt: String?
    let user: TRPCUserInfo?
}

/// Backend message response
struct TRPCMessage: Decodable {
    let id: String
    let chatroomId: String
    let senderId: String
    let content: String
    let messageType: TRPCMessageType
    let mediaUrl: String?
    let metadata: TRPCMessageMetadata?
    let readAt: String?
    let createdAt: String
    let updatedAt: String
    let sender: TRPCUserInfo?
}

/// Message metadata for link previews etc
struct TRPCMessageMetadata: Decodable {
    let sharedContentId: String?
    let linkPreview: TRPCLinkPreview?
}

/// Link preview data
struct TRPCLinkPreview: Decodable {
    let title: String
    let description: String?
    let imageUrl: String?
    let url: String
}

// MARK: - Notification Types

/// Backend notification response
struct TRPCNotification: Decodable {
    let _id: String
    let recipientId: String
    let senderId: String?
    let type: NotificationType
    let title: String
    let message: String
    let metadata: TRPCNotificationMetadata?
    let isRead: Bool
    let createdAt: Int // Unix timestamp in milliseconds
    let updatedAt: Int
    let sender: TRPCNotificationSender?
}

/// Notification metadata
struct TRPCNotificationMetadata: Decodable {
    let postId: String?
    let commentId: String?
    let friendRequestId: String?
    let userId: String?
}

/// Notification sender info
struct TRPCNotificationSender: Decodable {
    let _id: String
    let clerkId: String
    let name: String?
    let username: String?
    let email: String?
    let bio: String?
    let profileImage: String?
    let followersCount: Int?
    let followingCount: Int?
    let postsCount: Int?
    let isVerified: Bool?
    let isActive: Bool?
    let createdAt: Int?
    let updatedAt: Int?
}

// MARK: - List Types

/// Backend list response
struct TRPCList: Decodable {
    let id: String
    let userId: String
    let name: String
    let description: String?
    let isPublic: Bool
    let coverImageUrl: String?
    let placeCount: Int?
    let createdAt: String
    let updatedAt: String
    let items: [TRPCListItem]?
}

/// Backend list item response
struct TRPCListItem: Decodable {
    let id: String
    let listId: String
    let placeId: String
    let notes: String?
    let addedAt: String
    let place: TRPCPlace?
}

// MARK: - Place Types

/// Backend place response
struct TRPCPlace: Decodable {
    let id: String
    let googlePlaceId: String?
    let name: String
    let address: String?
    let city: String?
    let state: String?
    let country: String?
    let postalCode: String?
    let latitude: Double?
    let longitude: Double?
    let phoneNumber: String?
    let website: String?
    let priceLevel: Int?
    let rating: Double?
    let userRatingsTotal: Int?
    let types: [String]?
    let photoReferences: [String]?
    let createdAt: String?
    let updatedAt: String?
}

// MARK: - Notification Settings

/// Notification settings response
struct TRPCNotificationSettings: Decodable {
    let emailNotifications: Bool
    let pushNotifications: Bool
    let likes: Bool
    let comments: Bool
    let follows: Bool
    let friendRequests: Bool
    let messages: Bool
}

