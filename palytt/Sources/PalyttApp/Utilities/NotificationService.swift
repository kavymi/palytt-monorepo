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
import Clerk
#if !targetEnvironment(simulator)
// import ConvexMobile // temporarily disabled
#endif
import SwiftUI
import Combine
import UserNotifications

@MainActor
class PalyttNotificationService: ObservableObject {
    static let shared = PalyttNotificationService()
    
    @Published var notifications: [BackendService.BackendNotification] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let backendService = BackendService.shared
    private let nativeNotificationManager = NativeNotificationManager.shared
    private var refreshTimer: Timer?
    private var notificationSubscription: AnyCancellable?
    
    // Polling interval in seconds
    private let pollingInterval: TimeInterval = 15.0
    
    // Track previous notifications to detect new ones
    private var previousNotificationIds: Set<String> = []
    
    private init() {
        print("🔔 NotificationService: Initializing...")
        setupNotificationObservers()
        setupNativeNotifications()
    }
    
    deinit {
        refreshTimer?.invalidate()
        refreshTimer = nil
        NotificationCenter.default.removeObserver(self)
        print("🔔 NotificationService: Cleaned up in deinit")
    }
    
    private func setupNotificationObservers() {
        // Listen for authentication state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userSignedIn),
            name: .userSignedIn,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userSignedOut),
            name: .userSignedOut,
            object: nil
        )
    }
    
    @objc private func userSignedIn() {
        print("🔔 NotificationService: User signed in, starting subscription")
        subscribeToNotifications()
        
        // Request native notification permissions when user signs in
        Task {
            await nativeNotificationManager.requestPermissions()
        }
    }
    
    @objc private func userSignedOut() {
        print("🔔 NotificationService: User signed out, stopping subscription")
        stopPolling()
        clearNotifications()
        
        // Clear native notifications when user signs out
        nativeNotificationManager.clearAllNotifications()
    }
    
    func subscribeToNotifications() {
        guard let clerkUser = Clerk.shared.user else {
            print("⚠️ NotificationService: No authenticated user found")
            errorMessage = "User not authenticated"
            return
        }
        
        print("🔔 NotificationService: Starting notification subscription for user: \(clerkUser.id)")
        
        // Stop any existing polling
        stopPolling()
        
        // Start fresh
        isLoading = true
        errorMessage = nil
        
        Task {
            // Fetch notifications immediately
            await fetchNotifications(userId: clerkUser.id)
            
            // Start polling timer
            await startPolling(userId: clerkUser.id)
        }
    }
    
    private func startPolling(userId: String) async {
        await MainActor.run {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
                Task { [weak self] in
                    await self?.fetchNotifications(userId: userId)
                }
            }
            print("✅ NotificationService: Started polling every \(pollingInterval) seconds")
        }
    }
    
    private func stopPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        print("🔔 NotificationService: Stopped polling")
    }
    
    private func clearNotifications() {
        notifications = []
        unreadCount = 0
        errorMessage = nil
        isLoading = false
        previousNotificationIds.removeAll()
    }
    
    /// Set up native notification system
    private func setupNativeNotifications() {
        Task {
            await nativeNotificationManager.checkAuthorizationStatus()
            nativeNotificationManager.setupNotificationCategories()
        }
    }
    
    private func fetchNotifications(userId: String) async {
        do {
            print("📱 NotificationService: Fetching notifications for user: \(userId)")
            
            let fetchedNotifications = try await backendService.getNotifications(
                userId: userId, 
                limit: 50, 
                onlyUnread: false
            )
            
            // Update UI on main thread
            await MainActor.run {
                // Detect new notifications
                let currentNotificationIds = Set(fetchedNotifications.map { $0._id })
                let newNotificationIds = currentNotificationIds.subtracting(self.previousNotificationIds)
                
                // Update state
                self.notifications = fetchedNotifications
                self.unreadCount = fetchedNotifications.filter { !$0.isRead }.count
                self.isLoading = false
                self.errorMessage = nil
                
                print("✅ NotificationService: Fetched \(fetchedNotifications.count) notifications, \(self.unreadCount) unread, \(newNotificationIds.count) new")
                
                // Update badge count
                Task {
                    await self.nativeNotificationManager.updateBadgeCount(self.unreadCount)
                }
                
                // Send native notifications for new unread notifications
                if !newNotificationIds.isEmpty {
                    let newNotifications = fetchedNotifications.filter { newNotificationIds.contains($0._id) && !$0.isRead }
                    
                    for notification in newNotifications {
                        Task {
                            await self.nativeNotificationManager.sendNativeNotification(for: notification)
                        }
                    }
                    
                    // Post notification for UI updates if there are unread notifications
                    NotificationCenter.default.post(name: .notificationReceived, object: nil)
                    
                    // Play notification sound for new notifications
                    // SoundManager.shared.playNotificationSound()
                }
                
                // Update previous notification IDs for next comparison
                self.previousNotificationIds = currentNotificationIds
            }
            
        } catch {
            print("❌ NotificationService: Failed to fetch notifications: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to fetch notifications: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func markAsRead(notificationId: String) async {
        do {
            let response = try await backendService.markNotificationAsRead(notificationId: notificationId)
            if response.success {
                await MainActor.run {
                    // Update local state
                    updateNotificationReadStatus(id: notificationId, isRead: true)
                    
                    // Update unread count
                    unreadCount = notifications.filter { !$0.isRead }.count
                    
                    // Remove native notification when marked as read
                    nativeNotificationManager.removeNotification(withId: notificationId)
                    
                    // Update badge count
                    Task {
                        await nativeNotificationManager.updateBadgeCount(unreadCount)
                    }
                    
                    print("✅ NotificationService: Marked notification as read: \(notificationId)")
                }
            }
        } catch {
            print("❌ NotificationService: Failed to mark notification as read: \(error)")
            await MainActor.run {
                errorMessage = "Failed to update notification"
            }
        }
    }
    
    private func updateNotificationReadStatus(id: String, isRead: Bool) {
        if let index = notifications.firstIndex(where: { $0._id == id }) {
            // Create a mutable copy and update the read status
            var updatedNotifications = notifications
            
            // Since BackendNotification properties might be immutable, we need to create a new instance
            let originalNotification = updatedNotifications[index]
            
            // Create notification dictionary with updated isRead status
            var notificationDict: [String: Any] = [
                "_id": originalNotification._id,
                "recipientId": originalNotification.recipientId,
                "type": originalNotification.type.rawValue,
                "title": originalNotification.title,
                "message": originalNotification.message,
                "isRead": isRead,
                "createdAt": originalNotification.createdAt,
                "updatedAt": originalNotification.updatedAt
            ]
            
            // Add optional properties
            if let senderId = originalNotification.senderId {
                notificationDict["senderId"] = senderId
            }
            if let metadata = originalNotification.metadata {
                notificationDict["metadata"] = metadata
            }
            if let sender = originalNotification.sender {
                notificationDict["sender"] = sender
            }
            
            // Convert back to BackendNotification
            if let jsonData = try? JSONSerialization.data(withJSONObject: notificationDict),
               let updatedNotification = try? JSONDecoder().decode(BackendService.BackendNotification.self, from: jsonData) {
                updatedNotifications[index] = updatedNotification
                notifications = updatedNotifications
            }
        }
    }
    
    func markAllAsRead() async {
        guard let user = Clerk.shared.user else {
            await MainActor.run {
                errorMessage = "User not authenticated"
            }
            return
        }
        
        do {
            let response = try await backendService.markAllNotificationsAsRead(userId: user.id)
            if response.success {
                await MainActor.run {
                    // Mark all notifications as read locally
                    var updatedNotifications: [BackendService.BackendNotification] = []
                    
                    for notification in notifications {
                        var notificationDict: [String: Any] = [
                            "_id": notification._id,
                            "recipientId": notification.recipientId,
                            "type": notification.type.rawValue,
                            "title": notification.title,
                            "message": notification.message,
                            "isRead": true,
                            "createdAt": notification.createdAt,
                            "updatedAt": notification.updatedAt
                        ]
                        
                        // Add optional properties
                        if let senderId = notification.senderId {
                            notificationDict["senderId"] = senderId
                        }
                        if let metadata = notification.metadata {
                            notificationDict["metadata"] = metadata
                        }
                        if let sender = notification.sender {
                            notificationDict["sender"] = sender
                        }
                        
                        if let jsonData = try? JSONSerialization.data(withJSONObject: notificationDict),
                           let updatedNotification = try? JSONDecoder().decode(BackendService.BackendNotification.self, from: jsonData) {
                            updatedNotifications.append(updatedNotification)
                        } else {
                            updatedNotifications.append(notification)
                        }
                    }
                    
                    notifications = updatedNotifications
                    unreadCount = 0
                    
                    // Clear all native notifications when all are marked as read
                    nativeNotificationManager.clearAllNotifications()
                    
                    print("✅ NotificationService: Marked all notifications as read")
                }
            }
        } catch {
            print("❌ NotificationService: Failed to mark all notifications as read: \(error)")
            await MainActor.run {
                errorMessage = "Failed to update notifications"
            }
        }
    }
    
    func fetchUnreadCount() async {
        guard let user = Clerk.shared.user else {
            await MainActor.run {
                errorMessage = "User not authenticated"
            }
            return
        }
        
        do {
            let response = try await backendService.getUnreadNotificationsCount(userId: user.id)
            await MainActor.run {
                unreadCount = response.count
                print("✅ NotificationService: Updated unread count: \(response.count)")
            }
        } catch {
            print("❌ NotificationService: Failed to fetch unread count: \(error)")
            await MainActor.run {
                errorMessage = "Failed to fetch notification count"
            }
        }
    }
    
    func refreshNotifications() async {
        guard let user = Clerk.shared.user else {
            await MainActor.run {
                errorMessage = "User not authenticated"
            }
            return
        }
        
        await fetchNotifications(userId: user.id)
    }
}

// MARK: - Notification Names
extension NSNotification.Name {
    static let notificationReceived = NSNotification.Name("NotificationReceived")
    static let userSignedIn = NSNotification.Name("UserSignedIn")
    static let userSignedOut = NSNotification.Name("UserSignedOut")
}
