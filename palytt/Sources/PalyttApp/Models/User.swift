//
//  User.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation

// MARK: - User Roles
enum UserRole: String, CaseIterable, Codable {
    case user = "user"
    case admin = "admin"
    
    var displayName: String {
        switch self {
        case .user: return "User"
        case .admin: return "Admin"
        }
    }
    
    var hasAdminAccess: Bool {
        return self == .admin
    }
}

// MARK: - User Model
struct User: Identifiable, Codable, Equatable {
    let id: UUID
    let email: String
    let firstName: String?
    let lastName: String?
    let username: String
    let displayName: String
    let bio: String?
    let avatarURL: URL?
    let clerkId: String?
    let role: UserRole
    let dietaryPreferences: [DietaryPreference]
    let location: Location?
    let joinedAt: Date
    let followersCount: Int
    let followingCount: Int
    let postsCount: Int
    
    init(
        id: UUID = UUID(),
        email: String,
        firstName: String? = nil,
        lastName: String? = nil,
        username: String,
        displayName: String? = nil,
        bio: String? = nil,
        avatarURL: URL? = nil,
        clerkId: String? = nil,
        role: UserRole = .user,
        dietaryPreferences: [DietaryPreference] = [],
        location: Location? = nil,
        joinedAt: Date = Date(),
        followersCount: Int = 0,
        followingCount: Int = 0,
        postsCount: Int = 0
    ) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        // Generate display name from firstName/lastName if not provided
        if let displayName = displayName {
            self.displayName = displayName
        } else if let firstName = firstName, let lastName = lastName {
            self.displayName = "\(firstName) \(lastName)"
        } else if let firstName = firstName {
            self.displayName = firstName
        } else {
            self.displayName = username
        }
        self.bio = bio
        self.avatarURL = avatarURL
        self.clerkId = clerkId
        self.role = role
        self.dietaryPreferences = dietaryPreferences
        self.location = location
        self.joinedAt = joinedAt
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.postsCount = postsCount
    }
    
    // MARK: - Role-based Access
    var isAdmin: Bool {
        return role.hasAdminAccess
    }
    
    var canSwitchAPIEndpoints: Bool {
        return isAdmin
    }
    
    var canViewAdminSettings: Bool {
        return isAdmin
    }
}

// MARK: - Backend Response Types
struct BackendUser: Codable {
    let id: String?
    let userId: String?  // Made optional to handle missing field in sender objects
    let clerkId: String
    let email: String?   // Made optional to handle incomplete sender objects
    let firstName: String?
    let lastName: String?
    let username: String?
    let displayName: String?
    let name: String?  // Backend returns "name" instead of firstName/lastName sometimes
    let bio: String?
    let avatarUrl: String?
    let profileImage: String?  // Backend uses profileImage, iOS uses avatarUrl
    let role: String?
    let appleId: String?
    let googleId: String?
    let dietaryPreferences: [String]?
    let followerCount: Int?  // Backend uses singular form
    let followingCount: Int?
    let postsCount: Int?
    let isVerified: Bool?
    let isActive: Bool?
    let createdAt: CreatedAtValue?  // Can be ISO string or timestamp
    let updatedAt: UpdatedAtValue?  // Can be ISO string or timestamp
    
    // Computed properties to handle different field names
    var followersCount: Int {
        return followerCount ?? 0
    }
    
    var effectiveFollowingCount: Int {
        return followingCount ?? 0
    }
    
    var effectivePostsCount: Int {
        return postsCount ?? 0
    }
    
    var effectiveIsVerified: Bool {
        return isVerified ?? false
    }
    
    var effectiveIsActive: Bool {
        return isActive ?? true
    }
    
    // Helper to parse createdAt timestamp
    var createdAtTimestamp: Int {
        switch createdAt {
        case .timestamp(let ts):
            return ts
        case .isoString(let str):
            if let date = ISO8601DateFormatter().date(from: str) {
                return Int(date.timeIntervalSince1970 * 1000)
            }
            return Int(Date().timeIntervalSince1970 * 1000)
        case .none:
            return Int(Date().timeIntervalSince1970 * 1000)
        }
    }
    
    // Helper to parse updatedAt timestamp
    var updatedAtTimestamp: Int {
        switch updatedAt {
        case .timestamp(let ts):
            return ts
        case .isoString(let str):
            if let date = ISO8601DateFormatter().date(from: str) {
                return Int(date.timeIntervalSince1970 * 1000)
            }
            return Int(Date().timeIntervalSince1970 * 1000)
        case .none:
            return Int(Date().timeIntervalSince1970 * 1000)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case clerkId
        case email
        case firstName
        case lastName
        case username
        case displayName
        case name
        case bio
        case avatarUrl
        case profileImage
        case role
        case appleId
        case googleId
        case dietaryPreferences
        case followerCount
        case followingCount
        case postsCount
        case isVerified
        case isActive
        case createdAt
        case updatedAt
    }
}

// Helper enum to handle both ISO string and timestamp for dates
enum CreatedAtValue: Codable {
    case timestamp(Int)
    case isoString(String)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .timestamp(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .isoString(stringValue)
        } else {
            throw DecodingError.typeMismatch(CreatedAtValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected Int or String"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .timestamp(let value):
            try container.encode(value)
        case .isoString(let value):
            try container.encode(value)
        }
    }
}

enum UpdatedAtValue: Codable {
    case timestamp(Int)
    case isoString(String)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .timestamp(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .isoString(stringValue)
        } else {
            throw DecodingError.typeMismatch(UpdatedAtValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected Int or String"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .timestamp(let value):
            try container.encode(value)
        case .isoString(let value):
            try container.encode(value)
        }
    }
}

extension BackendUser {
    
    // Computed property to ensure we always have a userId
    var effectiveUserId: String {
        return userId ?? clerkId
    }
    
    // Computed property to get avatar URL from either field
    var effectiveAvatarUrl: String? {
        return profileImage ?? avatarUrl
    }
    
    // Parse name into firstName and lastName
    var parsedFirstName: String? {
        if let firstName = firstName, !firstName.isEmpty {
            return firstName
        }
        if let name = name {
            let parts = name.split(separator: " ")
            return parts.first.map(String.init)
        }
        return nil
    }
    
    var parsedLastName: String? {
        if let lastName = lastName, !lastName.isEmpty {
            return lastName
        }
        if let name = name {
            let parts = name.split(separator: " ")
            if parts.count > 1 {
                return parts.dropFirst().joined(separator: " ")
            }
        }
        return nil
    }
    
    func toUser() -> User {
        // Convert string dietary preferences to enum
        let preferences = dietaryPreferences?.compactMap { 
            DietaryPreference(rawValue: $0) 
        } ?? []
        
        // Convert role string to UserRole enum, default to .user
        let userRole = UserRole(rawValue: role ?? "user") ?? .user
        
        // Convert timestamp to Date
        let joinedAt = Date(timeIntervalSince1970: Double(createdAtTimestamp) / 1000)
        
        return User(
            id: UUID(uuidString: id ?? effectiveUserId) ?? UUID(),
            email: email ?? "",
            firstName: parsedFirstName,
            lastName: parsedLastName,
            username: username ?? "user_\(clerkId.prefix(8))",
            displayName: displayName ?? name,
            bio: bio,
            avatarURL: effectiveAvatarUrl != nil ? URL(string: effectiveAvatarUrl!) : nil,
            clerkId: clerkId,
            role: userRole,
            dietaryPreferences: preferences,
            joinedAt: joinedAt,
            followersCount: followersCount,
            followingCount: effectiveFollowingCount,
            postsCount: effectivePostsCount
        )
    }
    
    static func from(_ dictionary: [String: Any]) -> BackendUser? {
        guard let clerkId = dictionary["clerkId"] as? String else {
            return nil
        }
        
        let userId = dictionary["userId"] as? String  // Can be nil for sender objects
        let email = dictionary["email"] as? String   // Can be nil for sender objects
        
        // Parse createdAt - can be Int or String
        let createdAtValue: CreatedAtValue?
        if let intValue = dictionary["createdAt"] as? Int {
            createdAtValue = .timestamp(intValue)
        } else if let stringValue = dictionary["createdAt"] as? String {
            createdAtValue = .isoString(stringValue)
        } else {
            createdAtValue = nil
        }
        
        // Parse updatedAt - can be Int or String
        let updatedAtValue: UpdatedAtValue?
        if let intValue = dictionary["updatedAt"] as? Int {
            updatedAtValue = .timestamp(intValue)
        } else if let stringValue = dictionary["updatedAt"] as? String {
            updatedAtValue = .isoString(stringValue)
        } else {
            updatedAtValue = nil
        }
        
        return BackendUser(
            id: dictionary["id"] as? String ?? dictionary["_id"] as? String,
            userId: userId,
            clerkId: clerkId,
            email: email,
            firstName: dictionary["firstName"] as? String,
            lastName: dictionary["lastName"] as? String,
            username: dictionary["username"] as? String,
            displayName: dictionary["displayName"] as? String,
            name: dictionary["name"] as? String,
            bio: dictionary["bio"] as? String,
            avatarUrl: dictionary["avatarUrl"] as? String,
            profileImage: dictionary["profileImage"] as? String,
            role: dictionary["role"] as? String,
            appleId: dictionary["appleId"] as? String,
            googleId: dictionary["googleId"] as? String,
            dietaryPreferences: dictionary["dietaryPreferences"] as? [String],
            followerCount: dictionary["followerCount"] as? Int ?? dictionary["followersCount"] as? Int,
            followingCount: dictionary["followingCount"] as? Int,
            postsCount: dictionary["postsCount"] as? Int,
            isVerified: dictionary["isVerified"] as? Bool,
            isActive: dictionary["isActive"] as? Bool,
            createdAt: createdAtValue,
            updatedAt: updatedAtValue
        )
    }
}

enum DietaryPreference: String, CaseIterable, Codable {
    case dairyFree = "Dairy Free"
    case glutenFree = "Gluten Free"
    case halal = "Halal"
    case keto = "Keto"
    case kosher = "Kosher"
    case nutFree = "Nut Free"
    case paleo = "Paleo"
    case pescatarian = "Pescatarian"
    case vegan = "Vegan"
    case vegetarian = "Vegetarian"
    
    var icon: String {
        switch self {
        case .dairyFree: return "🥛"
        case .glutenFree: return "🌾"
        case .halal: return "☪️"
        case .keto: return "🥑"
        case .kosher: return "✡️"
        case .nutFree: return "🥜"
        case .paleo: return ""
        case .pescatarian: return "🐟"
        case .vegan: return "🌱"
        case .vegetarian: return "🥗"
        }
    }
} 