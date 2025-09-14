//
//  MockData.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import SwiftUI
import CoreLocation
#if !targetEnvironment(simulator)
// import ConvexMobile // temporarily disabled
#endif

// MARK: - Mock View Models for SwiftUI Previews
@MainActor
class MockProfileViewModel: ObservableObject {
    @Published var currentUser: User? = MockData.currentUser
    @Published var userPosts: [Post] = MockData.generateUserPosts(for: MockData.currentUser)
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    func loadUserProfile() async {
        // Mock implementation for previews - do nothing
    }
}

@MainActor 
class MockHomeViewModel: ObservableObject {
    @Published var posts: [Post] = MockData.generatePreviewPosts()
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchPosts() {
        // Mock implementation for previews - already have posts loaded
        isLoading = false
    }
}

// Lightweight AppState for Xcode previews - avoids complex service initialization
@MainActor
class PreviewAppState: ObservableObject {
    @Published var isAuthenticated = true
    @Published var currentUser: User? = MockData.currentUser
    @Published var selectedTab: AppTab = .home
    @Published var homeViewModel = MockHomeViewModel()
    @Published var isTabBarVisible = true
    
    // Theme management
    let themeManager = ThemeManager()
    
    /// Refresh the home feed - no-op in preview
    func refreshHomeFeed() async {
        // No-op for preview
    }
    
    /// Activate notifications subscription - no-op in preview
    func activateNotifications() {
        // No-op for preview
    }
    
    /// Hide/show tab bar methods
    func hideTabBar() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isTabBarVisible = false
        }
    }
    
    func showTabBar() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isTabBarVisible = true
        }
    }
    
    func toggleTabBar() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isTabBarVisible.toggle()
        }
    }
}

@MainActor
class MockAppState: ObservableObject {
    @Published var isAuthenticated = true
    @Published var currentUser: User? = MockData.currentUser
    @Published var selectedTab: AppTab = .home
    @Published var homeViewModel = MockHomeViewModel()
    
    // Theme management
    let themeManager = ThemeManager()
    
    // Services
    let notificationService = NotificationService.shared
    
    /// Refresh the home feed - useful after creating a new post
    func refreshHomeFeed() async {
        homeViewModel.fetchPosts()
    }
    
    /// Activate notifications subscription
    func activateNotifications() {
        print("🔔 MockAppState: Activating notifications subscription...")
        // In preview, we don't actually subscribe
    }
}

@MainActor
class MockMapViewModel: ObservableObject {
    @Published var mapPosts: [MapPostAnnotation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Filter properties
    @Published var selectedTimeframe: String = "All Time"
    @Published var showFollowingOnly = false
    @Published var showFriendsOnly = false
    @Published var showAllUsers = true
    @Published var maxDistance: Double = 50.0
    @Published var timeFilter: TimeFilter = .allTime
    @Published var selectedCategories: Set<FoodCategory> = []
    @Published var priceRange: ClosedRange<Double> = 1.0...4.0
    @Published var minimumRating: Double = 0.0
    @Published var showHeatMap = false
    @Published var enableClustering = true
    @Published var clusterRadius: Double = 100.0
    
    func loadFollowingPosts(for userId: String) async {}
    func resetFilters() {
        selectedTimeframe = "All Time"
        showFollowingOnly = false
        showFriendsOnly = false
        showAllUsers = true
        maxDistance = 50.0
        timeFilter = .allTime
        selectedCategories = []
        priceRange = 1.0...4.0
        minimumRating = 0.0
    }
    func applyFilters() async {}
}

@MainActor
class MockMessagesViewModel: ObservableObject {
    @Published var chatrooms: [ChatRoom] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init() {
        // Load sample chatrooms
        loadSampleChatrooms()
    }
    
    private func loadSampleChatrooms() {
        chatrooms = [
            ChatRoom(
                id: "chat_1",
                participants: [MockData.currentUser, MockData.sampleUsers[0]],
                lastMessage: "Hey! How was that ramen place?",
                lastMessageTime: Date(),
                unreadCount: 2
            ),
            ChatRoom(
                id: "chat_2",
                participants: [MockData.currentUser, MockData.sampleUsers[1]],
                lastMessage: "Thanks for the coffee recommendation!",
                lastMessageTime: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
                unreadCount: 0
            )
        ]
    }
}

// MARK: - Mock Data Provider
struct MockData {
    
    // MARK: - Users (for SwiftUI previews only)
    static let currentUser = User(
        id: UUID(),
        email: "alex@palytt.com",
        firstName: "Alex",
        lastName: "Chen",
        username: "alexchen",
        displayName: "Alex Chen",
        bio: "Food enthusiast 🍽️ | Coffee addict ☕ | Always exploring new flavors and hidden gems around the city. SF local with a passion for authentic experiences.",
        avatarURL: URL(string: "https://picsum.photos/200/200?random=100"),
        clerkId: "user_current_mock",
        role: .user,
        dietaryPreferences: [.vegetarian, .glutenFree],
        location: sampleLocation,
        followersCount: 1247,
        followingCount: 892,
        postsCount: 156
    )
    
    static let adminUser = User(
        id: UUID(),
        email: "admin@palytt.com",
        firstName: "Jamie",
        lastName: "Admin",
        username: "admin",
        displayName: "Jamie Admin",
        bio: "Platform Administrator 🛡️ | Ensuring the best experience for all Palytt users | Coffee powered developer",
        avatarURL: URL(string: "https://picsum.photos/200/200?random=999"),
        clerkId: "user_admin_mock",
        role: .admin,
        dietaryPreferences: [.vegetarian],
        location: sampleLocation,
        followersCount: 2847,
        followingCount: 1342,
        postsCount: 89
    )
    
    static let previewUser = User(
        id: UUID(),
        email: "maya@foodie.com",
        firstName: "Maya",
        lastName: "Rodriguez",
        username: "mayafoods",
        displayName: "Maya Rodriguez",
        bio: "Food photographer 📸 | Brunch expert | Sharing the best eats in SF Bay Area. Professional foodie and weekend chef.",
        avatarURL: URL(string: "https://picsum.photos/200/200?random=1"),
        clerkId: "user_preview_mock",
        role: .user,
        dietaryPreferences: [.vegetarian],
        location: sampleLocation,
        followersCount: 2847,
        followingCount: 1205,
        postsCount: 342
    )
    
    static let sampleUsers = [
        User(
            id: UUID(),
            email: "jamie@coffeelover.com",
            firstName: "Jamie",
            lastName: "Park",
            username: "jamiepark",
            displayName: "Jamie Park",
            bio: "Coffee addict ☕ | Brunch lover | Finding the perfect matcha latte one sip at a time. Third wave coffee enthusiast.",
            avatarURL: URL(string: "https://picsum.photos/200/200?random=2"),
            clerkId: "user_jamie_mock",
            role: .user,
            dietaryPreferences: [.glutenFree],
            location: sampleLocation,
            followersCount: 567,
            followingCount: 423,
            postsCount: 89
        ),
        User(
            id: UUID(),
            email: "kim@ramenquest.com",
            firstName: "Kim",
            lastName: "Tanaka",
            username: "kimtanaka",
            displayName: "Kim Tanaka",
            bio: "Asian cuisine explorer 🥢 | Ramen enthusiast | Documenting authentic flavors from Japan to Southeast Asia.",
            avatarURL: URL(string: "https://picsum.photos/200/200?random=3"),
            clerkId: "user_kim_mock",
            role: .user,
            dietaryPreferences: [],
            location: sampleLocation,
            followersCount: 1923,
            followingCount: 756,
            postsCount: 278
        ),
        User(
            id: UUID(),
            email: "sam@sweetlife.com",
            firstName: "Sam",
            lastName: "Johnson",
            username: "samjohnson",
            displayName: "Sam Johnson",
            bio: "Dessert first, always 🍰 | Pastry chef | Creating sweet memories one bite at a time. Life's too short for bad desserts!",
            avatarURL: URL(string: "https://picsum.photos/200/200?random=4"),
            clerkId: "user_sam_mock",
            role: .user,
            dietaryPreferences: [.vegan],
            location: sampleLocation,
            followersCount: 3421,
            followingCount: 1876,
            postsCount: 445
        ),
        User(
            id: UUID(),
            email: "taylor@plantbased.life",
            firstName: "Taylor",
            lastName: "Williams",
            username: "taylorw",
            displayName: "Taylor Williams",
            bio: "Plant-based foodie 🌱 | Healthy living advocate | Sharing delicious vegan finds and sustainable eating tips.",
            avatarURL: URL(string: "https://picsum.photos/200/200?random=5"),
            clerkId: "user_taylor_mock",
            role: .user,
            dietaryPreferences: [.vegan, .glutenFree],
            location: sampleLocation,
            followersCount: 892,
            followingCount: 634,
            postsCount: 123
        ),
        User(
            id: UUID(),
            email: "maria@tacotuesday.mx",
            firstName: "Maria",
            lastName: "Gonzalez",
            username: "mariatacos",
            displayName: "Maria Gonzalez",
            bio: "Authentic Mexican food hunter 🌮 | Born in Mexico City, now in SF | Searching for the real deal, no fusion allowed!",
            avatarURL: URL(string: "https://picsum.photos/200/200?random=6"),
            clerkId: "user_maria_mock",
            role: .user,
            dietaryPreferences: [],
            location: missionLocation,
            followersCount: 1456,
            followingCount: 987,
            postsCount: 234
        ),
        User(
            id: UUID(),
            email: "david@sushisensei.jp",
            firstName: "David",
            lastName: "Kimura",
            username: "davidkimura",
            displayName: "David Kimura",
            bio: "Sushi connoisseur 🍣 | Former Tokyo resident | Rating omakase experiences and hidden sushi gems worldwide.",
            avatarURL: URL(string: "https://picsum.photos/200/200?random=7"),
            clerkId: "user_david_mock",
            role: .user,
            dietaryPreferences: [.pescatarian],
            location: sampleLocation,
            followersCount: 2134,
            followingCount: 543,
            postsCount: 167
        ),
        User(
            id: UUID(),
            email: "sophia@wineanddine.it",
            firstName: "Sophia",
            lastName: "Rossi",
            username: "sophiarossi",
            displayName: "Sophia Rossi",
            bio: "Wine sommelier 🍷 | Italian cuisine expert | Pairing the perfect wines with incredible dishes across the globe.",
            avatarURL: URL(string: "https://picsum.photos/200/200?random=8"),
            clerkId: "user_sophia_mock",
            role: .user,
            dietaryPreferences: [],
            location: northBeachLocation,
            followersCount: 3892,
            followingCount: 1234,
            postsCount: 456
        ),
        User(
            id: UUID(),
            email: "ahmed@spicemaster.in",
            firstName: "Ahmed",
            lastName: "Patel",
            username: "ahmedpatel",
            displayName: "Ahmed Patel",
            bio: "Indian spice master 🌶️ | Halal food advocate | Bringing you the most flavorful curries and biryanis in the Bay Area.",
            avatarURL: URL(string: "https://picsum.photos/200/200?random=9"),
            clerkId: "user_ahmed_mock",
            role: .user,
            dietaryPreferences: [.halal],
            location: sampleLocation,
            followersCount: 1678,
            followingCount: 456,
            postsCount: 189
        ),
        User(
            id: UUID(),
            email: "lisa@healthybites.com",
            firstName: "Lisa",
            lastName: "Thompson",
            username: "lisathompson",
            displayName: "Lisa Thompson",
            bio: "Nutritionist & food blogger 🥗 | Keto lifestyle advocate | Proving healthy food can be absolutely delicious.",
            avatarURL: URL(string: "https://picsum.photos/200/200?random=10"),
            clerkId: "user_lisa_mock",
            role: .user,
            dietaryPreferences: [.keto, .dairyFree],
            location: sampleLocation,
            followersCount: 2567,
            followingCount: 789,
            postsCount: 345
        ),
        User(
            id: UUID(),
            email: "mike@bbqking.us",
            firstName: "Mike",
            lastName: "Anderson",
            username: "mikebbq",
            displayName: "Mike Anderson",
            bio: "BBQ pitmaster 🔥 | Low & slow enthusiast | 20+ years perfecting the art of smoke and spice. Texas roots, Bay Area heart.",
            avatarURL: URL(string: "https://picsum.photos/200/200?random=11"),
            clerkId: "user_mike_mock",
            role: .user,
            dietaryPreferences: [],
            location: sampleLocation,
            followersCount: 4321,
            followingCount: 1567,
            postsCount: 678
        )
    ]
    
    // MARK: - Locations
    static let sampleLocation = Location(
        latitude: 37.7749,
        longitude: -122.4194,
        address: "123 Market Street",
        city: "San Francisco",
        state: "CA",
        country: "USA",
        postalCode: "94103"
    )
    
    static let missionLocation = Location(
        latitude: 37.7599,
        longitude: -122.4148,
        address: "456 Mission Street",
        city: "San Francisco",
        state: "CA",
        country: "USA",
        postalCode: "94105"
    )
    
    static let northBeachLocation = Location(
        latitude: 37.8067,
        longitude: -122.4102,
        address: "789 Columbus Avenue",
        city: "San Francisco",
        state: "CA",
        country: "USA",
        postalCode: "94133"
    )
    
    static let somLocation = Location(
        latitude: 37.7829,
        longitude: -122.4058,
        address: "321 2nd Street",
        city: "San Francisco",
        state: "CA",
        country: "USA",
        postalCode: "94107"
    )
    
    static let chinatownLocation = Location(
        latitude: 37.7941,
        longitude: -122.4078,
        address: "654 Grant Avenue",
        city: "San Francisco",
        state: "CA",
        country: "USA",
        postalCode: "94108"
    )
    
    // MARK: - Shops
    static let sampleShops = [
        Shop(
            name: "The Matcha House",
            description: "Authentic Japanese matcha drinks and desserts",
            location: sampleLocation,
            phoneNumber: "(415) 555-0123",
            website: URL(string: "https://thematchahouse.com"),
            hours: BusinessHours(
                monday: .init(open: "8:00", close: "20:00", isClosed: false),
                tuesday: .init(open: "8:00", close: "20:00", isClosed: false),
                wednesday: .init(open: "8:00", close: "20:00", isClosed: false),
                thursday: .init(open: "8:00", close: "20:00", isClosed: false),
                friday: .init(open: "8:00", close: "21:00", isClosed: false),
                saturday: .init(open: "9:00", close: "21:00", isClosed: false),
                sunday: .init(open: "9:00", close: "19:00", isClosed: false)
            ),
            cuisineTypes: [.japanese, .cafe, .dessert],
            drinkTypes: [.matcha, .tea, .coffee],
            priceRange: .moderate,
            rating: 4.5,
            reviewsCount: 234,
            photosCount: 567,
            isVerified: true,
            featuredImageURL: URL(string: "https://picsum.photos/400/300?random=10"),
            isFavorite: false
        ),
        Shop(
            name: "Bella Vista Italian Kitchen",
            description: "Traditional Italian cuisine with a modern twist",
            location: northBeachLocation,
            phoneNumber: "(415) 555-0456",
            website: URL(string: "https://bellavista.com"),
            hours: BusinessHours(
                monday: nil,
                tuesday: .init(open: "17:00", close: "22:00", isClosed: false),
                wednesday: .init(open: "17:00", close: "22:00", isClosed: false),
                thursday: .init(open: "17:00", close: "22:00", isClosed: false),
                friday: .init(open: "17:00", close: "23:00", isClosed: false),
                saturday: .init(open: "17:00", close: "23:00", isClosed: false),
                sunday: .init(open: "16:00", close: "21:00", isClosed: false)
            ),
            cuisineTypes: [.italian],
            drinkTypes: [.coffee],
            priceRange: .expensive,
            rating: 4.7,
            reviewsCount: 456,
            photosCount: 890,
            isVerified: true,
            featuredImageURL: URL(string: "https://picsum.photos/400/300?random=11"),
            isFavorite: false
        ),
        Shop(
            name: "Taco Libre",
            description: "Authentic Mexican street tacos",
            location: missionLocation,
            phoneNumber: "(415) 555-0789",
            hours: BusinessHours(
                monday: .init(open: "11:00", close: "23:00", isClosed: false),
                tuesday: .init(open: "11:00", close: "23:00", isClosed: false),
                wednesday: .init(open: "11:00", close: "23:00", isClosed: false),
                thursday: .init(open: "11:00", close: "23:00", isClosed: false),
                friday: .init(open: "11:00", close: "01:00", isClosed: false),
                saturday: .init(open: "11:00", close: "01:00", isClosed: false),
                sunday: .init(open: "11:00", close: "22:00", isClosed: false)
            ),
            cuisineTypes: [.mexican],
            drinkTypes: [.fruitTea],
            priceRange: .budget,
            rating: 4.3,
            reviewsCount: 678,
            photosCount: 432,
            isVerified: false,
            featuredImageURL: URL(string: "https://picsum.photos/400/300?random=12"),
            isFavorite: false
        ),
        Shop(
            name: "Blue Bottle Coffee",
            description: "Artisanal coffee roasted to perfection",
            location: sampleLocation,
            phoneNumber: "(415) 555-0321",
            website: URL(string: "https://bluebottlecoffee.com"),
            hours: BusinessHours(
                monday: .init(open: "6:00", close: "19:00", isClosed: false),
                tuesday: .init(open: "6:00", close: "19:00", isClosed: false),
                wednesday: .init(open: "6:00", close: "19:00", isClosed: false),
                thursday: .init(open: "6:00", close: "19:00", isClosed: false),
                friday: .init(open: "6:00", close: "20:00", isClosed: false),
                saturday: .init(open: "7:00", close: "20:00", isClosed: false),
                sunday: .init(open: "7:00", close: "19:00", isClosed: false)
            ),
            cuisineTypes: [.cafe],
            drinkTypes: [.coffee],
            priceRange: .moderate,
            rating: 4.6,
            reviewsCount: 1247,
            photosCount: 892,
            isVerified: true,
            featuredImageURL: URL(string: "https://picsum.photos/400/300?random=13"),
            isFavorite: true
        ),
        Shop(
            name: "Sakura Sushi Bar",
            description: "Authentic Japanese sushi and sashimi",
            location: somLocation,
            phoneNumber: "(415) 555-1234",
            website: URL(string: "https://sakurasushi.com"),
            hours: BusinessHours(
                monday: nil,
                tuesday: .init(open: "17:30", close: "22:00", isClosed: false),
                wednesday: .init(open: "17:30", close: "22:00", isClosed: false),
                thursday: .init(open: "17:30", close: "22:00", isClosed: false),
                friday: .init(open: "17:30", close: "23:00", isClosed: false),
                saturday: .init(open: "17:30", close: "23:00", isClosed: false),
                sunday: .init(open: "17:00", close: "21:30", isClosed: false)
            ),
            cuisineTypes: [.japanese],
            drinkTypes: [.tea],
            priceRange: .expensive,
            rating: 4.8,
            reviewsCount: 892,
            photosCount: 1234,
            isVerified: true,
            featuredImageURL: URL(string: "https://picsum.photos/400/300?random=14"),
            isFavorite: false
        ),
        Shop(
            name: "Spice Garden Indian",
            description: "Traditional Indian curries and tandoor specialties",
            location: chinatownLocation,
            phoneNumber: "(415) 555-5678",
            hours: BusinessHours(
                monday: .init(open: "11:30", close: "22:00", isClosed: false),
                tuesday: .init(open: "11:30", close: "22:00", isClosed: false),
                wednesday: .init(open: "11:30", close: "22:00", isClosed: false),
                thursday: .init(open: "11:30", close: "22:00", isClosed: false),
                friday: .init(open: "11:30", close: "22:30", isClosed: false),
                saturday: .init(open: "11:30", close: "22:30", isClosed: false),
                sunday: .init(open: "12:00", close: "22:00", isClosed: false)
            ),
            cuisineTypes: [.indian],
            drinkTypes: [.tea],
            priceRange: .moderate,
            rating: 4.4,
            reviewsCount: 567,
            photosCount: 789,
            isVerified: false,
            featuredImageURL: URL(string: "https://picsum.photos/400/300?random=15"),
            isFavorite: false
        )
    ]
    
    // MARK: - Posts (for SwiftUI previews only)
    static func generatePreviewPosts() -> [Post] {
        let posts = [
            Post(
                id: UUID(),
                convexId: "mock_post_1",
                userId: currentUser.id,
                author: currentUser,
                title: "Perfect Matcha Latte",
                caption: "Found the most amazing matcha latte at The Matcha House! The foam art is incredible and the flavor is so authentic. Definitely my new favorite spot for afternoon coffee breaks. ✨",
                mediaURLs: [URL(string: "https://picsum.photos/400/400?random=101")!],
                shop: sampleShops[0],
                location: sampleLocation,
                menuItems: ["Ceremonial Matcha Latte", "Matcha Cheesecake"],
                rating: 4.8,
                createdAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
                likesCount: 47,
                commentsCount: 8,
                isLiked: false,
                isSaved: true
            ),
            Post(
                id: UUID(),
                convexId: "mock_post_2",
                userId: sampleUsers[6].id, // Sophia Rossi - Wine expert
                author: sampleUsers[6],
                title: "Truffle Pasta & Wine Pairing",
                caption: "Indulged in the most incredible truffle pappardelle at Bella Vista tonight paired with a 2019 Barolo. The earthy flavors complement each other perfectly! Chef's kiss 🍝🍷✨",
                mediaURLs: [
                    URL(string: "https://picsum.photos/400/400?random=102")!,
                    URL(string: "https://picsum.photos/400/400?random=103")!
                ],
                shop: sampleShops[1],
                location: northBeachLocation,
                menuItems: ["Truffle Pappardelle", "Burrata Appetizer", "Tiramisu"],
                rating: 4.9,
                createdAt: Calendar.current.date(byAdding: .hour, value: -5, to: Date()) ?? Date(),
                likesCount: 123,
                commentsCount: 15,
                isLiked: true,
                isSaved: false
            ),
            Post(
                id: UUID(),
                convexId: "mock_post_3",
                userId: sampleUsers[4].id, // Maria Gonzalez - Mexican food expert
                author: sampleUsers[4],
                title: "Authentic Street Tacos",
                caption: "Finally found tacos that remind me of home! The carnitas are perfectly seasoned and the salsa verde has that authentic kick. Abuela would approve 🌮🔥",
                mediaURLs: [URL(string: "https://picsum.photos/400/400?random=104")!],
                shop: sampleShops[2],
                location: missionLocation,
                menuItems: ["Carnitas Tacos", "Al Pastor", "Horchata"],
                rating: 4.6,
                createdAt: Calendar.current.date(byAdding: .hour, value: -8, to: Date()) ?? Date(),
                likesCount: 89,
                commentsCount: 12,
                isLiked: false,
                isSaved: true
            ),
            Post(
                id: UUID(),
                convexId: "mock_post_4",
                userId: sampleUsers[3].id, // Taylor Williams - Vegan advocate
                author: sampleUsers[3],
                title: "Vegan Chocolate Decadence",
                caption: "Who says vegan desserts can't be decadent? This raw chocolate avocado mousse cake is rich, creamy, and absolutely divine. You'd never guess it's plant-based! 🍰🌱",
                mediaURLs: [URL(string: "https://picsum.photos/400/400?random=105")!],
                shop: nil,
                location: sampleLocation,
                menuItems: ["Raw Chocolate Avocado Cake", "Coconut Whipped Cream"],
                rating: 4.7,
                createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                likesCount: 156,
                commentsCount: 23,
                isLiked: true,
                isSaved: true
            ),
            Post(
                id: UUID(),
                convexId: "mock_post_5",
                userId: previewUser.id,
                author: previewUser,
                title: "Morning Coffee Ritual",
                caption: "Starting the day right with a perfectly crafted cortado from Blue Bottle. The single origin notes are incredible - bright citrus with chocolate undertones ☕️✨",
                mediaURLs: [URL(string: "https://picsum.photos/400/400?random=106")!],
                shop: sampleShops[3],
                location: sampleLocation,
                menuItems: ["Cortado", "Almond Croissant"],
                rating: 4.5,
                createdAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
                likesCount: 234,
                commentsCount: 31,
                isLiked: false,
                isSaved: false
            ),
            Post(
                id: UUID(),
                convexId: "mock_post_6",
                userId: sampleUsers[8].id, // Lisa Thompson - Nutritionist
                author: sampleUsers[8],
                title: "Keto Avocado Bowl",
                caption: "Perfect keto breakfast bowl! Avocado, hemp hearts, MCT oil, and everything bagel seasoning. High fat, zero carbs, endless energy 🥑💪",
                mediaURLs: [URL(string: "https://picsum.photos/400/400?random=107")!],
                shop: nil,
                location: sampleLocation,
                menuItems: ["Avocado Bowl", "Hemp Hearts", "MCT Oil"],
                rating: 4.4,
                createdAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                likesCount: 67,
                commentsCount: 9,
                isLiked: true,
                isSaved: false
            ),
            Post(
                id: UUID(),
                convexId: "mock_post_7",
                userId: sampleUsers[5].id, // David Kimura - Sushi expert
                author: sampleUsers[5],
                title: "Omakase Experience",
                caption: "Incredible 18-course omakase at Sakura! Chef's selection was flawless - from the buttery chu-toro to the perfectly seasoned uni. Worth every penny 🍣",
                mediaURLs: [
                    URL(string: "https://picsum.photos/400/400?random=108")!,
                    URL(string: "https://picsum.photos/400/400?random=109")!,
                    URL(string: "https://picsum.photos/400/400?random=110")!
                ],
                shop: sampleShops[4],
                location: somLocation,
                menuItems: ["18-Course Omakase", "Chu-toro", "Uni", "Sake Pairing"],
                rating: 5.0,
                createdAt: Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date(),
                likesCount: 287,
                commentsCount: 42,
                isLiked: true,
                isSaved: true
            ),
            Post(
                id: UUID(),
                convexId: "mock_post_8",
                userId: sampleUsers[7].id, // Ahmed Patel - Indian spice master
                author: sampleUsers[7],
                title: "Authentic Biryani",
                caption: "This chicken biryani at Spice Garden brings back memories of my grandmother's cooking. The saffron, the perfectly cooked basmati, the tender meat - pure perfection! 🍛",
                mediaURLs: [URL(string: "https://picsum.photos/400/400?random=111")!],
                shop: sampleShops[5],
                location: chinatownLocation,
                menuItems: ["Chicken Biryani", "Raita", "Naan"],
                rating: 4.6,
                createdAt: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
                likesCount: 145,
                commentsCount: 18,
                isLiked: false,
                isSaved: true
            ),
            Post(
                id: UUID(),
                convexId: "mock_post_9",
                userId: sampleUsers[9].id, // Mike Anderson - BBQ master
                author: sampleUsers[9],
                title: "Weekend Smoke Session",
                caption: "14-hour brisket smoke session complete! Bark is perfect, smoke ring is deep, and the flavor is incredible. Nothing beats low and slow BBQ 🔥🥩",
                mediaURLs: [
                    URL(string: "https://picsum.photos/400/400?random=112")!,
                    URL(string: "https://picsum.photos/400/400?random=113")!
                ],
                shop: nil,
                location: sampleLocation,
                menuItems: ["14-Hour Smoked Brisket", "Coleslaw", "BBQ Sauce"],
                rating: 4.9,
                createdAt: Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date(),
                likesCount: 198,
                commentsCount: 25,
                isLiked: true,
                isSaved: false
            ),
            Post(
                id: UUID(),
                convexId: "mock_post_10",
                userId: sampleUsers[1].id, // Kim Tanaka - Ramen enthusiast
                author: sampleUsers[1],
                title: "Homemade Tonkotsu Ramen",
                caption: "Spent 18 hours making this tonkotsu broth from scratch. The pork bones, the perfect chashu, house-made noodles - this is what real ramen should taste like! 🍜",
                mediaURLs: [URL(string: "https://picsum.photos/400/400?random=114")!],
                shop: nil,
                location: sampleLocation,
                menuItems: ["Tonkotsu Ramen", "Chashu Pork", "Soft-boiled Egg"],
                rating: 5.0,
                createdAt: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
                likesCount: 412,
                commentsCount: 67,
                isLiked: true,
                isSaved: true
            ),
            Post(
                id: UUID(),
                convexId: "mock_post_11",
                userId: sampleUsers[2].id, // Sam Johnson - Pastry chef
                author: sampleUsers[2],
                title: "French Macaron Masterclass",
                caption: "Finally nailed the perfect macaron! Smooth tops, ruffled feet, and that perfect chewy texture. Raspberry and dark chocolate ganache filling 🥮✨",
                mediaURLs: [
                    URL(string: "https://picsum.photos/400/400?random=115")!,
                    URL(string: "https://picsum.photos/400/400?random=116")!
                ],
                shop: nil,
                location: sampleLocation,
                menuItems: ["French Macarons", "Raspberry Ganache", "Dark Chocolate"],
                rating: 4.8,
                createdAt: Calendar.current.date(byAdding: .day, value: -8, to: Date()) ?? Date(),
                likesCount: 234,
                commentsCount: 31,
                isLiked: false,
                isSaved: true
            ),
            Post(
                id: UUID(),
                convexId: "mock_post_12",
                userId: sampleUsers[0].id, // Jamie Park - Coffee enthusiast
                author: sampleUsers[0],
                title: "Latte Art Competition",
                caption: "Just won 2nd place in the SF Latte Art Championship! This rosetta took months of practice to perfect. Coffee is truly an art form ☕🏆",
                mediaURLs: [URL(string: "https://picsum.photos/400/400?random=117")!],
                shop: sampleShops[3],
                location: sampleLocation,
                menuItems: ["Competition Latte", "Single Origin Espresso"],
                rating: 4.7,
                createdAt: Calendar.current.date(byAdding: .day, value: -9, to: Date()) ?? Date(),
                likesCount: 156,
                commentsCount: 22,
                isLiked: true,
                isSaved: false
            )
        ]
        
        return posts
    }
    
    // MARK: - Enhanced User-specific Posts with Rich Content
    static func generateUserPosts(for user: User) -> [Post] {
        // Generate 15-20 posts with varied content for rich previews
        let postTemplates = [
            (
                title: "Weekend Brunch Discovery",
                caption: "Discovered this amazing hidden gem for weekend brunch! The eggs benedict is cooked to perfection and the hollandaise sauce is divine. The hash browns are crispy outside, fluffy inside. Already planning my next visit! 🍳✨ #BrunchLife #FoodieFinds",
                menuItems: ["Eggs Benedict", "Fresh Fruit Bowl", "Mimosa", "Avocado Toast"],
                rating: 4.6,
                likesCount: 89,
                commentsCount: 12,
                dayOffset: -1
            ),
            (
                title: "Homemade Pasta Night",
                caption: "Spent the afternoon making fresh pasta from scratch. Hand-rolled pappardelle with wild mushroom ragu - nothing beats the satisfaction of homemade comfort food. The process is meditative and the results are incredible 🍝👨‍🍳 #HomeCooking #PastaLove",
                menuItems: ["Hand-rolled Pappardelle", "Wild Mushroom Ragu", "Parmesan Crisp"],
                rating: 5.0,
                likesCount: 167,
                commentsCount: 24,
                dayOffset: -4
            ),
            (
                title: "Farmers Market Haul",
                caption: "Saturday morning at the farmers market never disappoints! Got these beautiful heirloom tomatoes, fresh basil, and artisanal cheese. Can't wait to make a caprese salad that'll make you question everything 🍅🌿🧀 #FarmersMarket #FreshIngredients",
                menuItems: ["Heirloom Tomatoes", "Fresh Basil", "Buffalo Mozzarella", "Sourdough Bread"],
                rating: nil,
                likesCount: 45,
                commentsCount: 6,
                dayOffset: -7
            ),
            (
                title: "Late Night Ramen Craving",
                caption: "Sometimes you just need a proper bowl of ramen at 11 PM. This spicy miso ramen hit all the right spots - rich, complex broth, perfect noodles, and that soft egg that breaks like silk 🍜🔥 #RamenLife #LateNightEats",
                menuItems: ["Spicy Miso Ramen", "Soft-boiled Egg", "Bamboo Shoots", "Nori"],
                rating: 4.5,
                likesCount: 78,
                commentsCount: 11,
                dayOffset: -10
            ),
            (
                title: "Sourdough Success",
                caption: "After weeks of failed attempts, finally nailed the perfect sourdough! Crispy crust, open crumb, and that tangy flavor. My starter 'Winston' is finally cooperating. The aroma filled the entire house 🍞❤️ #SourdoughJourney #BreadMaking",
                menuItems: ["Homemade Sourdough", "Sea Salt Butter", "Local Honey"],
                rating: 4.8,
                likesCount: 234,
                commentsCount: 35,
                dayOffset: -14
            ),
            (
                title: "Sushi Master Class",
                caption: "Took a sushi making class today and learned the art of proper rice preparation. The chef showed us how to cut fish at the perfect angle. My california rolls actually looked decent! 🍣🎓 #SushiClass #LearningNewSkills",
                menuItems: ["California Roll", "Salmon Nigiri", "Miso Soup", "Edamame"],
                rating: 4.7,
                likesCount: 123,
                commentsCount: 18,
                dayOffset: -17
            ),
            (
                title: "Wine Tasting Adventure",
                caption: "Explored Napa Valley today and discovered some incredible small batch wines. This Pinot Noir has notes of cherry and earth that transport you. Perfect pairing with aged cheese 🍷🧀 #WineTasting #NapaValley",
                menuItems: ["Pinot Noir 2019", "Aged Cheddar", "Fig Jam", "Crackers"],
                rating: 4.9,
                likesCount: 156,
                commentsCount: 27,
                dayOffset: -20
            ),
            (
                title: "Korean BBQ Night",
                caption: "Korean BBQ with friends is always a good idea! The galbi was perfectly marinated and grilled to perfection. Nothing beats cooking your own meat at the table while sharing stories 🥩🔥 #KoreanBBQ #FriendsNight",
                menuItems: ["Galbi", "Bulgogi", "Kimchi", "Korean Fried Rice"],
                rating: 4.6,
                likesCount: 201,
                commentsCount: 33,
                dayOffset: -23
            ),
            (
                title: "Coffee Cupping Session",
                caption: "Attended a coffee cupping session today and my palate is blown! Learned to identify flavor notes I never knew existed. This Ethiopian single origin has bright blueberry notes ☕️👃 #CoffeeCupping #SingleOrigin",
                menuItems: ["Ethiopian Yirgacheffe", "Colombian Supremo", "Dark Chocolate"],
                rating: 4.4,
                likesCount: 87,
                commentsCount: 14,
                dayOffset: -26
            ),
            (
                title: "Michelin Star Experience",
                caption: "Saved up for months for this Michelin star tasting menu and it exceeded every expectation. Each course was a work of art. The amuse-bouche alone was worth the price 🌟👨‍🍳 #MichelinStar #FineDining",
                menuItems: ["12-Course Tasting Menu", "Wine Pairing", "Petit Fours"],
                rating: 5.0,
                likesCount: 445,
                commentsCount: 67,
                dayOffset: -30
            ),
            (
                title: "Street Food Festival",
                caption: "Street food festival was incredible! Tried fusion tacos, Korean corn dogs, and Thai mango sticky rice. The diversity of flavors in one place is mind-blowing 🌮🌽🥭 #StreetFood #FoodFestival",
                menuItems: ["Fusion Tacos", "Korean Corn Dogs", "Mango Sticky Rice", "Bubble Tea"],
                rating: 4.3,
                likesCount: 167,
                commentsCount: 22,
                dayOffset: -33
            ),
            (
                title: "Homemade Pizza Night",
                caption: "Made pizza from scratch tonight! Hand-stretched dough, fresh mozzarella, and basil from the garden. The crust came out perfectly crispy with just the right amount of char 🍕🔥 #HomemadePizza #PizzaNight",
                menuItems: ["Margherita Pizza", "Pepperoni Pizza", "Caesar Salad"],
                rating: 4.5,
                likesCount: 134,
                commentsCount: 19,
                dayOffset: -36
            ),
            (
                title: "Dessert Heaven",
                caption: "This chocolate lava cake is pure perfection! The molten center flows like silk and paired with vanilla bean ice cream, it's heavenly. Sometimes you just need to treat yourself 🍰🍦 #DessertTime #ChocolateLover",
                menuItems: ["Chocolate Lava Cake", "Vanilla Bean Ice Cream", "Fresh Berries"],
                rating: 4.8,
                likesCount: 298,
                commentsCount: 41,
                dayOffset: -39
            ),
            (
                title: "Healthy Bowl Creation",
                caption: "Created this colorful Buddha bowl with quinoa, roasted vegetables, and tahini dressing. Eating the rainbow never tasted so good! Feeling energized and satisfied 🥗🌈 #HealthyEating #BuddleBowl",
                menuItems: ["Quinoa Buddha Bowl", "Tahini Dressing", "Roasted Chickpeas"],
                rating: 4.2,
                likesCount: 112,
                commentsCount: 15,
                dayOffset: -42
            ),
            (
                title: "Dim Sum Brunch",
                caption: "Dim sum brunch is the best brunch! Har gow, siu mai, and char siu bao - each dumpling is a little pocket of joy. The tea service makes it even more special 🥟🍵 #DimSum #ChineseCuisine",
                menuItems: ["Har Gow", "Siu Mai", "Char Siu Bao", "Jasmine Tea"],
                rating: 4.7,
                likesCount: 189,
                commentsCount: 28,
                dayOffset: -45
            ),
            (
                title: "Seafood Market Fresh",
                caption: "Bought fresh lobster from the market today and grilled it with garlic butter. The sweetness of the meat with that smoky char is unbeatable. Simple ingredients, perfect execution 🦞🧄 #FreshSeafood #GrilledLobster",
                menuItems: ["Grilled Lobster", "Garlic Butter", "Lemon", "Asparagus"],
                rating: 4.9,
                likesCount: 267,
                commentsCount: 34,
                dayOffset: -48
            ),
            (
                title: "Artisanal Ice Cream",
                caption: "This lavender honey ice cream is unlike anything I've ever tasted! The floral notes are subtle and the honey adds the perfect sweetness. Summer in a scoop 🍦💜 #ArtisanalIceCream #LavenderHoney",
                menuItems: ["Lavender Honey Ice Cream", "Waffle Cone", "Candied Violets"],
                rating: 4.6,
                likesCount: 156,
                commentsCount: 21,
                dayOffset: -51
            ),
            (
                title: "BBQ Smokehouse",
                caption: "Spent 12 hours smoking this brisket and the bark is absolutely perfect! Low and slow is the only way. The smoke ring tells the whole story of patience and technique 🔥🥩 #BBQ #SmokedBrisket",
                menuItems: ["Smoked Brisket", "Mac and Cheese", "Coleslaw", "Cornbread"],
                rating: 5.0,
                likesCount: 378,
                commentsCount: 56,
                dayOffset: -54
            ),
            (
                title: "Farm-to-Table Dinner",
                caption: "Farm-to-table dinner where every ingredient was sourced within 20 miles. The connection between the food and the land is incredible. This is how food should be 🌱🚜 #FarmToTable #LocalIngredients",
                menuItems: ["Local Pork Chop", "Seasonal Vegetables", "Heirloom Potatoes"],
                rating: 4.8,
                likesCount: 223,
                commentsCount: 37,
                dayOffset: -57
            ),
            (
                title: "Craft Cocktail Experience",
                caption: "This mixologist is an artist! The craft cocktail combines flavors I never thought would work together. Smoky mezcal, fresh pineapple, and jalapeño - genius 🍹🔥 #CraftCocktails #Mixology",
                menuItems: ["Smoky Pineapple Margarita", "Duck Tacos", "Guacamole"],
                rating: 4.7,
                likesCount: 189,
                commentsCount: 25,
                dayOffset: -60
            )
        ]
        
        // Generate posts from templates
        var userPosts: [Post] = []
        let randomTemplates = postTemplates.shuffled().prefix(min(18, postTemplates.count))
        
        for (index, template) in randomTemplates.enumerated() {
            let post = Post(
                id: UUID(),
                convexId: "mock_user_post_\(index + 1)",
                userId: user.id,
                author: user,
                title: template.title,
                caption: template.caption,
                mediaURLs: [
                    URL(string: "https://picsum.photos/400/400?random=\(200 + index)")!,
                    // Add additional images for some posts
                    index % 3 == 0 ? URL(string: "https://picsum.photos/400/400?random=\(300 + index)")! : nil,
                    index % 5 == 0 ? URL(string: "https://picsum.photos/400/400?random=\(400 + index)")! : nil
                ].compactMap { $0 },
                shop: index % 4 == 0 ? sampleShops.randomElement() : nil,
                location: [sampleLocation, missionLocation, northBeachLocation, somLocation].randomElement() ?? sampleLocation,
                menuItems: template.menuItems,
                rating: template.rating,
                createdAt: Calendar.current.date(byAdding: .day, value: template.dayOffset, to: Date()) ?? Date(),
                likesCount: template.likesCount,
                commentsCount: template.commentsCount,
                isLiked: index % 4 == 0,
                isSaved: index % 6 == 0
            )
            userPosts.append(post)
        }
        
        return userPosts.sorted { $0.createdAt > $1.createdAt }
    }
    
    // MARK: - Specialized Mock Data Generators
    
    /// Generate posts for a specific cuisine type
    static func generatePostsForCuisine(_ cuisineType: CuisineType) -> [Post] {
        switch cuisineType {
        case .japanese:
            return [
                Post(
                    id: UUID(),
                    convexId: "japanese_post_1",
                    userId: sampleUsers[5].id,
                    author: sampleUsers[5],
                    title: "Authentic Chirashi Bowl",
                    caption: "Fresh sashimi over perfectly seasoned sushi rice. The fish quality is exceptional - each piece melts in your mouth 🍣",
                    mediaURLs: [URL(string: "https://picsum.photos/400/400?random=300")!],
                    shop: sampleShops[4],
                    location: somLocation,
                    menuItems: ["Chirashi Bowl", "Miso Soup", "Green Tea"],
                    rating: 4.7,
                    createdAt: Date(),
                    likesCount: 156,
                    commentsCount: 18
                )
            ]
        case .italian:
            return [
                Post(
                    id: UUID(),
                    convexId: "italian_post_1",
                    userId: sampleUsers[6].id,
                    author: sampleUsers[6],
                    title: "Cacio e Pepe Perfection",
                    caption: "Simple ingredients, perfect execution. This cacio e pepe is what Roman dreams are made of 🍝",
                    mediaURLs: [URL(string: "https://picsum.photos/400/400?random=301")!],
                    shop: sampleShops[1],
                    location: northBeachLocation,
                    menuItems: ["Cacio e Pepe", "Caesar Salad", "Chianti"],
                    rating: 4.8,
                    createdAt: Date(),
                    likesCount: 203,
                    commentsCount: 25
                )
            ]
        default:
            return []
        }
    }
    
    /// Generate posts for dietary preferences
    static func generatePostsForDiet(_ preference: DietaryPreference) -> [Post] {
        switch preference {
        case .vegan:
            return [
                Post(
                    id: UUID(),
                    convexId: "vegan_post_1",
                    userId: sampleUsers[3].id,
                    author: sampleUsers[3],
                    title: "Cashew Alfredo Paradise",
                    caption: "Who needs dairy when you can make alfredo this creamy with cashews? Paired with fresh spinach and sun-dried tomatoes 🌱",
                    mediaURLs: [URL(string: "https://picsum.photos/400/400?random=400")!],
                    shop: nil,
                    location: sampleLocation,
                    menuItems: ["Cashew Alfredo", "Spinach", "Sun-dried Tomatoes"],
                    rating: 4.6,
                    createdAt: Date(),
                    likesCount: 134,
                    commentsCount: 16
                )
            ]
        case .keto:
            return [
                Post(
                    id: UUID(),
                    convexId: "keto_post_1",
                    userId: sampleUsers[8].id,
                    author: sampleUsers[8],
                    title: "Cauliflower Risotto",
                    caption: "Amazing how cauliflower can mimic risotto so perfectly! Loaded with parmesan and herbs - zero guilt, all flavor 🥦",
                    mediaURLs: [URL(string: "https://picsum.photos/400/400?random=401")!],
                    shop: nil,
                    location: sampleLocation,
                    menuItems: ["Cauliflower Risotto", "Parmesan", "Fresh Herbs"],
                    rating: 4.4,
                    createdAt: Date(),
                    likesCount: 89,
                    commentsCount: 12
                )
            ]
        default:
            return []
        }
    }
    
    /// Generate trending posts
    static func generateTrendingPosts() -> [Post] {
        return generatePreviewPosts().filter { $0.likesCount > 150 }
    }
    
    /// Generate recent posts (last 24 hours)
    static func generateRecentPosts() -> [Post] {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return generatePreviewPosts().filter { $0.createdAt > yesterday }
    }
    
    // MARK: - Specialized Post Generators for Rich Previews
    
    /// Generate photography-focused posts
    static func generatePhotographyPosts(for user: User) -> [Post] {
        let photoPostTemplates = [
            (
                title: "Golden Hour Magic",
                caption: "Captured this truffle pasta during golden hour and the lighting is everything! The way the light hits the shaved truffles creates such depth. Food photography is all about timing ✨📸 #GoldenHour #FoodPhotography #TrufflePasta",
                menuItems: ["Truffle Pasta", "Shaved Black Truffle", "Parmesan"],
                rating: 4.9,
                likesCount: 567,
                commentsCount: 43,
                dayOffset: -2
            ),
            (
                title: "Macro Lens Magic",
                caption: "Used my new macro lens to capture the intricate details of this chocolate dessert. You can see every crystalline sugar structure! Sometimes the smallest details tell the biggest stories 🍫🔍 #MacroPhotography #ChocolateArt",
                menuItems: ["Chocolate Sculpture", "Gold Leaf", "Raspberry Coulis"],
                rating: 5.0,
                likesCount: 892,
                commentsCount: 67,
                dayOffset: -5
            ),
            (
                title: "Behind the Scenes",
                caption: "Setting up for a restaurant shoot today. 47 plates, 12 lighting setups, and endless adjustments. The final shot will be worth it! Food photography is 90% preparation 📷⚡ #BehindTheScenes #RestaurantShoot",
                menuItems: ["Styled Dishes", "Photography Equipment"],
                rating: nil,
                likesCount: 234,
                commentsCount: 28,
                dayOffset: -8
            )
        ]
        
        return generatePostsFromTemplates(photoPostTemplates, for: user, startIndex: 500)
    }
    
    /// Generate sushi-focused posts
    static func generateSushiPosts(for user: User) -> [Post] {
        let sushiPostTemplates = [
            (
                title: "Perfect Chu-Toro",
                caption: "This chu-toro melts like butter! The marbling is absolutely perfect - you can taste the craftsmanship in every bite. Chef trained in Tsukiji for 15 years and it shows 🍣✨ #ChutoroNigiri #SushiCraftsmanship #Tsukiji",
                menuItems: ["Chu-toro Nigiri", "Wasabi", "Soy Sauce", "Pickled Ginger"],
                rating: 5.0,
                likesCount: 1234,
                commentsCount: 89,
                dayOffset: -1
            ),
            (
                title: "Omakase Masterclass",
                caption: "20-course omakase journey at Sakura. Each piece tells a story of seasons, technique, and tradition. The uni from Hokkaido was transcendent. This is why I study sushi 🍣🎌 #Omakase #TraditionalSushi #HokkaidoUni",
                menuItems: ["20-Course Omakase", "Hokkaido Uni", "Seasonal Fish", "Sake Pairing"],
                rating: 5.0,
                likesCount: 1876,
                commentsCount: 156,
                dayOffset: -4
            ),
            (
                title: "Rice Temperature Matters",
                caption: "Perfect sushi rice is body temperature - 98.6°F exactly. Too cold and it doesn't meld with the fish. Too warm and it falls apart. The details matter in sushi 🍚🌡️ #SushiRice #TechnicalDetails #SushiEducation",
                menuItems: ["Shari (Sushi Rice)", "Rice Vinegar", "Sea Salt"],
                rating: 4.8,
                likesCount: 567,
                commentsCount: 67,
                dayOffset: -7
            )
        ]
        
        return generatePostsFromTemplates(sushiPostTemplates, for: user, startIndex: 600)
    }
    
    /// Generate wine-focused posts
    static func generateWinePosts(for user: User) -> [Post] {
        let winePostTemplates = [
            (
                title: "Perfect Pairing Discovery",
                caption: "2018 Barolo with truffle risotto - the earthy tannins complement the mushroom earthiness perfectly. The wine's structure holds up to the rich texture. Poetry in a glass 🍷🍄 #BaroloPairing #TruffleRisotto #WineSommelier",
                menuItems: ["2018 Barolo", "Truffle Risotto", "Aged Parmesan"],
                rating: 4.9,
                likesCount: 934,
                commentsCount: 78,
                dayOffset: -3
            ),
            (
                title: "Vintage Bordeaux Tasting",
                caption: "Tasting a 1989 Bordeaux tonight and the complexity is incredible. Notes of leather, tobacco, and dark fruit that develop for minutes after each sip. Some wines are liquid history 🍷📚 #VintageBordeaux #WineTasting #1989Vintage",
                menuItems: ["1989 Bordeaux", "Aged Cheese Selection", "Dark Chocolate"],
                rating: 5.0,
                likesCount: 1456,
                commentsCount: 123,
                dayOffset: -6
            ),
            (
                title: "Champagne Knowledge",
                caption: "Real Champagne only comes from the Champagne region of France. Everything else is sparkling wine! The méthode champenoise creates those perfect bubbles. Education is key to appreciation 🥂🇫🇷 #ChampagneEducation #MethodeChampenoise",
                menuItems: ["Dom Pérignon 2012", "Fresh Oysters", "Caviar"],
                rating: 4.7,
                likesCount: 678,
                commentsCount: 45,
                dayOffset: -9
            )
        ]
        
        return generatePostsFromTemplates(winePostTemplates, for: user, startIndex: 700)
    }
    
    /// Generate BBQ-focused posts
    static func generateBBQPosts(for user: User) -> [Post] {
        let bbqPostTemplates = [
            (
                title: "16-Hour Brisket Journey",
                caption: "Started this brisket at 4 AM and it's finally ready! 16 hours at 225°F with post oak. The bark is perfect and the smoke ring is deep red. Low and slow is the only way 🔥🥩 #BrisketMaster #16HourSmoke #PostOakWood",
                menuItems: ["Smoked Brisket", "BBQ Sauce", "Pickles", "White Bread"],
                rating: 5.0,
                likesCount: 2134,
                commentsCount: 178,
                dayOffset: -2
            ),
            (
                title: "Competition BBQ Setup",
                caption: "Setting up for the Bay Area BBQ Championship! Four categories to compete in: brisket, ribs, pork, and chicken. The competition is fierce but I'm ready 🏆🔥 #BBQCompetition #PitMaster #CompetitionBBQ",
                menuItems: ["Competition Brisket", "St. Louis Ribs", "Pork Shoulder", "Chicken Thighs"],
                rating: nil,
                likesCount: 876,
                commentsCount: 89,
                dayOffset: -5
            ),
            (
                title: "Wood Selection Science",
                caption: "Different woods create different flavors. Apple for subtle sweetness, hickory for bold smoke, cherry for color. Post oak is my go-to for brisket - clean burn, mild flavor 🪵🔬 #BBQScience #WoodSelection #SmokeFlavors",
                menuItems: ["Apple Wood", "Hickory", "Cherry Wood", "Post Oak"],
                rating: 4.8,
                likesCount: 567,
                commentsCount: 67,
                dayOffset: -8
            )
        ]
        
        return generatePostsFromTemplates(bbqPostTemplates, for: user, startIndex: 800)
    }
    
    /// Generate vegan-focused posts
    static func generateVeganPosts(for user: User) -> [Post] {
        let veganPostTemplates = [
            (
                title: "Cashew Cream Perfection",
                caption: "Made this incredible cashew cream sauce from scratch! Soaked overnight, blended with nutritional yeast and lemon. You won't believe it's not dairy. Plant-based cooking is pure magic 🥜✨ #CashewCream #PlantBased #VeganCooking",
                menuItems: ["Cashew Cream Sauce", "Nutritional Yeast", "Lemon Juice"],
                rating: 4.8,
                likesCount: 678,
                commentsCount: 45,
                dayOffset: -3
            ),
            (
                title: "Rainbow Buddha Bowl",
                caption: "Eating the rainbow! Purple cabbage, orange carrots, green kale, yellow peppers. Each color provides different nutrients and antioxidants. Nature's pharmacy on a plate 🌈🥗 #BuddhaOwl #EatTheRainbow #PlantBasedNutrition",
                menuItems: ["Rainbow Vegetables", "Quinoa", "Tahini Dressing", "Hemp Seeds"],
                rating: 4.6,
                likesCount: 567,
                commentsCount: 34,
                dayOffset: -6
            ),
            (
                title: "Vegan Cheese Success",
                caption: "Finally perfected my aged cashew cheese recipe! 3 weeks of culturing and it has that sharp, tangy flavor. Who says you need dairy for amazing cheese? 🧀🌱 #VeganCheese #CashewCheese #FermentedFoods",
                menuItems: ["Aged Cashew Cheese", "Crackers", "Fig Jam", "Walnuts"],
                rating: 4.9,
                likesCount: 1234,
                commentsCount: 89,
                dayOffset: -9
            )
        ]
        
        return generatePostsFromTemplates(veganPostTemplates, for: user, startIndex: 900)
    }
    
    /// Helper method to generate posts from templates
    private static func generatePostsFromTemplates(_ templates: [(title: String, caption: String, menuItems: [String], rating: Double?, likesCount: Int, commentsCount: Int, dayOffset: Int)], for user: User, startIndex: Int) -> [Post] {
        var posts: [Post] = []
        
        for (index, template) in templates.enumerated() {
            let post = Post(
                id: UUID(),
                convexId: "mock_specialized_post_\(startIndex + index)",
                userId: user.id,
                author: user,
                title: template.title,
                caption: template.caption,
                mediaURLs: [
                    URL(string: "https://picsum.photos/400/400?random=\(startIndex + index)")!,
                    URL(string: "https://picsum.photos/400/400?random=\(startIndex + index + 100)")!
                ],
                shop: sampleShops.randomElement(),
                location: [sampleLocation, missionLocation, northBeachLocation, somLocation].randomElement() ?? sampleLocation,
                menuItems: template.menuItems,
                rating: template.rating,
                createdAt: Calendar.current.date(byAdding: .day, value: template.dayOffset, to: Date()) ?? Date(),
                likesCount: template.likesCount,
                commentsCount: template.commentsCount,
                isLiked: index % 3 == 0,
                isSaved: index % 2 == 0
            )
            posts.append(post)
        }
        
        return posts
    }
}

// MARK: - Enhanced Mock View Models for ProfileView Previews
@MainActor
class EnhancedMockProfileViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var userPosts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    init(user: User) {
        self.currentUser = user
        self.userPosts = MockData.generateUserPosts(for: user)
    }
    
    func loadUserProfile() async {
        // Mock implementation - data already loaded
    }
    
    func loadOtherUserProfile(_ user: User) async {
        // Mock implementation - data already loaded
    }
}

// MARK: - Specialized Mock Profile ViewModels
@MainActor
class MockFoodPhotographerProfileViewModel: EnhancedMockProfileViewModel {
    init() {
        // Create new user with updated properties instead of modifying existing
        let user = User(
            id: MockData.previewUser.id,
            email: MockData.previewUser.email,
            firstName: MockData.previewUser.firstName,
            lastName: MockData.previewUser.lastName,
            username: MockData.previewUser.username,
            displayName: MockData.previewUser.displayName,
            bio: "Food photographer 📸 | Visual storyteller | Capturing the artistry of culinary creation from farm to table. Available for restaurant collaborations worldwide.",
            avatarURL: MockData.previewUser.avatarURL,
            clerkId: MockData.previewUser.clerkId,
            role: MockData.previewUser.role,
            dietaryPreferences: MockData.previewUser.dietaryPreferences,
            location: MockData.previewUser.location,
            joinedAt: MockData.previewUser.joinedAt,
            followersCount: 15647,
            followingCount: 1205,
            postsCount: 342
        )
        super.init(user: user)
        
        // Add specialized photography posts
        self.userPosts = MockData.generatePhotographyPosts(for: user) + self.userPosts
    }
}

@MainActor
class MockSushiExpertProfileViewModel: EnhancedMockProfileViewModel {
    init() {
        // Create new user with updated properties
        let originalUser = MockData.sampleUsers[5] // David Kimura
        let user = User(
            id: originalUser.id,
            email: originalUser.email,
            firstName: originalUser.firstName,
            lastName: originalUser.lastName,
            username: originalUser.username,
            displayName: originalUser.displayName,
            bio: "Sushi connoisseur 🍣 | Former Tokyo resident | 15 years studying authentic Japanese cuisine | Rating omakase experiences worldwide | Sake certified sommelier",
            avatarURL: originalUser.avatarURL,
            clerkId: originalUser.clerkId,
            role: originalUser.role,
            dietaryPreferences: originalUser.dietaryPreferences,
            location: originalUser.location,
            joinedAt: originalUser.joinedAt,
            followersCount: 23456,
            followingCount: 543,
            postsCount: 567
        )
        super.init(user: user)
        
        // Add specialized sushi posts
        self.userPosts = MockData.generateSushiPosts(for: user) + self.userPosts
    }
}

@MainActor
class MockWineSommelierProfileViewModel: EnhancedMockProfileViewModel {
    init() {
        // Create new user with updated properties
        let originalUser = MockData.sampleUsers[6] // Sophia Rossi
        let user = User(
            id: originalUser.id,
            email: originalUser.email,
            firstName: originalUser.firstName,
            lastName: originalUser.lastName,
            username: originalUser.username,
            displayName: originalUser.displayName,
            bio: "Wine sommelier 🍷 | Level 3 WSET certified | Italian cuisine expert | Pairing perfect wines with incredible dishes across the globe | Napa Valley native",
            avatarURL: originalUser.avatarURL,
            clerkId: originalUser.clerkId,
            role: originalUser.role,
            dietaryPreferences: originalUser.dietaryPreferences,
            location: originalUser.location,
            joinedAt: originalUser.joinedAt,
            followersCount: 34892,
            followingCount: 1234,
            postsCount: 789
        )
        super.init(user: user)
        
        // Add specialized wine posts
        self.userPosts = MockData.generateWinePosts(for: user) + self.userPosts
    }
}

@MainActor
class MockBBQMasterProfileViewModel: EnhancedMockProfileViewModel {
    init() {
        // Create new user with updated properties
        let originalUser = MockData.sampleUsers[9] // Mike Anderson
        let user = User(
            id: originalUser.id,
            email: originalUser.email,
            firstName: originalUser.firstName,
            lastName: originalUser.lastName,
            username: originalUser.username,
            displayName: originalUser.displayName,
            bio: "BBQ pitmaster 🔥 | Competition circuit veteran | 20+ years perfecting smoke and spice | Teaching low & slow techniques | Texas roots, Bay Area heart",
            avatarURL: originalUser.avatarURL,
            clerkId: originalUser.clerkId,
            role: originalUser.role,
            dietaryPreferences: originalUser.dietaryPreferences,
            location: originalUser.location,
            joinedAt: originalUser.joinedAt,
            followersCount: 45321,
            followingCount: 1567,
            postsCount: 678
        )
        super.init(user: user)
        
        // Add specialized BBQ posts
        self.userPosts = MockData.generateBBQPosts(for: user) + self.userPosts
    }
}

@MainActor
class MockVeganAdvocateProfileViewModel: EnhancedMockProfileViewModel {
    init() {
        // Create new user with updated properties
        let originalUser = MockData.sampleUsers[3] // Taylor Williams
        let user = User(
            id: originalUser.id,
            email: originalUser.email,
            firstName: originalUser.firstName,
            lastName: originalUser.lastName,
            username: originalUser.username,
            displayName: originalUser.displayName,
            bio: "Plant-based foodie 🌱 | Certified nutritionist | Healthy living advocate | Sharing delicious vegan finds and sustainable eating tips | Recipe developer",
            avatarURL: originalUser.avatarURL,
            clerkId: originalUser.clerkId,
            role: originalUser.role,
            dietaryPreferences: originalUser.dietaryPreferences,
            location: originalUser.location,
            joinedAt: originalUser.joinedAt,
            followersCount: 18923,
            followingCount: 634,
            postsCount: 234
        )
        super.init(user: user)
        
        // Add specialized vegan posts
        self.userPosts = MockData.generateVeganPosts(for: user) + self.userPosts
    }
}

// MARK: - Additional Mock Data Extensions for Specific Views

extension MockData {
    
    /// Mock data for explore view
    static let exploreCategories = [
        "Trending Now", "Coffee & Tea", "Asian Cuisine", "Italian", "Vegan Options", "Desserts", "Brunch Spots"
    ]
    
    /// Mock notifications for notification view
    static let sampleNotifications = [
        PalyttNotification(
            id: UUID().uuidString,
            userId: "mock_user_1",
            type: .postLike,
            title: "New like on your post",
            message: "Jamie Park liked your matcha latte post",
            data: NotificationData(
                postId: "mock_post_1",
                senderId: "jamie_park_id",
                senderName: "Jamie Park",
                senderUsername: "jamiepark"
            ),
            isRead: false,
            createdAt: Date()
        ),
        PalyttNotification(
            id: UUID().uuidString,
            userId: "mock_user_1",
            type: .follow,
            title: "New follower",
            message: "Kim Tanaka started following you",
            data: NotificationData(
                senderId: "kim_tanaka_id",
                senderName: "Kim Tanaka",
                senderUsername: "kimtanaka"
            ),
            isRead: false,
            createdAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date()
        ),
        PalyttNotification(
            id: UUID().uuidString,
            userId: "mock_user_1",
            type: .general,
            title: "Weekly roundup",
            message: "Your posts got 156 likes this week!",
            data: nil,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        )
    ]
    
    /// Mock saved lists for SaveOptionsView
    static let sampleSavedLists = [
        SavedList(
            name: "Favorite Restaurants",
            description: "My go-to dining spots",
            userId: "current-user",
            isPrivate: false
        ),
        SavedList(
            name: "Coffee Adventures",
            description: "Best coffee shops in the city",
            userId: "current-user",
            isPrivate: false
        ),
        SavedList(
            name: "Date Night Ideas",
            description: "Romantic dinner spots",
            userId: "current-user",
            isPrivate: true
        ),
        SavedList(
            name: "Brunch Spots",
            description: "Weekend brunch favorites",
            userId: "current-user",
            isPrivate: false
        )
    ]
    
    /// Mock map annotations for map views - temporarily empty to avoid conflicts
    static let sampleMapAnnotations: [String] = []
}

// MARK: - Additional Mock Models

/// Mock ChatRoom for messaging previews
struct ChatRoom: Identifiable {
    let id: String
    let participants: [User]
    let lastMessage: String
    let lastMessageTime: Date
    let unreadCount: Int
    
    var otherParticipant: User? {
        participants.first { $0.id != MockData.currentUser.id }
    }
}

// MapPostAnnotation is defined in MapViewModel - removed duplicate

// MARK: - Mock Notification Model (using the real PalyttNotification from Models/Notification.swift) 
