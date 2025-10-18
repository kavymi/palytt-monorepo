//
//  NotificationService.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation

// MARK: - Protocol

protocol NotificationServiceProtocol {
    func getNotifications(userId: String, limit: Int, onlyUnread: Bool) async throws -> [AppNotification]
    func getUnreadCount(userId: String) async throws -> Int
    func markAsRead(notificationId: String) async throws -> Bool
    func markAllAsRead(userId: String) async throws -> Bool
    func deleteNotification(notificationId: String) async throws -> Bool
    func deleteAllNotifications(userId: String) async throws -> Bool
    func createNotification(_ request: CreateNotificationRequest) async throws -> AppNotification
}

// MARK: - Service Implementation

@MainActor
final class NotificationService: NotificationServiceProtocol {
    
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }
    
    convenience init(baseURL: URL) {
        let apiClient = APIClient(baseURL: baseURL)
        self.init(apiClient: apiClient)
    }
    
    // MARK: - Get Notifications
    
    func getNotifications(userId: String, limit: Int = 50, onlyUnread: Bool = false) async throws -> [AppNotification] {
        print("🔔 NotificationService: Getting notifications for user \(userId)")
        
        let request = GetNotificationsRequest(
            userId: userId,
            limit: limit,
            onlyUnread: onlyUnread
        )
        
        let response = try await apiClient.request(
            path: "trpc/notifications.getNotifications",
            method: .get,
            parameters: request,
            responseType: GetNotificationsResponse.self
        )
        
        print("✅ NotificationService: Retrieved \(response.notifications.count) notifications (\(response.unreadCount) unread)")
        return response.notifications.map { AppNotification.from(notificationDTO: $0) }
    }
    
    // MARK: - Get Unread Count
    
    func getUnreadCount(userId: String) async throws -> Int {
        print("🔔 NotificationService: Getting unread count for user \(userId)")
        
        let request = GetUnreadCountRequest(userId: userId)
        
        let response = try await apiClient.request(
            path: "trpc/notifications.getUnreadCount",
            method: .get,
            parameters: request,
            responseType: UnreadCountResponse.self
        )
        
        print("✅ NotificationService: Unread count: \(response.count)")
        return response.count
    }
    
    // MARK: - Mark as Read
    
    func markAsRead(notificationId: String) async throws -> Bool {
        print("✅ NotificationService: Marking notification \(notificationId) as read")
        
        let request = MarkNotificationAsReadRequest(notificationId: notificationId)
        
        let response = try await apiClient.request(
            path: "trpc/notifications.markAsRead",
            method: .post,
            parameters: request,
            responseType: NotificationActionResponse.self
        )
        
        print("✅ NotificationService: Successfully marked as read")
        return response.success
    }
    
    func markAllAsRead(userId: String) async throws -> Bool {
        print("✅ NotificationService: Marking all notifications as read for user \(userId)")
        
        let request = MarkAllAsReadRequest(userId: userId)
        
        let response = try await apiClient.request(
            path: "trpc/notifications.markAllAsRead",
            method: .post,
            parameters: request,
            responseType: NotificationActionResponse.self
        )
        
        print("✅ NotificationService: Successfully marked all as read")
        return response.success
    }
    
    // MARK: - Delete Notifications
    
    func deleteNotification(notificationId: String) async throws -> Bool {
        print("🗑️ NotificationService: Deleting notification \(notificationId)")
        
        let request = DeleteNotificationRequest(notificationId: notificationId)
        
        let response = try await apiClient.request(
            path: "trpc/notifications.deleteNotification",
            method: .post,
            parameters: request,
            responseType: NotificationActionResponse.self
        )
        
        print("✅ NotificationService: Successfully deleted notification")
        return response.success
    }
    
    func deleteAllNotifications(userId: String) async throws -> Bool {
        print("🗑️ NotificationService: Deleting all notifications for user \(userId)")
        
        let request = DeleteAllNotificationsRequest(userId: userId)
        
        let response = try await apiClient.request(
            path: "trpc/notifications.deleteAll",
            method: .post,
            parameters: request,
            responseType: NotificationActionResponse.self
        )
        
        print("✅ NotificationService: Successfully deleted all notifications")
        return response.success
    }
    
    // MARK: - Create Notification
    
    func createNotification(_ request: CreateNotificationRequest) async throws -> AppNotification {
        print("🔔 NotificationService: Creating notification for user \(request.userId)")
        
        let response = try await apiClient.request(
            path: "trpc/notifications.create",
            method: .post,
            parameters: request,
            responseType: CreateNotificationResponse.self
        )
        
        guard response.success else {
            throw APIError.serverError(message: "Failed to create notification")
        }
        
        print("✅ NotificationService: Successfully created notification")
        return AppNotification.from(notificationDTO: response.notification)
    }
}

// MARK: - Mock Implementation for Testing

#if DEBUG
final class MockNotificationService: NotificationServiceProtocol {
    var mockNotifications: [AppNotification] = []
    var mockNotification: AppNotification?
    var mockUnreadCount = 0
    var shouldFail = false
    var mockError: APIError = .networkError(URLError(.notConnectedToInternet))
    var mockSuccess = true
    
    func getNotifications(userId: String, limit: Int, onlyUnread: Bool) async throws -> [AppNotification] {
        if shouldFail { throw mockError }
        return mockNotifications
    }
    
    func getUnreadCount(userId: String) async throws -> Int {
        if shouldFail { throw mockError }
        return mockUnreadCount
    }
    
    func markAsRead(notificationId: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockSuccess
    }
    
    func markAllAsRead(userId: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockSuccess
    }
    
    func deleteNotification(notificationId: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockSuccess
    }
    
    func deleteAllNotifications(userId: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockSuccess
    }
    
    func createNotification(_ request: CreateNotificationRequest) async throws -> AppNotification {
        if shouldFail { throw mockError }
        return mockNotification ?? createMockNotification()
    }
    
    private func createMockNotification() -> AppNotification {
        return AppNotification(
            id: UUID(),
            convexId: nil,
            userId: UUID(),
            type: .like,
            title: "Mock Notification",
            message: "This is a mock notification",
            isRead: false,
            actor: nil,
            postId: nil,
            commentId: nil,
            friendRequestId: nil,
            createdAt: Date()
        )
    }
}
#endif

