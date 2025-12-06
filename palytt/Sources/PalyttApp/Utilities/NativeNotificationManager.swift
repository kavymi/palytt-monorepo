//
//  NativeNotificationManager.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation
import UserNotifications
import UIKit
import SwiftUI

@MainActor
class NativeNotificationManager: NSObject, ObservableObject {
    static let shared = NativeNotificationManager()
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var deviceToken: String?
    
    private let center = UNUserNotificationCenter.current()
    
    private override init() {
        super.init()
        center.delegate = self
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    // MARK: - Permission Management
    
    /// Request notification permissions from the user
    func requestPermissions() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [
                .alert,
                .badge,
                .sound,
                .provisional // Allows quiet notifications without explicit permission
            ])
            
            await MainActor.run {
                self.isAuthorized = granted
                print("📱 NativeNotificationManager: Permission \(granted ? "granted" : "denied")")
            }
            
            if granted {
                await checkAuthorizationStatus()
                // Register for remote notifications after permission is granted
                await registerForRemoteNotifications()
            }
            
            return granted
        } catch {
            print("❌ NativeNotificationManager: Failed to request permissions: \(error)")
            return false
        }
    }
    
    /// Check current authorization status
    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        
        await MainActor.run {
            self.authorizationStatus = settings.authorizationStatus
            self.isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            
            print("📱 NativeNotificationManager: Authorization status: \(settings.authorizationStatus.description)")
        }
        
        // Register for remote notifications if authorized
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            await registerForRemoteNotifications()
        }
    }
    
    // MARK: - Remote Notification Registration
    
    /// Register for remote notifications with APNs
    func registerForRemoteNotifications() async {
        await MainActor.run {
            print("📱 NativeNotificationManager: Registering for remote notifications")
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    /// Handle successful device token registration
    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        print("📱 NativeNotificationManager: Device token received: \(tokenString.prefix(20))...")
        
        // Send token to backend
        Task {
            await sendDeviceTokenToBackend(token: tokenString)
        }
    }
    
    /// Handle failed device token registration
    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("❌ NativeNotificationManager: Failed to register for remote notifications: \(error)")
    }
    
    /// Send device token to backend for push notification delivery
    private func sendDeviceTokenToBackend(token: String) async {
        do {
            try await BackendService.shared.registerDeviceToken(token: token)
            print("✅ NativeNotificationManager: Device token sent to backend")
        } catch {
            print("❌ NativeNotificationManager: Failed to send device token to backend: \(error)")
        }
    }
    
    /// Unregister device token from backend (call on logout)
    func unregisterDeviceToken() async {
        guard let token = deviceToken else { return }
        
        do {
            try await BackendService.shared.unregisterDeviceToken(token: token)
            self.deviceToken = nil
            print("✅ NativeNotificationManager: Device token unregistered from backend")
        } catch {
            print("❌ NativeNotificationManager: Failed to unregister device token: \(error)")
        }
    }
    
    // MARK: - Notification Creation
    
    /// Send a native iOS notification for a received app notification
    /// Supports rich content including images and thread grouping
    func sendNativeNotification(for notification: BackendService.BackendNotification) async {
        guard isAuthorized else {
            print("⚠️ NativeNotificationManager: Not authorized to send notifications")
            return
        }
        
        // Don't send native notification if app is in foreground and active
        if UIApplication.shared.applicationState == .active {
            print("📱 NativeNotificationManager: App is active, skipping native notification")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.message
        content.sound = getNotificationSound(for: notification.type)
        content.badge = NSNumber(value: await getUnreadCount())
        
        // Add custom user info for handling notification taps
        content.userInfo = [
            "notificationId": notification._id,
            "type": notification.type.rawValue,
            "senderId": notification.senderId ?? "",
            "createdAt": notification.createdAt
        ]
        
        // Add category for interactive notifications
        content.categoryIdentifier = getNotificationCategory(for: notification.type)
        
        // Thread identifier for grouping related notifications
        content.threadIdentifier = getThreadIdentifier(for: notification)
        
        // Mark friend requests and messages as time-sensitive for Focus breakthrough
        if notification.type == .friendRequest || notification.type == .message {
            content.interruptionLevel = .timeSensitive
        }
        
        // Add rich content (image attachment) if available
        if let attachment = await createImageAttachment(for: notification) {
            content.attachments = [attachment]
        }
        
        // Create request with unique identifier
        let request = UNNotificationRequest(
            identifier: notification._id,
            content: content,
            trigger: nil // Immediate delivery
        )
        
        do {
            try await center.add(request)
            print("✅ NativeNotificationManager: Sent native notification for \(notification.type.rawValue)")
        } catch {
            print("❌ NativeNotificationManager: Failed to send notification: \(error)")
        }
    }
    
    // MARK: - Rich Notification Content
    
    /// Creates an image attachment for the notification
    /// - For post interactions: shows the post image thumbnail
    /// - For social notifications: shows the sender's profile picture
    private func createImageAttachment(for notification: BackendService.BackendNotification) async -> UNNotificationAttachment? {
        // Note: Image attachments require postImage or profileImage in the notification data
        // Currently NotificationMetadata doesn't include these fields
        // This will be enabled once the backend includes image URLs in notifications
        
        // For now, skip image attachments
        return nil
    }
    
    /// Downloads an image and creates a notification attachment
    private func downloadAndCreateAttachment(from url: URL, identifier: String) async -> UNNotificationAttachment? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            // Verify it's an image
            guard let mimeType = (response as? HTTPURLResponse)?.mimeType,
                  mimeType.hasPrefix("image/") else {
                return nil
            }
            
            // Determine file extension from MIME type
            let fileExtension: String
            switch mimeType {
            case "image/jpeg", "image/jpg":
                fileExtension = "jpg"
            case "image/png":
                fileExtension = "png"
            case "image/gif":
                fileExtension = "gif"
            case "image/webp":
                fileExtension = "webp"
            default:
                fileExtension = "jpg"
            }
            
            // Create temporary file
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileName = "\(identifier)_attachment.\(fileExtension)"
            let fileURL = tempDirectory.appendingPathComponent(fileName)
            
            // Write data to file
            try data.write(to: fileURL)
            
            // Create attachment with options for thumbnail
            let options: [String: Any] = [
                UNNotificationAttachmentOptionsThumbnailClippingRectKey: CGRect(x: 0, y: 0, width: 1, height: 1).dictionaryRepresentation,
                UNNotificationAttachmentOptionsThumbnailHiddenKey: false
            ]
            
            let attachment = try UNNotificationAttachment(
                identifier: "\(identifier)_image",
                url: fileURL,
                options: options
            )
            
            print("📸 NativeNotificationManager: Created image attachment for notification")
            return attachment
            
        } catch {
            print("⚠️ NativeNotificationManager: Failed to create image attachment: \(error)")
            return nil
        }
    }
    
    /// Generates a thread identifier for grouping related notifications
    /// - Post interactions on the same post are grouped together
    /// - Messages from the same conversation are grouped
    /// - Friend requests are grouped together
    private func getThreadIdentifier(for notification: BackendService.BackendNotification) -> String {
        switch notification.type {
        case .postLike, .postComment, .commentLike:
            // Group by post
            if let postId = notification.metadata?.postId {
                return "post_\(postId)"
            }
        case .friendRequest, .friendRequestAccepted:
            // Group all friend-related notifications
            return "friends"
        case .message:
            // Group by conversation/sender
            if let senderId = notification.senderId {
                return "messages_\(senderId)"
            }
        case .newFollower:
            // Group all follow notifications
            return "followers"
        default:
            break
        }
        
        // Default: group by notification type
        return "general_\(notification.type.rawValue)"
    }
    
    /// Send a native notification for friend requests
    /// Includes sender's profile picture as rich content
    func sendFriendRequestNotification(from senderName: String, requestId: String, senderProfileImage: String? = nil) async {
        guard isAuthorized else { return }
        
        if UIApplication.shared.applicationState == .active {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "New Friend Request"
        content.body = "\(senderName) sent you a friend request"
        content.sound = .default
        content.badge = NSNumber(value: await getUnreadCount())
        
        content.userInfo = [
            "type": "friend_request",
            "requestId": requestId,
            "senderName": senderName
        ]
        
        content.categoryIdentifier = "FRIEND_REQUEST"
        
        // Group with other friend notifications
        content.threadIdentifier = "friends"
        
        // Friend requests are time-sensitive
        content.interruptionLevel = .timeSensitive
        
        // Add sender's profile picture if available
        if let profileImageURL = senderProfileImage,
           let url = URL(string: profileImageURL),
           let attachment = await downloadAndCreateAttachment(from: url, identifier: "friend_request_\(requestId)") {
            content.attachments = [attachment]
        }
        
        let request = UNNotificationRequest(
            identifier: "friend_request_\(requestId)",
            content: content,
            trigger: nil
        )
        
        do {
            try await center.add(request)
            print("✅ NativeNotificationManager: Sent friend request notification")
        } catch {
            print("❌ NativeNotificationManager: Failed to send friend request notification: \(error)")
        }
    }
    
    /// Send a rich notification with custom image
    /// Useful for batched notifications ("Sarah and 3 others liked your post")
    func sendRichNotification(
        identifier: String,
        title: String,
        body: String,
        imageURL: String? = nil,
        category: String = "GENERAL",
        threadId: String? = nil,
        userInfo: [String: Any] = [:],
        isTimeSensitive: Bool = false
    ) async {
        guard isAuthorized else { return }
        
        if UIApplication.shared.applicationState == .active {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = NSNumber(value: await getUnreadCount())
        content.userInfo = userInfo
        content.categoryIdentifier = category
        
        if let threadId = threadId {
            content.threadIdentifier = threadId
        }
        
        if isTimeSensitive {
            content.interruptionLevel = .timeSensitive
        }
        
        // Add image attachment if provided
        if let imageURLString = imageURL,
           let url = URL(string: imageURLString),
           let attachment = await downloadAndCreateAttachment(from: url, identifier: identifier) {
            content.attachments = [attachment]
        }
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        
        do {
            try await center.add(request)
            print("✅ NativeNotificationManager: Sent rich notification: \(title)")
        } catch {
            print("❌ NativeNotificationManager: Failed to send rich notification: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getNotificationSound(for type: BackendService.NotificationType) -> UNNotificationSound {
        switch type {
        case .postLike, .commentLike:
            return .defaultCritical // More prominent for likes
        case .friendRequest, .friendRequestAccepted:
            return .default
        case .postComment, .message:
            return .default
        case .newFollower:
            return .default
        default:
            return .default
        }
    }
    
    private func getNotificationCategory(for type: BackendService.NotificationType) -> String {
        switch type {
        case .friendRequest:
            return "FRIEND_REQUEST"
        case .postLike, .postComment:
            return "POST_INTERACTION"
        case .message:
            return "MESSAGE"
        default:
            return "GENERAL"
        }
    }
    
    private func getUnreadCount() async -> Int {
        return NotificationService.shared.unreadCount
    }
    
    // MARK: - Notification Management
    
    /// Remove delivered notifications for read items
    func removeNotification(withId id: String) {
        center.removeDeliveredNotifications(withIdentifiers: [id])
        print("📱 NativeNotificationManager: Removed delivered notification: \(id)")
    }
    
    /// Clear all delivered notifications
    func clearAllNotifications() {
        center.removeAllDeliveredNotifications()
        // Reset badge count
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(0)
        }
        print("📱 NativeNotificationManager: Cleared all delivered notifications")
    }
    
    /// Update app badge count
    func updateBadgeCount(_ count: Int) async {
        try? await UNUserNotificationCenter.current().setBadgeCount(count)
        print("📱 NativeNotificationManager: Updated badge count to \(count)")
    }
    
    // MARK: - Interactive Notification Setup
    
    /// Set up interactive notification categories
    func setupNotificationCategories() {
        let friendRequestCategory = UNNotificationCategory(
            identifier: "FRIEND_REQUEST",
            actions: [
                UNNotificationAction(
                    identifier: "ACCEPT_FRIEND_REQUEST",
                    title: "Accept",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "DECLINE_FRIEND_REQUEST",
                    title: "Decline",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let postInteractionCategory = UNNotificationCategory(
            identifier: "POST_INTERACTION",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_POST",
                    title: "View",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let messageCategory = UNNotificationCategory(
            identifier: "MESSAGE",
            actions: [
                UNNotificationAction(
                    identifier: "REPLY_MESSAGE",
                    title: "Reply",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "MARK_READ",
                    title: "Mark as Read",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([
            friendRequestCategory,
            postInteractionCategory,
            messageCategory
        ])
        
        print("✅ NativeNotificationManager: Set up notification categories")
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NativeNotificationManager: @preconcurrency UNUserNotificationCenterDelegate {
    
    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Handle notification tap/interaction
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        Task {
            await handleNotificationInteraction(
                actionIdentifier: response.actionIdentifier,
                userInfo: userInfo
            )
            completionHandler()
        }
    }
    
    /// Handle notification interactions (taps, action buttons)
    private func handleNotificationInteraction(actionIdentifier: String, userInfo: [AnyHashable: Any]) async {
        print("📱 NativeNotificationManager: Handling interaction: \(actionIdentifier)")
        
        switch actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            await handleNotificationTap(userInfo: userInfo)
            
        case "ACCEPT_FRIEND_REQUEST":
            if let requestId = userInfo["requestId"] as? String {
                await handleFriendRequestAction(requestId: requestId, accept: true)
            }
            
        case "DECLINE_FRIEND_REQUEST":
            if let requestId = userInfo["requestId"] as? String {
                await handleFriendRequestAction(requestId: requestId, accept: false)
            }
            
        case "VIEW_POST":
            // Navigate to post view
            await handlePostNavigation(userInfo: userInfo)
            
        case "REPLY_MESSAGE":
            // Navigate to message view
            await handleMessageNavigation(userInfo: userInfo)
            
        case "MARK_READ":
            if let notificationId = userInfo["notificationId"] as? String {
                await NotificationService.shared.markAsRead(notificationIds: [notificationId])
            }
            
        default:
            break
        }
    }
    
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) async {
        // Navigate to notifications view or specific content
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToNotifications"),
                object: userInfo
            )
        }
    }
    
    private func handleFriendRequestAction(requestId: String, accept: Bool) async {
        // Handle friend request acceptance/decline
        print("📱 NativeNotificationManager: \(accept ? "Accepting" : "Declining") friend request: \(requestId)")
        
        // Post notification to handle in UI
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("HandleFriendRequest"),
                object: ["requestId": requestId, "accept": accept]
            )
        }
    }
    
    private func handlePostNavigation(userInfo: [AnyHashable: Any]) async {
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToPost"),
                object: userInfo
            )
        }
    }
    
    private func handleMessageNavigation(userInfo: [AnyHashable: Any]) async {
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToMessages"),
                object: userInfo
            )
        }
    }
}

// MARK: - UNAuthorizationStatus Extension

extension UNAuthorizationStatus {
    var description: String {
        switch self {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .notDetermined: return "notDetermined"
        case .provisional: return "provisional"
        case .ephemeral: return "ephemeral"
        @unknown default: return "unknown"
        }
    }
}
