# Palytt Convex - Real-Time Microservice

Real-time presence, typing indicators, and live notifications microservice for Palytt, powered by [Convex](https://docs.convex.dev/home).

## Features

- **Presence Tracking**: Real-time online/offline/away status for users
- **Typing Indicators**: Live "User is typing..." in chatrooms
- **Live Notifications**: Instant notification delivery to connected clients
- **Read Receipts**: Real-time "seen" indicators for messages
- **Friend Activity Feed**: Live activity updates from friends

## Architecture

```
┌──────────────────┐     ┌──────────────────┐
│    iOS App       │     │   tRPC Backend   │
│  (ConvexMobile)  │     │  (PostgreSQL)    │
└────────┬─────────┘     └────────┬─────────┘
         │                        │
         │  Real-time             │  Persistent
         │  subscriptions         │  data storage
         │                        │
         ▼                        ▼
┌─────────────────────────────────────────────┐
│           Convex Cloud                       │
│  (clear-goose-685.convex.cloud)             │
│                                              │
│  ┌──────────┐ ┌──────────┐ ┌──────────────┐ │
│  │ Presence │ │ Typing   │ │ Notifications│ │
│  └──────────┘ └──────────┘ └──────────────┘ │
│                                              │
│  ┌──────────────┐ ┌──────────────────────┐  │
│  │Read Receipts │ │ Friend Activity Feed │  │
│  └──────────────┘ └──────────────────────┘  │
└─────────────────────────────────────────────┘
```

## Setup

### Prerequisites

- Node.js 18+
- Convex account (https://dashboard.convex.dev)

### Installation

```bash
cd palytt-convex
npm install
```

### Development

```bash
# Start Convex dev server (requires authentication)
npm run dev

# Deploy to production
npm run deploy

# Run once (for CI/CD)
npm run dev:once
```

### Convex Dashboard

- **Dev**: https://dashboard.convex.dev/d/clear-goose-685
- **Prod**: https://dashboard.convex.dev/d/beloved-peacock-771

## Schema

### Tables

| Table | Description |
|-------|-------------|
| `presence` | User online/offline status with heartbeat timestamps |
| `typingIndicators` | Active typing indicators in chatrooms (auto-expire after 5s) |
| `liveNotifications` | Real-time notification delivery |
| `messageReadReceipts` | "Seen" status for chat messages |
| `friendActivity` | Activity feed entries (auto-expire after 24h) |

## Functions

### Presence (`convex/presence.ts`)

| Function | Type | Description |
|----------|------|-------------|
| `updatePresence` | mutation | Update user's presence status |
| `heartbeat` | mutation | Lightweight presence update (call every 30s) |
| `setOffline` | mutation | Mark user as offline |
| `getMyPresence` | query | Get current user's presence |
| `getUserPresence` | query | Get another user's presence |
| `getBatchPresence` | query | Get presence for multiple users |
| `getOnlineFriends` | query | Get all online friends |

### Typing Indicators (`convex/typing.ts`)

| Function | Type | Description |
|----------|------|-------------|
| `startTyping` | mutation | Start/update typing indicator |
| `stopTyping` | mutation | Stop typing indicator |
| `getTypingInChatroom` | query | Get who's typing in a chatroom |
| `getTypingCount` | query | Get count of users typing |

### Notifications (`convex/notifications.ts`)

| Function | Type | Description |
|----------|------|-------------|
| `pushNotification` | mutation | Send instant notification |
| `markAsRead` | mutation | Mark notification as read |
| `markAllAsRead` | mutation | Mark all notifications as read |
| `subscribeToNotifications` | query | Real-time notification subscription |
| `getUnreadCount` | query | Get unread notification count |

### Read Receipts (`convex/readReceipts.ts`)

| Function | Type | Description |
|----------|------|-------------|
| `markMessageRead` | mutation | Mark a message as read |
| `markChatroomRead` | mutation | Mark all messages in chatroom as read |
| `getMessageReadReceipts` | query | Get who has read a message |
| `hasUserReadMessage` | query | Check if specific user read message |

### Friend Activity (`convex/friendActivity.ts`)

| Function | Type | Description |
|----------|------|-------------|
| `recordActivity` | mutation | Record a friend activity |
| `getFriendActivityFeed` | query | Get activity feed for friends |
| `hasNewActivity` | query | Check for new activity since timestamp |

## iOS Integration

The iOS app uses `ConvexMobile` (Swift) to connect to Convex:

```swift
// In PresenceService.swift
import ConvexMobile

let client = ConvexClient(deploymentUrl: "https://clear-goose-685.convex.cloud")

// Subscribe to online friends
client.subscribe(to: "presence:getOnlineFriends", with: ["friendClerkIds": friendIds])

// Start heartbeat
client.mutation("presence:heartbeat", with: ["clerkId": userId])
```

## Environment URLs

| Environment | Convex URL |
|-------------|------------|
| Development | `https://clear-goose-685.convex.cloud` |
| Production | `https://beloved-peacock-771.convex.cloud` |

## Related

- [Convex Documentation](https://docs.convex.dev/home)
- [ConvexMobile (Swift)](https://docs.convex.dev/client/swift)
- [Palytt iOS App](../palytt/)
- [Palytt Backend](../palytt-backend/)

