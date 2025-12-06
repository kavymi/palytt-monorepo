//
//  AppDelegate.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("📱 AppDelegate: didFinishLaunchingWithOptions")
        return true
    }
    
    // MARK: - Remote Notification Registration
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            NativeNotificationManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
        }
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            NativeNotificationManager.shared.didFailToRegisterForRemoteNotifications(error: error)
        }
    }
    
    // MARK: - Remote Notification Handling
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("📱 AppDelegate: Received remote notification")
        
        // Handle background notification
        Task { @MainActor in
            // Refresh notification count
            await NotificationService.shared.refreshUnreadCount()
            
            // Update badge
            let unreadCount = NotificationService.shared.unreadCount
            await NativeNotificationManager.shared.updateBadgeCount(unreadCount)
            
            completionHandler(.newData)
        }
    }
}

