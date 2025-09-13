//
//  GroupGathering.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation
import EventKit

// MARK: - Group Gathering Models

/// Represents a group gathering event with comprehensive calendar and voting features
struct GroupGathering: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String?
    let creatorId: String
    let createdAt: Date
    let updatedAt: Date
    
    // Status and lifecycle
    var status: GatheringStatus
    var phase: GatheringPhase
    var isArchived: Bool
    var archivedAt: Date?
    var archivedBy: String?
    
    // Participants
    var participants: [GatheringParticipant]
    var invitations: [GatheringInvitation]
    
    // Time voting and scheduling
    var proposedTimeSlots: [TimeSlot]
    var timeVotes: [TimeVote]
    var finalDateTime: Date?
    var duration: TimeInterval // in seconds
    
    // Venue voting and selection
    var venueRecommendations: [VenueRecommendation]
    var venueVotes: [VenueVote]
    var finalVenue: VenueRecommendation?
    
    // Calendar integration
    var calendarEventId: String? // EventKit event identifier
    var calendarSyncEnabled: Bool
    var reminderSettings: ReminderSettings
    
    // Chat and communication
    var chatThreadId: String?
    var lastMessageAt: Date?
    
    // File uploads and media
    var attachedFiles: [GatheringFile]
    var sharedImages: [GatheringImage]
    var manualVenues: [ManualVenue] // User-added venues not from AI/API
    
    // Post linking and social features
    var linkedPosts: [LinkedPost] // Posts created by participants about this gathering
    var gatheringHashtag: String? // Auto-generated hashtag for this gathering
    
    // Voting permissions and settings
    var votingSettings: VotingSettings
    
    // History and analytics
    var gatheringHistory: GatheringHistory
    
    // Metadata and preferences
    var gatheringType: GatheringType
    var preferenceFilters: PreferenceFilters
    var budget: BudgetRange?
    var location: GatheringLocation
    
    init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        creatorId: String,
        type: GatheringType,
        duration: TimeInterval = 7200, // 2 hours default
        location: GatheringLocation
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.creatorId = creatorId
        self.createdAt = Date()
        self.updatedAt = Date()
        self.status = .planning
        self.phase = .invitation
        self.isArchived = false
        self.participants = []
        self.invitations = []
        self.proposedTimeSlots = []
        self.timeVotes = []
        self.duration = duration
        self.venueRecommendations = []
        self.venueVotes = []
        self.calendarSyncEnabled = true
        self.reminderSettings = ReminderSettings()
        self.gatheringType = type
        self.preferenceFilters = PreferenceFilters()
        self.location = location
        self.attachedFiles = []
        self.sharedImages = []
        self.manualVenues = []
        self.linkedPosts = []
        self.gatheringHashtag = Self.generateHashtag(for: title)
        self.votingSettings = VotingSettings()
        self.gatheringHistory = GatheringHistory(createdAt: Date())
    }
    
    // MARK: - Helper Functions
    
    /// Generate a hashtag for the gathering
    static func generateHashtag(for title: String) -> String {
        let cleaned = title
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
        let timestamp = String(Date().timeIntervalSince1970).replacingOccurrences(of: ".", with: "")
        return "#\(cleaned)\(timestamp.suffix(4))"
    }
    
    /// Check if user can vote (is participant and gathering is in voting phase)
    func canUserVote(_ userId: String) -> Bool {
        guard !isArchived else { return false }
        let isParticipant = participants.contains { $0.userId == userId }
        let isCreator = creatorId == userId
        return (isParticipant || isCreator) && votingSettings.votingEnabled
    }
    
    /// Check if user can archive (only creator can archive)
    func canUserArchive(_ userId: String) -> Bool {
        return creatorId == userId && !isArchived
    }
    
    /// Archive the gathering
    mutating func archive(by userId: String) {
        guard canUserArchive(userId) else { return }
        isArchived = true
        archivedAt = Date()
        archivedBy = userId
        status = .completed
        gatheringHistory.archivedAt = Date()
    }
}

// MARK: - Supporting Types

enum GatheringStatus: String, Codable, CaseIterable {
    case planning = "planning"
    case timeVoting = "time_voting"
    case venueVoting = "venue_voting"
    case confirmed = "confirmed"
    case completed = "completed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .planning: return "Planning"
        case .timeVoting: return "Voting on Time"
        case .venueVoting: return "Voting on Venue"
        case .confirmed: return "Confirmed"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var icon: String {
        switch self {
        case .planning: return "calendar.badge.plus"
        case .timeVoting: return "clock.badge.questionmark"
        case .venueVoting: return "location.badge.questionmark"
        case .confirmed: return "checkmark.circle.fill"
        case .completed: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
        }
    }
}

enum GatheringPhase: String, Codable, CaseIterable {
    case invitation = "invitation"
    case timeSelection = "time_selection"
    case venueSelection = "venue_selection"
    case confirmation = "confirmation"
    case active = "active"
    case completed = "completed"
}

enum GatheringType: String, Codable, CaseIterable {
    case lunch = "lunch"
    case dinner = "dinner"
    case brunch = "brunch"
    case coffee = "coffee"
    case drinks = "drinks"
    case activity = "activity"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .brunch: return "Brunch"
        case .coffee: return "Coffee"
        case .drinks: return "Drinks"
        case .activity: return "Activity"
        case .custom: return "Custom"
        }
    }
    
    var icon: String {
        switch self {
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .brunch: return "sunrise.fill"
        case .coffee: return "cup.and.saucer.fill"
        case .drinks: return "wineglass.fill"
        case .activity: return "figure.walk"
        case .custom: return "star.fill"
        }
    }
    
    var suggestedDuration: TimeInterval {
        switch self {
        case .lunch: return 3600 // 1 hour
        case .dinner: return 7200 // 2 hours
        case .brunch: return 5400 // 1.5 hours
        case .coffee: return 1800 // 30 minutes
        case .drinks: return 5400 // 1.5 hours
        case .activity: return 10800 // 3 hours
        case .custom: return 7200 // 2 hours
        }
    }
}

struct GatheringParticipant: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let userName: String
    let userAvatar: String?
    let joinedAt: Date
    var calendarSyncEnabled: Bool
    var availabilityShared: Bool
    var preferences: UserGatheringPreferences
    
    init(userId: String, userName: String, userAvatar: String? = nil) {
        self.id = UUID().uuidString
        self.userId = userId
        self.userName = userName
        self.userAvatar = userAvatar
        self.joinedAt = Date()
        self.calendarSyncEnabled = false
        self.availabilityShared = false
        self.preferences = UserGatheringPreferences()
    }
}

struct GatheringInvitation: Codable, Identifiable, Hashable {
    let id: String
    let gatheringId: String
    let fromUserId: String
    let toUserId: String
    let toUserEmail: String?
    let sentAt: Date
    var status: InvitationStatus
    var respondedAt: Date?
    var message: String?
    
    enum InvitationStatus: String, Codable, CaseIterable {
        case pending = "pending"
        case accepted = "accepted"
        case declined = "declined"
        case expired = "expired"
    }
}

// MARK: - Time Management

struct TimeSlot: Codable, Identifiable, Hashable {
    let id: String
    let proposedBy: String
    let startTime: Date
    let endTime: Date
    let timezone: String
    let isFlexible: Bool // allows +/- 30 minutes
    var votes: [TimeVote]
    var conflictCount: Int // number of participants with conflicts
    
    init(proposedBy: String, startTime: Date, endTime: Date, timezone: String = TimeZone.current.identifier) {
        self.id = UUID().uuidString
        self.proposedBy = proposedBy
        self.startTime = startTime
        self.endTime = endTime
        self.timezone = timezone
        self.isFlexible = false
        self.votes = []
        self.conflictCount = 0
    }
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

struct TimeVote: Codable, Identifiable, Hashable {
    let id: String
    let timeSlotId: String
    let userId: String
    let vote: VoteType
    let availabilityStatus: AvailabilityStatus
    let votedAt: Date
    var notes: String?
    
    enum VoteType: String, Codable, CaseIterable {
        case yes = "yes"
        case maybe = "maybe"
        case no = "no"
        
        var weight: Double {
            switch self {
            case .yes: return 1.0
            case .maybe: return 0.5
            case .no: return 0.0
            }
        }
        
        var displayName: String {
            switch self {
            case .yes: return "Available"
            case .maybe: return "Maybe"
            case .no: return "Not Available"
            }
        }
        
        var color: String {
            switch self {
            case .yes: return "green"
            case .maybe: return "orange"
            case .no: return "red"
            }
        }
    }
    
    enum AvailabilityStatus: String, Codable, CaseIterable {
        case free = "free"
        case busy = "busy"
        case tentative = "tentative"
        case unknown = "unknown"
    }
}

// MARK: - Venue Management

struct VenueRecommendation: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let category: String
    let cuisine: String?
    let priceLevel: Int // 1-4 scale
    let rating: Double
    let reviewCount: Int
    let phoneNumber: String?
    let website: String?
    let imageUrl: String?
    
    // AI recommendation data
    var aiScore: Double // 0-1 scale
    var aiReasoning: String
    var matchingPreferences: [String]
    var estimatedCost: BudgetRange?
    
    // Distance and logistics
    var distanceFromCenter: Double // in meters
    var estimatedTravelTime: TimeInterval?
    
    // Availability
    var isOpen: Bool?
    var reservationRequired: Bool
    var reservationUrl: String?
    
    init(
        id: String = UUID().uuidString,
        name: String,
        address: String,
        latitude: Double,
        longitude: Double,
        category: String,
        aiScore: Double = 0.0,
        aiReasoning: String = ""
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.category = category
        self.cuisine = nil
        self.priceLevel = 2
        self.rating = 0.0
        self.reviewCount = 0
        self.phoneNumber = nil
        self.website = nil
        self.imageUrl = nil
        self.aiScore = aiScore
        self.aiReasoning = aiReasoning
        self.matchingPreferences = []
        self.estimatedCost = nil
        self.distanceFromCenter = 0.0
        self.isOpen = true
        self.reservationRequired = false
        self.reservationUrl = nil
    }
}

struct VenueVote: Codable, Identifiable, Hashable {
    let id: String
    let venueId: String
    let userId: String
    let vote: VoteType
    let votedAt: Date
    var notes: String?
    
    enum VoteType: String, Codable, CaseIterable {
        case love = "love"
        case like = "like"
        case neutral = "neutral"
        case dislike = "dislike"
        
        var weight: Double {
            switch self {
            case .love: return 2.0
            case .like: return 1.0
            case .neutral: return 0.0
            case .dislike: return -1.0
            }
        }
        
        var displayName: String {
            switch self {
            case .love: return "Love It!"
            case .like: return "Like It"
            case .neutral: return "Neutral"
            case .dislike: return "Not For Me"
            }
        }
        
        var icon: String {
            switch self {
            case .love: return "heart.fill"
            case .like: return "hand.thumbsup.fill"
            case .neutral: return "minus.circle"
            case .dislike: return "hand.thumbsdown.fill"
            }
        }
    }
}

// MARK: - Calendar Integration

struct ReminderSettings: Codable, Hashable {
    var enabled: Bool = true
    var reminderIntervals: [ReminderInterval] = [.oneDay, .oneHour]
    var syncWithSystemCalendar: Bool = true
    var sendPushNotifications: Bool = true
    
    enum ReminderInterval: String, Codable, CaseIterable {
        case oneWeek = "one_week"
        case threeDays = "three_days"
        case oneDay = "one_day"
        case sixHours = "six_hours"
        case oneHour = "one_hour"
        case thirtyMinutes = "thirty_minutes"
        case fifteenMinutes = "fifteen_minutes"
        
        var timeInterval: TimeInterval {
            switch self {
            case .oneWeek: return 604800
            case .threeDays: return 259200
            case .oneDay: return 86400
            case .sixHours: return 21600
            case .oneHour: return 3600
            case .thirtyMinutes: return 1800
            case .fifteenMinutes: return 900
            }
        }
        
        var displayName: String {
            switch self {
            case .oneWeek: return "1 week before"
            case .threeDays: return "3 days before"
            case .oneDay: return "1 day before"
            case .sixHours: return "6 hours before"
            case .oneHour: return "1 hour before"
            case .thirtyMinutes: return "30 minutes before"
            case .fifteenMinutes: return "15 minutes before"
            }
        }
    }
}

// MARK: - Preferences and Filters

struct PreferenceFilters: Codable, Hashable {
    var cuisineTypes: [String] = []
    var dietaryRestrictions: [DietaryRestriction] = []
    var priceRange: BudgetRange = BudgetRange.moderate
    var distanceRadius: Double = 5000 // meters
    var ambience: [AmbienceType] = []
    var features: [VenueFeature] = []
    
    enum DietaryRestriction: String, Codable, CaseIterable {
        case dairyFree = "dairy_free"
        case glutenFree = "gluten_free"
        case halal = "halal"
        case keto = "keto"
        case kosher = "kosher"
        case nutFree = "nut_free"
        case paleo = "paleo"
        case vegan = "vegan"
        case vegetarian = "vegetarian"
        
        var displayName: String {
            switch self {
            case .dairyFree: return "Dairy-Free"
            case .glutenFree: return "Gluten-Free"
            case .halal: return "Halal"
            case .keto: return "Keto"
            case .kosher: return "Kosher"
            case .nutFree: return "Nut-Free"
            case .paleo: return "Paleo"
            case .vegan: return "Vegan"
            case .vegetarian: return "Vegetarian"
            }
        }
    }
    
    enum AmbienceType: String, Codable, CaseIterable {
        case casual = "casual"
        case cozy = "cozy"
        case familyFriendly = "family_friendly"
        case lively = "lively"
        case outdoor = "outdoor"
        case quiet = "quiet"
        case romantic = "romantic"
        case upscale = "upscale"
        
        var displayName: String {
            rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
    
    enum VenueFeature: String, Codable, CaseIterable {
        case parking = "parking"
        case wifi = "wifi"
        case petFriendly = "pet_friendly"
        case wheelchairAccessible = "wheelchair_accessible"
        case outdoorSeating = "outdoor_seating"
        case liveMusic = "live_music"
        case privateRoom = "private_room"
        case groupDiscount = "group_discount"
        
        var displayName: String {
            rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

struct UserGatheringPreferences: Codable, Hashable {
    var favoriteCuisines: [String] = []
    var dietaryRestrictions: [PreferenceFilters.DietaryRestriction] = []
    var preferredBudget: BudgetRange = .moderate
    var preferredAmbience: [PreferenceFilters.AmbienceType] = []
    var dislikedVenues: [String] = [] // venue IDs
    var travelPreference: TravelPreference = .moderate
    
    enum TravelPreference: String, Codable, CaseIterable {
        case nearby = "nearby" // within 1km
        case moderate = "moderate" // within 5km
        case flexible = "flexible" // within 15km
        case anywhere = "anywhere" // no limit
        
        var maxDistance: Double {
            switch self {
            case .nearby: return 1000
            case .moderate: return 5000
            case .flexible: return 15000
            case .anywhere: return Double.infinity
            }
        }
    }
}

enum BudgetRange: String, Codable, CaseIterable {
    case budget = "budget" // $
    case moderate = "moderate" // $$
    case upscale = "upscale" // $$$
    case luxury = "luxury" // $$$$
    
    var displayName: String {
        switch self {
        case .budget: return "Budget ($)"
        case .moderate: return "Moderate ($$)"
        case .upscale: return "Upscale ($$$)"
        case .luxury: return "Luxury ($$$$)"
        }
    }
    
    var priceLevel: Int {
        switch self {
        case .budget: return 1
        case .moderate: return 2
        case .upscale: return 3
        case .luxury: return 4
        }
    }
}

struct GatheringLocation: Codable, Hashable {
    var centerPoint: LocationPoint?
    var searchRadius: Double = 5000 // meters
    var preferredArea: String?
    var excludedAreas: [String] = []
    
    struct LocationPoint: Codable, Hashable {
        let latitude: Double
        let longitude: Double
        let name: String?
        let address: String?
    }
}

// MARK: - Group Chat Integration

struct GatheringMessage: Codable, Identifiable, Hashable {
    let id: String
    let gatheringId: String
    let senderId: String
    let senderName: String
    let content: String
    let timestamp: Date
    var messageType: MessageType = .text
    var isSystemMessage: Bool = false
    
    enum MessageType: String, Codable {
        case text = "text"
        case timeProposal = "time_proposal"
        case venueProposal = "venue_proposal"
        case vote = "vote"
        case statusUpdate = "status_update"
        case reminder = "reminder"
    }
}

// MARK: - File Upload and Media Management

struct GatheringFile: Codable, Identifiable, Hashable {
    let id: String
    let fileName: String
    let originalName: String
    let fileUrl: String
    let fileType: FileType
    let fileSize: Int64 // in bytes
    let uploadedBy: String
    let uploadedAt: Date
    var description: String?
    var isPublic: Bool = true // visible to all participants
    
    enum FileType: String, Codable, CaseIterable {
        case document = "document"
        case image = "image"
        case video = "video"
        case audio = "audio"
        case other = "other"
        
        var allowedExtensions: [String] {
            switch self {
            case .document:
                return ["pdf", "doc", "docx", "txt", "rtf", "pages"]
            case .image:
                return ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic"]
            case .video:
                return ["mp4", "mov", "avi", "mkv", "wmv", "flv"]
            case .audio:
                return ["mp3", "wav", "aac", "m4a", "ogg", "flac"]
            case .other:
                return []
            }
        }
        
        var maxFileSize: Int64 {
            switch self {
            case .document: return 50 * 1024 * 1024 // 50MB
            case .image: return 20 * 1024 * 1024 // 20MB
            case .video: return 500 * 1024 * 1024 // 500MB
            case .audio: return 100 * 1024 * 1024 // 100MB
            case .other: return 50 * 1024 * 1024 // 50MB
            }
        }
        
        var icon: String {
            switch self {
            case .document: return "doc.fill"
            case .image: return "photo.fill"
            case .video: return "video.fill"
            case .audio: return "music.note"
            case .other: return "paperclip"
            }
        }
    }
    
    init(
        fileName: String,
        originalName: String,
        fileUrl: String,
        fileType: FileType,
        fileSize: Int64,
        uploadedBy: String,
        description: String? = nil
    ) {
        self.id = UUID().uuidString
        self.fileName = fileName
        self.originalName = originalName
        self.fileUrl = fileUrl
        self.fileType = fileType
        self.fileSize = fileSize
        self.uploadedBy = uploadedBy
        self.uploadedAt = Date()
        self.description = description
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

struct GatheringImage: Codable, Identifiable, Hashable {
    let id: String
    let imageUrl: String
    let thumbnailUrl: String?
    let caption: String?
    let uploadedBy: String
    let uploadedAt: Date
    let width: Int?
    let height: Int?
    var tags: [String] = []
    var isVenueRelated: Bool = false
    var venueId: String? // if related to a specific venue
    
    init(
        imageUrl: String,
        thumbnailUrl: String? = nil,
        caption: String? = nil,
        uploadedBy: String,
        width: Int? = nil,
        height: Int? = nil
    ) {
        self.id = UUID().uuidString
        self.imageUrl = imageUrl
        self.thumbnailUrl = thumbnailUrl
        self.caption = caption
        self.uploadedBy = uploadedBy
        self.uploadedAt = Date()
        self.width = width
        self.height = height
    }
}

// MARK: - Manual Venue Management

struct ManualVenue: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var description: String?
    var address: String?
    var latitude: Double?
    var longitude: Double?
    var category: VenueCategory
    var website: String?
    var phoneNumber: String?
    var priceLevel: Int? // 1-4 scale
    var estimatedCost: String?
    var notes: String?
    let addedBy: String
    let addedAt: Date
    var updatedAt: Date
    
    // Manual venue specific data
    var isVerified: Bool = false
    var images: [GatheringImage] = []
    var userRating: Double?
    var userReview: String?
    var recommendedDishes: [String] = []
    var amenities: [String] = []
    
    enum VenueCategory: String, Codable, CaseIterable {
        case restaurant = "restaurant"
        case cafe = "cafe"
        case bar = "bar"
        case fastFood = "fast_food"
        case fineDining = "fine_dining"
        case foodTruck = "food_truck"
        case brewery = "brewery"
        case bakery = "bakery"
        case pizzeria = "pizzeria"
        case sushi = "sushi"
        case bbq = "bbq"
        case seafood = "seafood"
        case steakhouse = "steakhouse"
        case vegetarian = "vegetarian"
        case ethnic = "ethnic"
        case buffet = "buffet"
        case deli = "deli"
        case iceCream = "ice_cream"
        case juice = "juice"
        case teaHouse = "tea_house"
        case winery = "winery"
        case rooftop = "rooftop"
        case outdoor = "outdoor"
        case casual = "casual"
        case takeout = "takeout"
        case delivery = "delivery"
        case homeKitchen = "home_kitchen"
        case popUp = "pop_up"
        case other = "other"
        
        var displayName: String {
            switch self {
            case .restaurant: return "Restaurant"
            case .cafe: return "Café"
            case .bar: return "Bar"
            case .fastFood: return "Fast Food"
            case .fineDining: return "Fine Dining"
            case .foodTruck: return "Food Truck"
            case .brewery: return "Brewery"
            case .bakery: return "Bakery"
            case .pizzeria: return "Pizzeria"
            case .sushi: return "Sushi"
            case .bbq: return "BBQ"
            case .seafood: return "Seafood"
            case .steakhouse: return "Steakhouse"
            case .vegetarian: return "Vegetarian"
            case .ethnic: return "Ethnic"
            case .buffet: return "Buffet"
            case .deli: return "Deli"
            case .iceCream: return "Ice Cream"
            case .juice: return "Juice Bar"
            case .teaHouse: return "Tea House"
            case .winery: return "Winery"
            case .rooftop: return "Rooftop"
            case .outdoor: return "Outdoor Dining"
            case .casual: return "Casual Dining"
            case .takeout: return "Takeout"
            case .delivery: return "Delivery Only"
            case .homeKitchen: return "Home Kitchen"
            case .popUp: return "Pop-up"
            case .other: return "Other"
            }
        }
        
        var icon: String {
            switch self {
            case .restaurant: return "fork.knife"
            case .cafe: return "cup.and.saucer.fill"
            case .bar: return "wineglass.fill"
            case .fastFood: return "takeoutbag.and.cup.and.straw.fill"
            case .fineDining: return "star.fill"
            case .foodTruck: return "truck.box.fill"
            case .brewery: return "cup.and.saucer"
            case .bakery: return "birthday.cake.fill"
            case .pizzeria: return "circle.grid.cross.fill"
            case .sushi: return "fish.fill"
            case .bbq: return "flame.fill"
            case .seafood: return "fish"
            case .steakhouse: return "flame"
            case .vegetarian: return "leaf.fill"
            case .ethnic: return "globe"
            case .buffet: return "tray.2.fill"
            case .deli: return "takeoutbag.and.cup.and.straw"
            case .iceCream: return "snowflake"
            case .juice: return "drop.fill"
            case .teaHouse: return "mug.fill"
            case .winery: return "grapes.fill"
            case .rooftop: return "building.2.fill"
            case .outdoor: return "tree.fill"
            case .casual: return "house.fill"
            case .takeout: return "bag.fill"
            case .delivery: return "bicycle"
            case .homeKitchen: return "house.circle.fill"
            case .popUp: return "tent.fill"
            case .other: return "questionmark.circle.fill"
            }
        }
    }
    
    init(
        name: String,
        description: String? = nil,
        address: String? = nil,
        category: VenueCategory,
        addedBy: String
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.description = description
        self.address = address
        self.category = category
        self.addedBy = addedBy
        self.addedAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Location Search and Management

struct LocationSearchResult: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let category: String?
    let source: SearchSource
    var distance: Double? // from search center
    var isBusinessVerified: Bool = false
    var businessHours: [BusinessHour] = []
    var contactInfo: ContactInfo?
    
    enum SearchSource: String, Codable {
        case apple = "apple" // Apple Maps
        case google = "google" // Google Places
        case manual = "manual" // User entered
        case imported = "imported" // From external source
    }
    
    struct BusinessHour: Codable, Hashable {
        let dayOfWeek: Int // 1-7, Sunday = 1
        let openTime: String // "09:00"
        let closeTime: String // "22:00"
        let isClosed: Bool
    }
    
    struct ContactInfo: Codable, Hashable {
        let phoneNumber: String?
        let website: String?
        let email: String?
        var socialMedia: [String: String] = [:] // platform: handle
    }
    
    init(
        name: String,
        address: String,
        latitude: Double,
        longitude: Double,
        category: String? = nil,
        source: SearchSource
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.category = category
        self.source = source
    }
}

// MARK: - Post Linking and Social Features

struct LinkedPost: Codable, Identifiable, Hashable {
    let id: String
    let postId: String
    let userId: String
    let userName: String
    let linkedAt: Date
    var isVisible: Bool = true
    var linkType: LinkType
    
    enum LinkType: String, Codable, CaseIterable {
        case beforeGathering = "before_gathering"
        case duringGathering = "during_gathering"
        case afterGathering = "after_gathering"
        case venueReview = "venue_review"
        case invitation = "invitation"
        case memory = "memory"
        
        var displayName: String {
            switch self {
            case .beforeGathering: return "Getting Ready"
            case .duringGathering: return "Live Updates"
            case .afterGathering: return "Memories"
            case .venueReview: return "Venue Review"
            case .invitation: return "Invitation"
            case .memory: return "Memory"
            }
        }
        
        var icon: String {
            switch self {
            case .beforeGathering: return "clock.arrow.circlepath"
            case .duringGathering: return "dot.radiowaves.left.and.right"
            case .afterGathering: return "heart.fill"
            case .venueReview: return "star.fill"
            case .invitation: return "paperplane.fill"
            case .memory: return "photo.fill"
            }
        }
    }
    
    init(postId: String, userId: String, userName: String, linkType: LinkType) {
        self.id = UUID().uuidString
        self.postId = postId
        self.userId = userId
        self.userName = userName
        self.linkedAt = Date()
        self.linkType = linkType
    }
}

// MARK: - Voting System and Permissions

struct VotingSettings: Codable, Hashable {
    var votingEnabled: Bool = true
    var allowParticipantVoting: Bool = true
    var allowCreatorOnlyVoting: Bool = false
    var timeVotingDeadline: Date?
    var venueVotingDeadline: Date?
    var requireAllParticipantsToVote: Bool = false
    var allowVoteChanges: Bool = true
    var showVoteResults: VoteVisibility = .afterVoting
    var anonymousVoting: Bool = false
    
    enum VoteVisibility: String, Codable, CaseIterable {
        case realTime = "real_time"
        case afterVoting = "after_voting"
        case afterDeadline = "after_deadline"
        case creatorOnly = "creator_only"
        
        var displayName: String {
            switch self {
            case .realTime: return "Show Results in Real-time"
            case .afterVoting: return "Show After Everyone Votes"
            case .afterDeadline: return "Show After Deadline"
            case .creatorOnly: return "Creator Only"
            }
        }
    }
    
    init() {
        self.votingEnabled = true
        self.allowParticipantVoting = true
        self.allowCreatorOnlyVoting = false
        self.requireAllParticipantsToVote = false
        self.allowVoteChanges = true
        self.showVoteResults = .afterVoting
        self.anonymousVoting = false
    }
}

// MARK: - Gathering History and Analytics

struct GatheringHistory: Codable, Hashable {
    let createdAt: Date
    var invitationsSent: Int = 0
    var invitationsAccepted: Int = 0
    var totalParticipants: Int = 0
    var timeProposals: Int = 0
    var venueProposals: Int = 0
    var totalVotes: Int = 0
    var messagesExchanged: Int = 0
    var filesShared: Int = 0
    var imagesShared: Int = 0
    var linkedPostsCount: Int = 0
    var finalVenueSelected: Bool = false
    var finalTimeSelected: Bool = false
    var gatheringCompleted: Bool = false
    var archivedAt: Date?
    
    // Engagement metrics
    var averageResponseTime: TimeInterval = 0
    var mostActiveParticipant: String?
    var totalPlanningDuration: TimeInterval = 0
    
    // Outcome tracking
    var satisfactionRating: Double?
    var wouldMeetAgain: Bool?
    var venueRating: Double?
    
    init(createdAt: Date) {
        self.createdAt = createdAt
    }
    
    mutating func incrementInvitationsSent() {
        invitationsSent += 1
    }
    
    mutating func incrementInvitationsAccepted() {
        invitationsAccepted += 1
    }
    
    mutating func incrementTotalVotes() {
        totalVotes += 1
    }
    
    mutating func incrementMessagesExchanged() {
        messagesExchanged += 1
    }
    
    mutating func incrementFilesShared() {
        filesShared += 1
    }
    
    mutating func incrementImagesShared() {
        imagesShared += 1
    }
    
    mutating func incrementLinkedPosts() {
        linkedPostsCount += 1
    }
    
    mutating func markCompleted() {
        gatheringCompleted = true
        totalPlanningDuration = Date().timeIntervalSince(createdAt)
    }
}

// MARK: - User Profile History Integration

struct UserGatheringHistory: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    var participatedGatherings: [ParticipatedGathering]
    var createdGatherings: [String] // gathering IDs
    var totalGatheringsJoined: Int
    var totalGatheringsCreated: Int
    var favoriteVenueTypes: [String]
    var averageSatisfactionRating: Double
    var totalFriendsMetThroughGatherings: Int
    
    init(userId: String) {
        self.id = UUID().uuidString
        self.userId = userId
        self.participatedGatherings = []
        self.createdGatherings = []
        self.totalGatheringsJoined = 0
        self.totalGatheringsCreated = 0
        self.favoriteVenueTypes = []
        self.averageSatisfactionRating = 0.0
        self.totalFriendsMetThroughGatherings = 0
    }
}

struct ParticipatedGathering: Codable, Identifiable, Hashable {
    let id: String
    let gatheringId: String
    let gatheringTitle: String
    let gatheringType: GatheringType
    let role: ParticipantRole
    let joinedAt: Date
    let completedAt: Date?
    let finalVenue: String?
    let finalVenueCategory: String?
    let satisfactionRating: Double?
    let wouldRecommendVenue: Bool?
    let newFriendsMet: Int
    let postsCreated: Int
    let votesParticipated: Int
    let filesShared: Int
    let memoriesShared: Int
    
    enum ParticipantRole: String, Codable, CaseIterable {
        case creator = "creator"
        case participant = "participant"
        case invitee = "invitee"
        
        var displayName: String {
            switch self {
            case .creator: return "Creator"
            case .participant: return "Participant"
            case .invitee: return "Invitee"
            }
        }
        
        var icon: String {
            switch self {
            case .creator: return "crown.fill"
            case .participant: return "person.fill"
            case .invitee: return "envelope.fill"
            }
        }
    }
    
    init(
        gatheringId: String,
        gatheringTitle: String,
        gatheringType: GatheringType,
        role: ParticipantRole,
        joinedAt: Date = Date()
    ) {
        self.id = UUID().uuidString
        self.gatheringId = gatheringId
        self.gatheringTitle = gatheringTitle
        self.gatheringType = gatheringType
        self.role = role
        self.joinedAt = joinedAt
        self.completedAt = nil
        self.finalVenue = nil
        self.finalVenueCategory = nil
        self.satisfactionRating = nil
        self.wouldRecommendVenue = nil
        self.newFriendsMet = 0
        self.postsCreated = 0
        self.votesParticipated = 0
        self.filesShared = 0
        self.memoriesShared = 0
    }
}

// MARK: - Enhanced Message Types for File Sharing

extension GatheringMessage {
    enum EnhancedMessageType: String, Codable {
        case text = "text"
        case image = "image"
        case file = "file"
        case location = "location"
        case venueProposal = "venue_proposal"
        case timeProposal = "time_proposal"
        case vote = "vote"
        case statusUpdate = "status_update"
        case reminder = "reminder"
        case poll = "poll"
    }
    
    struct MessageAttachment: Codable, Hashable {
        let id: String
        let type: AttachmentType
        let url: String
        let fileName: String?
        let fileSize: Int64?
        let thumbnailUrl: String?
        
        enum AttachmentType: String, Codable {
            case image = "image"
            case file = "file"
            case location = "location"
            case venue = "venue"
        }
    }
}
