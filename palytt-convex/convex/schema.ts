import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

/**
 * Convex Schema for Palytt Real-Time Features
 * 
 * This schema defines the data structures for:
 * - User presence tracking (online/offline/away status)
 * - Typing indicators in chatrooms
 * - Live notifications delivery
 * - Real-time read receipts
 */
export default defineSchema({
  // ============================================
  // PRESENCE TRACKING
  // ============================================
  
  /**
   * Tracks user online/offline status and activity
   * - Heartbeat every 30 seconds updates lastSeen
   * - Status changes trigger real-time updates to friends
   */
  presence: defineTable({
    // User identification (matches Clerk user ID)
    clerkId: v.string(),
    
    // Current presence status
    status: v.union(
      v.literal("online"),
      v.literal("away"),
      v.literal("offline")
    ),
    
    // Last activity timestamp (Unix ms)
    lastSeen: v.number(),
    
    // Optional: Current location in app (e.g., "home", "messages", "profile")
    currentScreen: v.optional(v.string()),
    
    // Device information for multi-device support
    deviceId: v.optional(v.string()),
    deviceType: v.optional(v.union(
      v.literal("ios"),
      v.literal("android"),
      v.literal("web")
    )),
  })
    .index("by_clerk_id", ["clerkId"])
    .index("by_status", ["status"])
    .index("by_last_seen", ["lastSeen"]),

  // ============================================
  // TYPING INDICATORS
  // ============================================
  
  /**
   * Tracks who is currently typing in which chatroom
   * - Entries are automatically cleaned up after 5 seconds of no updates
   * - Real-time subscriptions notify all chatroom participants
   */
  typingIndicators: defineTable({
    // User who is typing (Clerk ID)
    clerkId: v.string(),
    
    // Chatroom where typing is happening (UUID from PostgreSQL)
    chatroomId: v.string(),
    
    // User display info for UI (cached to avoid extra lookups)
    userName: v.optional(v.string()),
    userProfileImage: v.optional(v.string()),
    
    // Timestamp when typing started/last updated
    startedAt: v.number(),
    
    // Auto-expire after this timestamp (startedAt + 5000ms)
    expiresAt: v.number(),
  })
    .index("by_chatroom", ["chatroomId"])
    .index("by_clerk_id", ["clerkId"])
    .index("by_chatroom_and_clerk", ["chatroomId", "clerkId"])
    .index("by_expires_at", ["expiresAt"]),

  // ============================================
  // LIVE NOTIFICATIONS
  // ============================================
  
  /**
   * Real-time notification delivery
   * - Instant push to connected clients
   * - Syncs with PostgreSQL notifications for persistence
   */
  liveNotifications: defineTable({
    // Recipient (Clerk ID)
    recipientClerkId: v.string(),
    
    // Sender info (optional - some notifications are system-generated)
    senderClerkId: v.optional(v.string()),
    senderName: v.optional(v.string()),
    senderProfileImage: v.optional(v.string()),
    
    // Notification type (matches backend NotificationType enum)
    type: v.union(
      v.literal("POST_LIKE"),
      v.literal("COMMENT"),
      v.literal("COMMENT_LIKE"),
      v.literal("FOLLOW"),
      v.literal("FRIEND_REQUEST"),
      v.literal("FRIEND_ACCEPTED"),
      v.literal("FRIEND_POST"),
      v.literal("MESSAGE"),
      v.literal("POST_MENTION"),
      v.literal("GENERAL")
    ),
    
    // Display content
    title: v.string(),
    message: v.string(),
    
    // Optional metadata for deep linking
    metadata: v.optional(v.object({
      postId: v.optional(v.string()),
      commentId: v.optional(v.string()),
      chatroomId: v.optional(v.string()),
      friendRequestId: v.optional(v.string()),
      userId: v.optional(v.string()),
    })),
    
    // Read status
    isRead: v.boolean(),
    
    // PostgreSQL notification ID for sync (optional)
    postgresId: v.optional(v.string()),
    
    // Timestamps
    createdAt: v.number(),
  })
    .index("by_recipient", ["recipientClerkId"])
    .index("by_recipient_unread", ["recipientClerkId", "isRead"])
    .index("by_type", ["type"])
    .index("by_created_at", ["createdAt"])
    .index("by_postgres_id", ["postgresId"]),

  // ============================================
  // MESSAGE READ RECEIPTS
  // ============================================
  
  /**
   * Real-time read receipts for messages
   * - Tracks when messages are read
   * - Enables "seen" indicators in chat
   */
  messageReadReceipts: defineTable({
    // PostgreSQL message ID
    messageId: v.string(),
    
    // Chatroom ID for efficient queries
    chatroomId: v.string(),
    
    // Reader (Clerk ID)
    readerClerkId: v.string(),
    
    // When the message was read
    readAt: v.number(),
  })
    .index("by_message", ["messageId"])
    .index("by_chatroom", ["chatroomId"])
    .index("by_reader", ["readerClerkId"])
    .index("by_chatroom_and_reader", ["chatroomId", "readerClerkId"]),

  // ============================================
  // GATHERING VOTES (Real-time voting)
  // ============================================
  
  /**
   * Real-time voting for group gatherings
   * - Instant vote updates for venues, dates, and times
   * - All participants see changes immediately
   */
  gatheringVotes: defineTable({
    // PostgreSQL gathering ID
    gatheringId: v.string(),
    
    // Voter (Clerk ID)
    clerkId: v.string(),
    
    // Voter display name (cached for UI)
    voterName: v.optional(v.string()),
    
    // Vote type
    voteType: v.union(
      v.literal("venue"),
      v.literal("date"),
      v.literal("time")
    ),
    
    // The option being voted for
    optionId: v.string(),
    
    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_gathering", ["gatheringId"])
    .index("by_voter", ["clerkId"])
    .index("by_gathering_voter_type", ["gatheringId", "clerkId", "voteType"])
    .index("by_gathering_option", ["gatheringId", "optionId"]),

  // ============================================
  // FRIEND ACTIVITY FEED
  // ============================================
  
  /**
   * Real-time activity feed for friends
   * - Shows when friends post, like, or comment
   * - Enables "X is viewing Y" features
   */
  friendActivity: defineTable({
    // User who performed the action (Clerk ID)
    actorClerkId: v.string(),
    actorName: v.optional(v.string()),
    actorProfileImage: v.optional(v.string()),
    
    // Activity type
    activityType: v.union(
      v.literal("posted"),
      v.literal("liked_post"),
      v.literal("commented"),
      v.literal("followed"),
      v.literal("joined_gathering"),
      v.literal("shared_place")
    ),
    
    // Target of the activity (optional)
    targetId: v.optional(v.string()),
    targetType: v.optional(v.union(
      v.literal("post"),
      v.literal("comment"),
      v.literal("user"),
      v.literal("gathering"),
      v.literal("place")
    )),
    targetPreview: v.optional(v.string()), // Brief preview text/image URL
    
    // Timestamp
    createdAt: v.number(),
    
    // Auto-expire old activity (24 hours)
    expiresAt: v.number(),
  })
    .index("by_actor", ["actorClerkId"])
    .index("by_created_at", ["createdAt"])
    .index("by_expires_at", ["expiresAt"])
    .index("by_activity_type", ["activityType"]),
});

