//
//  BackendService.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import Alamofire
import Clerk

// MARK: - Architecture Detection
private let isConvexSupported: Bool = {
    #if targetEnvironment(simulator)
    // Check if simulator is running on Apple Silicon (arm64)
    #if arch(arm64)
    return true
    #else
    // x86_64 simulators are not supported by ConvexMobile
    return false
    #endif
    #else
    // Real devices support Convex
    return true
    #endif
}()

// Conditional import based on architecture support
#if canImport(ConvexMobile)
import ConvexMobile
#endif

// Type alias to reference the main app's User model before local structs
typealias MainAppUser = User

// Custom decoder for handling Convex values
private let convexJSONDecoder = {
    let decoder = JSONDecoder()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    decoder.dateDecodingStrategy = .formatted(formatter)
    return decoder
}()

// Dynamic key for decoding metadata with unknown keys
struct DynamicKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

@MainActor
class BackendService: ObservableObject {
    static let shared = BackendService()
    
    private let apiConfig = APIConfigurationManager.shared
    
    // Conditional Convex client - only available on supported architectures
    #if canImport(ConvexMobile)
    private var convexClient: ConvexClient?
    #endif
    
    private var baseURL: String {
        return apiConfig.currentBaseURL
    }
    
    private var healthURL: String {
        return apiConfig.currentHealthURL
    }
    
    private init() {
        // Production initialization - debug logs removed for App Store submission
        
        // Initialize Convex client only on supported architectures
        #if canImport(ConvexMobile)
        if isConvexSupported {
            self.convexClient = ConvexClient(deploymentUrl: apiConfig.convexDeploymentURL)
            print("🟢 Convex client initialized successfully")
        } else {
            self.convexClient = nil
            print("🟡 Convex client not initialized - unsupported architecture")
        }
        #endif
        
        // Listen for API environment changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(apiEnvironmentChanged),
            name: .apiEnvironmentChanged,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func apiEnvironmentChanged() {
        print("🔄 BackendService: API environment changed to \(apiConfig.currentEnvironment.displayName)")
        
        // Reinitialize the Convex client with the new URL if supported
        #if canImport(ConvexMobile)
        if isConvexSupported {
            let newURL = apiConfig.convexDeploymentURL
            print("🔄 BackendService: Updating Convex client with URL: \(newURL)")
            self.convexClient = ConvexClient(deploymentUrl: newURL)
            print("🟢 Convex client reinitialized successfully")
        } else {
            print("🟡 Convex client not reinitialized - unsupported architecture")
        }
        #endif
    }
    
    // MARK: - Current API Information
    
    var currentAPIEnvironment: APIEnvironment {
        return apiConfig.currentEnvironment
    }
    
    /// Check if Convex is available and can be used on this architecture
    var isConvexAvailable: Bool {
        #if canImport(ConvexMobile)
        return isConvexSupported && convexClient != nil
        #else
        return false
        #endif
    }
    
    // MARK: - Convex Architecture Support Information
    
    /// Get detailed information about Convex support on current architecture
    var convexSupportInfo: String {
        let architectureInfo: String
        #if arch(arm64)
        architectureInfo = "ARM64 (Apple Silicon)"
        #elseif arch(x86_64)
        architectureInfo = "x86_64 (Intel)"
        #else
        architectureInfo = "Unknown"
        #endif
        
        let environmentInfo: String
        #if targetEnvironment(simulator)
        environmentInfo = "iOS Simulator"
        #else
        environmentInfo = "Physical Device"
        #endif
        
        return """
        🏗️ Architecture: \(architectureInfo)
        📱 Environment: \(environmentInfo)
        🔗 Convex Available: \(isConvexAvailable ? "✅ Yes" : "❌ No")
        """
    }
    
    @Published var isAPIHealthy: Bool = true
    
    private var lastHealthCheck: Date?
    private let healthCheckInterval: TimeInterval = 30.0
    
    // MARK: - Authentication Helper
    
    private func getAuthHeaders() async -> [String: String] {
        // For now, use the user's Clerk ID as authentication
        // In production, this should be replaced with proper JWT token from Clerk
        let baseHeaders = ["Content-Type": "application/json"]
        
        guard let user = Clerk.shared.user else {
            return baseHeaders
        }
        
        return [
            "Content-Type": "application/json",
            "Authorization": "Bearer clerk_\(user.id)",
            "x-clerk-user-id": user.id
        ]
    }
    
    // MARK: - Production Configuration (duplicate removed - see end of file for main implementation)
    
    private func setupErrorHandling() {
        // Add comprehensive error handling for production
        print("🛡️ BackendService: Setting up error handling for production")
    }

    // MARK: - Health Check
    
    func healthCheck() async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(healthURL)
                .validate()
                .responseData { response in
                    switch response.result {
                    case .success:
                        continuation.resume(returning: true)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
        }
    }
    
    // MARK: - tRPC Response Models
    
    struct TRPCPostsResponse: Codable {
        let posts: [TRPCPost]
        let hasMore: Bool
        let nextCursor: String?
        let pagination: PaginationInfo
    }
    
    struct PersonalizedFeedResponse: Codable {
        let posts: [TRPCPost]
        let hasMore: Bool
        let nextCursor: String?
        let totalReturned: Int
        let fromFollowed: Int
        let fromNearby: Int
    }
    
    struct MutualFriendsResponse: Codable {
        let mutualFriends: [BackendUser]
        let totalCount: Int
    }
    
    struct FriendSuggestionsResponse: Codable {
        let suggestions: [SuggestedUser]
    }
    
    struct SuggestedUser: Codable {
        let id: String
        let clerkId: String
        let username: String?
        let name: String?
        let profileImage: String?
        let bio: String?
        let followerCount: Int
        let mutualFriendsCount: Int
        let connectionReason: String
    }
    
    struct TRPCPost: Codable {
        let _id: String
        let _creationTime: Double?
        let userId: String
        let title: String?
        let content: String
        let imageUrl: String?
        let imageUrls: [String]
        let location: String?
        let locationData: TRPCLocation?
        let shopName: String
        let tags: [String]
        let isPublic: Bool
        let isActive: Bool
        let metadata: [String: String] // Simplified metadata for Codable compliance
        let likes: Int
        let comments: Int
        let viewCount: Int
        let createdAt: Int
        let updatedAt: Int
        let author: TRPCAuthor?
        
        enum CodingKeys: String, CodingKey {
            case _id, _creationTime, userId, title, content, imageUrl, imageUrls
            case location, locationData, shopName, tags, isPublic, isActive
            case metadata, likes, comments, viewCount, createdAt, updatedAt, author
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            _id = try container.decode(String.self, forKey: ._id)
            _creationTime = try container.decodeIfPresent(Double.self, forKey: ._creationTime)
            userId = try container.decode(String.self, forKey: .userId)
            title = try container.decodeIfPresent(String.self, forKey: .title)
            content = try container.decode(String.self, forKey: .content)
            imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
            imageUrls = try container.decodeIfPresent([String].self, forKey: .imageUrls) ?? []
            location = try container.decodeIfPresent(String.self, forKey: .location)
            locationData = try container.decodeIfPresent(TRPCLocation.self, forKey: .locationData)
            shopName = try container.decodeIfPresent(String.self, forKey: .shopName) ?? ""
            tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
            isPublic = try container.decodeIfPresent(Bool.self, forKey: .isPublic) ?? true
            isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
            likes = try container.decodeIfPresent(Int.self, forKey: .likes) ?? 0
            comments = try container.decodeIfPresent(Int.self, forKey: .comments) ?? 0
            viewCount = try container.decodeIfPresent(Int.self, forKey: .viewCount) ?? 0
            createdAt = try container.decodeIfPresent(Int.self, forKey: .createdAt) ?? 0
            updatedAt = try container.decodeIfPresent(Int.self, forKey: .updatedAt) ?? 0
            author = try container.decodeIfPresent(TRPCAuthor.self, forKey: .author)
            
            // Handle metadata with custom decoding to convert numbers to strings
            if let metadataContainer = try? container.nestedContainer(keyedBy: DynamicKey.self, forKey: .metadata) {
                var metadataDict: [String: String] = [:]
                for key in metadataContainer.allKeys {
                    if let stringValue = try? metadataContainer.decode(String.self, forKey: key) {
                        metadataDict[key.stringValue] = stringValue
                    } else if let intValue = try? metadataContainer.decode(Int.self, forKey: key) {
                        metadataDict[key.stringValue] = String(intValue)
                    } else if let doubleValue = try? metadataContainer.decode(Double.self, forKey: key) {
                        metadataDict[key.stringValue] = String(doubleValue)
                    } else if let boolValue = try? metadataContainer.decode(Bool.self, forKey: key) {
                        metadataDict[key.stringValue] = String(boolValue)
                    }
                }
                metadata = metadataDict
            } else {
                metadata = [:]
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(_id, forKey: ._id)
            try container.encodeIfPresent(_creationTime, forKey: ._creationTime)
            try container.encode(userId, forKey: .userId)
            try container.encodeIfPresent(title, forKey: .title)
            try container.encode(content, forKey: .content)
            try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
            try container.encode(imageUrls, forKey: .imageUrls)
            try container.encodeIfPresent(location, forKey: .location)
            try container.encodeIfPresent(locationData, forKey: .locationData)
            try container.encode(shopName, forKey: .shopName)
            try container.encode(tags, forKey: .tags)
            try container.encode(isPublic, forKey: .isPublic)
            try container.encode(isActive, forKey: .isActive)
            try container.encode(metadata, forKey: .metadata)
            try container.encode(likes, forKey: .likes)
            try container.encode(comments, forKey: .comments)
            try container.encode(viewCount, forKey: .viewCount)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(updatedAt, forKey: .updatedAt)
            try container.encodeIfPresent(author, forKey: .author)
        }
    }
    
    struct TRPCAuthor: Codable {
        let _id: String?
        let clerkId: String?
        let displayName: String?
        let username: String?
        let firstName: String?
        let lastName: String?
        let avatarUrl: String?
    }
    
    struct TRPCLocation: Codable {
        let latitude: Double
        let longitude: Double
        let address: String
        let city: String?
        let country: String?
    }

    // MARK: - Backend Data Models
    
    struct BackendPost: Codable {
        let id: String
        let userId: String
        let authorId: String
        let authorClerkId: String
        let authorDisplayName: String? // Author's display name
        let title: String?
        let description: String?
        let content: String
        let imageUrl: String?
        let imageUrls: [String]
        let location: BackendLocation?
        let shopName: String
        let foodItem: String?
        let tags: [String]
        let rating: Double?
        let likesCount: Int
        let commentsCount: Int
        let viewCount: Int
        let isLiked: Bool? // User's like status for this post
        let isBookmarked: Bool? // User's bookmark status for this post
        let isPublic: Bool
        let isActive: Bool
        let createdAt: String
        let updatedAt: String
        
        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case userId
            case authorId = "authorId"
            case authorClerkId = "authorClerkId"
            case authorDisplayName = "authorDisplayName"
            case title
            case description
            case content
            case imageUrl
            case imageUrls
            case location = "locationData"
            case shopName
            case foodItem = "foodItem"
            case tags
            case rating
            case likesCount = "likes"
            case commentsCount = "comments"
            case viewCount
            case isLiked
            case isBookmarked
            case isPublic
            case isActive
            case createdAt
            case updatedAt
        }
    }
    
    struct BackendLocation: Codable {
        let latitude: Double
        let longitude: Double
        let address: String
        let city: String?
        let country: String?
    }
    
    struct BackendComment: Codable {
        let id: String
        let postId: String
        let authorId: String
        let content: String
        let parentCommentId: String?
        let likes: Int
        let isActive: Bool
        let createdAt: Double  // Changed from String to Double (Unix timestamp)
        let updatedAt: Double  // Changed from String to Double (Unix timestamp)
        let replies: [BackendComment]?
        let author: ConvexUser? // Backend provides author object
        
        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case postId
            case authorId = "userId"  // Backend sends "userId", not "authorId"
            case content
            case parentCommentId
            case likes
            case isActive
            case createdAt
            case updatedAt
            case replies
            case author
        }
        
        // Computed property to use authorId as authorClerkId since they're the same
        var authorClerkId: String {
            return authorId
        }
    }
    
    struct PostsResponse: Codable {
        let posts: [BackendPost]
        let hasMore: Bool
        let nextCursor: String?
        let pagination: PaginationInfo
    }
    
    struct CommentsResponse: Codable {
        let comments: [BackendComment]
        let pagination: PaginationInfo
    }
    
    struct PaginationInfo: Codable {
        let page: Int
        let limit: Int
        let totalPages: Int
        let totalItems: Int
    }
    
    struct LikeResponse: Codable {
        let liked: Bool
        let totalLikes: Int
        let likesCount: Int
        let isLiked: Bool
    }
    
    struct BookmarkResponse: Codable {
        let bookmarked: Bool
        let isBookmarked: Bool
    }
    
    struct CommentResponse: Codable {
        let comment: BackendComment
    }
    
    struct PostLike: Codable {
        let id: String
        let postId: String
        let userId: String
        let createdAt: String
        let user: BackendUser
    }
    
    struct PostLikesResponse: Codable {
        let likes: [PostLike]
        let nextCursor: String?
    }
    
    // MARK: - Notifications Management
    
    struct BackendNotification: Codable {
        let _id: String
        let recipientId: String
        let senderId: String?
        let type: NotificationType
        let title: String
        let message: String
        let metadata: NotificationMetadata?
        let isRead: Bool
        let createdAt: Int
        let updatedAt: Int
        let sender: BackendUser?
    }
    
    enum NotificationType: String, Codable {
        case friendRequest = "FRIEND_REQUEST"
        case friendRequestAccepted = "FRIEND_ACCEPTED"
        case newFollower = "FOLLOW"
        case postLike = "POST_LIKE"
        case postComment = "COMMENT"
        case commentLike = "COMMENT_LIKE"
        case friendPost = "FRIEND_POST"
        case postMention = "POST_MENTION"
        case message = "MESSAGE"
        case general = "GENERAL"
    }
    
    struct NotificationMetadata: Codable {
        let postId: String?
        let commentId: String?
        let friendRequestId: String?
        let userId: String?
    }
    
    struct NotificationsResponse: Codable {
        let notifications: [BackendNotification]
        let count: Int
    }
    
    struct UnreadCountResponse: Codable {
        let count: Int
    }
    
    struct NotificationActionResponse: Codable {
        let success: Bool
    }
    
    // MARK: - User Management
    
    struct UpsertUserResponse: Codable {
        let success: Bool
        let user: BackendUser
        let created: Bool?
        let needsUsername: Bool?
    }
    
    struct UpdateUserResponse: Codable {
        let success: Bool
        let user: BackendUser
    }
    

    
    struct UpsertUserRequest: Codable {
        let email: String?
        let firstName: String?
        let lastName: String?
        let username: String?
        let avatarUrl: String?
        let clerkId: String
        let appleId: String?
        let googleId: String?
    }
    
    struct UpdateUserRequest: Codable {
        let firstName: String?
        let lastName: String?
        let username: String?
        let bio: String?
        let avatarUrl: String?
        let dietaryPreferences: [String]?
    }
    
    struct UpdateByClerkIdRequest: Codable {
        let clerkId: String
        let data: UpdateUserRequest
    }
    
    struct UpsertUserByClerkIdRequest: Codable {
        let clerkId: String
        let email: String?
        let firstName: String?
        let lastName: String?
        let username: String?
        let avatarUrl: String?
        let appleId: String?
        let googleId: String?
    }
    
    func updateUserByClerkId(
        clerkId: String,
        firstName: String?,
        lastName: String?,
        username: String?,
        bio: String?,
        avatarUrl: String?,
        dietaryPreferences: [String]?
    ) async throws -> UpdateUserResponse {
        let request = UpdateUserRequest(
            firstName: firstName,
            lastName: lastName,
            username: username,
            bio: bio,
            avatarUrl: avatarUrl,
            dietaryPreferences: dietaryPreferences
        )
        
        let requestData = UpdateByClerkIdRequest(
            clerkId: clerkId,
            data: request
        )
        
        return try await performTRPCRequest(procedure: "users.updateByClerkId", input: requestData, method: .post)
    }
    
    func getUserByClerkId(clerkId: String) async throws -> BackendUser {
        let request = ["clerkId": clerkId]
        return try await performTRPCQuery(procedure: "users.getByClerkId", input: request)
    }
    
    // Auto-sync user from Clerk to backend
    func syncUserFromClerk() async throws -> BackendUser {
        guard let clerkUser = Clerk.shared.user else {
            throw BackendError.trpcError("User not authenticated", 401)
        }
        
        // Try to get existing user first
        do {
            return try await getUserByClerkId(clerkId: clerkUser.id)
        } catch {
            // User doesn't exist, create them
            _ = try await upsertUserByClerkId(
                clerkId: clerkUser.id,
                email: clerkUser.primaryEmailAddress?.emailAddress,
                firstName: clerkUser.firstName,
                lastName: clerkUser.lastName,
                username: clerkUser.username,
                avatarUrl: clerkUser.imageUrl.isEmpty ? nil : clerkUser.imageUrl
            )
            
            // Return the synced user
            return try await getUserByClerkId(clerkId: clerkUser.id)
        }
    }
    
    // Upsert user by Clerk ID (main sync function)
    func upsertUserByClerkId(
        clerkId: String,
        email: String?,
        firstName: String?,
        lastName: String?,
        username: String?,
        avatarUrl: String?
    ) async throws -> UpsertUserResponse {
        let request = UpsertUserByClerkIdRequest(
            clerkId: clerkId,
            email: email,
            firstName: firstName,
            lastName: lastName,
            username: username,
            avatarUrl: avatarUrl,
            appleId: nil,
            googleId: nil
        )
        
        return try await performTRPCRequest(procedure: "users.upsertByClerkId", input: request, method: .post)
    }
    
    func upsertUser(
        email: String?,
        firstName: String?,
        lastName: String?,
        username: String?,
        avatarUrl: String?,
        clerkId: String,
        appleId: String?
    ) async throws -> UpsertUserResponse {
        let request = UpsertUserRequest(
            email: email,
            firstName: firstName,
            lastName: lastName,
            username: username,
            avatarUrl: avatarUrl,
            clerkId: clerkId,
            appleId: appleId,
            googleId: nil
        )
        
        return try await performTRPCRequest(procedure: "users.upsert", input: request, method: .post)
    }
    
    func upsertUserByAppleId(
        appleId: String,
        clerkId: String,
        email: String?,
        firstName: String?,
        lastName: String?,
        username: String?
    ) async throws -> UpsertUserResponse {
        let request = UpsertUserRequest(
            email: email,
            firstName: firstName,
            lastName: lastName,
            username: username,
            avatarUrl: nil,
            clerkId: clerkId,
            appleId: appleId,
            googleId: nil
        )
        
        return try await performTRPCRequest(procedure: "users.upsertByAppleId", input: request, method: .post)
    }
    
    func upsertUserByGoogleId(
        googleId: String,
        clerkId: String,
        email: String?,
        firstName: String?,
        lastName: String?,
        username: String?,
        avatarUrl: String?
    ) async throws -> UpsertUserResponse {
        let request = UpsertUserRequest(
            email: email,
            firstName: firstName,
            lastName: lastName,
            username: username,
            avatarUrl: avatarUrl,
            clerkId: clerkId,
            appleId: nil,
            googleId: googleId
        )
        
        return try await performTRPCRequest(procedure: "users.upsertByGoogleId", input: request, method: .post)
    }
    
    // MARK: - Comments Management
    
    struct AddCommentRequest: Codable {
        let postId: String
        let content: String
        let parentCommentId: String?
    }
    
    func getComments(for postId: String) async throws -> [Comment] {
        print("📱 BackendService: Getting comments for post: \(postId)")
        
        let commentsResponse = try await getComments(postId: postId, page: 1, limit: 50)
        
        // Convert BackendComment to Comment model
        let comments = commentsResponse.comments.compactMap { backendComment in
            convertBackendCommentToComment(backendComment)
        }
        
        print("✅ BackendService: Loaded \(comments.count) comments for post: \(postId)")
        return comments
    }
    
    func submitComment(postId: String, content: String) async throws -> Comment? {
        print("💬 BackendService: Submitting comment for post: \(postId)")
        
        let commentResponse = try await addComment(postId: postId, content: content)
        let comment = convertBackendCommentToComment(commentResponse.comment)
        
        print("✅ BackendService: Comment submitted successfully for post: \(postId)")
        return comment
    }
    
    // Helper method to convert BackendComment to Comment
    private func convertBackendCommentToComment(_ backendComment: BackendComment) -> Comment? {
        // Create a User object for the comment author - using the main app User model
        let author = MainAppUser(
            id: UUID(), 
            email: backendComment.author?.email ?? "",
            firstName: backendComment.author?.firstName,
            lastName: backendComment.author?.lastName,
            username: backendComment.author?.username ?? "unknown",
            bio: backendComment.author?.bio,
            avatarURL: backendComment.author?.avatarUrl != nil ? URL(string: backendComment.author!.avatarUrl!) : nil,
            clerkId: backendComment.authorClerkId
        )
        
        return Comment(
            id: UUID(),
            postId: UUID(), // We'd need to convert this properly
            author: author,
            text: backendComment.content,
            createdAt: Date(timeIntervalSince1970: backendComment.createdAt / 1000),
            likesCount: backendComment.likes,
            isLiked: false, // Would need to check if current user liked this comment
            replies: []
        )
    }
    
    // Helper function to parse Convex date strings
    private func parseConvexDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: dateString) ?? Date()
    }
    
    // MARK: - Posts Management
    
    struct GetPostsRequest: Codable {
        let page: Int
        let limit: Int
    }
    
    func getPosts(page: Int = 1, limit: Int = 20) async throws -> PostsResponse {
        print("📱 BackendService: Getting posts - page: \(page), limit: \(limit)")
        print("🔗 BackendService: Current environment: \(apiConfig.currentEnvironment.displayName)")
        print("🔗 BackendService: Current environment raw: \(apiConfig.currentEnvironment.rawValue)")
        print("🔗 BackendService: Base URL: \(baseURL)")
        print("🔗 BackendService: API Config Base URL: \(apiConfig.currentBaseURL)")
        
        // Environment configuration handled by APIConfiguration
        
        // Use the correct tRPC endpoint "posts.getRecentPosts" with GET method for queries
        let input = ["page": page, "limit": limit]
        let inputData = try JSONSerialization.data(withJSONObject: input)
        let inputString = String(data: inputData, encoding: .utf8) ?? "{}"
        let encodedInput = inputString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = "\(baseURL)/trpc/posts.getRecentPosts?input=\(encodedInput)"
        print("🌐 BackendService: Calling URL: \(urlString)")
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(urlString, method: .get)
                .validate()
                .responseData { response in
                    switch response.result {
                    case .success(let data):
                        do {
                            // Parse the tRPC response structure
                            let jsonData = try JSONSerialization.jsonObject(with: data)
                            guard let responseDict = jsonData as? [String: Any],
                                  let result = responseDict["result"] as? [String: Any],
                                  let data = result["data"] as? [String: Any] else {
                                throw BackendError.trpcError("Invalid response structure", 422)
                            }
                            
                            let postsData = try JSONSerialization.data(withJSONObject: data)
                            let tRPCResponse = try JSONDecoder().decode(TRPCPostsResponse.self, from: postsData)
                            
                            // Convert to BackendPost format
                            let backendPosts = tRPCResponse.posts.map { tRPCPost -> BackendPost in
                                BackendPost(
                                    id: tRPCPost._id,
                                    userId: tRPCPost.userId,
                                    authorId: tRPCPost.userId,
                                    authorClerkId: tRPCPost.userId,
                                    authorDisplayName: tRPCPost.author?.displayName ?? tRPCPost.author?.username ?? "Unknown User",
                                    title: tRPCPost.title ?? "",
                                    description: tRPCPost.content,
                                    content: tRPCPost.content,
                                    imageUrl: tRPCPost.imageUrl,
                                    imageUrls: tRPCPost.imageUrls,
                                    location: tRPCPost.locationData.map { location in
                                        BackendLocation(
                                            latitude: location.latitude,
                                            longitude: location.longitude,
                                            address: location.address,
                                            city: location.city,
                                            country: location.country
                                        )
                                    },
                                    shopName: tRPCPost.shopName,
                                    foodItem: tRPCPost.title,
                                    tags: tRPCPost.tags,
                                    rating: {
                                        if let ratingString = tRPCPost.metadata["rating"] as? String,
                                           let ratingValue = Double(ratingString) {
                                            return ratingValue
                                        }
                                        return nil
                                    }(),
                                    likesCount: tRPCPost.likes,
                                    commentsCount: tRPCPost.comments,
                                    viewCount: tRPCPost.viewCount,
                                    isLiked: false, // Will be updated when user interacts
                                    isBookmarked: false, // Will be updated when user interacts
                                    isPublic: tRPCPost.isPublic,
                                    isActive: tRPCPost.isActive,
                                    createdAt: ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: Double(tRPCPost.createdAt) / 1000)),
                                    updatedAt: ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: Double(tRPCPost.updatedAt) / 1000))
                                )
                            }
                            
                            let postsResponse = PostsResponse(
                                posts: backendPosts,
                                hasMore: tRPCResponse.hasMore,
                                nextCursor: tRPCResponse.nextCursor,
                                pagination: tRPCResponse.pagination
                            )
                            
                            print("✅ BackendService: Successfully loaded \(backendPosts.count) posts")
                            continuation.resume(returning: postsResponse)
                            
                        } catch {
                            print("❌ BackendService: Failed to parse posts response: \(error)")
                            continuation.resume(throwing: error)
                        }
                    case .failure(let error):
                        print("❌ BackendService: Failed to get posts: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
        }
    }
    
    func getPostsByUser(userId: String) async throws -> [BackendPost] {
        let request = ["userId": userId]
        
        // Get the Convex response for user posts
        let convexPosts: [ConvexPost] = try await performTRPCQuery(procedure: "posts.getByUser", input: request)
        
        // Convert ConvexPost objects to BackendPost objects
        let backendPosts = convexPosts.map { convexPost in
            // Get author information
            let authorDisplayName = convexPost.author?.displayName ?? 
                                  convexPost.author?.username ?? 
                                  "Unknown User"
            let authorClerkId = convexPost.author?.clerkId ?? convexPost.userId
            
            return BackendPost(
                id: convexPost._id ?? "",
                userId: convexPost.userId,
                authorId: authorClerkId,
                authorClerkId: authorClerkId,
                authorDisplayName: authorDisplayName,
                title: convexPost.title,
                description: convexPost.content,
                content: convexPost.content,
                imageUrl: convexPost.imageUrl,
                imageUrls: convexPost.imageUrls ?? [],
                location: convexPost.locationData.map { location in
                    BackendLocation(
                        latitude: location.latitude,
                        longitude: location.longitude,
                        address: location.address,
                        city: location.city,
                        country: location.country
                    )
                },
                shopName: convexPost.shopName ?? "",
                foodItem: convexPost.title,
                tags: convexPost.tags ?? [],
                rating: Double(convexPost.metadata.rating ?? 0),
                likesCount: convexPost.likes,
                commentsCount: convexPost.comments,
                viewCount: convexPost.viewCount,
                isLiked: false, // Will be updated when user interacts with posts
                isBookmarked: false, // Will be updated when user interacts with posts
                isPublic: convexPost.isPublic,
                isActive: convexPost.isActive,
                createdAt: ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: Double(convexPost.createdAt) / 1000)),
                updatedAt: ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: Double(convexPost.updatedAt) / 1000))
            )
        }
        
        return backendPosts
    }
    
    func getBookmarkedPosts() async throws -> [BackendPost] {
        guard let user = Clerk.shared.user else {
            throw BackendError.trpcError("User not authenticated", 401)
        }
        
        // Get the Convex response for bookmarked posts
        struct GetBookmarkedPostsRequest: Codable {
            let userId: String
        }
        let request = GetBookmarkedPostsRequest(userId: user.id)
        let convexPosts: [ConvexPost] = try await performTRPCQuery(procedure: "posts.getBookmarkedPosts", input: request)
        
        // Convert ConvexPost objects to BackendPost objects
        let backendPosts = convexPosts.map { convexPost in
            // Get author information
            let authorDisplayName = convexPost.author?.displayName ?? 
                                  convexPost.author?.username ?? 
                                  "Unknown User"
            let authorClerkId = convexPost.author?.clerkId ?? convexPost.userId
            
            return BackendPost(
                id: convexPost._id ?? "",
                userId: convexPost.userId,
                authorId: authorClerkId,
                authorClerkId: authorClerkId,
                authorDisplayName: authorDisplayName,
                title: convexPost.title,
                description: convexPost.content,
                content: convexPost.content,
                imageUrl: convexPost.imageUrl,
                imageUrls: convexPost.imageUrls ?? [],
                location: convexPost.locationData.map { location in
                    BackendLocation(
                        latitude: location.latitude,
                        longitude: location.longitude,
                        address: location.address,
                        city: location.city,
                        country: location.country
                    )
                },
                shopName: convexPost.shopName ?? "",
                foodItem: convexPost.title,
                tags: convexPost.tags ?? [],
                rating: Double(convexPost.metadata.rating ?? 0),
                likesCount: convexPost.likes,
                commentsCount: convexPost.comments,
                viewCount: convexPost.viewCount,
                isLiked: false, // Will be updated when user interacts with posts
                isBookmarked: true, // These are bookmarked posts, so always true
                isPublic: convexPost.isPublic,
                isActive: convexPost.isActive,
                createdAt: ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: Double(convexPost.createdAt) / 1000)),
                updatedAt: ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: Double(convexPost.updatedAt) / 1000))
            )
        }
        
        return backendPosts
    }
    
    func toggleLike(postId: String) async throws -> LikeResponse {
        print("❤️ BackendService: Toggling like for post: \(postId)")
        
        let input = ["postId": postId]
        
        // Use the correct tRPC mutation endpoint "posts.toggleLike"
        let response: ToggleLikeResponse = try await performTRPCMutation(procedure: "posts.toggleLike", input: input)
        
        // Convert to expected LikeResponse format
        return LikeResponse(
            liked: response.liked,
            totalLikes: response.totalLikes,
            likesCount: response.totalLikes,
            isLiked: response.liked
        )
    }
    
    func toggleBookmark(postId: String) async throws -> BookmarkResponse {
        print("🔖 BackendService: Toggling bookmark for post: \(postId)")
        
        guard let user = Clerk.shared.user else {
            throw BackendError.trpcError("User not authenticated", 401)
        }
        
        let request = ToggleBookmarkRequest(postId: postId, userId: user.id)
        let response: ToggleBookmarkResponse = try await performTRPCMutation(procedure: "posts.toggleBookmark", input: request)
        
        print("✅ Successfully toggled bookmark for post \(postId): \(response.bookmarked ? "bookmarked" : "unbookmarked")")
        
        // Convert to expected BookmarkResponse format
        return BookmarkResponse(
            bookmarked: response.bookmarked,
            isBookmarked: response.bookmarked
        )
    }
    
    // MARK: - Comments Management
    
    func getComments(postId: String, page: Int = 1, limit: Int = 20) async throws -> CommentsResponse {
        let request = ["postId": postId]
        let convexComments: [BackendComment] = try await performTRPCQuery(procedure: "comments.getComments", input: request)
        // Now convexComments will include nested replies
        return CommentsResponse(
            comments: convexComments,
            pagination: PaginationInfo(
                page: page,
                limit: limit,
                totalPages: 1,
                totalItems: convexComments.count
            )
        )
    }
    
    func addComment(postId: String, content: String, parentCommentId: String? = nil) async throws -> CommentResponse {
        guard Clerk.shared.user != nil else {
            throw BackendError.trpcError("User not authenticated", 401)
        }
        struct AddCommentRequest: Codable {
            let postId: String
            let content: String
            let parentCommentId: String?
        }
        let request = AddCommentRequest(postId: postId, content: content, parentCommentId: parentCommentId)
        let response: ConvexCommentResponse = try await performTRPCMutation(procedure: "comments.addComment", input: request)
        return CommentResponse(
            comment: BackendComment(
                id: response.comment._id ?? "",
                postId: response.comment.postId,
                authorId: response.comment.userId,
                content: response.comment.content,
                parentCommentId: response.comment.parentCommentId,
                likes: response.comment.likes,
                isActive: response.comment.isActive,
                createdAt: Double(response.comment.createdAt), // Use raw timestamp
                updatedAt: Double(response.comment.updatedAt), // Use raw timestamp
                replies: [], // New comments/replies start with no replies
                author: nil // Will be populated by backend if available
            )
        )
    }
    
    func toggleCommentLike(commentId: String) async throws -> LikeResponse {
        guard Clerk.shared.user != nil else {
            throw BackendError.trpcError("User not authenticated", 401)
        }
        
        struct ToggleCommentLikeRequest: Codable {
            let commentId: String
        }
        
        let request = ToggleCommentLikeRequest(commentId: commentId)
        
        let response: ConvexLikeResponse = try await performTRPCMutation(procedure: "comments.toggleLike", input: request)
        
        return LikeResponse(
            liked: response.liked,
            totalLikes: response.totalLikes,
            likesCount: response.totalLikes,
            isLiked: response.liked
        )
    }
    
    // MARK: - Recent Comments & Post Likes
    
    func getRecentComments(postId: String, limit: Int = 2) async throws -> [BackendComment] {
        struct GetRecentCommentsRequest: Codable {
            let postId: String
            let limit: Int
        }
        
        let request = GetRecentCommentsRequest(postId: postId, limit: limit)
        let comments: [BackendComment] = try await performTRPCQuery(procedure: "posts.getRecentComments", input: request)
        return comments
    }
    
    func getPostLikes(postId: String, limit: Int = 20, cursor: String? = nil) async throws -> PostLikesResponse {
        struct GetPostLikesRequest: Codable {
            let postId: String
            let limit: Int
            let cursor: String?
        }
        
        let request = GetPostLikesRequest(postId: postId, limit: limit, cursor: cursor)
        let response: PostLikesResponse = try await performTRPCQuery(procedure: "posts.getPostLikes", input: request)
        return response
    }
    
    // MARK: - Convex Response Models
    
    struct ConvexPostsResponse: Codable {
        let posts: [ConvexPost]
        let hasMore: Bool
        let nextCursor: String?
        let pagination: PaginationInfo?
    }
    
    struct ConvexPost: Codable {
        let _id: String?
        let _creationTime: Double?
        let userId: String
        let title: String?
        let content: String
        let imageUrl: String?
        let imageUrls: [String]?
        let location: String?
        let locationData: ConvexLocation?
        let shopName: String?
        let tags: [String]?
        let isPublic: Bool
        let metadata: ConvexMetadata
        let likes: Int
        let comments: Int
        let viewCount: Int
        let isActive: Bool
        let createdAt: Int
        let updatedAt: Int
        let author: ConvexUser?
    }
    
    struct ConvexUser: Codable {
        let _id: String?
        let userId: String?
        let clerkId: String?
        let email: String?
        let firstName: String?
        let lastName: String?
        let username: String?
        let displayName: String?
        let bio: String?
        let avatarUrl: String?
        let followersCount: Int?
        let followingCount: Int?
        let postsCount: Int?
        let isVerified: Bool?
        let isActive: Bool?
        let createdAt: Int?
        let updatedAt: Int?
    }
    
    struct ConvexLocation: Codable {
        let latitude: Double
        let longitude: Double
        let address: String
        let city: String?
        let country: String?
    }
    
    struct ConvexMetadata: Codable {
        let category: String?
        let rating: Int?
    }
    
    struct ConvexComment: Codable {
        let _id: String?
        let postId: String
        let userId: String
        let content: String
        let parentCommentId: String?
        let likes: Int
        let isActive: Bool
        let createdAt: Int
        let updatedAt: Int
    }
    
    struct ConvexCommentResponse: Codable {
        let comment: ConvexComment
    }
    
    struct ConvexLikeResponse: Codable {
        let liked: Bool
        let totalLikes: Int
    }
    
    struct ConvexBookmarkResponse: Codable {
        let bookmarked: Bool
    }
    
    struct ConvexLikeCheckResponse: Codable {
        let liked: Bool
    }
    
    struct ConvexBookmarkCheckResponse: Codable {
        let bookmarked: Bool
    }
    
    struct CreatePostResponse: Codable {
        let postId: String
    }
    
    // MARK: - Convex Posts Management
    
    struct CreateConvexPostRequest: Codable {
        let userId: String
        let title: String?
        let content: String
        let imageUrl: String?
        let imageUrls: [String]?
        let location: String?
        let locationData: ConvexLocationData?
        let shopName: String?
        let tags: [String]?
        let isPublic: Bool?
        let metadata: ConvexPostMetadata?
    }
    
    struct ConvexLocationData: Codable {
        let latitude: Double
        let longitude: Double
        let address: String
        let city: String?
        let country: String?
    }
    
    struct ConvexPostMetadata: Codable {
        let category: String?
        let rating: Double?
    }
    
    func createPost(
        userId: String,
        title: String?,
        content: String,
        imageUrl: String?,
        imageUrls: [String],
        location: String?,
        locationData: ConvexLocationData?,
        shopName: String?,
        tags: [String],
        isPublic: Bool = true,
        metadata: ConvexPostMetadata?
    ) async throws -> CreatePostResponse {
        let request = CreateConvexPostRequest(
            userId: userId,
            title: title,
            content: content,
            imageUrl: imageUrl,
            imageUrls: imageUrls,
            location: location,
            locationData: locationData,
            shopName: shopName,
            tags: tags,
            isPublic: isPublic,
            metadata: metadata
        )
        
        return try await performTRPCMutation(procedure: "posts.create", input: request)
    }
    
    func createPostViaConvex(
        userId: String,
        title: String?,
        content: String,
        imageUrl: String?,
        imageUrls: [String],
        location: Location?,
        tags: [String],
        isPublic: Bool = true,
        metadata: ConvexPostMetadata?
    ) async throws -> String {
        // Extract location data if available
        var locationData: ConvexLocationData?
        var locationString: String?
        
        if let location = location {
            // Use the actual coordinates and location data from the Location object
            let cityWithState = location.state != nil ? "\(location.city), \(location.state!)" : location.city
            
            locationData = ConvexLocationData(
                latitude: location.latitude,
                longitude: location.longitude,
                address: location.address,
                city: cityWithState,
                country: location.country
            )
            
            // Use the formatted address for the location string
            locationString = location.formattedAddress
        }
        
        let response = try await createPost(
            userId: userId,
            title: title,
            content: content,
            imageUrl: imageUrl,
            imageUrls: imageUrls,
            location: locationString,
            locationData: locationData,
            shopName: title,
            tags: tags,
            isPublic: isPublic,
            metadata: metadata
        )
        
        return response.postId
    }
    
    // MARK: - Validation Methods
    
    struct AvailabilityRequest: Codable {
        let value: String
    }
    
    struct AvailabilityResponse: Codable {
        let available: Bool
    }
    
    func checkUsernameAvailability(username: String) async throws -> Bool {
        let request = AvailabilityRequest(value: username)
        let response: AvailabilityResponse = try await performTRPCQuery(procedure: "users.checkUsernameAvailability", input: request)
        return response.available
    }
    
    func checkEmailAvailability(email: String) async throws -> Bool {
        let request = AvailabilityRequest(value: email)
        let response: AvailabilityResponse = try await performTRPCQuery(procedure: "users.checkEmailAvailability", input: request)
        return response.available
    }
    
    func checkPhoneAvailability(phoneNumber: String) async throws -> Bool {
        let request = AvailabilityRequest(value: phoneNumber)
        let response: AvailabilityResponse = try await performTRPCQuery(procedure: "users.checkPhoneAvailability", input: request)
        return response.available
    }
    
    // MARK: - Follow Management
    
    struct FollowRequest: Codable {
        let followerId: String
        let followingId: String
    }
    
    struct UserLimitRequest: Codable {
        let userId: String
        let limit: Int
    }
    
    struct SearchRequest: Codable {
        let query: String
        let limit: Int
        let offset: Int
    }
    
    func followUser(followerId: String, followingId: String) async throws -> FollowResponse {
        let request = FollowRequest(followerId: followerId, followingId: followingId)
        return try await performTRPCMutation(procedure: "follows.follow", input: request)
    }
    
    func unfollowUser(followerId: String, followingId: String) async throws -> FollowResponse {
        let request = FollowRequest(followerId: followerId, followingId: followingId)
        return try await performTRPCMutation(procedure: "follows.unfollow", input: request)
    }
    
    func isFollowing(followerId: String, followingId: String) async throws -> IsFollowingResponse {
        let request = FollowRequest(followerId: followerId, followingId: followingId)
        return try await performTRPCQuery(procedure: "follows.isFollowing", input: request)
    }
    
    func getFollowing(userId: String, limit: Int = 50) async throws -> [BackendUser] {
        let request = UserLimitRequest(userId: userId, limit: limit)
        return try await performTRPCQuery(procedure: "follows.getFollowing", input: request)
    }
    
    func getFollowers(userId: String, limit: Int = 50) async throws -> [BackendUser] {
        let request = UserLimitRequest(userId: userId, limit: limit)
        return try await performTRPCQuery(procedure: "follows.getFollowers", input: request)
    }
    
    func getFollowingPosts(userId: String, limit: Int = 100) async throws -> [FollowingPost] {
        let request = UserLimitRequest(userId: userId, limit: limit)
        return try await performTRPCQuery(procedure: "follows.getFollowingPosts", input: request)
    }
    
    // Wrapper method for MapViewModel compatibility
    func getFriends(userId: String) async throws -> [MainAppUser] {
        print("👥 BackendService: Getting friends for user: \(userId)")
        
        let backendFriends = try await getFollowing(userId: userId)
        
        // Convert BackendService.User to local User model
        let friends = backendFriends.map { backendUser in
            convertBackendUserToUser(backendUser)
        }
        
        print("✅ BackendService: Loaded \(friends.count) friends for user: \(userId)")
        return friends
    }
    
    // Helper method to convert BackendUser to local User model
    private func convertBackendUserToUser(_ backendUser: BackendUser) -> MainAppUser {
        return MainAppUser(
            id: UUID(),
            email: backendUser.email ?? "",
            firstName: backendUser.firstName,
            lastName: backendUser.lastName,
            username: backendUser.username ?? "unknown",
            bio: backendUser.bio,
            avatarURL: backendUser.avatarUrl != nil ? URL(string: backendUser.avatarUrl!) : nil,
            clerkId: backendUser.clerkId
        )
    }
    
    // MARK: - Friend Management
    
    func getMutualFriends(between userId1: String, and userId2: String, limit: Int = 10) async throws -> MutualFriendsResponse {
        struct MutualFriendsRequest: Codable {
            let userId1: String
            let userId2: String
            let limit: Int
        }
        
        let request = MutualFriendsRequest(userId1: userId1, userId2: userId2, limit: limit)
        return try await performTRPCQuery(procedure: "friends.getMutualFriends", input: request)
    }
    
    func getFriendSuggestions(limit: Int = 20, excludeRequested: Bool = true) async throws -> FriendSuggestionsResponse {
        struct FriendSuggestionsRequest: Codable {
            let limit: Int
            let excludeRequested: Bool
        }
        
        let request = FriendSuggestionsRequest(limit: limit, excludeRequested: excludeRequested)
        return try await performTRPCQuery(procedure: "friends.getFriendSuggestions", input: request)
    }
    
    func sendFriendRequest(senderId: String, receiverId: String) async throws -> FriendRequestResponse {
        let request = ["senderId": senderId, "receiverId": receiverId]
        return try await performTRPCMutation(procedure: "friends.sendRequest", input: request)
    }
    
    func acceptFriendRequest(requestId: String) async throws -> FriendRequestResponse {
        let request = ["requestId": requestId]
        return try await performTRPCMutation(procedure: "friends.acceptRequest", input: request)
    }
    
    func rejectFriendRequest(requestId: String) async throws -> FriendRequestResponse {
        let request = ["requestId": requestId]
        return try await performTRPCMutation(procedure: "friends.rejectRequest", input: request)
    }
    
    func removeFriend(userId1: String, userId2: String) async throws -> FriendRequestResponse {
        let request = ["userId1": userId1, "userId2": userId2]
        return try await performTRPCMutation(procedure: "friends.removeFriend", input: request)
    }
    
    func getPendingFriendRequests(userId: String) async throws -> [FriendRequest] {
        let request = ["userId": userId]
        return try await performTRPCQuery(procedure: "friends.getPendingRequests", input: request)
    }
    
    func getFriends(userId: String, limit: Int = 50) async throws -> [BackendUser] {
        let request = UserLimitRequest(userId: userId, limit: limit)
        return try await performTRPCQuery(procedure: "friends.getFriends", input: request)
    }
    
    func areFriends(userId1: String, userId2: String) async throws -> AreFriendsResponse {
        let request = ["userId1": userId1, "userId2": userId2]
        return try await performTRPCQuery(procedure: "friends.areFriends", input: request)
    }
    
    func getFriendRequestStatus(userId1: String, userId2: String) async throws -> FriendRequestStatusResponse {
        let request = ["userId1": userId1, "userId2": userId2]
        return try await performTRPCQuery(procedure: "friends.getRequestStatus", input: request)
    }
    
    // MARK: - Notifications Management
    
    struct GetNotificationsRequest: Codable {
        let userId: String
        let limit: Int
        let onlyUnread: Bool
    }
    
    func getNotifications(userId: String, limit: Int = 50, onlyUnread: Bool = false) async throws -> [BackendNotification] {
        let request = GetNotificationsRequest(userId: userId, limit: limit, onlyUnread: onlyUnread)
        return try await performTRPCQuery(procedure: "notifications.getNotifications", input: request)
    }
    
    func getUnreadNotificationsCount(userId: String) async throws -> UnreadCountResponse {
        let request = ["userId": userId]
        return try await performTRPCQuery(procedure: "notifications.getUnreadCount", input: request)
    }
    
    func markNotificationAsRead(notificationId: String) async throws -> NotificationActionResponse {
        let request = ["notificationId": notificationId]
        return try await performTRPCMutation(procedure: "notifications.markAsRead", input: request)
    }
    
    func markAllNotificationsAsRead(userId: String) async throws -> NotificationActionResponse {
        let request = ["userId": userId]
        return try await performTRPCMutation(procedure: "notifications.markAllAsRead", input: request)
    }
    
    func deleteNotification(notificationId: String) async throws -> NotificationActionResponse {
        let request = ["notificationId": notificationId]
        return try await performTRPCMutation(procedure: "notifications.deleteNotification", input: request)
    }
    
    func deleteAllNotifications(userId: String) async throws -> NotificationActionResponse {
        let request = ["userId": userId]
        return try await performTRPCMutation(procedure: "notifications.deleteAllNotifications", input: request)
    }
    
    func createNotification(
        recipientId: String,
        senderId: String,
        type: String,
        title: String,
        message: String,
        metadata: [String: String]? = nil
    ) async throws -> NotificationActionResponse {
        print("📲 BackendService: Creating notification - type: \(type)")
        
        struct CreateNotificationRequest: Codable {
            let recipientId: String
            let senderId: String?
            let type: String
            let title: String
            let message: String
            let metadata: [String: String]?
        }
        
        let request = CreateNotificationRequest(
            recipientId: recipientId,
            senderId: senderId,
            type: type,
            title: title,
            message: message,
            metadata: metadata
        )
        
        let response: NotificationActionResponse = try await performTRPCMutation(procedure: "notifications.createNotification", input: request)
        return response
    }
    
    func searchUsers(query: String, limit: Int = 10) async throws -> [BackendUser] {
        struct SearchUsersRequest: Codable {
            let query: String
            let limit: Int
        }
        
        let request = SearchUsersRequest(query: query, limit: limit)
        let users: [BackendUser] = try await performTRPCQuery(procedure: "users.search", input: request)
        return users
    }
    
    // MARK: - Messaging Data Models
    
    struct Chatroom: Codable, Equatable {
        let _id: String
        let name: String?
        let type: String // "direct" or "group"
        var participants: [User]
        let createdBy: String
        let lastMessageId: String?
        let lastMessage: Message?
        let lastActivity: Int
        let unreadCount: Int
        let isTyping: Bool
        let typingUserId: String?
        
        static func == (lhs: Chatroom, rhs: Chatroom) -> Bool {
            lhs._id == rhs._id
        }
    }
    
    struct Message: Codable, Equatable {
        let _id: String
        let chatroomId: String
        let senderId: String
        let text: String
        let type: String // "text", "image", "location", "post_share", "system"
        let mediaURL: String?
        let replyToId: String?
        let isEdited: Bool
        let isDeleted: Bool
        let readBy: [MessageRead]
        let createdAt: Int
        let updatedAt: Int
        let sender: User?
        
        static func == (lhs: Message, rhs: Message) -> Bool {
            lhs._id == rhs._id
        }
    }
    
    struct MessageRead: Codable, Equatable {
        let userId: String
        let readAt: Int
    }
    
    struct User: Codable, Equatable {
        let _id: String
        let clerkId: String
        let username: String?
        let displayName: String?
        let avatarUrl: String?
        let bio: String?
        let isOnline: Bool
        let lastActiveAt: Int
        
        static func == (lhs: User, rhs: User) -> Bool {
            lhs._id == rhs._id
        }
    }
    

    
    struct TypingStatus: Codable {
        let isTyping: Bool
        let userId: String?
        let timestamp: Int
    }
    
    // MARK: - Messaging Methods
    
    func getChatrooms() async throws -> [Chatroom] {
        let request: [String: String] = [:]
        return try await performTRPCQuery(procedure: "messages.getChatrooms", input: request)
    }
    
    struct GetMessagesRequest: Codable {
        let chatroomId: String
        let limit: Int
    }
    
    func getMessages(for chatroomId: String, limit: Int = 50) async throws -> [Message] {
        let request = GetMessagesRequest(chatroomId: chatroomId, limit: limit)
        return try await performTRPCQuery(procedure: "messages.getMessages", input: request)
    }
    
    struct SendMessageRequest: Codable {
        let chatroomId: String
        let text: String
        let type: String
        let mediaURL: String?
        let replyToId: String?
    }
    
    struct SendMessageResponse: Codable {
        let messageId: String
    }
    
    func sendMessage(_ text: String, to chatroomId: String, type: String = "text", mediaURL: String? = nil, replyToId: String? = nil) async throws -> Message {
        let request = SendMessageRequest(
            chatroomId: chatroomId,
            text: text,
            type: type,
            mediaURL: mediaURL,
            replyToId: replyToId
        )
        
        // ✅ Backend returns { messageId: string }, so we handle that and return a properly formatted Message
        let response: SendMessageResponse = try await performTRPCMutation(procedure: "messages.sendMessage", input: request)
        
        // Create a message object with the returned ID and current user info
        let currentUserId = Clerk.shared.user?.id ?? ""
        let now = Int(Date().timeIntervalSince1970 * 1000)
        
        return Message(
            _id: response.messageId, // ✅ Use the correct messageId from backend
            chatroomId: chatroomId,
            senderId: currentUserId,
            text: text,
            type: type,
            mediaURL: mediaURL,
            replyToId: replyToId,
            isEdited: false,
            isDeleted: false,
            readBy: [MessageRead(userId: currentUserId, readAt: now)],
            createdAt: now,
            updatedAt: now,
            sender: User(
                _id: currentUserId,
                clerkId: currentUserId,
                username: Clerk.shared.user?.username,
                displayName: "\(Clerk.shared.user?.firstName ?? "") \(Clerk.shared.user?.lastName ?? "")".trimmingCharacters(in: .whitespaces),
                avatarUrl: Clerk.shared.user?.imageUrl,
                bio: nil,
                isOnline: true,
                lastActiveAt: now
            )
        )
    }
    
    struct CreateChatroomRequest: Codable {
        let participants: [String]
        let type: String
        let name: String?
    }
    
    struct CreateChatroomResponse: Codable {
        let chatroomId: String
    }
    
    func createChatroom(participants: [String], type: String, name: String? = nil) async throws -> String {
        let request = CreateChatroomRequest(
            participants: participants,
            type: type,
            name: name
        )
        
        let response: CreateChatroomResponse = try await performTRPCMutation(procedure: "messages.createChatroom", input: request)
        return response.chatroomId
    }
    
    func markMessagesAsRead(in chatroomId: String) async throws -> Int {
        let request = ["chatroomId": chatroomId]
        let response: [String: Int] = try await performTRPCMutation(procedure: "messages.markMessagesAsRead", input: request)
        return response["count"] ?? 0
    }
    
    func markChatroomAsRead(_ chatroomId: String) async throws {
        let request = ["chatroomId": chatroomId]
        let _: [String: Bool] = try await performTRPCMutation(procedure: "messages.markChatroomAsRead", input: request)
    }
    
    struct SetTypingStatusRequest: Codable {
        let chatroomId: String
        let isTyping: Bool
    }
    
    func setTypingStatus(_ isTyping: Bool, for chatroomId: String) async throws {
        let request = SetTypingStatusRequest(chatroomId: chatroomId, isTyping: isTyping)
        let _: [String: Bool] = try await performTRPCMutation(procedure: "messages.setTypingStatus", input: request)
    }
    
    func getTypingStatus(for chatroomId: String) async throws -> TypingStatus {
        let request = ["chatroomId": chatroomId]
        return try await performTRPCQuery(procedure: "messages.getTypingStatus", input: request)
    }
    
    func deleteMessage(_ messageId: String, from chatroomId: String) async throws {
        let request = [
            "messageId": messageId,
            "chatroomId": chatroomId
        ]
        let _: [String: Bool] = try await performTRPCMutation(procedure: "messages.deleteMessage", input: request)
    }
    
    struct SearchUsersRequest: Codable {
        let query: String
        let limit: Int
    }
    
    func searchUsersForMessaging(query: String, limit: Int = 20) async throws -> [User] {
        let request = SearchUsersRequest(query: query, limit: limit)
        // ✅ Use the correct messaging endpoint for user search
        return try await performTRPCQuery(procedure: "messages.searchUsers", input: request)
    }
    
    // MARK: - Enhanced Group Messaging
    
    struct CreateGroupChatroomRequest: Codable {
        let participantIds: [String]
        let type: String
        let name: String
        let description: String?
        let imageUrl: String?
    }
    
    func createGroupChatroom(name: String, description: String?, participantIds: [String], imageUrl: String? = nil) async throws -> Chatroom {
        let request = CreateGroupChatroomRequest(
            participantIds: participantIds,
            type: "GROUP",
            name: name,
            description: description,
            imageUrl: imageUrl
        )
        
        return try await performTRPCMutation(procedure: "messages.createChatroom", input: request)
    }
    
    func createDirectChatroom(with participantId: String) async throws -> Chatroom {
        struct CreateDirectChatroomRequest: Codable {
            let participantId: String
            let type: String
        }
        
        let request = CreateDirectChatroomRequest(
            participantId: participantId,
            type: "DIRECT"
        )
        
        return try await performTRPCMutation(procedure: "messages.createChatroom", input: request)
    }
    
    // MARK: - Enhanced Message Sending
    
    struct EnhancedSendMessageRequest: Codable {
        let chatroomId: String
        let content: String
        let messageType: String
        let mediaUrl: String?
        let sharedContentId: String?
        let linkPreview: LinkPreview?
        
        struct LinkPreview: Codable {
            let title: String
            let description: String?
            let imageUrl: String?
            let url: String
        }
    }
    
    func sendTextMessage(_ content: String, to chatroomId: String) async throws -> Message {
        let request = EnhancedSendMessageRequest(
            chatroomId: chatroomId,
            content: content,
            messageType: "TEXT",
            mediaUrl: nil,
            sharedContentId: nil,
            linkPreview: nil
        )
        
        return try await performTRPCMutation(procedure: "messages.sendMessage", input: request)
    }
    
    func sendPostShare(_ postId: String, content: String, to chatroomId: String) async throws -> Message {
        let request = EnhancedSendMessageRequest(
            chatroomId: chatroomId,
            content: content,
            messageType: "POST_SHARE",
            mediaUrl: nil,
            sharedContentId: postId,
            linkPreview: nil
        )
        
        return try await performTRPCMutation(procedure: "messages.sendMessage", input: request)
    }
    
    func sendPlaceShare(_ placeId: String, content: String, to chatroomId: String) async throws -> Message {
        let request = EnhancedSendMessageRequest(
            chatroomId: chatroomId,
            content: content,
            messageType: "PLACE_SHARE",
            mediaUrl: nil,
            sharedContentId: placeId,
            linkPreview: nil
        )
        
        return try await performTRPCMutation(procedure: "messages.sendMessage", input: request)
    }
    
    func sendLinkShare(url: String, title: String, description: String?, imageUrl: String?, content: String, to chatroomId: String) async throws -> Message {
        let linkPreview = EnhancedSendMessageRequest.LinkPreview(
            title: title,
            description: description,
            imageUrl: imageUrl,
            url: url
        )
        
        let request = EnhancedSendMessageRequest(
            chatroomId: chatroomId,
            content: content,
            messageType: "LINK_SHARE",
            mediaUrl: nil,
            sharedContentId: nil,
            linkPreview: linkPreview
        )
        
        return try await performTRPCMutation(procedure: "messages.sendMessage", input: request)
    }
    
    func sendMediaMessage(_ mediaUrl: String, content: String, messageType: String, to chatroomId: String) async throws -> Message {
        let request = EnhancedSendMessageRequest(
            chatroomId: chatroomId,
            content: content,
            messageType: messageType,
            mediaUrl: mediaUrl,
            sharedContentId: nil,
            linkPreview: nil
        )
        
        return try await performTRPCMutation(procedure: "messages.sendMessage", input: request)
    }
    
    // MARK: - Group Management
    
    struct UpdateGroupSettingsRequest: Codable {
        let chatroomId: String
        let name: String?
        let description: String?
        let imageUrl: String?
    }
    
    func updateGroupSettings(chatroomId: String, name: String? = nil, description: String? = nil, imageUrl: String? = nil) async throws -> Chatroom {
        let request = UpdateGroupSettingsRequest(
            chatroomId: chatroomId,
            name: name,
            description: description,
            imageUrl: imageUrl
        )
        
        return try await performTRPCMutation(procedure: "messages.updateGroupSettings", input: request)
    }
    
    struct AddParticipantsRequest: Codable {
        let chatroomId: String
        let userIds: [String]
    }
    
    func addParticipants(to chatroomId: String, userIds: [String]) async throws {
        let request = AddParticipantsRequest(chatroomId: chatroomId, userIds: userIds)
        let _: [String: Bool] = try await performTRPCMutation(procedure: "messages.addParticipants", input: request)
    }
    
    struct RemoveParticipantRequest: Codable {
        let chatroomId: String
        let userId: String
    }
    
    func removeParticipant(from chatroomId: String, userId: String) async throws {
        let request = RemoveParticipantRequest(chatroomId: chatroomId, userId: userId)
        let _: [String: Bool] = try await performTRPCMutation(procedure: "messages.removeParticipant", input: request)
    }
    
    func makeAdmin(in chatroomId: String, userId: String) async throws {
        let request = RemoveParticipantRequest(chatroomId: chatroomId, userId: userId)
        let _: [String: Bool] = try await performTRPCMutation(procedure: "messages.makeAdmin", input: request)
    }
    
    func leaveChatroom(_ chatroomId: String) async throws {
        struct LeaveChatroomRequest: Codable {
            let chatroomId: String
        }
        
        let request = LeaveChatroomRequest(chatroomId: chatroomId)
        let _: [String: Bool] = try await performTRPCMutation(procedure: "messages.leaveChatroom", input: request)
    }
    
    // MARK: - Shared Media
    
    struct GetSharedMediaRequest: Codable {
        let chatroomId: String
        let messageType: String?
        let limit: Int
        let cursor: String?
    }
    
    struct GetSharedMediaResponse: Codable {
        let messages: [Message]
        let nextCursor: String?
    }
    
    func getSharedMedia(in chatroomId: String, messageType: String? = nil, limit: Int = 20, cursor: String? = nil) async throws -> GetSharedMediaResponse {
        let request = GetSharedMediaRequest(
            chatroomId: chatroomId,
            messageType: messageType,
            limit: limit,
            cursor: cursor
        )
        
        return try await performTRPCQuery(procedure: "messages.getSharedMedia", input: request)
    }
    
    // MARK: - User Search for Messaging
    
    func searchUsersMessaging(query: String, limit: Int = 20) async throws -> [User] {
        let request = SearchUsersRequest(query: query, limit: limit)
        return try await performTRPCQuery(procedure: "messages.searchUsers", input: request)
    }

    // MARK: - User Search
    
    struct GetSuggestedUsersRequest: Codable {
        let limit: Int?
        let excludeUserId: String?
        
        init(limit: Int? = nil, excludeUserId: String? = nil) {
            self.limit = limit
            self.excludeUserId = excludeUserId
        }
    }
    
    func getSuggestedUsers(limit: Int = 10) async throws -> [BackendUser] {
        // Get current user to exclude from suggestions
        var excludeUserId: String? = nil
        if let user = Clerk.shared.user {
            excludeUserId = user.id
        }
        
        let request = GetSuggestedUsersRequest(limit: limit, excludeUserId: excludeUserId)
        
        do {
            let users: [ConvexUser] = try await performTRPCQuery(procedure: "users.getSuggested", input: request)
            
            // Convert ConvexUser to BackendUser
            let backendUsers = users.map { convexUser -> BackendUser in
                return BackendUser(
                    id: convexUser._id ?? "",
                    userId: convexUser.userId ?? convexUser.clerkId ?? "",
                    clerkId: convexUser.clerkId ?? "",
                    email: convexUser.email ?? "",
                    firstName: convexUser.firstName,
                    lastName: convexUser.lastName,
                    username: convexUser.username ?? "user_\((convexUser.clerkId ?? "").suffix(8))",
                    displayName: convexUser.displayName ?? convexUser.username ?? "Unknown User",
                    bio: convexUser.bio,
                    avatarUrl: convexUser.avatarUrl,
                    role: nil,
                    appleId: nil,
                    googleId: nil,
                    dietaryPreferences: nil,
                    followersCount: convexUser.followersCount ?? 0,
                    followingCount: convexUser.followingCount ?? 0,
                    postsCount: convexUser.postsCount ?? 0,
                    isVerified: convexUser.isVerified ?? false,
                    isActive: convexUser.isActive ?? true,
                    createdAt: convexUser.createdAt ?? 0,
                    updatedAt: convexUser.updatedAt ?? 0
                )
            }
            return backendUsers
        } catch {
            print("❌ Error loading suggested users: \(error)")
            throw error
        }
    }
    
    func searchBackendUsers(query: String, limit: Int = 20, offset: Int = 0) async throws -> [BackendUser] {
        // Get current user to exclude from search results
        var excludeUserId: String? = nil
        if let user = Clerk.shared.user {
            excludeUserId = user.id
        }
        
        struct UserSearchRequest: Codable {
            let query: String
            let limit: Int
            let offset: Int
            let excludeUserId: String
        }
        
        let request = UserSearchRequest(
            query: query,
            limit: limit,
            offset: offset,
            excludeUserId: excludeUserId ?? ""
        )
        
        do {
            let users: [ConvexUser] = try await performTRPCQuery(procedure: "users.search", input: request)
            
            // Convert ConvexUser to BackendUser
            let backendUsers = users.map { convexUser -> BackendUser in
                return BackendUser(
                    id: convexUser._id ?? "",
                    userId: convexUser.userId ?? convexUser.clerkId ?? "",
                    clerkId: convexUser.clerkId ?? "",
                    email: convexUser.email ?? "",
                    firstName: convexUser.firstName,
                    lastName: convexUser.lastName,
                    username: convexUser.username ?? "user_\((convexUser.clerkId ?? "").suffix(8))",
                    displayName: convexUser.displayName ?? convexUser.username ?? "Unknown User",
                    bio: convexUser.bio,
                    avatarUrl: convexUser.avatarUrl,
                    role: nil,
                    appleId: nil,
                    googleId: nil,
                    dietaryPreferences: nil,
                    followersCount: convexUser.followersCount ?? 0,
                    followingCount: convexUser.followingCount ?? 0,
                    postsCount: convexUser.postsCount ?? 0,
                    isVerified: convexUser.isVerified ?? false,
                    isActive: convexUser.isActive ?? true,
                    createdAt: convexUser.createdAt ?? 0,
                    updatedAt: convexUser.updatedAt ?? 0
                )
            }
            return backendUsers
        } catch {
            print("❌ Error searching users: \(error)")
            throw error
        }
    }
    
    // MARK: - Posts Search
    
    func searchPosts(query: String, limit: Int = 20, offset: Int = 0) async throws -> [BackendPost] {
        let request = SearchRequest(query: query, limit: limit, offset: offset)
        return try await performTRPCQuery(procedure: "posts.search", input: request)
    }
    
    // MARK: - Places Search
    
    struct PlaceSearchResult: Codable {
        let id: String
        let name: String
        let address: String
        let latitude: Double
        let longitude: Double
        let rating: Double?
        let priceLevel: Int?
        let types: [String]
        let placeId: String?
        let photoUrl: String?
    }
    
    struct PlaceSearchRequest: Codable {
        let query: String
        let latitude: Double?
        let longitude: Double?
        let radius: Int
        let limit: Int
    }
    
    func searchPlaces(query: String, latitude: Double?, longitude: Double?, radius: Int = 5000, limit: Int = 20) async throws -> [PlaceSearchResult] {
        let request = PlaceSearchRequest(
            query: query,
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            limit: limit
        )
        return try await performTRPCQuery(procedure: "places.search", input: request)
    }
    
    // MARK: - Response Models
    
    struct FollowResponse: Codable {
        let success: Bool
        let message: String?
    }
    
    struct IsFollowingResponse: Codable {
        let isFollowing: Bool
    }
    
    struct FollowingPost: Codable {
        let _id: String?
        let userId: String
        let title: String?
        let content: String
        let imageUrl: String?
        let imageUrls: [String]?
        let location: String?
        let locationData: ConvexLocation?
        let shopName: String?
        let tags: [String]?
        let isPublic: Bool
        let metadata: ConvexMetadata
        let likes: Int
        let comments: Int
        let viewCount: Int
        let isActive: Bool
        let createdAt: Int
        let updatedAt: Int
        let author: FollowingPostAuthor?
    }
    
    struct FollowingPostAuthor: Codable {
        let _id: String
        let clerkId: String
        let displayName: String?
        let username: String?
        let avatarUrl: String?
    }
    
    struct FriendRequestResponse: Codable {
        let success: Bool
        let message: String?
    }
    
    struct FriendRequest: Codable {
        let _id: String
        let senderId: String
        let receiverId: String
        let status: String
        let createdAt: Int
        let updatedAt: Int
        let sender: FriendRequestSender?
    }
    
    struct FriendRequestSender: Codable {
        let _id: String
        let clerkId: String
        let displayName: String?
        let username: String?
        let avatarUrl: String?
    }
    
    struct AreFriendsResponse: Codable {
        let areFriends: Bool
    }
    
    struct FriendRequestStatusResponse: Codable {
        let status: String // "friends", "sent", "received", "none"
        let request: FriendRequest?
    }

    // MARK: - Generic tRPC Request Handler
    
    func performTRPCQuery<T: Codable, R: Codable>(
        procedure: String,
        input: T
    ) async throws -> R {
        // tRPC queries use GET requests with URL query parameters
        return try await performTRPCRequest(procedure: procedure, input: input, method: .get)
    }
    
    func performTRPCMutation<T: Codable, R: Codable>(
        procedure: String,
        input: T
    ) async throws -> R {
        return try await performTRPCRequest(procedure: procedure, input: input, method: .post)
    }
    
    private func performTRPCRequest<T: Codable, R: Codable>(
        procedure: String,
        input: T,
        method: HTTPMethod
    ) async throws -> R {
        let headers = await getAuthHeaders()
        
        return try await withCheckedThrowingContinuation { continuation in
            let url = "\(baseURL)/trpc/\(procedure)"
            
            // Use appropriate parameter encoding based on HTTP method
            let request: DataRequest
            if method == .get {
                // For tRPC GET requests, parameters must be passed as a JSON-encoded "input" query parameter
                do {
                    let inputData = try JSONEncoder().encode(input)
                    let inputString = String(data: inputData, encoding: .utf8) ?? "{}"
                    let parameters = ["input": inputString]
                    
                    request = AF.request(
                        url,
                        method: method,
                        parameters: parameters,
                        encoder: URLEncodedFormParameterEncoder.default,
                        headers: HTTPHeaders(headers)
                    )
                } catch {
                    print("❌ BackendService: Failed to encode input: \(error)")
                    continuation.resume(throwing: BackendError.decodingError)
                    return
                }
            } else {
                // For POST/PUT/etc., use JSON body encoding
                request = AF.request(
                    url,
                    method: method,
                    parameters: input,
                    encoder: JSONParameterEncoder.default,
                    headers: HTTPHeaders(headers)
                )
            }
            
            request
                .validate()
                .responseDecodable(of: TRPCResponse<R>.self) { response in
                    switch response.result {
                    case .success(let trpcResponse):
                        if let result = trpcResponse.result.data {
                            continuation.resume(returning: result)
                        } else if let error = trpcResponse.error {
                            print("❌ BackendService: tRPC error: \(error.message) (code: \(error.code))")
                            let backendError = BackendError.trpcError(error.message, error.code)
                            continuation.resume(throwing: backendError)
                        } else {
                            print("❌ BackendService: Invalid tRPC response structure")
                            continuation.resume(throwing: BackendError.invalidResponse)
                        }
                    case .failure(let error):
                        print("❌ Backend request failed: \(error)")
                        if case .responseSerializationFailed(let reason) = error {
                            if case .decodingFailed(let decodingError) = reason {
                                print("❌ Decoding error: \(decodingError)")
                            }
                        }
                        continuation.resume(throwing: BackendError.networkError(error))
                    }
                }
        }
    }

    // MARK: - Convex Real-time Subscriptions
    
    /// Example method showing how to safely use Convex when available with tRPC fallback
    /// This demonstrates the pattern that should be used throughout the app
    func subscribeToNotificationsConditionally() {
        if isConvexAvailable {
            print("🟢 Using Convex for real-time notifications")
            // TODO: Implement Convex subscription when needed
            #if canImport(ConvexMobile)
            // convexClient?.subscribe(...)
            #endif
        } else {
            print("🟡 Convex not available, using tRPC polling for notifications")
            // Fallback to tRPC polling or other methods
            // TODO: Implement tRPC polling as fallback
        }
    }

    // MARK: - Lists Management
    
    struct CreateListRequest: Codable {
        let name: String
        let description: String?
        let isPrivate: Bool
        let userId: String
    }
    
    struct CreateListResponse: Codable {
        let listId: String
        let success: Bool
    }
    
    struct BackendList: Codable {
        let _id: String
        let name: String
        let description: String?
        let isPrivate: Bool
        let userId: String
        let postIds: [String]
        let createdAt: Int
        let updatedAt: Int
    }
    
    func createList(name: String, description: String?, isPrivate: Bool) async throws -> CreateListResponse {
        guard let user = Clerk.shared.user else {
            throw BackendError.trpcError("User not authenticated", 401)
        }
        
        let request = CreateListRequest(
            name: name,
            description: description,
            isPrivate: isPrivate,
            userId: user.id
        )
        
        return try await performTRPCMutation(procedure: "lists.create", input: request)
    }
    
    func getUserLists(userId: String) async throws -> [BackendList] {
        let request = ["userId": userId]
        return try await performTRPCQuery(procedure: "lists.getUserLists", input: request)
    }
    
    struct UpdateListRequest: Codable {
        let listId: String
        let name: String?
        let description: String?
        let isPrivate: Bool?
    }
    
    func updateList(listId: String, name: String?, description: String?, isPrivate: Bool?) async throws -> BackendList {
        let request = UpdateListRequest(
            listId: listId,
            name: name,
            description: description,
            isPrivate: isPrivate
        )
        
        return try await performTRPCMutation(procedure: "lists.update", input: request)
    }
    
    struct DeleteListResponse: Codable {
        let success: Bool
    }
    
    func deleteList(listId: String) async throws -> Bool {
        let request = ["listId": listId]
        let response: DeleteListResponse = try await performTRPCMutation(procedure: "lists.delete", input: request)
        return response.success
    }
    
    func addPostToList(listId: String, postId: String) async throws -> Bool {
        let request = ["listId": listId, "postId": postId]
        let response: DeleteListResponse = try await performTRPCMutation(procedure: "lists.addPost", input: request)
        return response.success
    }
    
    func removePostFromList(listId: String, postId: String) async throws -> Bool {
        let request = ["listId": listId, "postId": postId]
        let response: DeleteListResponse = try await performTRPCMutation(procedure: "lists.removePost", input: request)
        return response.success
    }

    // MARK: - Production Configuration

    /// Configure the service for production use
    func configureForProduction() {
        print("🔧 BackendService: Configuring for production use")
        
        // Set production URL if not already set
        if apiConfig.currentEnvironment != .production {
            print("⚠️ BackendService: Switching to production environment")
            apiConfig.switchEnvironment(to: .production, userRole: .admin)
        }
        
        // Verify production connectivity
        Task {
            do {
                let isHealthy = try await healthCheck()
                if isHealthy {
                    print("✅ BackendService: Production backend is healthy")
                } else {
                    print("❌ BackendService: Production backend health check failed")
                }
            } catch {
                print("❌ BackendService: Production backend connection error: \(error)")
            }
        }
    }

    // MARK: - Error Management
    
    /// Comprehensive error handling for all backend operations
    func handleError(_ error: Error, operation: String) {
        print("🚨 BackendService Error in \(operation): \(error.localizedDescription)")
        
        if let afError = error as? AFError {
            switch afError {
            case .responseValidationFailed(let reason):
                print("📍 Response Validation Failed: \(reason)")
            case .sessionTaskFailed(let urlError):
                print("📍 Session Task Failed: \(urlError.localizedDescription)")
            default:
                print("📍 AFError: \(afError.localizedDescription)")
            }
        }
        
        // Track error for analytics (when implemented)
        // analyticsService.trackError(error, operation: operation)
    }

    // MARK: - Feed Methods
    
    func getPersonalizedFeed(
        userId: String,
        userLatitude: Double,
        userLongitude: Double,
        limit: Int = 20,
        cursor: String? = nil
    ) async throws -> PersonalizedFeedResponse {
        print("🎯 BackendService: Getting personalized feed for user: \(userId) at location: (\(userLatitude), \(userLongitude))")
        
        let input: [String: Any] = [
            "userId": userId,
            "userLatitude": userLatitude,
            "userLongitude": userLongitude,
            "limit": limit,
            "cursor": cursor as Any
        ].compactMapValues { $0 }
        
        let inputData = try JSONSerialization.data(withJSONObject: input)
        let inputString = String(data: inputData, encoding: .utf8) ?? "{}"
        let encodedInput = inputString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = "\(baseURL)/trpc/posts.getPersonalizedFeed?input=\(encodedInput)"
        print("🌐 BackendService: Calling personalized feed URL: \(urlString)")
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(urlString, method: .get)
                .validate()
                .responseData { response in
                    switch response.result {
                    case .success(let data):
                        do {
                            // Parse the tRPC response structure
                            let jsonData = try JSONSerialization.jsonObject(with: data)
                            guard let responseDict = jsonData as? [String: Any],
                                  let result = responseDict["result"] as? [String: Any],
                                  let data = result["data"] as? [String: Any] else {
                                throw BackendError.trpcError("Invalid response structure", 422)
                            }
                            
                            let responseData = try JSONSerialization.data(withJSONObject: data)
                            let personalizedResponse = try JSONDecoder().decode(PersonalizedFeedResponse.self, from: responseData)
                            
                            print("✅ BackendService: Successfully loaded personalized feed: \(personalizedResponse.totalReturned) posts (\(personalizedResponse.fromFollowed) from followed, \(personalizedResponse.fromNearby) nearby)")
                            continuation.resume(returning: personalizedResponse)
                            
                        } catch {
                            print("❌ BackendService: Failed to parse personalized feed response: \(error)")
                            continuation.resume(throwing: error)
                        }
                    case .failure(let error):
                        print("❌ BackendService: Failed to get personalized feed: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
        }
    }
}

// MARK: - tRPC Response Models

private struct TRPCResponse<T: Codable>: Codable {
    let result: TRPCResult<T>
    let error: TRPCError?
}

private struct TRPCResult<T: Codable>: Codable {
    let data: T?
}

private struct TRPCError: Codable {
    let message: String
    let code: Int
    let data: TRPCErrorData?
}

private struct TRPCErrorData: Codable {
    let code: String
    let httpStatus: Int
}

// MARK: - Backend Errors

enum BackendError: Error, LocalizedError {
    case networkError(Error)
    case trpcError(String, Int)
    case invalidResponse
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .trpcError(let message, let code):
            return "Backend error (\(code)): \(message)"
        case .invalidResponse:
            return "Invalid response from backend"
        case .decodingError:
            return "Failed to decode backend response"
        }
    }
}

// MARK: - Post Like/Save Functions (Extension of BackendService)

extension BackendService {
    struct ToggleLikeRequest: Codable {
        let postId: String
        let userId: String
    }
    
    struct ToggleLikeResponse: Codable {
        let liked: Bool
        let totalLikes: Int
    }
    
    struct ToggleBookmarkRequest: Codable {
        let postId: String
        let userId: String
    }
    
    struct ToggleBookmarkResponse: Codable {
        let bookmarked: Bool
    }
    
    func togglePostLike(postId: String) async throws -> Bool {
        guard let user = Clerk.shared.user else {
            throw BackendError.trpcError("User not authenticated", 401)
        }
        
        let request = ToggleLikeRequest(postId: postId, userId: user.id)
        let response: ToggleLikeResponse = try await performTRPCMutation(procedure: "posts.toggleLike", input: request)
        
        print("✅ Successfully toggled like for post \\(postId): \\(response.liked ? \"liked\" : \"unliked\")")
        return response.liked
    }
    

} 
