# Palytt Backend API Reference

## Overview

The Palytt backend uses **tRPC** for type-safe API communication. All endpoints are accessible via the tRPC endpoint.

**Base URL:** `http://localhost:4000/trpc` (development)  
**Production URL:** `https://palytt-backend-production.up.railway.app/trpc`

## Authentication

Protected endpoints require a JWT token from Clerk. Include the token in the Authorization header:

```
Authorization: Bearer <jwt_token>
```

### iOS Swift Integration

```swift
// In your APIClient
func makeAuthenticatedRequest<T: Decodable>(
    procedure: String,
    input: Encodable? = nil,
    method: HTTPMethod = .GET
) async throws -> T {
    var request = URLRequest(url: buildURL(procedure: procedure, input: input))
    request.httpMethod = method.rawValue
    
    if let token = try? await Clerk.shared.session?.getToken() {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    
    // ... rest of request handling
}
```

---

## Routers

### 1. Posts Router (`posts`)

| Endpoint | Type | Auth | Description |
|----------|------|------|-------------|
| `getRecentPosts` | Query | Public | Get recent public posts with pagination |
| `getFeedPosts` | Query | Protected | Get personalized feed posts |
| `getPostById` | Query | Public | Get a single post by ID |
| `getPostsByUserId` | Query | Public | Get posts by a user (clerkId) |
| `createPost` | Mutation | Protected | Create a new post |
| `updatePost` | Mutation | Protected | Update an existing post |
| `deletePost` | Mutation | Protected | Soft delete a post |
| `likePost` | Mutation | Protected | Toggle like on a post |
| `savePost` | Mutation | Protected | Toggle save/bookmark on a post |
| `getSavedPosts` | Query | Protected | Get user's saved posts |
| `getPostStats` | Query | Public | Get like/comment/save counts |
| `getTrendingPosts` | Query | Public | Get trending posts |
| `getPopularPosts` | Query | Public | Get popular posts |
| `searchPosts` | Query | Public | Search posts by query |

#### Example: Get Recent Posts

```swift
// iOS Swift
let posts = try await api.query(
    procedure: "posts.getRecentPosts",
    input: ["limit": 20, "page": 1]
)

// curl
curl 'http://localhost:4000/trpc/posts.getRecentPosts?input={"limit":20,"page":1}'
```

**Input Schema:**
```typescript
{
  limit?: number,  // 1-100, default: 20
  page?: number    // default: 1
}
```

**Output:**
```typescript
{
  posts: Post[],
  totalCount: number,
  page: number,
  totalPages: number
}
```

---

### 2. Users Router (`users`)

| Endpoint | Type | Auth | Description |
|----------|------|------|-------------|
| `getAll` | Query | Public | Get all users (paginated) |
| `getById` | Query | Public | Get user by database UUID |
| `getUserByClerkId` | Query | Public | Get user by Clerk ID |
| `searchUsers` | Query | Public | Search users by username/name |
| `getByUsername` | Query | Public | Get user by username |
| `createUser` | Mutation | Public | Create/ensure user exists |
| `updateUser` | Mutation | Public | Update user profile |
| `deleteUser` | Mutation | Public | Delete user |

#### Example: Get User by Clerk ID

```swift
// iOS Swift
let user = try await api.query(
    procedure: "users.getUserByClerkId",
    input: ["clerkId": clerkUserId]
)

// curl
curl 'http://localhost:4000/trpc/users.getUserByClerkId?input={"clerkId":"user_xxx"}'
```

---

### 3. Friends Router (`friends`)

| Endpoint | Type | Auth | Description |
|----------|------|------|-------------|
| `sendRequest` | Mutation | Protected | Send a friend request |
| `acceptRequest` | Mutation | Protected | Accept a friend request |
| `rejectRequest` | Mutation | Protected | Reject a friend request |
| `getFriends` | Query | Public | Get user's friends list |
| `getPendingRequests` | Query | Protected | Get pending friend requests |
| `areFriends` | Query | Public | Check if two users are friends |
| `removeFriend` | Mutation | Protected | Remove/unfriend a user |
| `blockUser` | Mutation | Protected | Block a user |
| `getMutualFriends` | Query | Public | Get mutual friends between users |
| `getFriendSuggestions` | Query | Protected | Get friend suggestions |

#### Example: Send Friend Request

```swift
// iOS Swift
let result = try await api.mutate(
    procedure: "friends.sendRequest",
    input: ["receiverId": targetUserClerkId]
)

// curl
curl -X POST 'http://localhost:4000/trpc/friends.sendRequest' \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"receiverId":"user_xxx"}'
```

**Note:** All user IDs in friend operations are **Clerk IDs** (not database UUIDs).

---

### 4. Follows Router (`follows`)

| Endpoint | Type | Auth | Description |
|----------|------|------|-------------|
| `follow` | Mutation | Protected | Follow a user |
| `unfollow` | Mutation | Protected | Unfollow a user |
| `getFollowing` | Query | Public | Get users someone is following |
| `getFollowers` | Query | Public | Get user's followers |
| `isFollowing` | Query | Public | Check if user1 follows user2 |
| `getFollowStats` | Query | Public | Get follower/following counts |
| `getMutualFollows` | Query | Public | Get users both users follow |
| `getSuggestedFollows` | Query | Protected | Get follow suggestions |

#### Example: Follow a User

```swift
// iOS Swift
let result = try await api.mutate(
    procedure: "follows.follow",
    input: ["userId": targetUserClerkId]
)

// curl
curl -X POST 'http://localhost:4000/trpc/follows.follow' \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"userId":"user_xxx"}'
```

---

### 5. Messages Router (`messages`)

| Endpoint | Type | Auth | Description |
|----------|------|------|-------------|
| `getChatrooms` | Query | Protected | Get user's chatrooms |
| `createChatroom` | Mutation | Protected | Create direct/group chat |
| `sendMessage` | Mutation | Protected | Send a message |
| `getMessages` | Query | Protected | Get messages from chatroom |
| `markMessagesAsRead` | Mutation | Protected | Mark messages as read |
| `addParticipants` | Mutation | Protected | Add users to group chat |
| `leaveChatroom` | Mutation | Protected | Leave a chatroom |
| `getUnreadCount` | Query | Protected | Get total unread count |
| `updateGroupSettings` | Mutation | Protected | Update group name/image |
| `makeAdmin` | Mutation | Protected | Make participant admin |
| `removeParticipant` | Mutation | Protected | Remove from group |
| `getSharedMedia` | Query | Protected | Get media shared in chat |

#### Example: Create Direct Message Chatroom

```swift
// iOS Swift
let chatroom = try await api.mutate(
    procedure: "messages.createChatroom",
    input: [
        "participantId": otherUserClerkId,
        "type": "DIRECT"
    ]
)

// curl
curl -X POST 'http://localhost:4000/trpc/messages.createChatroom' \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"participantId":"user_xxx","type":"DIRECT"}'
```

#### Example: Send Message

```swift
// iOS Swift
let message = try await api.mutate(
    procedure: "messages.sendMessage",
    input: [
        "chatroomId": chatroomId,
        "content": "Hello!",
        "messageType": "TEXT"
    ]
)
```

**Message Types:** `TEXT`, `IMAGE`, `VIDEO`, `AUDIO`, `FILE`, `POST_SHARE`, `PLACE_SHARE`, `LINK_SHARE`

---

### 6. Comments Router (`comments`)

| Endpoint | Type | Auth | Description |
|----------|------|------|-------------|
| `getComments` | Query | Public | Get comments for a post |
| `addComment` | Mutation | Protected | Add comment to a post |
| `deleteComment` | Mutation | Protected | Delete own comment |
| `toggleLike` | Mutation | Protected | Toggle like on comment |
| `getCommentsByUser` | Query | Public | Get comments by user |

#### Example: Add Comment

```swift
// iOS Swift
let comment = try await api.mutate(
    procedure: "comments.addComment",
    input: [
        "postId": postId,
        "content": "Great post!"
    ]
)

// curl
curl -X POST 'http://localhost:4000/trpc/comments.addComment' \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"postId":"post-uuid","content":"Great post!"}'
```

---

### 7. Notifications Router (`notifications`)

| Endpoint | Type | Auth | Description |
|----------|------|------|-------------|
| `getNotifications` | Query | Protected | Get user's notifications |
| `markAsRead` | Mutation | Protected | Mark specific notifications read |
| `markAllAsRead` | Mutation | Protected | Mark all notifications read |
| `createNotification` | Mutation | Protected | Create notification (internal) |
| `getUnreadCount` | Query | Protected | Get unread notification count |
| `deleteNotifications` | Mutation | Protected | Delete specific notifications |
| `clearAll` | Mutation | Protected | Clear all notifications |
| `getSettings` | Query | Protected | Get notification preferences |
| `updateSettings` | Mutation | Protected | Update notification preferences |
| `getNotificationsByType` | Query | Protected | Get notifications grouped by type |

**Notification Types:**
- `POST_LIKE` - Someone liked your post
- `COMMENT` - Someone commented on your post
- `COMMENT_LIKE` - Someone liked your comment
- `FOLLOW` - Someone followed you
- `FRIEND_REQUEST` - Friend request received
- `FRIEND_ACCEPTED` - Friend request accepted
- `FRIEND_POST` - Friend posted something
- `MESSAGE` - New message received
- `POST_MENTION` - Mentioned in a post
- `GENERAL` - General notification

#### Example: Get Notifications

```swift
// iOS Swift - Using TRPCClient
let notifications = try await TRPCClient.shared.getNotifications(
    limit: 20,
    types: [.friendRequest, .follow],  // Filter by multiple types
    unreadOnly: false
)

// Or using raw procedure call
let input = NotificationsProcedures.GetNotifications.Input(
    limit: 20,
    types: [.friendRequest, .follow]
)
let response = try await client.call(
    procedure: "notifications.getNotifications",
    input: input
)

// curl
curl 'http://localhost:4000/trpc/notifications.getNotifications?input={"limit":20,"types":["FRIEND_REQUEST","FOLLOW"]}' \
  -H "Authorization: Bearer $JWT"
```

**Input Schema:**
```typescript
{
  limit?: number,                // 1-50, default: 20
  cursor?: string,               // Pagination cursor
  type?: NotificationType,       // Single type filter
  types?: NotificationType[],    // Multiple types filter (NEW)
  unreadOnly?: boolean           // default: false
}
```

---

### 8. Lists Router (`lists`)

| Endpoint | Type | Auth | Description |
|----------|------|------|-------------|
| `getUserLists` | Query | Public | Get user's lists |
| `getListById` | Query | Public | Get list with items |
| `createList` | Mutation | Protected | Create a new list |
| `updateList` | Mutation | Protected | Update list details |
| `deleteList` | Mutation | Protected | Delete a list |
| `addToList` | Mutation | Protected | Add place to list |
| `removeFromList` | Mutation | Protected | Remove place from list |

#### Example: Create List

```swift
// iOS Swift
let list = try await api.mutate(
    procedure: "lists.createList",
    input: [
        "name": "Best Tacos",
        "description": "My favorite taco spots",
        "isPublic": true
    ]
)
```

---

### 9. Places Router (`places`)

| Endpoint | Type | Auth | Description |
|----------|------|------|-------------|
| `searchPlaces` | Query | Public | Search for places |

#### Example: Search Places

```swift
// iOS Swift
let places = try await api.query(
    procedure: "places.searchPlaces",
    input: [
        "query": "ramen",
        "limit": 10
    ]
)
```

---

### 10. Example Router (`example`)

| Endpoint | Type | Auth | Description |
|----------|------|------|-------------|
| `hello` | Query | Public | Simple test endpoint |

---

## Error Handling

### Error Response Format

```typescript
{
  "error": {
    "message": "Error message",
    "code": "UNAUTHORIZED" | "BAD_REQUEST" | "NOT_FOUND" | "INTERNAL_SERVER_ERROR",
    "data": {
      "code": "UNAUTHORIZED",
      "httpStatus": 401
    }
  }
}
```

### Common Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `UNAUTHORIZED` | 401 | Missing or invalid JWT token |
| `BAD_REQUEST` | 400 | Invalid input parameters |
| `NOT_FOUND` | 404 | Resource not found |
| `FORBIDDEN` | 403 | No permission for this action |
| `INTERNAL_SERVER_ERROR` | 500 | Server error |

### iOS Error Handling

```swift
enum APIError: Error {
    case unauthorized
    case badRequest(message: String)
    case notFound
    case serverError
    case networkError(Error)
    case decodingError(Error)
}

func handleTRPCError(_ response: TRPCResponse) throws {
    if let error = response.error {
        switch error.data?.code {
        case "UNAUTHORIZED":
            throw APIError.unauthorized
        case "BAD_REQUEST":
            throw APIError.badRequest(message: error.message)
        case "NOT_FOUND":
            throw APIError.notFound
        default:
            throw APIError.serverError
        }
    }
}
```

---

## Pagination

Most list endpoints support cursor-based pagination:

**Input:**
```typescript
{
  limit?: number,     // Items per page (default varies)
  cursor?: string     // Cursor from previous response
}
```

**Output:**
```typescript
{
  items: T[],
  nextCursor?: string  // Pass this as cursor for next page
}
```

### Example: Paginated Fetching

```swift
// iOS Swift
func fetchAllFriends() async throws -> [Friend] {
    var allFriends: [Friend] = []
    var cursor: String? = nil
    
    repeat {
        var input: [String: Any] = ["limit": 50]
        if let cursor = cursor {
            input["cursor"] = cursor
        }
        
        let response = try await api.query(
            procedure: "friends.getFriends",
            input: input
        )
        
        allFriends.append(contentsOf: response.friends)
        cursor = response.nextCursor
    } while cursor != nil
    
    return allFriends
}
```

---

## User ID Convention

**Important:** Throughout this API, when user IDs are required:

- Frontend sends **Clerk IDs** (e.g., `user_35KEqmF7tbWeHKWa1oP3PRTpBDX`)
- Backend handles UUID lookup internally
- Responses include both `id` (UUID) and `clerkId` for flexibility

Example user object in response:
```json
{
  "id": "767e0fa3-60b8-43f8-a548-2f227ed3f9d5",
  "clerkId": "user_35KEqmF7tbWeHKWa1oP3PRTpBDX",
  "username": "johndoe",
  "name": "John Doe"
}
```

---

## Health Check

```bash
curl http://localhost:4000/health
```

Response:
```json
{
  "status": "ok",
  "timestamp": "2025-12-04T03:53:26.485Z",
  "uptime": 63.522496542
}
```

---

## tRPC Panel (Development)

Access the interactive tRPC panel at:
```
http://localhost:4000/trpc/panel
```

This allows you to test all endpoints interactively in the browser.




