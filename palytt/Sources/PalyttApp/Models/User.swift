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
    let bio: String?
    let avatarUrl: String?
    let role: String?
    let appleId: String?
    let googleId: String?
    let dietaryPreferences: [String]?
    let followersCount: Int
    let followingCount: Int
    let postsCount: Int
    let isVerified: Bool
    let isActive: Bool
    let createdAt: Int
    let updatedAt: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId
        case clerkId
        case email
        case firstName
        case lastName
        case username
        case displayName
        case bio
        case avatarUrl
        case role
        case appleId
        case googleId
        case dietaryPreferences
        case followersCount
        case followingCount
        case postsCount
        case isVerified
        case isActive
        case createdAt
        case updatedAt
    }
    
    // Computed property to ensure we always have a userId
    var effectiveUserId: String {
        return userId ?? clerkId
    }
    
    func toUser() -> User {
        // Convert string dietary preferences to enum
        let preferences = dietaryPreferences?.compactMap { 
            DietaryPreference(rawValue: $0) 
        } ?? []
        
        // Convert role string to UserRole enum, default to .user
        let userRole = UserRole(rawValue: role ?? "user") ?? .user
        
        // Convert timestamp to Date
        let joinedAt = Date(timeIntervalSince1970: Double(createdAt) / 1000)
        
        return User(
            id: UUID(uuidString: id ?? effectiveUserId) ?? UUID(),
            email: email ?? "",
            firstName: firstName,
            lastName: lastName,
            username: username ?? "user_\(clerkId.prefix(8))",
            displayName: displayName,
            bio: bio,
            avatarURL: avatarUrl != nil ? URL(string: avatarUrl!) : nil,
            clerkId: clerkId,
            role: userRole,
            dietaryPreferences: preferences,
            joinedAt: joinedAt,
            followersCount: followersCount,
            followingCount: followingCount,
            postsCount: postsCount
        )
    }
    
    static func from(_ dictionary: [String: Any]) -> BackendUser? {
        guard let clerkId = dictionary["clerkId"] as? String else {
            return nil
        }
        
        let userId = dictionary["userId"] as? String  // Can be nil for sender objects
        let email = dictionary["email"] as? String   // Can be nil for sender objects
        
        return BackendUser(
            id: dictionary["_id"] as? String,
            userId: userId,
            clerkId: clerkId,
            email: email,
            firstName: dictionary["firstName"] as? String,
            lastName: dictionary["lastName"] as? String,
            username: dictionary["username"] as? String,
            displayName: dictionary["displayName"] as? String,
            bio: dictionary["bio"] as? String,
            avatarUrl: dictionary["avatarUrl"] as? String,
            role: dictionary["role"] as? String,
            appleId: dictionary["appleId"] as? String,
            googleId: dictionary["googleId"] as? String,
            dietaryPreferences: dictionary["dietaryPreferences"] as? [String],
            followersCount: dictionary["followersCount"] as? Int ?? 0,
            followingCount: dictionary["followingCount"] as? Int ?? 0,
            postsCount: dictionary["postsCount"] as? Int ?? 0,
            isVerified: dictionary["isVerified"] as? Bool ?? false,
            isActive: dictionary["isActive"] as? Bool ?? true,
            createdAt: dictionary["createdAt"] as? Int ?? Int(Date().timeIntervalSince1970 * 1000),
            updatedAt: dictionary["updatedAt"] as? Int ?? Int(Date().timeIntervalSince1970 * 1000)
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
        case .vegan: return "🌱"
        case .vegetarian: return "🥗"
        case .glutenFree: return "🌾"
        case .dairyFree: return "🥛"
        case .halal: return "☪️"
        case .kosher: return "✡️"
        case .nutFree: return "🥜"
        case .pescatarian: return "🐟"
        case .keto: return "🥑"
        case .paleo: return ""
        }
    }
} 