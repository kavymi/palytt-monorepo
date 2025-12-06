//
//  DeepLinkRouter.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation
import SwiftUI

// MARK: - Deep Link Destination

/// Represents a destination that can be navigated to via deep link
enum DeepLinkDestination: Hashable {
    case user(userId: String)
    case place(placeId: String)
    case hashtag(tag: String)
    case post(postId: String)
    case shop(shopId: String)
    case gathering(gatheringId: String)
    case notifications
    case messages
    case profile
    case settings
    
    /// The URL scheme prefix for this destination
    var urlScheme: String {
        switch self {
        case .user: return "palytt://user/"
        case .place: return "palytt://place/"
        case .hashtag: return "palytt://hashtag/"
        case .post: return "palytt://post/"
        case .shop: return "palytt://shop/"
        case .gathering: return "palytt://gathering/"
        case .notifications: return "palytt://notifications"
        case .messages: return "palytt://messages"
        case .profile: return "palytt://profile"
        case .settings: return "palytt://settings"
        }
    }
    
    /// The identifier for this destination (if applicable)
    var identifier: String? {
        switch self {
        case .user(let userId): return userId
        case .place(let placeId): return placeId
        case .hashtag(let tag): return tag
        case .post(let postId): return postId
        case .shop(let shopId): return shopId
        case .gathering(let gatheringId): return gatheringId
        default: return nil
        }
    }
    
    /// Create a URL for this destination
    var url: URL? {
        if let identifier = identifier {
            return URL(string: urlScheme + identifier)
        }
        return URL(string: urlScheme)
    }
}

// MARK: - Deep Link Router

/// Handles parsing and navigation for deep links
@MainActor
class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()
    
    @Published var pendingDestination: DeepLinkDestination?
    @Published var navigationPath = NavigationPath()
    
    private init() {}
    
    // MARK: - URL Parsing
    
    /// Parse a URL into a deep link destination
    func parseURL(_ url: URL) -> DeepLinkDestination? {
        guard url.scheme == "palytt" else { return nil }
        
        let host = url.host ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        let identifier = pathComponents.first ?? url.lastPathComponent
        
        switch host {
        case "user":
            guard !identifier.isEmpty else { return nil }
            return .user(userId: identifier)
            
        case "place":
            guard !identifier.isEmpty else { return nil }
            return .place(placeId: identifier)
            
        case "hashtag":
            guard !identifier.isEmpty else { return nil }
            return .hashtag(tag: identifier)
            
        case "post":
            guard !identifier.isEmpty else { return nil }
            return .post(postId: identifier)
            
        case "shop":
            guard !identifier.isEmpty else { return nil }
            return .shop(shopId: identifier)
            
        case "gathering":
            guard !identifier.isEmpty else { return nil }
            return .gathering(gatheringId: identifier)
            
        case "notifications":
            return .notifications
            
        case "messages":
            return .messages
            
        case "profile":
            return .profile
            
        case "settings":
            return .settings
            
        default:
            return nil
        }
    }
    
    /// Parse a URL string into a deep link destination
    func parseURLString(_ urlString: String) -> DeepLinkDestination? {
        guard let url = URL(string: urlString) else { return nil }
        return parseURL(url)
    }
    
    // MARK: - Navigation
    
    /// Navigate to a deep link destination
    func navigate(to destination: DeepLinkDestination, appState: AppState) {
        switch destination {
        case .user(let userId):
            navigateToUser(userId: userId, appState: appState)
            
        case .place(let placeId):
            navigateToPlace(placeId: placeId, appState: appState)
            
        case .hashtag(let tag):
            navigateToHashtag(tag: tag, appState: appState)
            
        case .post(let postId):
            navigateToPost(postId: postId, appState: appState)
            
        case .shop(let shopId):
            navigateToShop(shopId: shopId, appState: appState)
            
        case .gathering(let gatheringId):
            navigateToGathering(gatheringId: gatheringId, appState: appState)
            
        case .notifications:
            appState.selectedTab = .home
            NotificationCenter.default.post(name: .navigateToNotifications, object: nil)
            
        case .messages:
            appState.selectedTab = .friends
            NotificationCenter.default.post(name: .navigateToMessages, object: nil)
            
        case .profile:
            appState.selectedTab = .profile
            
        case .settings:
            appState.selectedTab = .profile
            NotificationCenter.default.post(name: .navigateToSettings, object: nil)
        }
    }
    
    /// Navigate from a URL
    func navigate(from url: URL, appState: AppState) {
        guard let destination = parseURL(url) else {
            print("⚠️ DeepLinkRouter: Unable to parse URL: \(url)")
            return
        }
        navigate(to: destination, appState: appState)
    }
    
    /// Navigate from a mention
    func navigate(from mention: Mention, appState: AppState) {
        let destination: DeepLinkDestination
        
        switch mention.type {
        case .user:
            destination = .user(userId: mention.targetId)
        case .place:
            destination = .place(placeId: mention.targetId)
        case .hashtag:
            destination = .hashtag(tag: mention.targetId)
        }
        
        navigate(to: destination, appState: appState)
    }
    
    // MARK: - Private Navigation Methods
    
    private func navigateToUser(userId: String, appState: AppState) {
        print("📱 DeepLinkRouter: Navigating to user: \(userId)")
        
        // Post notification for user navigation
        NotificationCenter.default.post(
            name: .navigateToUser,
            object: nil,
            userInfo: ["userId": userId]
        )
        
        // Switch to appropriate tab
        appState.selectedTab = .profile
    }
    
    private func navigateToPlace(placeId: String, appState: AppState) {
        print("📱 DeepLinkRouter: Navigating to place: \(placeId)")
        
        // Post notification for place navigation
        NotificationCenter.default.post(
            name: .navigateToPlace,
            object: nil,
            userInfo: ["placeId": placeId]
        )
        
        // Switch to explore tab
        appState.selectedTab = .explore
    }
    
    private func navigateToHashtag(tag: String, appState: AppState) {
        print("📱 DeepLinkRouter: Navigating to hashtag: #\(tag)")
        
        // Clean the tag (remove # if present)
        let cleanTag = tag.hasPrefix("#") ? String(tag.dropFirst()) : tag
        
        // Post notification for hashtag navigation with the clean tag
        NotificationCenter.default.post(
            name: .navigateToHashtag,
            object: nil,
            userInfo: ["hashtag": cleanTag]
        )
    }
    
    private func navigateToPost(postId: String, appState: AppState) {
        print("📱 DeepLinkRouter: Navigating to post: \(postId)")
        
        // Post notification for post navigation
        NotificationCenter.default.post(
            name: .navigateToPost,
            object: nil,
            userInfo: ["postId": postId]
        )
        
        // Switch to home tab
        appState.selectedTab = .home
    }
    
    private func navigateToShop(shopId: String, appState: AppState) {
        print("📱 DeepLinkRouter: Navigating to shop: \(shopId)")
        
        // Post notification for shop navigation
        NotificationCenter.default.post(
            name: .navigateToShop,
            object: nil,
            userInfo: ["shopId": shopId]
        )
        
        // Switch to explore tab
        appState.selectedTab = .explore
    }
    
    private func navigateToGathering(gatheringId: String, appState: AppState) {
        print("📱 DeepLinkRouter: Navigating to gathering: \(gatheringId)")
        
        // Post notification for gathering navigation
        NotificationCenter.default.post(
            name: .navigateToGathering,
            object: nil,
            userInfo: ["gatheringId": gatheringId]
        )
        
        // Switch to friends tab
        appState.selectedTab = .friends
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let navigateToUser = Notification.Name("navigateToUser")
    static let navigateToPlace = Notification.Name("navigateToPlace")
    static let navigateToHashtag = Notification.Name("navigateToHashtag")
    static let navigateToPost = Notification.Name("NavigateToPost")
    static let navigateToShop = Notification.Name("navigateToShop")
    static let navigateToGathering = Notification.Name("navigateToGathering")
    static let navigateToNotifications = Notification.Name("NavigateToNotifications")
    static let navigateToMessages = Notification.Name("NavigateToMessages")
    static let navigateToSettings = Notification.Name("navigateToSettings")
}

// MARK: - Environment Key

private struct DeepLinkRouterKey: EnvironmentKey {
    @MainActor static var defaultValue: DeepLinkRouter { DeepLinkRouter.shared }
}

extension EnvironmentValues {
    @MainActor
    var deepLinkRouter: DeepLinkRouter {
        get { self[DeepLinkRouterKey.self] }
        set { self[DeepLinkRouterKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Handle deep links from this view
    func handleDeepLinks(appState: AppState) -> some View {
        self.onOpenURL { url in
            DeepLinkRouter.shared.navigate(from: url, appState: appState)
        }
    }
}


