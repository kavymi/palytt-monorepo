//
//  MessageCacheManager.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import OSLog

@globalActor
actor MessageCacheActor {
    static let shared = MessageCacheActor()
    
    private init() {}
}

@MessageCacheActor
class MessageCacheManager {
    static let shared = MessageCacheManager()
    
    private let logger = Logger(subsystem: "com.palytt.app", category: "MessageCache")
    private let cacheLimit = 1000 // Maximum messages per chatroom
    
    // MARK: - In-Memory Cache
    private var messageCache: [String: [BackendService.Message]] = [:]
    
    private init() {}
    
    // MARK: - Message Caching
    func cacheMessage(_ message: BackendService.Message) async throws {
        if messageCache[message.chatroomId] == nil {
            messageCache[message.chatroomId] = []
        }
        
        // Remove existing message if it exists (for updates)
        messageCache[message.chatroomId]?.removeAll { $0._id == message._id }
        
        // Add new message
        messageCache[message.chatroomId]?.append(message)
        
        // Sort by creation time
        messageCache[message.chatroomId]?.sort { $0.createdAt < $1.createdAt }
        
        // Clean up old messages if we exceed limit
        await maintainCacheLimit(for: message.chatroomId)
        
        logger.info("Cached message: \(message._id)")
    }
    
    func cacheMessages(_ messages: [BackendService.Message], for chatroomId: String) async throws {
        // Clear existing messages for this chatroom
        messageCache[chatroomId] = []
        
        for message in messages {
            try await cacheMessage(message)
        }
    }
    
    func getCachedMessages(for chatroomId: String, limit: Int = 50) async -> [BackendService.Message] {
        guard let messages = messageCache[chatroomId] else { return [] }
        return Array(messages.suffix(limit))
    }
    
    func getLatestMessage(for chatroomId: String) async -> BackendService.Message? {
        guard let messages = messageCache[chatroomId], !messages.isEmpty else { return nil }
        return messages.last
    }
    
    private func maintainCacheLimit(for chatroomId: String) async {
        guard let messages = messageCache[chatroomId], messages.count > cacheLimit else { return }
        
        let messagesToKeep = Array(messages.suffix(cacheLimit))
        messageCache[chatroomId] = messagesToKeep
        
        let removedCount = messages.count - messagesToKeep.count
        logger.info("Cleaned up \(removedCount) old messages for chatroom: \(chatroomId)")
    }
    
    // MARK: - Cache Management
    func clearCache() async {
        messageCache.removeAll()
        logger.info("Cleared all message cache")
    }
    
    func clearCache(for chatroomId: String) async {
        messageCache[chatroomId] = []
        logger.info("Cleared cache for chatroom: \(chatroomId)")
    }
    
    func getCacheSize() async -> String {
        let totalMessages = messageCache.values.reduce(0) { $0 + $1.count }
        return "\(totalMessages) messages cached"
    }
    
    func getMessageCount(for chatroomId: String) async -> Int {
        return messageCache[chatroomId]?.count ?? 0
    }
    
    func hasCachedMessages(for chatroomId: String) async -> Bool {
        guard let messages = messageCache[chatroomId] else { return false }
        return !messages.isEmpty
    }
} 