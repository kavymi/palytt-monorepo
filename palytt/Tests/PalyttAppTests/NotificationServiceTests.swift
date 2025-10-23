//
//  NotificationServiceTests.swift
//  PalyttAppTests
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import XCTest
@testable import PalyttApp

@MainActor
final class NotificationServiceTests: XCTestCase {
    
    var sut: NotificationService!
    var mockAPIClient: MockAPIClient!
    
    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        sut = NotificationService(apiClient: mockAPIClient)
    }
    
    override func tearDown() {
        sut = nil
        mockAPIClient = nil
        super.tearDown()
    }
    
    // MARK: - Get Notifications Tests
    
    func testGetNotifications_AllNotifications() async throws {
        // Given
        let mockNotifications = [createMockNotificationDTO(), createMockNotificationDTO()]
        let response = GetNotificationsResponse(
            notifications: mockNotifications,
            total: 2,
            unreadCount: 1,
            hasMore: false
        )
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let notifications = try await sut.getNotifications(userId: "user123", limit: 50, onlyUnread: false)
        
        // Then
        XCTAssertEqual(notifications.count, 2)
        XCTAssertEqual(mockAPIClient.lastRequestPath, "trpc/notifications.getNotifications")
    }
    
    func testGetNotifications_OnlyUnread() async throws {
        // Given
        let unreadNotification = createMockNotificationDTO(isRead: false)
        let response = GetNotificationsResponse(
            notifications: [unreadNotification],
            total: 1,
            unreadCount: 1,
            hasMore: false
        )
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let notifications = try await sut.getNotifications(userId: "user123", limit: 50, onlyUnread: true)
        
        // Then
        XCTAssertEqual(notifications.count, 1)
        XCTAssertFalse(notifications[0].isRead)
    }
    
    // MARK: - Get Unread Count Tests
    
    func testGetUnreadCount_Success() async throws {
        // Given
        let response = UnreadCountResponse(count: 5)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let count = try await sut.getUnreadCount(userId: "user123")
        
        // Then
        XCTAssertEqual(count, 5)
    }
    
    // MARK: - Mark as Read Tests
    
    func testMarkAsRead_Single() async throws {
        // Given
        let response = NotificationActionResponse(success: true, message: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let success = try await sut.markAsRead(notificationId: "notif123")
        
        // Then
        XCTAssertTrue(success)
    }
    
    func testMarkAllAsRead_Success() async throws {
        // Given
        let response = NotificationActionResponse(success: true, message: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let success = try await sut.markAllAsRead(userId: "user123")
        
        // Then
        XCTAssertTrue(success)
    }
    
    // MARK: - Delete Tests
    
    func testDeleteNotification_Success() async throws {
        // Given
        let response = NotificationActionResponse(success: true, message: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let success = try await sut.deleteNotification(notificationId: "notif123")
        
        // Then
        XCTAssertTrue(success)
    }
    
    func testDeleteAllNotifications_Success() async throws {
        // Given
        let response = NotificationActionResponse(success: true, message: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let success = try await sut.deleteAllNotifications(userId: "user123")
        
        // Then
        XCTAssertTrue(success)
    }
    
    // MARK: - Create Notification Tests
    
    func testCreateNotification_Success() async throws {
        // Given
        let mockNotification = createMockNotificationDTO()
        let response = CreateNotificationResponse(success: true, notification: mockNotification)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        let request = CreateNotificationRequest(
            userId: "user123",
            type: "like",
            title: "New Like",
            message: "Someone liked your post",
            actorId: "user456",
            postId: nil,
            commentId: nil,
            friendRequestId: nil,
            metadata: nil
        )
        
        // When
        let notification = try await sut.createNotification(request)
        
        // Then
        XCTAssertNotNil(notification)
    }
    
    // MARK: - Helper Methods
    
    private func createMockNotificationDTO(isRead: Bool = false) -> NotificationDTO {
        return NotificationDTO(
            id: UUID().uuidString,
            userId: "user123",
            type: "like",
            title: "New Like",
            message: "Someone liked your post",
            isRead: isRead,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            actorId: "user456",
            actorUsername: "actor",
            actorDisplayName: "Actor User",
            actorProfileImageUrl: nil,
            postId: nil,
            commentId: nil,
            friendRequestId: nil,
            metadata: nil
        )
    }
}

