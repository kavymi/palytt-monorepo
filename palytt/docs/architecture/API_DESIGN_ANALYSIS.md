# Palytt API Design Analysis: Frontend to Backend

**Date:** October 19, 2025  
**Version:** 1.0  
**Scope:** Complete API architecture from iOS Swift to Node.js/tRPC backend

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Communication Layer](#communication-layer)
4. [Type Safety & Data Flow](#type-safety--data-flow)
5. [Authentication Architecture](#authentication-architecture)
6. [Real-time Communication](#real-time-communication)
7. [Strengths](#strengths)
8. [Critical Issues](#critical-issues)
9. [Detailed Recommendations](#detailed-recommendations)
10. [Implementation Roadmap](#implementation-roadmap)

---

## Executive Summary

### Current State

**Technology Stack:**
- **Frontend:** iOS/SwiftUI with Alamofire for HTTP
- **Backend:** Node.js/Fastify with tRPC
- **Database:** PostgreSQL via Prisma ORM
- **Auth:** Clerk (JWT-based)
- **Real-time:** WebSocket (partial implementation)

### Key Findings

**✅ Strengths:**
- Modern technology choices
- Proper environment configuration
- Real-time infrastructure present
- Clerk authentication integrated

**❌ Critical Issues:**
1. **❌ NOT using tRPC properly** - Frontend bypasses tRPC's type safety
2. **❌ Manual JSON encoding** - Reimplementing what tRPC provides for free
3. **❌ No type sharing** - Zero type safety between frontend/backend
4. **❌ Mixed backend approaches** - tRPC + Convex + manual REST calls
5. **❌ Inconsistent error handling** - Different patterns throughout
6. **❌ WebSocket not integrated with tRPC** - Separate implementation

---

## Architecture Overview

### High-Level Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     iOS SwiftUI App                          │
│                                                               │
│  ┌──────────────┐      ┌──────────────┐                     │
│  │   Views      │─────▶│  ViewModels  │                     │
│  └──────────────┘      └──────┬───────┘                     │
│                               │                               │
│                        ┌──────▼───────────────┐              │
│                        │  BackendService      │              │
│                        │  (Alamofire)         │              │
│                        │  2655 LINES!         │              │
│                        └──────┬───────────────┘              │
│                               │                               │
│         ┌─────────────────────┼─────────────────┐            │
│         │                     │                 │            │
│  ┌──────▼──────┐    ┌────────▼────────┐  ┌─────▼──────┐    │
│  │  Convex     │    │  Manual tRPC    │  │ WebSocket  │    │
│  │  Client     │    │  (REST-like)    │  │  Manager   │    │
│  └─────────────┘    └─────────────────┘  └────────────┘    │
└───────────────────────────────────────────────────────────┘
                              │
                              │ HTTP/HTTPS
                              │
┌─────────────────────────────▼─────────────────────────────┐
│                    Node.js Backend                         │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐ │
│  │              Fastify Server                          │ │
│  │              Port 4000                               │ │
│  └──────────────────┬───────────────────────────────────┘ │
│                     │                                      │
│      ┌──────────────┼──────────────┐                      │
│      │              │              │                      │
│  ┌───▼────┐   ┌────▼─────┐   ┌───▼────┐                 │
│  │  tRPC  │   │WebSocket │   │  CORS  │                 │
│  │ Plugin │   │  Plugin  │   │ Plugin │                 │
│  └───┬────┘   └──────────┘   └────────┘                 │
│      │                                                    │
│  ┌───▼──────────────────────────────┐                    │
│  │      tRPC Routers (11)           │                    │
│  │  ┌──────┐  ┌──────┐  ┌──────┐   │                    │
│  │  │Users │  │Posts │  │Msgs  │   │                    │
│  │  └──────┘  └──────┘  └──────┘   │                    │
│  └───────────────┬──────────────────┘                    │
│                  │                                        │
│  ┌───────────────▼──────────────────┐                    │
│  │         Prisma ORM               │                    │
│  └───────────────┬──────────────────┘                    │
└──────────────────┼───────────────────────────────────────┘
                   │
                   ▼
        ┌──────────────────┐
        │   PostgreSQL     │
        │    Database      │
        └──────────────────┘
```

---

## Communication Layer

### Problem: Manual tRPC Implementation ❌

#### Current Approach (BackendService.swift)

```swift
// Lines 2295-2342: Manual tRPC call implementation
private func callTRPCProcedure<T: Encodable, R: Decodable>(
    procedure: String,
    input: T,
    method: HTTPMethod
) async throws -> R {
    let headers = await getAuthHeaders()
    
    return try await withCheckedThrowingContinuation { continuation in
        let url = "\(baseURL)/trpc/\(procedure)"
        
        // Manual JSON encoding for GET requests
        if method == .get {
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
                continuation.resume(throwing: BackendError.decodingError)
                return
            }
        } else {
            // Manual JSON body encoding for POST
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
            .responseDecodable(of: R.self) { response in
                // Manual response handling...
            }
    }
}
```

**Problems with this approach:**

1. **❌ No Type Safety** - Swift types and TypeScript types are disconnected
2. **❌ Manual Work** - Reimplementing what tRPC provides automatically
3. **❌ Error Prone** - Easy to mismatch frontend/backend types
4. **❌ No Auto-completion** - No IDE support for API calls
5. **❌ Maintenance Hell** - Every API change requires manual updates on both sides
6. **❌ No Validation** - Client-side validation missing

#### What You're Missing: tRPC's Value Proposition

**tRPC's Core Benefit:** End-to-end type safety WITHOUT code generation!

```typescript
// Backend (TypeScript)
export const usersRouter = router({
  getById: publicProcedure
    .input(z.object({ id: z.string().uuid() }))
    .query(async ({ input }) => {
      return await prisma.user.findUnique({
        where: { id: input.id }
      });
    }),
});

// Frontend (TypeScript/React) - Would look like:
const user = await trpc.users.getById.query({ id: "uuid" });
// ✅ Full type safety
// ✅ Auto-completion
// ✅ Compile-time errors if types mismatch
// ✅ Runtime validation with Zod
```

### Reality: iOS Can't Use tRPC's Type Safety Directly

**The fundamental challenge:** tRPC is designed for TypeScript-to-TypeScript communication. Swift cannot directly consume TypeScript types.

**However, you're currently getting ZERO benefits from tRPC:**
- ❌ No type safety
- ❌ No auto-completion  
- ❌ No validation
- ❌ Manual JSON encoding/decoding
- ❌ Error-prone manual URL construction

---

## Type Safety & Data Flow

### Current State: Complete Type Disconnect ❌

#### Backend Type Definition (TypeScript)

```typescript
// palytt-backend/src/routers/posts.ts
export const postsRouter = router({
  create: protectedProcedure
    .input(
      z.object({
        shopName: z.string(),
        foodItem: z.string(),
        description: z.string().optional(),
        rating: z.number().min(1).max(5),
        imageUrl: z.string().url().optional(),
        imageUrls: z.array(z.string().url()),
        tags: z.array(z.string()),
        location: z.object({
          latitude: z.number(),
          longitude: z.number(),
          address: z.string(),
          name: z.string().optional(),
        }).optional(),
        isPublic: z.boolean().default(true),
      })
    )
    .mutation(async ({ input, ctx }) => {
      // Implementation...
    }),
});
```

#### Frontend Type Definition (Swift) - DISCONNECTED!

```swift
// palytt/Sources/PalyttApp/Models/Post.swift
struct Post: Identifiable, Codable, Equatable {
    let id: UUID
    let convexId: String
    let userId: UUID
    let author: User
    let title: String?
    let caption: String
    let mediaURLs: [URL]
    let shop: Shop?
    let location: Location
    let menuItems: [String]
    let rating: Double?
    // ...
}
```

**Problems:**
1. ❌ No shared source of truth
2. ❌ Types can drift apart without detection
3. ❌ Manual synchronization required
4. ❌ Refactoring becomes dangerous
5. ❌ No compile-time safety

### Data Transformation Complexity

#### Backend Response (posts.ts)

```typescript
const transformedPost = {
  id: post.id,
  authorId: post.userId,
  authorClerkId: post.author.clerkId,
  shopId: null,
  shopName: post.title || '',
  foodItem: post.menuItems[0] || '',
  description: post.caption,
  rating: post.rating || 5,
  imageUrl: post.mediaUrls[0] || null,
  imageUrls: post.mediaUrls,
  tags: input.tags,
  location: input.location,
  // ...
};
```

#### Frontend Conversion (Post.swift - lines 89-208)

```swift
static func from(
    backendPost: BackendService.BackendPost,
    author: User? = nil
) -> Post {
    // 120+ lines of manual conversion
    let dateFormatter = ISO8601DateFormatter()
    let createdAt = dateFormatter.date(from: backendPost.createdAt) ?? Date()
    
    var mediaURLs: [URL] = []
    var seenURLStrings: Set<String> = []
    
    // Manual deduplication
    for urlString in backendPost.imageUrls {
        if !seenURLStrings.contains(urlString), let url = URL(string: urlString) {
            seenURLStrings.insert(urlString)
            mediaURLs.append(url)
        }
    }
    
    // More manual mapping...
}
```

**This is a maintenance nightmare!**

---

## Authentication Architecture

### Current Implementation: Hybrid Approach

#### Frontend Auth (BackendService.swift - lines 174-189)

```swift
private func getAuthHeaders() async -> [String: String] {
    let baseHeaders = ["Content-Type": "application/json"]
    
    guard let user = Clerk.shared.user else {
        return baseHeaders
    }
    
    return [
        "Content-Type": "application/json",
        "Authorization": "Bearer clerk_\(user.id)",  // ⚠️ NOT A REAL JWT!
        "x-clerk-user-id": user.id
    ]
}
```

**Problems:**
1. ⚠️ Using `clerk_` prefix + user ID as token (development only)
2. ⚠️ Should use real JWT from Clerk: `await user.getToken()`
3. ⚠️ Insecure for production
4. ⚠️ Backend has to handle two auth modes

#### Backend Auth (trpc.ts - lines 17-49)

```typescript
export async function createContext({ req }: CreateFastifyContextOptions) {
  let user: AuthenticatedUser | null = null;
  
  const authHeader = req.headers.authorization;
  const clerkUserId = req.headers['x-clerk-user-id'];
  
  if (authHeader?.startsWith('Bearer ')) {
    const token = authHeader.slice(7);
    
    // Development mode: Accept clerk_ prefixed tokens ⚠️
    if (token.startsWith('clerk_') && clerkUserId) {
      console.log('⚠️ Using development authentication for user:', clerkUserId);
      user = {
        id: clerkUserId,
        clerkId: clerkUserId,
      };
    } else {
      try {
        // Production mode: Use Clerk's proper JWT verification ✅
        user = await validateClerkToken(token);
      } catch (error) {
        console.error('Token verification failed:', error);
      }
    }
  }
  
  return { user, req };
}
```

**Assessment:**
- ✅ Proper JWT validation exists for production
- ⚠️ Development shortcut is insecure
- ⚠️ Frontend should be updated to use real JWTs

### Security Issues

1. **Development tokens in production?**
   - Need to ensure `clerk_` tokens are rejected in production
   - Environment checks missing

2. **Token refresh not handled**
   - Clerk JWTs expire
   - No automatic refresh mechanism
   - Will cause sudden authentication failures

3. **No token caching**
   - Fetching token on every request
   - Could hit rate limits

---

## Real-time Communication

### Multiple WebSocket Implementations ❌

You have **THREE separate WebSocket implementations:**

#### 1. RealtimeService.swift (209 lines)

```swift
@MainActor
class RealtimeService: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private let baseURL = "ws://localhost:4000"
    
    func connect() async {
        await createWebSocketConnection()
    }
    
    func sendLiveUpdate(_ update: LiveUpdate) async {
        // Send via WebSocket
    }
    
    // Heartbeat, reconnection, etc.
}
```

#### 2. WebSocketManager.swift (71+ lines)

```swift
@MainActor
class WebSocketManager: NSObject, ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    
    func connect(to url: URL) {
        // Another WebSocket implementation
    }
}
```

#### 3. tRPC Backend WebSocket Support

```typescript
// index.ts - lines 56-70
await server.register(websocket);

await server.register(fastifyTRPCPlugin, {
  // ...
  useWSS: true, // Enable WebSocket support
});
```

**Problems:**
1. ❌ **Fragmentation** - Multiple implementations doing similar things
2. ❌ **No integration** - WebSocket not integrated with tRPC
3. ❌ **Incomplete** - RealtimeService connects to `/ws`, which doesn't exist in backend
4. ❌ **Duplication** - Heartbeat, reconnection logic duplicated
5. ❌ **Type safety** - WebSocket messages have no type checking

### Missing: tRPC Subscriptions

**tRPC supports subscriptions out of the box:**

```typescript
// Backend example (what you should have)
export const postsRouter = router({
  onPostCreated: publicProcedure
    .subscription(async function* ({ ctx }) {
      // Yield new posts in real-time
      for await (const post of watchPosts()) {
        yield post;
      }
    }),
});

// Frontend (if you were using TypeScript)
const subscription = trpc.posts.onPostCreated.subscribe({
  onData: (post) => {
    console.log('New post:', post);
  }
});
```

---

## Strengths

### ✅ What's Working Well

1. **Modern Technology Stack**
   - tRPC on backend is a good choice
   - Fastify is performant
   - Prisma provides good ORM layer
   - Clerk for auth is production-ready

2. **Environment Configuration**
   - `APIConfigurationManager` handles local/production switching well
   - Environment-based URLs configured properly

3. **Backend Structure**
   - 11 domain-specific routers well organized
   - Proper Prisma schema with relations
   - Authentication middleware in place
   - Basic rate limiting implemented

4. **Type Validation (Backend)**
   - Zod schemas validate inputs
   - Type-safe database queries with Prisma
   - Proper error handling in procedures

5. **Infrastructure**
   - Health check endpoint
   - CORS properly configured
   - WebSocket plugins registered
   - Logging with Pino

---

## Critical Issues

### 1. ❌ Not Using tRPC Properly

**Issue:** Frontend makes manual HTTP calls to tRPC endpoints, bypassing all of tRPC's benefits.

**Impact:**
- No type safety
- No auto-completion
- No validation
- Manual encoding/decoding
- Fragile to changes

**Root Cause:** iOS/Swift cannot use TypeScript types directly.

**Solution:** → See recommendations below

---

### 2. ❌ BackendService is 2655 Lines

**File:** `palytt/Sources/PalyttApp/Utilities/BackendService.swift`

**Contents:**
- Authentication
- Posts CRUD
- Comments
- Likes/Bookmarks
- Friends/Follows
- Messages
- Notifications
- User management
- Convex integration
- WebSocket setup
- Error handling
- Response transformations

**Problems:**
- Impossible to test in isolation
- Violates Single Responsibility Principle
- Hard to maintain
- Merge conflicts
- Difficult for team collaboration

**Impact:** Development velocity significantly slowed

---

### 3. ❌ Triple Backend Strategy

You're using THREE different backend approaches:

1. **Manual tRPC calls** (via Alamofire)
   ```swift
   let urlString = "\(baseURL)/trpc/posts.getRecentPosts?input=\(encodedInput)"
   ```

2. **Convex SDK** (conditional import)
   ```swift
   #if canImport(ConvexMobile)
   private var convexClient: ConvexClient?
   #endif
   ```

3. **WebSocket** (custom implementation)
   ```swift
   webSocketTask = urlSession.webSocketTask(with: request)
   ```

**Problems:**
- Confusing architecture
- Maintenance burden
- Which one is source of truth?
- Different error handling for each
- Team confusion

**Decision needed:** Pick ONE primary backend approach

---

### 4. ❌ No Shared Type Definitions

**Backend:** TypeScript types in tRPC routers + Zod schemas
**Frontend:** Swift structs completely separate

**Example disconnect:**

Backend expects:
```typescript
{
  shopName: string,
  foodItem: string,
  rating: number,
  imageUrls: string[]
}
```

Frontend sends:
```swift
Post(
  title: "Shop Name",
  menuItems: ["Food"],
  rating: 5.0,
  mediaURLs: [URL]
)
```

**Result:** Brittle, easy to break, no safety net

---

### 5. ❌ Inconsistent Error Handling

Different error handling approaches throughout:

**Backend:**
```typescript
throw new Error('User not found');  // Plain Error
throw new TRPCError({ code: 'NOT_FOUND' });  // tRPC Error
return { success: false, error: 'Message' };  // Error in response
```

**Frontend:**
```swift
enum BackendError: Error {
  case networkError
  case decodingError
  case serverError
  // ...
}

// But also:
print("❌ Error: \(error)")  // Console logs
continuation.resume(throwing: error)  // Throwing
// Sometimes swallowed silently
```

**Impact:** Inconsistent user experience, hard to debug

---

### 6. ❌ WebSocket Not Integrated

**Backend:** tRPC has WebSocket support registered
**Frontend:** Custom WebSocket implementation not using tRPC

**Problems:**
- No type safety for real-time messages
- Manual message parsing
- Separate connection management
- Duplicate error handling

---

### 7. ❌ Missing Production Features

**No Caching:**
- Every request hits backend
- Same data fetched repeatedly
- Poor user experience on slow connections

**No Request Deduplication:**
- Multiple components can trigger same API call
- Wasteful network usage

**No Optimistic Updates:**
- Every action waits for server response
- Feels slow to users

**No Offline Support:**
- App breaks without network
- No local persistence
- Bad mobile UX

---

## Detailed Recommendations

### Priority 1: Decide on Backend Architecture

**Option A: Pure tRPC + Swift Client (Recommended)**

**Approach:** Generate Swift types from TypeScript types

**Tools:**
- [openapi-generator](https://github.com/OpenAPITools/openapi-generator)
- [quicktype](https://quicktype.io/)
- Custom codegen script

**Workflow:**
```bash
# 1. Export tRPC types to OpenAPI/JSON Schema
npm run generate-schema

# 2. Generate Swift models
./scripts/generate-swift-types.sh

# 3. Use generated types in app
```

**Pros:**
- ✅ Maintains type safety
- ✅ Single source of truth (backend)
- ✅ Automated type generation
- ✅ Catches breaking changes at build time

**Cons:**
- ⚠️ Requires build pipeline setup
- ⚠️ Generated code might need customization
- ⚠️ Swift and TypeScript type systems differ

**Implementation:**

```typescript
// backend/scripts/export-types.ts
import { generateOpenApiDocument } from 'trpc-openapi';
import { appRouter } from '../src/routers/app';

const openApiDocument = generateOpenApiDocument(appRouter, {
  title: 'Palytt API',
  version: '1.0.0',
  baseUrl: 'https://api.palytt.com',
});

fs.writeFileSync(
  'generated/openapi.json',
  JSON.stringify(openApiDocument, null, 2)
);
```

```bash
# Generate Swift types
openapi-generator generate \
  -i generated/openapi.json \
  -g swift5 \
  -o ios/Generated/
```

```swift
// Use generated client
let api = PalyttAPI(baseURL: "https://api.palytt.com")

// Type-safe API calls
let posts = try await api.posts.getRecentPosts(
  input: GetRecentPostsInput(page: 1, limit: 20)
)
```

---

**Option B: Keep Manual Approach But Improve It**

If code generation is too complex, improve current approach:

#### 1. Split BackendService into Domain Services

```swift
// PostsService.swift (300 lines max)
protocol PostsServiceProtocol {
    func getPosts(page: Int, limit: Int) async throws -> [Post]
    func createPost(_ post: CreatePostRequest) async throws -> Post
    func likePost(id: UUID) async throws
    func deletePost(id: UUID) async throws
}

final class PostsService: PostsServiceProtocol {
    private let apiClient: APIClient
    private let authProvider: AuthProvider
    
    init(apiClient: APIClient, authProvider: AuthProvider) {
        self.apiClient = apiClient
        self.authProvider = authProvider
    }
    
    func getPosts(page: Int, limit: Int) async throws -> [Post] {
        let request = GetPostsRequest(page: page, limit: limit)
        let response: GetPostsResponse = try await apiClient.call(
            procedure: "posts.getRecentPosts",
            input: request,
            method: .get
        )
        return response.posts.map { Post.from($0) }
    }
}

// Repeat for:
// - UserService
// - MessagingService
// - SocialService (friends/follows)
// - CommentService
// - NotificationService
```

#### 2. Create Shared DTOs

```swift
// DTOs/PostDTO.swift
struct PostDTO: Codable {
    let id: String
    let authorId: String
    let shopName: String
    let foodItem: String
    let description: String?
    let rating: Double
    let imageUrls: [String]
    let tags: [String]
    let location: LocationDTO?
    let createdAt: String
    let updatedAt: String
    let likesCount: Int
    let commentsCount: Int
    let isLiked: Bool?
    let isSaved: Bool?
}

// DTOs/Requests/CreatePostRequest.swift
struct CreatePostRequest: Codable {
    let shopName: String
    let foodItem: String
    let description: String?
    let rating: Double
    let imageUrls: [String]
    let tags: [String]
    let location: LocationDTO?
    let isPublic: Bool
}
```

#### 3. Separate API Client

```swift
// APIClient.swift (200 lines max)
final class APIClient {
    private let session: URLSession
    private let baseURL: URL
    private let authProvider: AuthProvider
    
    func call<T: Encodable, R: Decodable>(
        procedure: String,
        input: T,
        method: HTTPMethod
    ) async throws -> R {
        let request = try buildRequest(
            procedure: procedure,
            input: input,
            method: method
        )
        
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response)
        
        return try JSONDecoder().decode(R.self, from: data)
    }
    
    private func buildRequest<T: Encodable>(
        procedure: String,
        input: T,
        method: HTTPMethod
    ) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent("/trpc/\(procedure)"))
        request.httpMethod = method.rawValue
        
        // Add auth headers
        let headers = try await authProvider.getHeaders()
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        // Encode input
        if method == .get {
            // URL query parameter
            let inputData = try JSONEncoder().encode(input)
            let inputString = String(data: inputData, encoding: .utf8)!
            var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "input", value: inputString)]
            request.url = components.url
        } else {
            // JSON body
            request.httpBody = try JSONEncoder().encode(input)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        return request
    }
}
```

---

### Priority 2: Fix Authentication

#### Use Real Clerk JWTs

```swift
// AuthProvider.swift
final class AuthProvider {
    private let clerk = Clerk.shared
    private var cachedToken: String?
    private var tokenExpiry: Date?
    
    func getToken() async throws -> String {
        // Return cached token if still valid
        if let token = cachedToken,
           let expiry = tokenExpiry,
           expiry > Date() {
            return token
        }
        
        // Get fresh token from Clerk
        guard let user = clerk.user else {
            throw AuthError.notAuthenticated
        }
        
        // ✅ Use real JWT, not clerk_ prefix
        let token = try await user.getToken()
        
        // Cache with 5 minute buffer before expiry
        cachedToken = token
        tokenExpiry = Date().addingTimeInterval(55 * 60) // 55 minutes
        
        return token
    }
    
    func getHeaders() async throws -> [String: String] {
        let token = try await getToken()
        
        return [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(token)"
        ]
    }
    
    func clearCache() {
        cachedToken = nil
        tokenExpiry = nil
    }
}
```

#### Remove Development Auth from Backend

```typescript
// trpc.ts - Remove development bypass
export async function createContext({ req }: CreateFastifyContextOptions) {
  let user: AuthenticatedUser | null = null;
  
  const authHeader = req.headers.authorization;
  
  if (authHeader?.startsWith('Bearer ')) {
    const token = authHeader.slice(7);
    
    // ✅ Always use proper JWT validation
    try {
      user = await validateClerkToken(token);
    } catch (error) {
      console.error('Token verification failed:', error);
      // Let procedures handle auth errors
    }
  }
  
  return { user, req };
}
```

---

### Priority 3: Implement Caching Layer

```swift
// CacheService.swift
final class CacheService {
    private var cache: [String: CacheEntry] = [:]
    private let queue = DispatchQueue(label: "com.palytt.cache", attributes: .concurrent)
    
    struct CacheEntry {
        let data: Data
        let expiresAt: Date
    }
    
    func get(key: String) -> Data? {
        queue.sync {
            guard let entry = cache[key],
                  entry.expiresAt > Date() else {
                return nil
            }
            return entry.data
        }
    }
    
    func set(key: String, data: Data, ttl: TimeInterval = 300) {
        queue.async(flags: .barrier) {
            self.cache[key] = CacheEntry(
                data: data,
                expiresAt: Date().addingTimeInterval(ttl)
            )
        }
    }
    
    func invalidate(pattern: String) {
        queue.async(flags: .barrier) {
            self.cache.keys
                .filter { $0.contains(pattern) }
                .forEach { self.cache.removeValue(forKey: $0) }
        }
    }
}

// Use in service
final class PostsService {
    private let api: APIClient
    private let cache: CacheService
    
    func getPosts(page: Int = 1, limit: Int = 20) async throws -> [Post] {
        let cacheKey = "posts:page:\(page):limit:\(limit)"
        
        // Try cache first
        if let cached = cache.get(key: cacheKey),
           let response = try? JSONDecoder().decode([Post].self, from: cached) {
            return response
        }
        
        // Fetch from API
        let posts: [Post] = try await api.call(
            procedure: "posts.getRecentPosts",
            input: GetPostsRequest(page: page, limit: limit),
            method: .get
        )
        
        // Cache for 5 minutes
        if let data = try? JSONEncoder().encode(posts) {
            cache.set(key: cacheKey, data: data, ttl: 300)
        }
        
        return posts
    }
    
    func createPost(_ request: CreatePostRequest) async throws -> Post {
        let post = try await api.call(
            procedure: "posts.create",
            input: request,
            method: .post
        )
        
        // Invalidate relevant caches
        cache.invalidate(pattern: "posts:")
        
        return post
    }
}
```

---

### Priority 4: Standardize Error Handling

#### Define App-Wide Error Types

```swift
// Errors/APIError.swift
enum APIError: LocalizedError, Equatable {
    case networkError(URLError)
    case serverError(statusCode: Int, message: String?)
    case decodingError(DecodingError)
    case unauthorized
    case forbidden
    case notFound
    case rateLimitExceeded
    case validationError([String])
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return message ?? "Server error (\(code))"
        case .decodingError:
            return "Invalid data received from server"
        case .unauthorized:
            return "Please sign in to continue"
        case .forbidden:
            return "You don't have permission to perform this action"
        case .notFound:
            return "The requested resource was not found"
        case .rateLimitExceeded:
            return "Too many requests. Please try again later"
        case .validationError(let errors):
            return errors.joined(separator: "\n")
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

// Global error handler
@MainActor
final class ErrorHandler: ObservableObject {
    @Published var currentError: APIError?
    @Published var showError = false
    
    func handle(_ error: Error) {
        let apiError: APIError
        
        if let err = error as? APIError {
            apiError = err
        } else if let urlError = error as? URLError {
            apiError = .networkError(urlError)
        } else if let decodingError = error as? DecodingError {
            apiError = .decodingError(decodingError)
        } else {
            apiError = .unknown(error)
        }
        
        currentError = apiError
        showError = true
        
        // Log to analytics
        AnalyticsService.shared.logError(apiError)
    }
}
```

#### Use in ViewModels

```swift
@MainActor
final class HomeViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    
    private let postsService: PostsServiceProtocol
    private let errorHandler: ErrorHandler
    
    init(
        postsService: PostsServiceProtocol,
        errorHandler: ErrorHandler
    ) {
        self.postsService = postsService
        self.errorHandler = errorHandler
    }
    
    func loadPosts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            posts = try await postsService.getPosts()
        } catch {
            errorHandler.handle(error)
        }
    }
}
```

---

### Priority 5: Implement Request Deduplication

```swift
// RequestDeduplicator.swift
actor RequestDeduplicator {
    private var inFlightRequests: [String: Task<Any, Error>] = [:]
    
    func deduplicate<T>(
        key: String,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        // Return existing request if in flight
        if let existingTask = inFlightRequests[key] {
            return try await existingTask.value as! T
        }
        
        // Create new task
        let task = Task {
            try await operation()
        }
        
        inFlightRequests[key] = task as! Task<Any, Error>
        
        defer {
            inFlightRequests.removeValue(forKey: key)
        }
        
        return try await task.value
    }
}

// Use in service
final class PostsService {
    private let deduplicator = RequestDeduplicator()
    
    func getPosts(page: Int, limit: Int) async throws -> [Post] {
        let key = "posts:page:\(page):limit:\(limit)"
        
        return try await deduplicator.deduplicate(key: key) {
            try await api.call(
                procedure: "posts.getRecentPosts",
                input: GetPostsRequest(page: page, limit: limit),
                method: .get
            )
        }
    }
}
```

---

## Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)

**Goal:** Clean up current mess, establish patterns

#### Week 1: Split BackendService
- [ ] Create APIClient (200 lines)
- [ ] Create AuthProvider (100 lines)
- [ ] Create PostsService (300 lines)
- [ ] Create UserService (200 lines)
- [ ] Update HomeViewModel to use PostsService
- [ ] Add unit tests

#### Week 2: More Services + Error Handling
- [ ] Create MessagingService
- [ ] Create SocialService
- [ ] Create CommentService
- [ ] Implement APIError types
- [ ] Create ErrorHandler
- [ ] Update all ViewModels to use ErrorHandler

**Estimated Effort:** 40-60 hours

---

### Phase 2: Type Safety & Caching (Weeks 3-4)

#### Week 3: DTOs & Type Generation
- [ ] Extract all request/response DTOs
- [ ] Document backend API shape
- [ ] Investigate type generation tools
- [ ] Set up OpenAPI export from tRPC
- [ ] Create initial code generation pipeline

#### Week 4: Caching Layer
- [ ] Implement CacheService
- [ ] Add caching to PostsService
- [ ] Add caching to UserService
- [ ] Implement cache invalidation
- [ ] Add cache metrics/monitoring

**Estimated Effort:** 40-50 hours

---

### Phase 3: Production Features (Weeks 5-6)

#### Week 5: Request Optimization
- [ ] Implement RequestDeduplicator
- [ ] Add optimistic updates for likes
- [ ] Add optimistic updates for follows
- [ ] Implement offline queue
- [ ] Add network connectivity monitoring

#### Week 6: Real-time Integration
- [ ] Choose ONE WebSocket approach
- [ ] Remove duplicate WebSocket code
- [ ] Integrate WebSocket with type system
- [ ] Add real-time post notifications
- [ ] Add real-time messaging

**Estimated Effort:** 50-60 hours

---

## Success Metrics

### Code Quality
- [ ] No files > 500 lines
- [ ] BackendService split into 7+ services
- [ ] All API calls use typed DTOs
- [ ] 80%+ code coverage on services

### Performance
- [ ] 50%+ reduction in API calls (via caching)
- [ ] 80%+ cache hit rate
- [ ] < 100ms cache lookup time
- [ ] Request deduplication working

### Developer Experience
- [ ] New API endpoint integration < 30 minutes
- [ ] Type mismatches caught at compile time
- [ ] Clear error messages for all failures
- [ ] API documentation auto-generated

### User Experience
- [ ] Optimistic updates feel instant
- [ ] App works offline for cached content
- [ ] Clear error messages shown to users
- [ ] Real-time updates feel immediate

---

## Conclusion

### Current State Summary

**Architecture:** Hybrid mess
- Manual tRPC calls (not using tRPC properly)
- Convex client (conditional)
- Custom WebSocket (disconnected from backend)

**Code Quality:** Technical debt
- 2655-line god object
- No type safety
- Scattered error handling
- Duplicated logic

**Capabilities:** Basic but brittle
- ✅ CRUD operations work
- ✅ Authentication works
- ❌ No caching
- ❌ No offline support
- ❌ No type safety
- ❌ Hard to maintain

### Recommended Path Forward

**Short Term (Weeks 1-2):**
1. Split BackendService → Focus here first!
2. Standardize error handling
3. Fix authentication to use real JWTs

**Medium Term (Weeks 3-4):**
1. Extract DTOs
2. Implement caching
3. Add request deduplication

**Long Term (Weeks 5-6):**
1. Set up type generation
2. Clean up WebSocket implementation
3. Add offline support

**Effort:** ~150 hours total (3-4 weeks for 1-2 developers)

**ROI:** 
- 10x easier to add new features
- 50% fewer bugs
- Better user experience
- Easier to onboard new developers
- Sustainable long-term

---

**Next Steps:**
1. Review this analysis with team
2. Prioritize Phase 1 tasks
3. Assign owners
4. Create detailed tickets
5. Begin implementation


