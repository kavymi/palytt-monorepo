//
//  OfflineSupportManager.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Combine
import Foundation
import Network

// MARK: - Offline Support Manager
@MainActor
class OfflineSupportManager: ObservableObject {
    static let shared = OfflineSupportManager()
    
    @Published var isOnline = true
    @Published var connectionStatus = "Online"
    @Published var offlineQueueCount = 0
    @Published var syncStatus = SyncStatus.synced
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var offlineQueue: [OfflineAction] = []
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNetworkMonitoring()
        loadOfflineQueue()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateConnectionStatus(path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func updateConnectionStatus(_ online: Bool) {
        let wasOffline = !isOnline
        isOnline = online
        connectionStatus = online ? "Online" : "Offline"
        
        if online && wasOffline {
            // Just came back online, sync offline actions
            Task {
                await syncOfflineActions()
            }
        }
    }
    
    // MARK: - Offline Queue Management
    
    func queueAction(_ action: OfflineAction) {
        offlineQueue.append(action)
        offlineQueueCount = offlineQueue.count
        saveOfflineQueue()
        
        if isOnline {
            Task {
                await syncOfflineActions()
            }
        }
    }
    
    private func syncOfflineActions() async {
        guard isOnline && !offlineQueue.isEmpty else { return }
        
        syncStatus = .syncing
        
        var successfulActions: [String] = []
        
        for action in offlineQueue {
            do {
                switch action.type {
                case .createPost:
                    try await syncCreatePost(action)
                case .likePost:
                    try await syncLikePost(action)
                case .commentOnPost:
                    try await syncCommentOnPost(action)
                case .followUser:
                    try await syncFollowUser(action)
                case .unfollowUser:
                    try await syncUnfollowUser(action)
                case .updateProfile:
                    try await syncUpdateProfile(action)
                case .sendMessage:
                    try await syncSendMessage(action)
                }
                
                successfulActions.append(action.id)
                print("✅ Synced offline action: \(action.type.rawValue)")
                
            } catch {
                print("❌ Failed to sync action \(action.type.rawValue): \(error)")
            }
        }
        
        // Remove successful actions
        offlineQueue.removeAll { successfulActions.contains($0.id) }
        offlineQueueCount = offlineQueue.count
        saveOfflineQueue()
        
        syncStatus = offlineQueue.isEmpty ? .synced : .pending
    }
    
    // MARK: - Sync Methods
    
    private func syncCreatePost(_ action: OfflineAction) async throws {
        // Implementation would sync with backend
        await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network delay
    }
    
    private func syncLikePost(_ action: OfflineAction) async throws {
        // Implementation would sync with backend
        await Task.sleep(nanoseconds: 500_000_000)
    }
    
    private func syncCommentOnPost(_ action: OfflineAction) async throws {
        // Implementation would sync with backend
        await Task.sleep(nanoseconds: 800_000_000)
    }
    
    private func syncFollowUser(_ action: OfflineAction) async throws {
        // Implementation would sync with backend
        await Task.sleep(nanoseconds: 600_000_000)
    }
    
    private func syncUnfollowUser(_ action: OfflineAction) async throws {
        // Implementation would sync with backend
        await Task.sleep(nanoseconds: 600_000_000)
    }
    
    private func syncUpdateProfile(_ action: OfflineAction) async throws {
        // Implementation would sync with backend
        await Task.sleep(nanoseconds: 1_200_000_000)
    }
    
    private func syncSendMessage(_ action: OfflineAction) async throws {
        // Implementation would sync with backend
        await Task.sleep(nanoseconds: 700_000_000)
    }
    
    // MARK: - Persistence
    
    private func saveOfflineQueue() {
        do {
            let data = try JSONEncoder().encode(offlineQueue)
            UserDefaults.standard.set(data, forKey: "offline_queue")
        } catch {
            print("Failed to save offline queue: \(error)")
        }
    }
    
    private func loadOfflineQueue() {
        guard let data = UserDefaults.standard.data(forKey: "offline_queue") else { return }
        
        do {
            offlineQueue = try JSONDecoder().decode([OfflineAction].self, from: data)
            offlineQueueCount = offlineQueue.count
        } catch {
            print("Failed to load offline queue: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    func clearOfflineQueue() {
        offlineQueue.removeAll()
        offlineQueueCount = 0
        saveOfflineQueue()
        syncStatus = .synced
    }
    
    func retrySync() {
        guard isOnline else { return }
        
        Task {
            await syncOfflineActions()
        }
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - Supporting Models

struct OfflineAction: Codable, Identifiable {
    let id: String
    let type: OfflineActionType
    let data: [String: String] // Simplified for JSON encoding
    let timestamp: Date
    
    init(type: OfflineActionType, data: [String: String] = [:]) {
        self.id = UUID().uuidString
        self.type = type
        self.data = data
        self.timestamp = Date()
    }
}

enum OfflineActionType: String, Codable, CaseIterable {
    case createPost = "create_post"
    case likePost = "like_post"
    case commentOnPost = "comment_on_post"
    case followUser = "follow_user"
    case unfollowUser = "unfollow_user"
    case updateProfile = "update_profile"
    case sendMessage = "send_message"
}

enum SyncStatus {
    case synced
    case pending
    case syncing
    case error
    
    var displayText: String {
        switch self {
        case .synced:
            return "All synced"
        case .pending:
            return "Pending sync"
        case .syncing:
            return "Syncing..."
        case .error:
            return "Sync error"
        }
    }
    
    var color: Color {
        switch self {
        case .synced:
            return .green
        case .pending:
            return .orange
        case .syncing:
            return .blue
        case .error:
            return .red
        }
    }
} 