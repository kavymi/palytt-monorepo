//
//  Mention.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation
import SwiftUI

// MARK: - Mention Type

/// The type of mention in a post or comment
enum MentionType: String, Codable, CaseIterable {
    case user = "user"           // @username
    case place = "place"         // @placename
    case hashtag = "hashtag"     // #hashtag
    
    var prefix: String {
        switch self {
        case .user, .place:
            return "@"
        case .hashtag:
            return "#"
        }
    }
    
    var icon: String {
        switch self {
        case .user:
            return "person.fill"
        case .place:
            return "mappin.circle.fill"
        case .hashtag:
            return "number"
        }
    }
    
    var color: Color {
        switch self {
        case .user:
            return .primaryBrand
        case .place:
            return .blueAccent
        case .hashtag:
            return .milkTea
        }
    }
    
    var deepLinkScheme: String {
        switch self {
        case .user:
            return "palytt://user/"
        case .place:
            return "palytt://place/"
        case .hashtag:
            return "palytt://hashtag/"
        }
    }
}

// MARK: - Mention Model

/// Represents a mention (@user, @place, or #hashtag) within text content
struct Mention: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let type: MentionType
    let text: String              // The display text (without prefix)
    let targetId: String          // The ID of the referenced entity (userId, placeId, or hashtag string)
    let range: MentionRange       // The position in the original text
    
    init(
        id: UUID = UUID(),
        type: MentionType,
        text: String,
        targetId: String,
        range: MentionRange
    ) {
        self.id = id
        self.type = type
        self.text = text
        self.targetId = targetId
        self.range = range
    }
    
    /// The full display text including prefix (@username, #hashtag)
    var displayText: String {
        "\(type.prefix)\(text)"
    }
    
    /// The deep link URL for this mention
    var deepLinkURL: URL? {
        URL(string: "\(type.deepLinkScheme)\(targetId)")
    }
    
    /// Create a user mention
    static func user(username: String, userId: String, range: MentionRange) -> Mention {
        Mention(
            type: .user,
            text: username,
            targetId: userId,
            range: range
        )
    }
    
    /// Create a place mention
    static func place(name: String, placeId: String, range: MentionRange) -> Mention {
        Mention(
            type: .place,
            text: name,
            targetId: placeId,
            range: range
        )
    }
    
    /// Create a hashtag mention
    static func hashtag(tag: String, range: MentionRange) -> Mention {
        Mention(
            type: .hashtag,
            text: tag,
            targetId: tag, // For hashtags, targetId is the tag itself
            range: range
        )
    }
}

// MARK: - Mention Range

/// Represents the position of a mention within text
struct MentionRange: Codable, Equatable, Hashable {
    let start: Int
    let end: Int
    
    var length: Int {
        end - start
    }
    
    init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }
    
    init(nsRange: NSRange) {
        self.start = nsRange.location
        self.end = nsRange.location + nsRange.length
    }
    
    var nsRange: NSRange {
        NSRange(location: start, length: length)
    }
}

// MARK: - Mention Detection

/// Utility for detecting and parsing mentions in text
struct MentionDetector {
    
    /// Regex pattern for detecting @mentions (users and places)
    private static let atMentionPattern = #"@(\w+)"#
    
    /// Regex pattern for detecting #hashtags
    private static let hashtagPattern = #"#(\w+)"#
    
    /// Detect all mentions in a given text
    /// Note: This returns detected patterns only - actual resolution of whether
    /// it's a user or place requires backend lookup
    static func detectMentions(in text: String) -> [DetectedMention] {
        var detected: [DetectedMention] = []
        
        // Detect @mentions
        if let regex = try? NSRegularExpression(pattern: atMentionPattern, options: []) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, options: [], range: range)
            
            for match in matches {
                if let textRange = Range(match.range(at: 1), in: text) {
                    let mentionText = String(text[textRange])
                    detected.append(DetectedMention(
                        text: mentionText,
                        fullMatch: "@\(mentionText)",
                        range: MentionRange(nsRange: match.range),
                        isHashtag: false
                    ))
                }
            }
        }
        
        // Detect #hashtags
        if let regex = try? NSRegularExpression(pattern: hashtagPattern, options: []) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, options: [], range: range)
            
            for match in matches {
                if let textRange = Range(match.range(at: 1), in: text) {
                    let hashtagText = String(text[textRange])
                    detected.append(DetectedMention(
                        text: hashtagText,
                        fullMatch: "#\(hashtagText)",
                        range: MentionRange(nsRange: match.range),
                        isHashtag: true
                    ))
                }
            }
        }
        
        // Sort by position in text
        return detected.sorted { $0.range.start < $1.range.start }
    }
    
    /// Check if the cursor is currently in a mention context
    /// Returns the partial text being typed and the trigger character
    static func getCurrentMentionContext(text: String, cursorPosition: Int) -> MentionContext? {
        guard cursorPosition > 0, cursorPosition <= text.count else { return nil }
        
        let textBeforeCursor = String(text.prefix(cursorPosition))
        
        // Find the last @ or # before cursor
        var lastTriggerIndex: String.Index?
        var lastTriggerChar: Character?
        
        for (index, char) in textBeforeCursor.enumerated().reversed() {
            if char == "@" || char == "#" {
                lastTriggerIndex = textBeforeCursor.index(textBeforeCursor.startIndex, offsetBy: index)
                lastTriggerChar = char
                break
            }
            // Stop if we hit a space or newline
            if char.isWhitespace {
                break
            }
        }
        
        guard let triggerIndex = lastTriggerIndex,
              let triggerChar = lastTriggerChar else {
            return nil
        }
        
        // Extract the text after the trigger
        let afterTrigger = textBeforeCursor[textBeforeCursor.index(after: triggerIndex)...]
        let query = String(afterTrigger)
        
        // Validate: query should not contain spaces
        guard !query.contains(" ") else { return nil }
        
        let triggerPosition = textBeforeCursor.distance(from: textBeforeCursor.startIndex, to: triggerIndex)
        
        return MentionContext(
            trigger: triggerChar,
            query: query,
            triggerPosition: triggerPosition,
            isHashtag: triggerChar == "#"
        )
    }
}

// MARK: - Detected Mention

/// A mention pattern detected in text (before resolution)
struct DetectedMention {
    let text: String          // The mention text without prefix
    let fullMatch: String     // The full match including @ or #
    let range: MentionRange
    let isHashtag: Bool
}

// MARK: - Mention Context

/// Context about a mention being typed
struct MentionContext {
    let trigger: Character    // @ or #
    let query: String         // The text being typed after trigger
    let triggerPosition: Int  // Position of the trigger in the text
    let isHashtag: Bool
    
    var isSearchable: Bool {
        // Only search if we have at least 1 character
        query.count >= 1
    }
}

// MARK: - Mention Suggestion

/// A suggestion for autocomplete
struct MentionSuggestion: Identifiable, Equatable {
    let id: String
    let type: MentionType
    let displayText: String
    let subtitle: String?
    let avatarURL: URL?
    let targetId: String
    
    static func user(user: User) -> MentionSuggestion {
        MentionSuggestion(
            id: user.clerkId ?? user.id.uuidString,
            type: .user,
            displayText: user.username,
            subtitle: user.displayName,
            avatarURL: user.avatarURL,
            targetId: user.clerkId ?? user.id.uuidString
        )
    }
    
    static func place(shop: Shop) -> MentionSuggestion {
        MentionSuggestion(
            id: shop.id.uuidString,
            type: .place,
            displayText: shop.name,
            subtitle: shop.location.address,
            avatarURL: shop.featuredImageURL,
            targetId: shop.id.uuidString
        )
    }
    
    static func hashtag(tag: String) -> MentionSuggestion {
        MentionSuggestion(
            id: tag,
            type: .hashtag,
            displayText: tag,
            subtitle: nil,
            avatarURL: nil,
            targetId: tag
        )
    }
}

// MARK: - Backend Conversion

extension Mention {
    /// Convert from backend mention data
    static func from(backendMention: BackendMention) -> Mention {
        Mention(
            id: UUID(),
            type: MentionType(rawValue: backendMention.type) ?? .user,
            text: backendMention.text,
            targetId: backendMention.targetId,
            range: MentionRange(start: backendMention.start, end: backendMention.end)
        )
    }
    
    /// Convert to backend mention data
    func toBackend() -> BackendMention {
        BackendMention(
            type: type.rawValue,
            text: text,
            targetId: targetId,
            start: range.start,
            end: range.end
        )
    }
}

/// Backend representation of a mention
struct BackendMention: Codable {
    let type: String
    let text: String
    let targetId: String
    let start: Int
    let end: Int
}


