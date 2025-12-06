//
//  PresenceService.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
//  Real-time presence, typing indicators, and live notifications using Convex.
//

import Foundation
import Combine
import SwiftUI
import Clerk

#if canImport(ConvexMobile)
import ConvexMobile
#endif

// MARK: - Presence Status

enum PresenceStatus: String, Codable {
    case online
    case away
    case offline
    
    var displayText: String {
        switch self {
        case .online: return "Online"
        case .away: return "Away"
        case .offline: return "Offline"
        }
    }
    
    var color: Color {
        switch self {
        case .online: return .green
        case .away: return .orange
        case .offline: return .gray
        }
    }
}

// MARK: - User Presence

struct UserPresence: Codable, Identifiable {
    let clerkId: String
    let status: PresenceStatus
    let lastSeen: Int64?
    let currentScreen: String?
    
    var id: String { clerkId }
    
    var lastSeenDate: Date? {
        guard let lastSeen = lastSeen else { return nil }
        return Date(timeIntervalSince1970: Double(lastSeen) / 1000.0)
    }
    
    var lastSeenText: String {
        guard let date = lastSeenDate else { return "Never" }
        
        let now = Date()
        let diff = now.timeIntervalSince(date)
        
        if diff < 60 {
            return "Just now"
        } else if diff < 3600 {
            let minutes = Int(diff / 60)
            return "\(minutes)m ago"
        } else if diff < 86400 {
            let hours = Int(diff / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(diff / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: Codable, Identifiable {
    let clerkId: String
    let userName: String?
    let userProfileImage: String?
    let startedAt: Int64
    
    var id: String { clerkId }
}

// MARK: - Presence Service

@MainActor
class PresenceService: ObservableObject {
    static let shared = PresenceService()
    
    // MARK: - Published Properties
    
    /// Current user's presence status
    @Published var myStatus: PresenceStatus = .offline
    
    /// Online friends (Clerk IDs -> presence data)
    @Published var onlineFriends: [String: UserPresence] = [:]
    
    /// Users currently typing in chatrooms (chatroom ID -> typing users)
    @Published var typingIndicators: [String: [TypingIndicator]] = [:]
    
    /// Service status
    @Published var isConnected: Bool = false
    @Published var error: String?
    
    // MARK: - Private Properties
    
    #if canImport(ConvexMobile)
    private var convexClient: ConvexClient?
    #endif
    
    private var heartbeatTimer: Timer?
    private var cleanupTimer: Timer?
    private let heartbeatInterval: TimeInterval = 30.0
    private let apiConfig = APIConfigurationManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupConvexClient()
        setupAppLifecycleObservers()
    }
    
    deinit {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        cleanupTimer?.invalidate()
    }
    
    // MARK: - Setup
    
    private func setupConvexClient() {
        #if canImport(ConvexMobile)
        // Check architecture support
        guard BackendService.shared.isConvexAvailable else {
            print("🟡 PresenceService: Convex not available on this architecture")
            return
        }
        
        let deploymentUrl = apiConfig.convexDeploymentURL
        convexClient = ConvexClient(deploymentUrl: deploymentUrl)
        isConnected = true
        print("🟢 PresenceService: Convex client initialized with URL: \(deploymentUrl)")
        #else
        print("🟡 PresenceService: ConvexMobile not available")
        #endif
    }
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.setOnline()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.setAway()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.setOffline()
                }
            }
            .store(in: &cancellables)
        
        // Listen for API environment changes
        NotificationCenter.default.publisher(for: .apiEnvironmentChanged)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.setupConvexClient()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Presence Management
    
    /// Set current user as online and start heartbeat
    func setOnline() async {
        guard getCurrentClerkId() != nil else {
            print("⚠️ PresenceService: No Clerk ID available")
            return
        }
        
        myStatus = .online
        await updatePresence(status: .online)
        startHeartbeat()
        print("🟢 PresenceService: User is now online")
    }
    
    /// Set current user as away
    func setAway() async {
        guard let _ = getCurrentClerkId() else { return }
        
        myStatus = .away
        await updatePresence(status: .away)
        stopHeartbeat()
        print("🟡 PresenceService: User is now away")
    }
    
    /// Set current user as offline
    func setOffline() async {
        guard let clerkId = getCurrentClerkId() else { return }
        
        myStatus = .offline
        stopHeartbeat()
        
        #if canImport(ConvexMobile)
        guard let client = convexClient else { return }
        
        do {
            let args: [String: ConvexEncodable] = ["clerkId": clerkId]
            _ = try await client.mutation("presence:setOffline", with: args)
            print("🔴 PresenceService: User is now offline")
        } catch {
            print("❌ PresenceService: Failed to set offline: \(error)")
        }
        #endif
    }
    
    private func updatePresence(status: PresenceStatus, currentScreen: String? = nil) async {
        #if canImport(ConvexMobile)
        guard let client = convexClient,
              let clerkId = getCurrentClerkId() else { return }
        
        do {
            var args: [String: ConvexEncodable] = [
                "clerkId": clerkId,
                "status": status.rawValue,
                "deviceType": "ios"
            ]
            if let screen = currentScreen {
                args["currentScreen"] = screen
            }
            
            _ = try await client.mutation("presence:updatePresence", with: args)
        } catch {
            self.error = "Failed to update presence: \(error.localizedDescription)"
            print("❌ PresenceService: \(self.error ?? "")")
        }
        #endif
    }
    
    // MARK: - Heartbeat
    
    private func startHeartbeat() {
        stopHeartbeat()
        
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.sendHeartbeat()
            }
        }
        
        // Send initial heartbeat
        Task {
            await sendHeartbeat()
        }
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func sendHeartbeat() async {
        #if canImport(ConvexMobile)
        guard let client = convexClient,
              let clerkId = getCurrentClerkId() else { return }
        
        do {
            let args: [String: ConvexEncodable] = ["clerkId": clerkId]
            _ = try await client.mutation("presence:heartbeat", with: args)
            print("💓 PresenceService: Heartbeat sent")
        } catch {
            print("❌ PresenceService: Heartbeat failed: \(error)")
        }
        #endif
    }
    
    // MARK: - Friend Presence
    
    /// Get presence for a single user
    func getUserPresence(clerkId: String) async -> UserPresence? {
        #if canImport(ConvexMobile)
        guard let client = convexClient else { return nil }
        
        do {
            let args: [String: ConvexEncodable] = ["clerkId": clerkId]
            let result: UserPresence = try await client.query("presence:getUserPresence", with: args)
            return result
        } catch {
            print("❌ PresenceService: Failed to get user presence: \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }
    
    /// Get presence for multiple users
    func getBatchPresence(clerkIds: [String]) async -> [String: UserPresence] {
        #if canImport(ConvexMobile)
        guard let client = convexClient else { return [:] }
        
        do {
            let args: [String: ConvexEncodable] = ["clerkIds": clerkIds]
            let result: [String: UserPresence] = try await client.query("presence:getBatchPresence", with: args)
            return result
        } catch {
            print("❌ PresenceService: Failed to get batch presence: \(error)")
            return [:]
        }
        #else
        return [:]
        #endif
    }
    
    /// Subscribe to online friends updates
    func subscribeToOnlineFriends(friendClerkIds: [String]) {
        #if canImport(ConvexMobile)
        guard let client = convexClient else { return }
        
        Task {
            do {
                let args: [String: ConvexEncodable] = ["friendClerkIds": friendClerkIds]
                
                for try await friends in client.subscribe(to: "presence:getOnlineFriends", with: args) as AsyncThrowingStream<[UserPresence], Error> {
                    await MainActor.run {
                        var newOnlineFriends: [String: UserPresence] = [:]
                        for friend in friends {
                            newOnlineFriends[friend.clerkId] = friend
                        }
                        self.onlineFriends = newOnlineFriends
                        print("👥 PresenceService: Updated online friends (\(friends.count) online)")
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to subscribe to friends: \(error.localizedDescription)"
                    print("❌ PresenceService: \(self.error ?? "")")
                }
            }
        }
        #endif
    }
    
    // MARK: - Typing Indicators
    
    /// Start typing indicator in a chatroom
    func startTyping(chatroomId: String, userName: String? = nil, userProfileImage: String? = nil) async {
        #if canImport(ConvexMobile)
        guard let client = convexClient,
              let clerkId = getCurrentClerkId() else { return }
        
        do {
            var args: [String: ConvexEncodable] = [
                "clerkId": clerkId,
                "chatroomId": chatroomId
            ]
            if let name = userName {
                args["userName"] = name
            }
            if let image = userProfileImage {
                args["userProfileImage"] = image
            }
            
            _ = try await client.mutation("typing:startTyping", with: args)
        } catch {
            print("❌ PresenceService: Failed to start typing: \(error)")
        }
        #endif
    }
    
    /// Stop typing indicator in a chatroom
    func stopTyping(chatroomId: String) async {
        #if canImport(ConvexMobile)
        guard let client = convexClient,
              let clerkId = getCurrentClerkId() else { return }
        
        do {
            let args: [String: ConvexEncodable] = [
                "clerkId": clerkId,
                "chatroomId": chatroomId
            ]
            _ = try await client.mutation("typing:stopTyping", with: args)
        } catch {
            print("❌ PresenceService: Failed to stop typing: \(error)")
        }
        #endif
    }
    
    /// Subscribe to typing indicators in a chatroom
    func subscribeToTyping(chatroomId: String) {
        #if canImport(ConvexMobile)
        guard let client = convexClient,
              let myClerkId = getCurrentClerkId() else { return }
        
        Task {
            do {
                let args: [String: ConvexEncodable] = [
                    "chatroomId": chatroomId,
                    "excludeClerkId": myClerkId
                ]
                
                for try await indicators in client.subscribe(to: "typing:getTypingInChatroom", with: args) as AsyncThrowingStream<[TypingIndicator], Error> {
                    await MainActor.run {
                        self.typingIndicators[chatroomId] = indicators
                        if !indicators.isEmpty {
                            print("⌨️ PresenceService: \(indicators.count) users typing in \(chatroomId)")
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ PresenceService: Failed to subscribe to typing: \(error)")
                }
            }
        }
        #endif
    }
    
    /// Get typing text for a chatroom (e.g., "John is typing..." or "John and 2 others are typing...")
    func getTypingText(for chatroomId: String) -> String? {
        guard let indicators = typingIndicators[chatroomId], !indicators.isEmpty else {
            return nil
        }
        
        if indicators.count == 1 {
            let name = indicators[0].userName ?? "Someone"
            return "\(name) is typing..."
        } else if indicators.count == 2 {
            let name1 = indicators[0].userName ?? "Someone"
            let name2 = indicators[1].userName ?? "someone else"
            return "\(name1) and \(name2) are typing..."
        } else {
            let name = indicators[0].userName ?? "Someone"
            return "\(name) and \(indicators.count - 1) others are typing..."
        }
    }
    
    // MARK: - Helpers
    
    private func getCurrentClerkId() -> String? {
        return Clerk.shared.user?.id
    }
    
    /// Update current screen (for activity tracking)
    func updateCurrentScreen(_ screen: String) async {
        guard myStatus == .online else { return }
        await updatePresence(status: .online, currentScreen: screen)
    }
    
    /// Check if Convex is available
    var isConvexAvailable: Bool {
        #if canImport(ConvexMobile)
        return convexClient != nil
        #else
        return false
        #endif
    }
}

// MARK: - Presence Indicator View

struct PresenceIndicatorView: View {
    let status: PresenceStatus
    let size: CGFloat
    
    init(status: PresenceStatus, size: CGFloat = 10) {
        self.status = status
        self.size = size
    }
    
    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.cardBackground, lineWidth: 2)
            )
    }
}

// MARK: - Convex Typing Indicator View
// Note: This is a Convex-specific typing indicator. MessagesView has its own TypingIndicatorView.

struct ConvexTypingIndicatorView: View {
    let text: String?
    
    @State private var dotOpacity1: Double = 0.3
    @State private var dotOpacity2: Double = 0.3
    @State private var dotOpacity3: Double = 0.3
    
    var body: some View {
        if let typingText = text {
            HStack(spacing: 4) {
                Text(typingText)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                
                // Animated dots
                HStack(spacing: 2) {
                    Circle()
                        .fill(Color.secondaryText)
                        .frame(width: 4, height: 4)
                        .opacity(dotOpacity1)
                    Circle()
                        .fill(Color.secondaryText)
                        .frame(width: 4, height: 4)
                        .opacity(dotOpacity2)
                    Circle()
                        .fill(Color.secondaryText)
                        .frame(width: 4, height: 4)
                        .opacity(dotOpacity3)
                }
            }
            .onAppear {
                startAnimation()
            }
        }
    }
    
    private func startAnimation() {
        withAnimation(Animation.easeInOut(duration: 0.4).repeatForever().delay(0)) {
            dotOpacity1 = 1.0
        }
        withAnimation(Animation.easeInOut(duration: 0.4).repeatForever().delay(0.2)) {
            dotOpacity2 = 1.0
        }
        withAnimation(Animation.easeInOut(duration: 0.4).repeatForever().delay(0.4)) {
            dotOpacity3 = 1.0
        }
    }
}

// MARK: - Preview

#Preview("Presence Indicators") {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            VStack {
                PresenceIndicatorView(status: .online)
                Text("Online").font(.caption)
            }
            VStack {
                PresenceIndicatorView(status: .away)
                Text("Away").font(.caption)
            }
            VStack {
                PresenceIndicatorView(status: .offline)
                Text("Offline").font(.caption)
            }
        }
        
        ConvexTypingIndicatorView(text: "John is typing...")
        ConvexTypingIndicatorView(text: "John and Sarah are typing...")
        ConvexTypingIndicatorView(text: "John and 3 others are typing...")
    }
    .padding()
}
