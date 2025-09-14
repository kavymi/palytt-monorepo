//
//  NotificationBadge.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI

struct NotificationBadge: View {
    let count: Int
    let maxDisplayCount: Int
    
    init(count: Int, maxDisplayCount: Int = 99) {
        self.count = count
        self.maxDisplayCount = maxDisplayCount
    }
    
    var body: some View {
        if count > 0 {
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: badgeSize, height: badgeSize)
                
                Text(displayText)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.7)
            }
        }
    }
    
    private var displayText: String {
        if count > maxDisplayCount {
            return "\(maxDisplayCount)+"
        } else {
            return "\(count)"
        }
    }
    
    private var badgeSize: CGFloat {
        if count > 9 {
            return 20
        } else {
            return 16
        }
    }
    
    private var fontSize: CGFloat {
        if count > 9 {
            return 10
        } else {
            return 11
        }
    }
}

// MARK: - Tab Bar Badge
struct TabBarNotificationBadge: View {
    @StateObject private var notificationService = NotificationService.shared
    
    var body: some View {
        NotificationBadge(count: notificationService.unreadCount)
            .task {
                await notificationService.refreshUnreadCount()
            }
    }
}

#Preview {
    VStack(spacing: 20) {
        NotificationBadge(count: 1)
        NotificationBadge(count: 9)
        NotificationBadge(count: 15)
        NotificationBadge(count: 99)
        NotificationBadge(count: 100)
    }
    .padding()
}
