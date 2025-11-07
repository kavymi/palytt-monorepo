# ViewModel Migration Guide

**Purpose:** Guide for migrating ViewModels from `BackendService` to new domain services

**Status:** HomeViewModel ✅ Complete | Others ⏳ Pending

---

## 📋 Overview

This guide shows how to migrate ViewModels from using the monolithic `BackendService` to the new domain-specific services.

### Migration Benefits
- ✅ **Testability:** Easy to mock services in tests
- ✅ **Clarity:** Clear dependencies via protocols
- ✅ **Maintainability:** Changes isolated to relevant services
- ✅ **Performance:** Only inject services you need

---

## ✅ Example: HomeViewModel (Already Migrated)

### Before (Using BackendService)
```swift
@MainActor
class HomeViewModel: ObservableObject {
    private let backendService = BackendService.shared // ❌ Singleton, hard to test
    
    func fetchPosts() {
        Task {
            let posts = try await backendService.getPosts() // ❌ God object
        }
    }
}
```

### After (Using PostsService)
```swift
@MainActor
class HomeViewModel: ObservableObject {
    private let postsService: PostsServiceProtocol? // ✅ Protocol-based, testable
    
    init(postsService: PostsServiceProtocol? = nil) {
        // Default initialization for production
        if let service = postsService {
            self.postsService = service
        } else {
            let apiConfig = APIConfigurationManager.shared
            let baseURL = URL(string: apiConfig.currentBaseURL)!
            self.postsService = PostsService(baseURL: baseURL)
        }
    }
    
    func fetchPosts() {
        Task {
            guard let postsService = postsService else { return }
            let posts = try await postsService.getPosts(page: 1, limit: 20) // ✅ Clean API
        }
    }
}
```

### Testing After Migration
```swift
func testFetchPosts() async {
    // Given
    let mockService = MockPostsService()
    mockService.mockPosts = [mockPost1, mockPost2]
    let viewModel = HomeViewModel(postsService: mockService) // ✅ Easy dependency injection!
    
    // When
    viewModel.fetchPosts()
    await Task.yield() // Let async work complete
    
    // Then
    XCTAssertEqual(viewModel.posts.count, 2)
}
```

---

## 📋 ViewModels to Migrate

### Priority 1: Core Features (High Traffic)

#### 1. ProfileViewModel
**Current:** Uses `BackendService` for user data, posts, followers/following
**Services Needed:** `UserService`, `PostsService`, `SocialService`

```swift
@MainActor
class ProfileViewModel: ObservableObject {
    private let userService: UserServiceProtocol
    private let postsService: PostsServiceProtocol
    private let socialService: SocialServiceProtocol
    
    init(
        userService: UserServiceProtocol? = nil,
        postsService: PostsServiceProtocol? = nil,
        socialService: SocialServiceProtocol? = nil
    ) {
        let baseURL = URL(string: APIConfigurationManager.shared.currentBaseURL)!
        self.userService = userService ?? UserService(baseURL: baseURL)
        self.postsService = postsService ?? PostsService(baseURL: baseURL)
        self.socialService = socialService ?? SocialService(baseURL: baseURL)
    }
    
    func loadUserProfile(userId: String) async throws {
        let user = try await userService.getUserByClerkId(userId)
        let posts = try await postsService.getPostsByUser(userId: userId)
        let followers = try await socialService.getFollowers(userId: userId, limit: 50)
        let following = try await socialService.getFollowing(userId: userId, limit: 50)
        
        // Update @Published properties
        await MainActor.run {
            self.user = user
            self.posts = posts
            self.followersCount = followers.count
            self.followingCount = following.count
        }
    }
}
```

#### 2. ExploreViewModel
**Current:** Uses `BackendService` for search, discovery
**Services Needed:** `SearchService`, `UserService`, `PostsService`

```swift
@MainActor
class ExploreViewModel: ObservableObject {
    private let searchService: SearchServiceProtocol
    private let userService: UserServiceProtocol
    
    init(
        searchService: SearchServiceProtocol? = nil,
        userService: UserServiceProtocol? = nil
    ) {
        let baseURL = URL(string: APIConfigurationManager.shared.currentBaseURL)!
        self.searchService = searchService ?? SearchService(baseURL: baseURL)
        self.userService = userService ?? UserService(baseURL: baseURL)
    }
    
    func searchPosts(query: String) async throws {
        let posts = try await searchService.searchPosts(query: query, limit: 20, offset: 0)
        await MainActor.run {
            self.searchResults = posts
        }
    }
    
    func searchUsers(query: String) async throws {
        let users = try await userService.searchUsers(query: query, limit: 20, offset: 0)
        await MainActor.run {
            self.userResults = users
        }
    }
    
    func searchPlaces(query: String, location: (lat: Double, lon: Double)?) async throws {
        let places = try await searchService.searchPlaces(
            query: query,
            latitude: location?.lat,
            longitude: location?.lon,
            radius: 5000,
            limit: 20
        )
        await MainActor.run {
            self.placeResults = places
        }
    }
}
```

#### 3. MessagingViewModel / ChatroomViewModel
**Current:** Uses `BackendService` for messages
**Services Needed:** `MessagingService`

```swift
@MainActor
class ChatroomViewModel: ObservableObject {
    private let messagingService: MessagingServiceProtocol
    
    init(messagingService: MessagingServiceProtocol? = nil) {
        let baseURL = URL(string: APIConfigurationManager.shared.currentBaseURL)!
        self.messagingService = messagingService ?? MessagingService(baseURL: baseURL)
    }
    
    func loadMessages(chatroomId: String) async throws {
        let messages = try await messagingService.getMessages(for: chatroomId, limit: 50)
        await MainActor.run {
            self.messages = messages
        }
    }
    
    func sendMessage(text: String, to chatroomId: String) async throws {
        let message = try await messagingService.sendTextMessage(text, to: chatroomId)
        await MainActor.run {
            self.messages.append(message)
        }
    }
    
    func setTyping(_ isTyping: Bool, chatroomId: String) async throws {
        _ = try await messagingService.setTypingStatus(isTyping, for: chatroomId)
    }
}
```

### Priority 2: Social Features

#### 4. FriendsViewModel
**Current:** Uses `BackendService` for friends, requests
**Services Needed:** `SocialService`

```swift
@MainActor
class FriendsViewModel: ObservableObject {
    private let socialService: SocialServiceProtocol
    
    init(socialService: SocialServiceProtocol? = nil) {
        let baseURL = URL(string: APIConfigurationManager.shared.currentBaseURL)!
        self.socialService = socialService ?? SocialService(baseURL: baseURL)
    }
    
    func loadFriends(userId: String) async throws {
        let friends = try await socialService.getFriends(userId: userId, limit: 50)
        await MainActor.run {
            self.friends = friends
        }
    }
    
    func sendFriendRequest(to receiverId: String) async throws {
        guard let senderId = currentUserId else { return }
        _ = try await socialService.sendFriendRequest(senderId: senderId, receiverId: receiverId)
        // Update UI
    }
    
    func loadFriendSuggestions() async throws {
        let suggestions = try await socialService.getFriendSuggestions(limit: 20, excludeRequested: true)
        await MainActor.run {
            self.suggestions = suggestions
        }
    }
}
```

#### 5. NotificationsViewModel
**Current:** Uses `BackendService` for notifications
**Services Needed:** `NotificationService`

```swift
@MainActor
class NotificationsViewModel: ObservableObject {
    private let notificationService: NotificationServiceProtocol
    
    init(notificationService: NotificationServiceProtocol? = nil) {
        let baseURL = URL(string: APIConfigurationManager.shared.currentBaseURL)!
        self.notificationService = notificationService ?? NotificationService(baseURL: baseURL)
    }
    
    func loadNotifications(userId: String) async throws {
        let notifications = try await notificationService.getNotifications(
            userId: userId,
            limit: 50,
            onlyUnread: false
        )
        await MainActor.run {
            self.notifications = notifications
        }
    }
    
    func markAsRead(notificationId: String) async throws {
        _ = try await notificationService.markAsRead(notificationId: notificationId)
        // Update local state
    }
    
    func loadUnreadCount(userId: String) async throws {
        let count = try await notificationService.getUnreadCount(userId: userId)
        await MainActor.run {
            self.unreadCount = count
        }
    }
}
```

### Priority 3: Content Features

#### 6. PostDetailViewModel
**Current:** Uses `BackendService` for comments, likes
**Services Needed:** `PostsService`, `CommentService`

```swift
@MainActor
class PostDetailViewModel: ObservableObject {
    private let postsService: PostsServiceProtocol
    private let commentService: CommentServiceProtocol
    
    init(
        postsService: PostsServiceProtocol? = nil,
        commentService: CommentServiceProtocol? = nil
    ) {
        let baseURL = URL(string: APIConfigurationManager.shared.currentBaseURL)!
        self.postsService = postsService ?? PostsService(baseURL: baseURL)
        self.commentService = commentService ?? CommentService(baseURL: baseURL)
    }
    
    func loadComments(postId: String) async throws {
        let comments = try await commentService.getComments(postId: postId, page: 1, limit: 20)
        await MainActor.run {
            self.comments = comments
        }
    }
    
    func addComment(postId: String, content: String) async throws {
        let comment = try await commentService.addComment(postId: postId, content: content, parentCommentId: nil)
        await MainActor.run {
            self.comments.insert(comment, at: 0)
        }
    }
    
    func toggleLike(postId: String) async throws {
        let result = try await postsService.toggleLike(postId: postId)
        await MainActor.run {
            self.isLiked = result.isLiked
            self.likesCount = result.likesCount
        }
    }
}
```

#### 7. SavedPostsViewModel
**Current:** Uses `BackendService` for saved posts, lists
**Services Needed:** `PostsService`, `ListService`

```swift
@MainActor
class SavedPostsViewModel: ObservableObject {
    private let postsService: PostsServiceProtocol
    private let listService: ListServiceProtocol
    
    init(
        postsService: PostsServiceProtocol? = nil,
        listService: ListServiceProtocol? = nil
    ) {
        let baseURL = URL(string: APIConfigurationManager.shared.currentBaseURL)!
        self.postsService = postsService ?? PostsService(baseURL: baseURL)
        self.listService = listService ?? ListService(baseURL: baseURL)
    }
    
    func loadSavedPosts() async throws {
        let posts = try await postsService.getBookmarkedPosts()
        await MainActor.run {
            self.savedPosts = posts
        }
    }
    
    func loadLists(userId: String) async throws {
        let lists = try await listService.getUserLists(userId: userId)
        await MainActor.run {
            self.lists = lists
        }
    }
    
    func addToList(postId: String, listId: String) async throws {
        _ = try await listService.addPostToList(listId: listId, postId: postId)
        // Update UI
    }
}
```

---

## 🔄 Migration Pattern

### Step-by-Step Migration Process

#### 1. Identify Dependencies
```swift
// Before: What BackendService methods does this ViewModel use?
// Example: ProfileViewModel uses:
// - getUserByClerkId()
// - getPosts()
// - getFollowers()
// - getFollowing()

// Map to services:
// UserService: getUserByClerkId()
// PostsService: getPosts()
// SocialService: getFollowers(), getFollowing()
```

#### 2. Add Service Properties
```swift
@MainActor
class YourViewModel: ObservableObject {
    // Add protocol-based service properties
    private let userService: UserServiceProtocol
    private let postsService: PostsServiceProtocol
    private let socialService: SocialServiceProtocol
}
```

#### 3. Update Initializer
```swift
init(
    userService: UserServiceProtocol? = nil,
    postsService: PostsServiceProtocol? = nil,
    socialService: SocialServiceProtocol? = nil
) {
    let baseURL = URL(string: APIConfigurationManager.shared.currentBaseURL)!
    
    // Use provided services or create defaults
    self.userService = userService ?? UserService(baseURL: baseURL)
    self.postsService = postsService ?? PostsService(baseURL: baseURL)
    self.socialService = socialService ?? SocialService(baseURL: baseURL)
}
```

#### 4. Replace BackendService Calls
```swift
// Before
let posts = try await BackendService.shared.getPosts()

// After
let posts = try await postsService.getPosts(page: 1, limit: 20)
```

#### 5. Update Tests
```swift
func testLoadProfile() async {
    // Given
    let mockUserService = MockUserService()
    mockUserService.mockUser = testUser
    let viewModel = ProfileViewModel(userService: mockUserService)
    
    // When
    await viewModel.loadProfile()
    
    // Then
    XCTAssertEqual(viewModel.user?.username, "testuser")
}
```

---

## 🧪 Testing After Migration

### Benefits of New Architecture
```swift
// ✅ Easy to mock services
let mockService = MockPostsService()
mockService.mockPosts = [testPost1, testPost2]

// ✅ Easy to test error handling
mockService.shouldFail = true
mockService.mockError = .networkError(URLError(.notConnectedToInternet))

// ✅ Easy to test different scenarios
mockService.mockPosts = [] // Empty state
mockService.mockPosts = Array(repeating: testPost, count: 100) // Large dataset
```

---

## ⚠️ Important Notes

### Backward Compatibility
- Keep `BackendService` until all ViewModels are migrated
- ViewModels can be migrated one at a time
- No breaking changes to existing functionality

### Preview Mode
- Don't forget to handle preview mode:
```swift
let isInPreviewMode = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

if isInPreviewMode {
    self.postsService = nil // Use mock data instead
} else {
    self.postsService = PostsService(baseURL: baseURL)
}
```

### Error Handling
- All service methods throw `APIError`
- Handle errors consistently:
```swift
do {
    let posts = try await postsService.getPosts(page: 1, limit: 20)
    self.posts = posts
} catch let error as APIError {
    self.errorMessage = error.localizedDescription
    // Log error, show alert, etc.
}
```

---

## 📊 Migration Checklist

For each ViewModel:
- [ ] Identify which services are needed
- [ ] Add service properties (protocol-based)
- [ ] Update initializer with dependency injection
- [ ] Replace `BackendService` calls with service calls
- [ ] Update error handling
- [ ] Handle preview mode
- [ ] Write/update tests
- [ ] Verify functionality in app

---

## 🚀 Quick Start

To migrate a ViewModel right now:

1. **Copy the pattern from HomeViewModel** (already migrated)
2. **Identify services needed** for your ViewModel
3. **Add service properties** with protocols
4. **Update init** for dependency injection
5. **Replace calls** to BackendService
6. **Test** with mock services

**Estimated time per ViewModel:** 15-30 minutes

---

## 📚 Resources

- `HomeViewModel.swift` - Reference implementation
- `*Service.swift` files - Service APIs
- `Mock*Service` classes - Testing mocks
- `*ServiceTests.swift` - Test examples

---

**Ready to migrate? Start with Priority 1 ViewModels for maximum impact!** 🚀

