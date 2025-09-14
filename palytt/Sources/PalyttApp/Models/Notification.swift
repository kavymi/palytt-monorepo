//
//  Notification.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation

// MARK: - Notification Types
enum NotificationType: String, CaseIterable, Codable {
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
    
    var displayName: String {
        switch self {
        case .postLike: return "Post Like"
        case .comment: return "Comment"
        case .commentLike: return "Comment Like"
        case .follow: return "Follow"
        case .friendRequest: return "Friend Request"
        case .friendAccepted: return "Friend Accepted"
        case .friendPost: return "Friend Post"
        case .message: return "Message"
        case .postMention: return "Post Mention"
        case .general: return "General"
        }
    }
    
    var iconName: String {
        switch self {
        case .postLike: return "heart.fill"
        case .comment: return "bubble.left.fill"
        case .commentLike: return "heart.fill"
        case .follow: return "person.badge.plus.fill"
        case .friendRequest: return "person.2.fill"
        case .friendAccepted: return "checkmark.circle.fill"
        case .friendPost: return "photo.fill"
        case .message: return "message.fill"
        case .postMention: return "at.circle.fill"
        case .general: return "bell.fill"
        }
    }
    
    var iconColor: String {
        switch self {
        case .postLike, .commentLike: return "red"
        case .comment: return "blue"
        case .follow, .friendRequest, .friendAccepted: return "green"
        case .friendPost: return "purple"
        case .message: return "blue"
        case .postMention: return "orange"
        case .general: return "gray"
        }
    }
}

// MARK: - Notification Data
struct NotificationData: Codable, Equatable {
    let postId: String?
    let commentId: String?
    let friendRequestId: String?
    let senderId: String?
    let senderName: String?
    let senderUsername: String?
    let senderAvatar: String?
    let postTitle: String?
    let postImage: String?
    
    // Additional custom data
    private let additionalData: [String: AnyCodable]?
    
    init(
        postId: String? = nil,
        commentId: String? = nil,
        friendRequestId: String? = nil,
        senderId: String? = nil,
        senderName: String? = nil,
        senderUsername: String? = nil,
        senderAvatar: String? = nil,
        postTitle: String? = nil,
        postImage: String? = nil,
        additionalData: [String: Any]? = nil
    ) {
        self.postId = postId
        self.commentId = commentId
        self.friendRequestId = friendRequestId
        self.senderId = senderId
        self.senderName = senderName
        self.senderUsername = senderUsername
        self.senderAvatar = senderAvatar
        self.postTitle = postTitle
        self.postImage = postImage
        self.additionalData = additionalData?.mapValues { AnyCodable($0) }
    }
    
    // Helper to get additional data
    func getValue<T>(for key: String, as type: T.Type) -> T? {
        return additionalData?[key]?.value as? T
    }
}

// MARK: - Notification Model
struct PalyttNotification: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let type: NotificationType
    let title: String
    let message: String
    let data: NotificationData?
    let isRead: Bool
    let createdAt: Date
    
    // Computed properties for UI
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    var actionText: String {
        switch type {
        case .postLike:
            return "liked your post"
        case .comment:
            return "commented on your post"
        case .commentLike:
            return "liked your comment"
        case .follow:
            return "started following you"
        case .friendRequest:
            return "sent you a friend request"
        case .friendAccepted:
            return "accepted your friend request"
        case .friendPost:
            return "shared a new post"
        case .message:
            return "sent you a message"
        case .postMention:
            return "mentioned you in a post"
        case .general:
            return message
        }
    }
    
    var senderName: String {
        return data?.senderName ?? "Someone"
    }
    
    var senderUsername: String? {
        return data?.senderUsername
    }
    
    var senderAvatarURL: URL? {
        guard let avatarString = data?.senderAvatar else { return nil }
        return URL(string: avatarString)
    }
    
    var postImageURL: URL? {
        guard let imageString = data?.postImage else { return nil }
        return URL(string: imageString)
    }
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        type: NotificationType,
        title: String,
        message: String,
        data: NotificationData? = nil,
        isRead: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.title = title
        self.message = message
        self.data = data
        self.isRead = isRead
        self.createdAt = createdAt
    }
}

// MARK: - Backend Response Types
struct BackendNotification: Codable {
    let id: String
    let userId: String
    let type: String
    let title: String
    let message: String
    let data: [String: AnyCodable]?
    let read: Bool
    let createdAt: String // ISO date string
    let user: BackendNotificationUser?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId
        case type
        case title
        case message
        case data
        case read
        case createdAt
        case user
    }
}

struct BackendNotificationUser: Codable {
    let id: String
    let clerkId: String
    let name: String?
    let username: String?
    let profileImage: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case clerkId
        case name
        case username
        case profileImage
    }
}

struct NotificationsResponse: Codable {
    let notifications: [BackendNotification]
    let nextCursor: String?
}

struct NotificationCountResponse: Codable {
    let count: Int
}

struct MarkAsReadResponse: Codable {
    let success: Bool
    let count: Int
}

// MARK: - Backend Conversion
extension BackendNotification {
    func toPalyttNotification() -> PalyttNotification? {
        guard let notificationType = NotificationType(rawValue: type) else {
            print("⚠️ Unknown notification type: \(type)")
            return nil
        }
        
        // Parse the date
        let dateFormatter = ISO8601DateFormatter()
        let date = dateFormatter.date(from: createdAt) ?? Date()
        
        // Convert data dictionary to NotificationData
        var notificationData: NotificationData?
        if let dataDict = data {
            let postId = dataDict["postId"]?.value as? String
            let commentId = dataDict["commentId"]?.value as? String
            let friendRequestId = dataDict["friendRequestId"]?.value as? String
            let senderId = dataDict["senderId"]?.value as? String ?? user?.clerkId
            let senderName = dataDict["senderName"]?.value as? String ?? user?.name
            let senderUsername = dataDict["senderUsername"]?.value as? String ?? user?.username
            let senderAvatar = dataDict["senderAvatar"]?.value as? String ?? user?.profileImage
            let postTitle = dataDict["postTitle"]?.value as? String
            let postImage = dataDict["postImage"]?.value as? String
            
            // Convert AnyCodable back to regular types for additional data
            let additionalData = dataDict.compactMapValues { $0.value }
            
            notificationData = NotificationData(
                postId: postId,
                commentId: commentId,
                friendRequestId: friendRequestId,
                senderId: senderId,
                senderName: senderName,
                senderUsername: senderUsername,
                senderAvatar: senderAvatar,
                postTitle: postTitle,
                postImage: postImage,
                additionalData: additionalData
            )
        }
        
        return PalyttNotification(
            id: id,
            userId: userId,
            type: notificationType,
            title: title,
            message: message,
            data: notificationData,
            isRead: read,
            createdAt: date
        )
    }
}

// MARK: - Helper for Any Codable
struct AnyCodable: Codable, Equatable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // Simple comparison based on string representation
        return String(describing: lhs.value) == String(describing: rhs.value)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}
