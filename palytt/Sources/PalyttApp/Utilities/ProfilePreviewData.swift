//
//  ProfilePreviewData.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI
import Foundation

// MARK: - Simple Profile Preview Extensions
extension MockData {
    // Additional mock users for profile previews
    static let profilePreviewUser = User(
        email: "preview@palytt.com",
        username: "profile_preview",
        displayName: "Preview User",
        bio: "This is a preview user for testing the profile view in Xcode",
        clerkId: "preview_user_123",
        followersCount: 500,
        followingCount: 250,
        postsCount: 42
    )
}

// MARK: - Theme Manager for Previews  
extension ThemeManager {
    convenience init() {
        self.init()
    }
}

