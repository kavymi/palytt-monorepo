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
import Combine
import Alamofire
import UIKit

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published var notifications: [PalyttNotification] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading: Bool = false
    @Published var hasMoreNotifications: Bool = true
    
    private var nextCursor: String?
    private let backendService = BackendService.shared
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    
    private init() {
        setupPeriodicRefresh()
    }
    
    deinit {
        refreshTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Load notifications with pagination support
    func loadNotifications(refresh: Bool = false) async {
        // Check if user is authenticated before making API calls
        guard AuthProvider.shared.isAuthenticated() else {
            print("⏳ NotificationService: Skipping load - not authenticated")
            return
        }
        
        guard !isLoading else { return }
        
        if refresh {
            nextCursor = nil
            hasMoreNotifications = true
        }
        
        guard hasMoreNotifications else { return }
        
        isLoading = true
        
        do {
            let response = try await fetchNotifications(
                limit: 20,
                cursor: nextCursor,
                unreadOnly: false
            )
            
            if refresh {
                notifications = response.notifications
            } else {
                notifications.append(contentsOf: response.notifications)
            }
            
            nextCursor = response.nextCursor
            hasMoreNotifications = response.nextCursor != nil
            
            print("✅ NotificationService: Loaded \(response.notifications.count) notifications")
            
        } catch {
            print("❌ NotificationService: Failed to load notifications: \(error)")
        }
        
        isLoading = false
    }
    
    /// Load only unread notifications
    func loadUnreadNotifications() async {
        // Check if user is authenticated before making API calls
        guard AuthProvider.shared.isAuthenticated() else {
            print("⏳ NotificationService: Skipping unread load - not authenticated")
            return
        }
        
        isLoading = true
        
        do {
            let response = try await fetchNotifications(
                limit: 50,
                cursor: nil,
                unreadOnly: true
            )
            
            // Update unread count
            unreadCount = response.notifications.count
            
            print("✅ NotificationService: Found \(unreadCount) unread notifications")
            
        } catch {
            print("❌ NotificationService: Failed to load unread notifications: \(error)")
        }
        
        isLoading = false
    }
    
    /// Get unread notification count
    func refreshUnreadCount() async {
        // Check if user is authenticated before making API calls
        guard AuthProvider.shared.isAuthenticated() else {
            print("⏳ NotificationService: Skipping refresh - not authenticated")
            return
        }
        
        do {
            let count = try await fetchUnreadCount()
            unreadCount = count
            print("✅ NotificationService: Unread count updated: \(count)")
        } catch {
            print("❌ NotificationService: Failed to refresh unread count: \(error)")
        }
    }
    
    /// Mark specific notifications as read
    func markAsRead(notificationIds: [String]) async {
        do {
            let response = try await markNotificationsAsRead(notificationIds: notificationIds)
            
            if response.success {
                // Update local notifications
                for id in notificationIds {
                    if let index = notifications.firstIndex(where: { $0.id == id }) {
                        let updatedNotification = notifications[index]
                        notifications[index] = PalyttNotification(
                            id: updatedNotification.id,
                            userId: updatedNotification.userId,
                            type: updatedNotification.type,
                            title: updatedNotification.title,
                            message: updatedNotification.message,
                            data: updatedNotification.data,
                            isRead: true,
                            createdAt: updatedNotification.createdAt
                        )
                    }
                }
                
                // Update unread count
                unreadCount = max(0, unreadCount - response.count)
                print("✅ NotificationService: Marked \(response.count) notifications as read")
            }
            
        } catch {
            print("❌ NotificationService: Failed to mark notifications as read: \(error)")
        }
    }
    
    /// Mark all notifications as read
    func markAllAsRead() async {
        do {
            let response = try await markNotificationsAsRead(notificationIds: nil)
            
            if response.success {
                // Update all local notifications to read
                notifications = notifications.map { notification in
                    PalyttNotification(
                        id: notification.id,
                        userId: notification.userId,
                        type: notification.type,
                        title: notification.title,
                        message: notification.message,
                        data: notification.data,
                        isRead: true,
                        createdAt: notification.createdAt
                    )
                }
                
                unreadCount = 0
                print("✅ NotificationService: Marked all notifications as read")
            }
            
        } catch {
            print("❌ NotificationService: Failed to mark all notifications as read: \(error)")
        }
    }
    
    /// Refresh notifications and unread count
    func refresh() async {
        await loadNotifications(refresh: true)
        await refreshUnreadCount()
    }
    
    // MARK: - Private Methods
    
    private func setupPeriodicRefresh() {
        // Refresh unread count every 30 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshUnreadCount()
                
                // Also refresh notifications if we're on the notifications tab
                // This provides a basic real-time experience
                if !(self?.notifications.isEmpty ?? true) {
                    await self?.loadNotifications(refresh: true)
                }
            }
        }
        
        // Listen for app becoming active to refresh immediately
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }
    
    private func fetchNotifications(
        limit: Int,
        cursor: String?,
        type: NotificationType? = nil,
        types: [NotificationType]? = nil,
        unreadOnly: Bool
    ) async throws -> (notifications: [PalyttNotification], nextCursor: String?) {
        
        // Create proper Codable input struct
        struct GetNotificationsInput: Codable {
            let limit: Int
            let unreadOnly: Bool
            let cursor: String?
            let type: String?
            let types: [String]?
        }
        
        let input = GetNotificationsInput(
            limit: limit,
            unreadOnly: unreadOnly,
            cursor: cursor,
            type: type?.rawValue,
            types: types?.map { $0.rawValue }
        )
        
        // Make tRPC query
        let response: NotificationsResponse = try await backendService.performTRPCQuery(
            procedure: "notifications.getNotifications",
            input: input
        )
        
        // Convert backend notifications to app notifications
        let appNotifications = response.notifications.compactMap { $0.toPalyttNotification() }
        
        return (notifications: appNotifications, nextCursor: response.nextCursor)
    }
    
    /// Load notifications filtered by types
    func loadNotifications(filterTypes: [NotificationType]?, refresh: Bool = false) async {
        // Check if user is authenticated before making API calls
        guard AuthProvider.shared.isAuthenticated() else {
            print("⏳ NotificationService: Skipping filtered load - not authenticated")
            return
        }
        
        guard !isLoading else { return }
        
        if refresh {
            nextCursor = nil
            hasMoreNotifications = true
        }
        
        guard hasMoreNotifications else { return }
        
        isLoading = true
        
        do {
            let response = try await fetchNotifications(
                limit: 20,
                cursor: nextCursor,
                types: filterTypes,
                unreadOnly: false
            )
            
            if refresh {
                notifications = response.notifications
            } else {
                notifications.append(contentsOf: response.notifications)
            }
            
            nextCursor = response.nextCursor
            hasMoreNotifications = response.nextCursor != nil
            
            print("✅ NotificationService: Loaded \(response.notifications.count) notifications (filtered)")
            
        } catch {
            print("❌ NotificationService: Failed to load notifications: \(error)")
        }
        
        isLoading = false
    }
    
    private func fetchUnreadCount() async throws -> Int {
        struct EmptyInput: Codable {}
        
        let response: NotificationCountResponse = try await backendService.performTRPCQuery(
            procedure: "notifications.getUnreadCount",
            input: EmptyInput()
        )
        
        return response.count
    }
    
    private func markNotificationsAsRead(notificationIds: [String]?) async throws -> MarkAsReadResponse {
        struct MarkAsReadInput: Codable {
            let notificationIds: [String]?
        }
        
        let input = MarkAsReadInput(notificationIds: notificationIds)
        
        let response: MarkAsReadResponse = try await backendService.performTRPCMutation(
            procedure: "notifications.markAsRead",
            input: input
        )
        
        return response
    }
}
