//
//  NotificationDTO.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation

// MARK: - Notification DTOs (Legacy - kept for compatibility)

struct NotificationDTO: Codable {
    let id: String
    let userId: String
    let type: String // "like", "comment", "follow", "friend_request", "mention", etc.
    let title: String
    let message: String
    let isRead: Bool
    let createdAt: String
    
    // Related entities
    let actorId: String?
    let actorUsername: String?
    let actorDisplayName: String?
    let actorProfileImageUrl: String?
    
    let postId: String?
    let commentId: String?
    let friendRequestId: String?
    
    // Additional metadata
    let metadata: [String: String]?
}

// MARK: - tRPC Request DTOs

/// Request input for getNotifications
struct TRPCGetNotificationsInput: Codable {
    let limit: Int?
    let cursor: String?
    let type: String?
    let types: [String]?
    let unreadOnly: Bool?
    
    init(limit: Int = 20, cursor: String? = nil, type: NotificationType? = nil, types: [NotificationType]? = nil, unreadOnly: Bool = false) {
        self.limit = limit
        self.cursor = cursor
        self.type = type?.rawValue
        self.types = types?.map { $0.rawValue }
        self.unreadOnly = unreadOnly
    }
}

/// Request input for markAsRead
struct TRPCMarkNotificationsAsReadInput: Codable {
    let notificationIds: [String]?
    
    init(notificationIds: [String]? = nil) {
        self.notificationIds = notificationIds
    }
}

/// Request input for deleteNotifications
struct TRPCDeleteNotificationsInput: Codable {
    let notificationIds: [String]
}

// MARK: - Legacy Request DTOs (kept for compatibility)

struct GetNotificationsRequest: Codable {
    let userId: String
    let limit: Int?
    let onlyUnread: Bool?
}

struct GetUnreadCountRequest: Codable {
    let userId: String
}

struct MarkNotificationAsReadRequest: Codable {
    let notificationId: String
}

struct MarkAllAsReadRequest: Codable {
    let userId: String
}

struct DeleteNotificationRequest: Codable {
    let notificationId: String
}

struct DeleteAllNotificationsRequest: Codable {
    let userId: String
}

struct CreateNotificationRequest: Codable {
    let userId: String
    let type: String
    let title: String
    let message: String
    let actorId: String?
    let postId: String?
    let commentId: String?
    let friendRequestId: String?
    let metadata: [String: String]?
}

// MARK: - Response DTOs

struct GetNotificationsResponse: Codable {
    let notifications: [NotificationDTO]
    let total: Int
    let unreadCount: Int
    let hasMore: Bool
}

struct UnreadCountResponse: Codable {
    let count: Int
}

struct NotificationActionResponse: Codable {
    let success: Bool
    let message: String?
}

struct CreateNotificationResponse: Codable {
    let success: Bool
    let notification: NotificationDTO
}

// MARK: - Domain Model Conversion

extension AppNotification {
    /// Convert backend NotificationDTO to domain AppNotification model
    static func from(notificationDTO: NotificationDTO) -> AppNotification {
        // Parse notification type
        let notificationType: NotificationType = {
            switch notificationDTO.type {
            case "like": return .like
            case "comment": return .comment
            case "follow": return .follow
            case "friend_request": return .friendRequest
            case "mention": return .mention
            case "post_share": return .postShare
            default: return .other
            }
        }()
        
        // Create actor user if we have actor info
        let actor: User? = {
            guard let actorId = notificationDTO.actorId,
                  let actorUsername = notificationDTO.actorUsername else {
                return nil
            }
            return User(
                id: UUID(uuidString: actorId) ?? UUID(),
                convexId: actorId,
                username: actorUsername,
                displayName: notificationDTO.actorDisplayName ?? actorUsername,
                email: nil,
                phoneNumber: nil,
                bio: nil,
                profileImageUrl: notificationDTO.actorProfileImageUrl.flatMap { URL(string: $0) }
            )
        }()
        
        return AppNotification(
            id: UUID(uuidString: notificationDTO.id) ?? UUID(),
            convexId: notificationDTO.id,
            userId: UUID(uuidString: notificationDTO.userId) ?? UUID(),
            type: notificationType,
            title: notificationDTO.title,
            message: notificationDTO.message,
            isRead: notificationDTO.isRead,
            actor: actor,
            postId: notificationDTO.postId.flatMap { UUID(uuidString: $0) },
            commentId: notificationDTO.commentId.flatMap { UUID(uuidString: $0) },
            friendRequestId: notificationDTO.friendRequestId.flatMap { UUID(uuidString: $0) },
            createdAt: ISO8601DateFormatter().date(from: notificationDTO.createdAt) ?? Date()
        )
    }
}

// Domain model extensions (if AppNotification doesn't exist yet)
struct AppNotification: Identifiable {
    let id: UUID
    let convexId: String?
    let userId: UUID
    let type: NotificationType
    let title: String
    let message: String
    let isRead: Bool
    let actor: User?
    let postId: UUID?
    let commentId: UUID?
    let friendRequestId: UUID?
    let createdAt: Date
}

enum NotificationType {
    case like
    case comment
    case follow
    case friendRequest
    case mention
    case postShare
    case other
}

