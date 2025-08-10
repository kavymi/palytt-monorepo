# Palytt - SwiftUI Food Sharing App

A modern SwiftUI application for sharing food and drink experiences with integrated backend and real-time database support.

## ✅ Integration Status

### Completed Features
- **Frontend-to-Backend Integration**: Full tRPC connection established
- **Post Creation**: End-to-end post creation with BunnyCDN integration
- **Convex Database**: Structured schema with posts, users, likes, comments
- **Location Support**: Location picker and address handling
- **Image Upload**: BunnyCDN integration for photo uploads
- **User Authentication**: Clerk integration for user management

### Backend Architecture
- **tRPC**: Type-safe API communication
- **Convex**: Real-time database with reactive queries
- **BunnyCDN**: Cloud image storage and optimization
- **Clerk**: User authentication and management

## 🚀 Quick Start

### Prerequisites
- Xcode 15+
- Node.js 18+
- pnpm
- iOS Simulator

### Backend Setup
```bash
cd palytt-backend
source ~/.zshrc
pnpm install
pnpm run dev
```

Expected output:
```
🚀 Server ready at: http://localhost:4000
⚡ tRPC endpoint: http://localhost:4000/trpc
🌐 tRPC panel: http://localhost:4000/trpc/panel
💓 Health check: http://localhost:4000/health
```

### iOS App Setup
```bash
# Build for iPhone 16 Pro Simulator
xcodebuild -scheme Palytt -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.3.1' clean build

# Run the app in Xcode or iOS Simulator
```

## 📱 Core Features

### Post Creation Flow
1. **Media Selection**: Camera or photo library integration
2. **Content Input**: Caption, rating, product name
3. **Location**: Address picker with coordinates
4. **Image Upload**: Automatic BunnyCDN cloud upload
5. **Database Storage**: Real-time Convex integration

### Data Models
- **Posts**: Content, images, location, ratings, engagement metrics
- **Users**: Profiles, preferences, authentication
- **Comments**: Nested comments with likes (ready for deployment)
- **Likes/Bookmarks**: Engagement tracking
- **Locations**: Address and coordinate data

## 🛠 Technical Implementation

### Frontend (SwiftUI)
- **MVVM Architecture**: Clean separation of concerns
- **Reactive UI**: Combine framework integration
- **Modern Design**: iOS 18 compatible interface
- **Type Safety**: Comprehensive Swift type system

### Backend (Node.js/TypeScript)
- **tRPC Router**: Type-safe API endpoints
- **Convex Integration**: Real-time database operations
- **Authentication**: Clerk user management
- **File Upload**: BunnyCDN cloud storage

### Database Schema (Convex)
```typescript
// Core tables implemented:
- posts: Content, metadata, engagement
- users: Profiles and authentication
- likes: Post engagement tracking
- comments: Threaded discussions (ready)
- bookmarks: Saved content (ready)
```

## 🔄 API Endpoints

### Posts
- `GET /trpc/convex.posts.getAll` - Fetch all posts
- `POST /trpc/convex.posts.create` - Create new post
- `POST /trpc/convex.posts.toggleLike` - Like/unlike posts

### Users
- `GET /trpc/users.getByClerkId` - Fetch user profile
- `POST /trpc/users.upsert` - Create/update user

### Health
- `GET /health` - Service health check

## 📝 Development Workflow

### Adding New Features
1. Define Convex schema in `convex/schema.ts`
2. Implement backend functions in `convex/*.ts`
3. Add tRPC endpoints in `src/routers/convex.ts`
4. Update Swift models in `Sources/PalyttApp/Models/`
5. Implement UI in SwiftUI views

### Testing Integration
1. Start backend server
2. Build iOS app
3. Test post creation flow
4. Verify data in Convex dashboard

## 🎯 Next Steps

### Immediate Priorities
1. **Deploy Convex Schema**: Enable comments and bookmarks
2. **Location Geocoding**: Real coordinate resolution
3. **Enhanced Authentication**: Profile completion flow
4. **Real-time Updates**: Live feed synchronization

### Future Enhancements
- Push notifications
- Social features (following, feed algorithm)
- Advanced search and filtering
- Content moderation
- Analytics dashboard

## 🏗 Project Structure

```
palytt-swiftui/
├── Sources/PalyttApp/
│   ├── Models/          # Data models
│   ├── Views/           # SwiftUI views
│   ├── ViewModels/      # Business logic
│   └── Utilities/       # Services & helpers
└── palytt-backend/
    ├── convex/          # Database schema & functions
    ├── src/routers/     # tRPC API routes
    └── src/             # Backend services
```

## 📊 Integration Health

- ✅ Frontend builds successfully
- ✅ Backend server starts without errors
- ✅ tRPC communication established
- ✅ Convex database schema deployed
- ✅ Image upload pipeline functional
- ✅ Post creation end-to-end working
- 🟡 Comments (ready for deployment)
- 🟡 Enhanced likes/bookmarks (ready for deployment)

---

For development questions or deployment assistance, refer to the integration test plan in `test-integration.md`. 