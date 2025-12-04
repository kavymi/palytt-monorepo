//
//  TRPCProcedures.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  Type-safe tRPC procedure definitions matching backend endpoints.
//

import Foundation

// MARK: - Posts Router

enum PostsProcedures {
    
    // MARK: - getRecentPosts (Query, Public)
    struct GetRecentPosts: TRPCQuery {
        static let procedure = "posts.getRecentPosts"
        
        struct Input: Encodable {
            let limit: Int?
            let page: Int?
            
            init(limit: Int = 20, page: Int = 1) {
                self.limit = limit
                self.page = page
            }
        }
        
        struct Output: Decodable {
            let posts: [TRPCPost]
            let totalCount: Int
            let page: Int
            let totalPages: Int
        }
    }
    
    // MARK: - getFeedPosts (Query, Protected)
    struct GetFeedPosts: TRPCQuery {
        static let procedure = "posts.getFeedPosts"
        
        struct Input: Encodable {
            let limit: Int?
            let cursor: String?
            
            init(limit: Int = 20, cursor: String? = nil) {
                self.limit = limit
                self.cursor = cursor
            }
        }
        
        struct Output: Decodable {
            let posts: [TRPCPost]
            let nextCursor: String?
        }
    }
    
    // MARK: - getPostById (Query, Public)
    struct GetPostById: TRPCQuery {
        static let procedure = "posts.getPostById"
        
        struct Input: Encodable {
            let id: String
        }
        
        typealias Output = TRPCPost
    }
    
    // MARK: - getPostsByUserId (Query, Public)
    struct GetPostsByUserId: TRPCQuery {
        static let procedure = "posts.getPostsByUserId"
        
        struct Input: Encodable {
            let userId: String // clerkId
            let limit: Int?
            let cursor: String?
            
            init(userId: String, limit: Int = 20, cursor: String? = nil) {
                self.userId = userId
                self.limit = limit
                self.cursor = cursor
            }
        }
        
        struct Output: Decodable {
            let posts: [TRPCPost]
            let nextCursor: String?
        }
    }
    
    // MARK: - createPost (Mutation, Protected)
    struct CreatePost: TRPCMutation {
        static let procedure = "posts.createPost"
        
        struct Input: Encodable {
            let title: String?
            let caption: String?
            let mediaUrls: [String]?
            let rating: Double?
            let menuItems: [String]?
            let locationName: String?
            let locationAddress: String?
            let locationCity: String?
            let locationState: String?
            let locationCountry: String?
            let locationPostalCode: String?
            let locationLatitude: Double?
            let locationLongitude: Double?
            let isPublic: Bool?
        }
        
        typealias Output = TRPCPost
    }
    
    // MARK: - likePost (Mutation, Protected)
    struct LikePost: TRPCMutation {
        static let procedure = "posts.likePost"
        
        struct Input: Encodable {
            let postId: String
        }
        
        struct Output: Decodable {
            let liked: Bool
            let likesCount: Int
        }
    }
    
    // MARK: - savePost (Mutation, Protected)
    struct SavePost: TRPCMutation {
        static let procedure = "posts.savePost"
        
        struct Input: Encodable {
            let postId: String
        }
        
        struct Output: Decodable {
            let saved: Bool
            let savesCount: Int
        }
    }
    
    // MARK: - getSavedPosts (Query, Protected)
    struct GetSavedPosts: TRPCQuery {
        static let procedure = "posts.getSavedPosts"
        
        struct Input: Encodable {
            let limit: Int?
            let cursor: String?
            
            init(limit: Int = 20, cursor: String? = nil) {
                self.limit = limit
                self.cursor = cursor
            }
        }
        
        struct Output: Decodable {
            let posts: [TRPCPost]
            let nextCursor: String?
        }
    }
    
    // MARK: - searchPosts (Query, Public)
    struct SearchPosts: TRPCQuery {
        static let procedure = "posts.searchPosts"
        
        struct Input: Encodable {
            let query: String
            let limit: Int?
            let cursor: String?
            
            init(query: String, limit: Int = 20, cursor: String? = nil) {
                self.query = query
                self.limit = limit
                self.cursor = cursor
            }
        }
        
        struct Output: Decodable {
            let posts: [TRPCPost]
            let nextCursor: String?
        }
    }
}

// MARK: - Users Router

enum UsersProcedures {
    
    // MARK: - getAll (Query, Public)
    struct GetAll: TRPCQuery {
        static let procedure = "users.getAll"
        
        struct Input: Encodable {
            let limit: Int?
            let cursor: String?
            
            init(limit: Int = 20, cursor: String? = nil) {
                self.limit = limit
                self.cursor = cursor
            }
        }
        
        typealias Output = [TRPCUser]
    }
    
    // MARK: - getUserByClerkId (Query, Public)
    struct GetUserByClerkId: TRPCQuery {
        static let procedure = "users.getUserByClerkId"
        
        struct Input: Encodable {
            let clerkId: String
        }
        
        typealias Output = TRPCUser?
    }
    
    // MARK: - getByUsername (Query, Public)
    struct GetByUsername: TRPCQuery {
        static let procedure = "users.getByUsername"
        
        struct Input: Encodable {
            let username: String
        }
        
        typealias Output = TRPCUser?
    }
    
    // MARK: - searchUsers (Query, Public)
    struct SearchUsers: TRPCQuery {
        static let procedure = "users.searchUsers"
        
        struct Input: Encodable {
            let query: String
            let limit: Int?
            
            init(query: String, limit: Int = 20) {
                self.query = query
                self.limit = limit
            }
        }
        
        typealias Output = [TRPCUser]
    }
    
    // MARK: - createUser (Mutation, Public)
    struct CreateUser: TRPCMutation {
        static let procedure = "users.createUser"
        
        struct Input: Encodable {
            let clerkId: String
            let email: String?
            let username: String?
            let name: String?
            let profileImage: String?
        }
        
        typealias Output = TRPCUser
    }
    
    // MARK: - updateUser (Mutation, Public)
    struct UpdateUser: TRPCMutation {
        static let procedure = "users.updateUser"
        
        struct Input: Encodable {
            let clerkId: String
            let username: String?
            let name: String?
            let bio: String?
            let profileImage: String?
            let website: String?
        }
        
        typealias Output = TRPCUser
    }
}

// MARK: - Friends Router

enum FriendsProcedures {
    
    // MARK: - sendRequest (Mutation, Protected)
    struct SendRequest: TRPCMutation {
        static let procedure = "friends.sendRequest"
        
        struct Input: Encodable {
            let receiverId: String // clerkId of the receiver
        }
        
        typealias Output = TRPCFriend
    }
    
    // MARK: - acceptRequest (Mutation, Protected)
    struct AcceptRequest: TRPCMutation {
        static let procedure = "friends.acceptRequest"
        
        struct Input: Encodable {
            let requestId: String
        }
        
        typealias Output = TRPCFriend
    }
    
    // MARK: - rejectRequest (Mutation, Protected)
    struct RejectRequest: TRPCMutation {
        static let procedure = "friends.rejectRequest"
        
        struct Input: Encodable {
            let requestId: String
        }
        
        typealias Output = SuccessResponse
    }
    
    // MARK: - getFriends (Query, Public)
    struct GetFriends: TRPCQuery {
        static let procedure = "friends.getFriends"
        
        struct Input: Encodable {
            let userId: String? // clerkId, optional for current user
            let limit: Int?
            let cursor: String?
            
            init(userId: String? = nil, limit: Int = 50, cursor: String? = nil) {
                self.userId = userId
                self.limit = limit
                self.cursor = cursor
            }
        }
        
        struct Output: Decodable {
            let friends: [TRPCFriendUser]
            let nextCursor: String?
        }
    }
    
    // MARK: - getPendingRequests (Query, Protected)
    struct GetPendingRequests: TRPCQuery {
        static let procedure = "friends.getPendingRequests"
        
        struct Input: Encodable {
            let type: FriendRequestFilterType
            let limit: Int?
            let cursor: String?
            
            init(type: FriendRequestFilterType = .all, limit: Int = 20, cursor: String? = nil) {
                self.type = type
                self.limit = limit
                self.cursor = cursor
            }
        }
        
        struct Output: Decodable {
            let requests: [TRPCFriend]
            let nextCursor: String?
        }
    }
    
    // MARK: - areFriends (Query, Public)
    struct AreFriends: TRPCQuery {
        static let procedure = "friends.areFriends"
        
        struct Input: Encodable {
            let userId1: String // clerkId
            let userId2: String // clerkId
        }
        
        struct Output: Decodable {
            let areFriends: Bool
        }
    }
    
    // MARK: - removeFriend (Mutation, Protected)
    struct RemoveFriend: TRPCMutation {
        static let procedure = "friends.removeFriend"
        
        struct Input: Encodable {
            let friendId: String // clerkId of friend to remove
        }
        
        typealias Output = SuccessResponse
    }
    
    // MARK: - blockUser (Mutation, Protected)
    struct BlockUser: TRPCMutation {
        static let procedure = "friends.blockUser"
        
        struct Input: Encodable {
            let userId: String // clerkId to block
        }
        
        typealias Output = SuccessResponse
    }
    
    // MARK: - getMutualFriends (Query, Public)
    struct GetMutualFriends: TRPCQuery {
        static let procedure = "friends.getMutualFriends"
        
        struct Input: Encodable {
            let userId1: String // clerkId
            let userId2: String // clerkId
            let limit: Int?
            
            init(userId1: String, userId2: String, limit: Int = 10) {
                self.userId1 = userId1
                self.userId2 = userId2
                self.limit = limit
            }
        }
        
        struct Output: Decodable {
            let mutualFriends: [TRPCUserInfo]
            let totalCount: Int
        }
    }
    
    // MARK: - getFriendSuggestions (Query, Protected)
    struct GetFriendSuggestions: TRPCQuery {
        static let procedure = "friends.getFriendSuggestions"
        
        struct Input: Encodable {
            let limit: Int?
            let excludeRequested: Bool?
            
            init(limit: Int = 20, excludeRequested: Bool = true) {
                self.limit = limit
                self.excludeRequested = excludeRequested
            }
        }
        
        struct Output: Decodable {
            let suggestions: [TRPCFriendSuggestion]
        }
    }
}

// MARK: - Follows Router

enum FollowsProcedures {
    
    // MARK: - follow (Mutation, Protected)
    struct Follow: TRPCMutation {
        static let procedure = "follows.follow"
        
        struct Input: Encodable {
            let userId: String // clerkId of user to follow
        }
        
        typealias Output = TRPCFollow
    }
    
    // MARK: - unfollow (Mutation, Protected)
    struct Unfollow: TRPCMutation {
        static let procedure = "follows.unfollow"
        
        struct Input: Encodable {
            let userId: String // clerkId of user to unfollow
        }
        
        typealias Output = SuccessResponse
    }
    
    // MARK: - getFollowing (Query, Public)
    struct GetFollowing: TRPCQuery {
        static let procedure = "follows.getFollowing"
        
        struct Input: Encodable {
            let userId: String? // clerkId, optional for current user
            let limit: Int?
            let cursor: String?
            
            init(userId: String? = nil, limit: Int = 50, cursor: String? = nil) {
                self.userId = userId
                self.limit = limit
                self.cursor = cursor
            }
        }
        
        struct Output: Decodable {
            let following: [TRPCFollowUser]
            let nextCursor: String?
        }
    }
    
    // MARK: - getFollowers (Query, Public)
    struct GetFollowers: TRPCQuery {
        static let procedure = "follows.getFollowers"
        
        struct Input: Encodable {
            let userId: String? // clerkId, optional for current user
            let limit: Int?
            let cursor: String?
            
            init(userId: String? = nil, limit: Int = 50, cursor: String? = nil) {
                self.userId = userId
                self.limit = limit
                self.cursor = cursor
            }
        }
        
        struct Output: Decodable {
            let followers: [TRPCFollowUser]
            let nextCursor: String?
        }
    }
    
    // MARK: - isFollowing (Query, Public)
    struct IsFollowing: TRPCQuery {
        static let procedure = "follows.isFollowing"
        
        struct Input: Encodable {
            let followerId: String // clerkId
            let followingId: String // clerkId
        }
        
        struct Output: Decodable {
            let isFollowing: Bool
        }
    }
    
    // MARK: - getFollowStats (Query, Public)
    struct GetFollowStats: TRPCQuery {
        static let procedure = "follows.getFollowStats"
        
        struct Input: Encodable {
            let userId: String // clerkId
        }
        
        typealias Output = TRPCFollowStats
    }
    
    // MARK: - getMutualFollows (Query, Public)
    struct GetMutualFollows: TRPCQuery {
        static let procedure = "follows.getMutualFollows"
        
        struct Input: Encodable {
            let userId1: String // clerkId
            let userId2: String // clerkId
            let limit: Int?
            
            init(userId1: String, userId2: String, limit: Int = 20) {
                self.userId1 = userId1
                self.userId2 = userId2
                self.limit = limit
            }
        }
        
        struct Output: Decodable {
            let mutualFollows: [TRPCUserInfo]
            let count: Int
        }
    }
    
    // MARK: - getSuggestedFollows (Query, Protected)
    struct GetSuggestedFollows: TRPCQuery {
        static let procedure = "follows.getSuggestedFollows"
        
        struct Input: Encodable {
            let limit: Int?
            
            init(limit: Int = 10) {
                self.limit = limit
            }
        }
        
        struct Output: Decodable {
            let suggestions: [TRPCUserInfo]
        }
    }
}

// MARK: - Comments Router

enum CommentsProcedures {
    
    // MARK: - getComments (Query, Public)
    struct GetComments: TRPCQuery {
        static let procedure = "comments.getComments"
        
        struct Input: Encodable {
            let postId: String
            let limit: Int?
            let cursor: String?
            
            init(postId: String, limit: Int = 20, cursor: String? = nil) {
                self.postId = postId
                self.limit = limit
                self.cursor = cursor
            }
        }
        
        struct Output: Decodable {
            let comments: [TRPCComment]
            let nextCursor: String?
        }
    }
    
    // MARK: - addComment (Mutation, Protected)
    struct AddComment: TRPCMutation {
        static let procedure = "comments.addComment"
        
        struct Input: Encodable {
            let postId: String
            let content: String
        }
        
        typealias Output = TRPCComment
    }
    
    // MARK: - deleteComment (Mutation, Protected)
    struct DeleteComment: TRPCMutation {
        static let procedure = "comments.deleteComment"
        
        struct Input: Encodable {
            let commentId: String
        }
        
        typealias Output = SuccessResponse
    }
    
    // MARK: - getCommentsByUser (Query, Public)
    struct GetCommentsByUser: TRPCQuery {
        static let procedure = "comments.getCommentsByUser"
        
        struct Input: Encodable {
            let userId: String // clerkId
            let limit: Int?
            let cursor: String?
            
            init(userId: String, limit: Int = 20, cursor: String? = nil) {
                self.userId = userId
                self.limit = limit
                self.cursor = cursor
            }
        }
        
        struct Output: Decodable {
            let comments: [TRPCComment]
            let nextCursor: String?
        }
    }
}

// MARK: - Messages Router

enum MessagesProcedures {
    
    // MARK: - getChatrooms (Query, Protected)
    struct GetChatrooms: TRPCQuery {
        static let procedure = "messages.getChatrooms"
        
        struct Input: Encodable {
            let limit: Int?
            let cursor: String?
            
            init(limit: Int = 20, cursor: String? = nil) {
                self.limit = limit
                self.cursor = cursor
            }
        }
        
        struct Output: Decodable {
            let chatrooms: [TRPCChatroom]
            let nextCursor: String?
        }
    }
    
    // MARK: - createChatroom (Mutation, Protected)
    struct CreateChatroom: TRPCMutation {
        static let procedure = "messages.createChatroom"
        
        struct Input: Encodable {
            let participantId: String? // clerkId for direct
            let participantIds: [String]? // clerkIds for group
            let type: TRPCChatroomType
            let name: String?
            let description: String?
            let imageUrl: String?
            
            init(participantId: String) {
                self.participantId = participantId
                self.participantIds = nil
                self.type = .direct
                self.name = nil
                self.description = nil
                self.imageUrl = nil
            }
            
            init(participantIds: [String], name: String, description: String? = nil, imageUrl: String? = nil) {
                self.participantId = nil
                self.participantIds = participantIds
                self.type = .group
                self.name = name
                self.description = description
                self.imageUrl = imageUrl
            }
        }
        
        typealias Output = TRPCChatroom
    }
    
    // MARK: - sendMessage (Mutation, Protected)
    struct SendMessage: TRPCMutation {
        static let procedure = "messages.sendMessage"
        
        struct Input: Encodable {
            let chatroomId: String
            let content: String
            let messageType: TRPCMessageType
            let mediaUrl: String?
            let sharedContentId: String?
            let linkPreview: LinkPreviewInput?
            
            init(chatroomId: String, content: String, messageType: TRPCMessageType = .text) {
                self.chatroomId = chatroomId
                self.content = content
                self.messageType = messageType
                self.mediaUrl = nil
                self.sharedContentId = nil
                self.linkPreview = nil
            }
            
            init(chatroomId: String, content: String, mediaUrl: String, messageType: TRPCMessageType) {
                self.chatroomId = chatroomId
                self.content = content
                self.messageType = messageType
                self.mediaUrl = mediaUrl
                self.sharedContentId = nil
                self.linkPreview = nil
            }
            
            struct LinkPreviewInput: Encodable {
                let title: String
                let description: String?
                let imageUrl: String?
                let url: String
            }
        }
        
        typealias Output = TRPCMessage
    }
    
    // MARK: - getMessages (Query, Protected)
    struct GetMessages: TRPCQuery {
        static let procedure = "messages.getMessages"
        
        struct Input: Encodable {
            let chatroomId: String
            let limit: Int?
            let cursor: String?
            
            init(chatroomId: String, limit: Int = 50, cursor: String? = nil) {
                self.chatroomId = chatroomId
                self.limit = limit
                self.cursor = cursor
            }
        }
        
        struct Output: Decodable {
            let messages: [TRPCMessage]
            let nextCursor: String?
        }
    }
    
    // MARK: - markMessagesAsRead (Mutation, Protected)
    struct MarkMessagesAsRead: TRPCMutation {
        static let procedure = "messages.markMessagesAsRead"
        
        struct Input: Encodable {
            let chatroomId: String
            let messageIds: [String]?
            
            init(chatroomId: String, messageIds: [String]? = nil) {
                self.chatroomId = chatroomId
                self.messageIds = messageIds
            }
        }
        
        typealias Output = SuccessResponse
    }
    
    // MARK: - getUnreadCount (Query, Protected)
    struct GetUnreadCount: TRPCQuery {
        static let procedure = "messages.getUnreadCount"
        
        typealias Input = EmptyInput
        
        struct Output: Decodable {
            let unreadCount: Int
        }
    }
    
    // MARK: - leaveChatroom (Mutation, Protected)
    struct LeaveChatroom: TRPCMutation {
        static let procedure = "messages.leaveChatroom"
        
        struct Input: Encodable {
            let chatroomId: String
        }
        
        typealias Output = SuccessResponse
    }
    
    // MARK: - addParticipants (Mutation, Protected)
    struct AddParticipants: TRPCMutation {
        static let procedure = "messages.addParticipants"
        
        struct Input: Encodable {
            let chatroomId: String
            let userIds: [String] // clerkIds
        }
        
        struct Output: Decodable {
            let success: Bool
            let added: Int
        }
    }
    
    // MARK: - removeParticipant (Mutation, Protected)
    struct RemoveParticipant: TRPCMutation {
        static let procedure = "messages.removeParticipant"
        
        struct Input: Encodable {
            let chatroomId: String
            let userId: String // clerkId
        }
        
        typealias Output = SuccessResponse
    }
    
    // MARK: - makeAdmin (Mutation, Protected)
    struct MakeAdmin: TRPCMutation {
        static let procedure = "messages.makeAdmin"
        
        struct Input: Encodable {
            let chatroomId: String
            let userId: String // clerkId
        }
        
        typealias Output = SuccessResponse
    }
    
    // MARK: - updateGroupSettings (Mutation, Protected)
    struct UpdateGroupSettings: TRPCMutation {
        static let procedure = "messages.updateGroupSettings"
        
        struct Input: Encodable {
            let chatroomId: String
            let name: String?
            let description: String?
            let imageUrl: String?
        }
        
        typealias Output = TRPCChatroom
    }
    
    // MARK: - getSharedMedia (Query, Protected)
    struct GetSharedMedia: TRPCQuery {
        static let procedure = "messages.getSharedMedia"
        
        struct Input: Encodable {
            let chatroomId: String
            let messageType: TRPCMessageType?
            let limit: Int?
            let cursor: String?
            
            init(chatroomId: String, messageType: TRPCMessageType? = nil, limit: Int = 20, cursor: String? = nil) {
                self.chatroomId = chatroomId
                self.messageType = messageType
                self.limit = limit
                self.cursor = cursor
            }
        }
        
        struct Output: Decodable {
            let messages: [TRPCMessage]
            let nextCursor: String?
        }
    }
}

// MARK: - Notifications Router

enum NotificationsProcedures {
    
    // MARK: - getNotifications (Query, Protected)
    struct GetNotifications: TRPCQuery {
        static let procedure = "notifications.getNotifications"
        
        struct Input: Encodable {
            let limit: Int?
            let cursor: String?
            let type: NotificationType?
            let types: [NotificationType]?
            let unreadOnly: Bool?
            
            init(limit: Int = 20, cursor: String? = nil, type: NotificationType? = nil, types: [NotificationType]? = nil, unreadOnly: Bool = false) {
                self.limit = limit
                self.cursor = cursor
                self.type = type
                self.types = types
                self.unreadOnly = unreadOnly
            }
        }
        
        struct Output: Decodable {
            let notifications: [TRPCNotification]
            let nextCursor: String?
        }
    }
    
    // MARK: - markAsRead (Mutation, Protected)
    struct MarkAsRead: TRPCMutation {
        static let procedure = "notifications.markAsRead"
        
        struct Input: Encodable {
            let notificationIds: [String]?
            
            init(notificationIds: [String]? = nil) {
                self.notificationIds = notificationIds
            }
        }
        
        typealias Output = SuccessResponse
    }
    
    // MARK: - markAllAsRead (Mutation, Protected)
    struct MarkAllAsRead: TRPCMutation {
        static let procedure = "notifications.markAllAsRead"
        
        typealias Input = EmptyInput
        typealias Output = SuccessResponse
    }
    
    // MARK: - getUnreadCount (Query, Protected)
    struct GetUnreadCount: TRPCQuery {
        static let procedure = "notifications.getUnreadCount"
        
        typealias Input = EmptyInput
        
        struct Output: Decodable {
            let count: Int
        }
    }
    
    // MARK: - deleteNotifications (Mutation, Protected)
    struct DeleteNotifications: TRPCMutation {
        static let procedure = "notifications.deleteNotifications"
        
        struct Input: Encodable {
            let notificationIds: [String]
        }
        
        typealias Output = SuccessResponse
    }
    
    // MARK: - clearAll (Mutation, Protected)
    struct ClearAll: TRPCMutation {
        static let procedure = "notifications.clearAll"
        
        typealias Input = EmptyInput
        typealias Output = SuccessResponse
    }
    
    // MARK: - getSettings (Query, Protected)
    struct GetSettings: TRPCQuery {
        static let procedure = "notifications.getSettings"
        
        typealias Input = EmptyInput
        typealias Output = TRPCNotificationSettings
    }
    
    // MARK: - updateSettings (Mutation, Protected)
    struct UpdateSettings: TRPCMutation {
        static let procedure = "notifications.updateSettings"
        
        struct Input: Encodable {
            let emailNotifications: Bool?
            let pushNotifications: Bool?
            let likes: Bool?
            let comments: Bool?
            let follows: Bool?
            let friendRequests: Bool?
            let messages: Bool?
        }
        
        struct Output: Decodable {
            let success: Bool
            let settings: TRPCNotificationSettings
        }
    }
    
    // MARK: - getNotificationsByType (Query, Protected)
    struct GetNotificationsByType: TRPCQuery {
        static let procedure = "notifications.getNotificationsByType"
        
        struct Input: Encodable {
            let days: Int
            
            init(days: Int = 7) {
                self.days = days
            }
        }
        
        struct Output: Decodable {
            let grouped: [String: [TRPCNotification]]
        }
    }
}

// MARK: - Lists Router

enum ListsProcedures {
    
    // MARK: - getUserLists (Query, Public)
    struct GetUserLists: TRPCQuery {
        static let procedure = "lists.getUserLists"
        
        struct Input: Encodable {
            let userId: String // clerkId
        }
        
        struct Output: Decodable {
            let lists: [TRPCList]
        }
    }
    
    // MARK: - getListById (Query, Public)
    struct GetListById: TRPCQuery {
        static let procedure = "lists.getListById"
        
        struct Input: Encodable {
            let listId: String
        }
        
        typealias Output = TRPCList
    }
    
    // MARK: - createList (Mutation, Protected)
    struct CreateList: TRPCMutation {
        static let procedure = "lists.createList"
        
        struct Input: Encodable {
            let name: String
            let description: String?
            let isPublic: Bool?
            let coverImageUrl: String?
            
            init(name: String, description: String? = nil, isPublic: Bool = true, coverImageUrl: String? = nil) {
                self.name = name
                self.description = description
                self.isPublic = isPublic
                self.coverImageUrl = coverImageUrl
            }
        }
        
        typealias Output = TRPCList
    }
    
    // MARK: - updateList (Mutation, Protected)
    struct UpdateList: TRPCMutation {
        static let procedure = "lists.updateList"
        
        struct Input: Encodable {
            let listId: String
            let name: String?
            let description: String?
            let isPublic: Bool?
            let coverImageUrl: String?
        }
        
        typealias Output = TRPCList
    }
    
    // MARK: - deleteList (Mutation, Protected)
    struct DeleteList: TRPCMutation {
        static let procedure = "lists.deleteList"
        
        struct Input: Encodable {
            let listId: String
        }
        
        typealias Output = SuccessResponse
    }
    
    // MARK: - addToList (Mutation, Protected)
    struct AddToList: TRPCMutation {
        static let procedure = "lists.addToList"
        
        struct Input: Encodable {
            let listId: String
            let placeId: String
            let notes: String?
            
            init(listId: String, placeId: String, notes: String? = nil) {
                self.listId = listId
                self.placeId = placeId
                self.notes = notes
            }
        }
        
        typealias Output = TRPCListItem
    }
    
    // MARK: - removeFromList (Mutation, Protected)
    struct RemoveFromList: TRPCMutation {
        static let procedure = "lists.removeFromList"
        
        struct Input: Encodable {
            let listId: String
            let placeId: String
        }
        
        typealias Output = SuccessResponse
    }
}

// MARK: - Places Router

enum PlacesProcedures {
    
    // MARK: - searchPlaces (Query, Public)
    struct SearchPlaces: TRPCQuery {
        static let procedure = "places.searchPlaces"
        
        struct Input: Encodable {
            let query: String
            let limit: Int?
            
            init(query: String, limit: Int = 10) {
                self.query = query
                self.limit = limit
            }
        }
        
        typealias Output = [TRPCPlace]
    }
}

// MARK: - Helper Types

/// Empty input for procedures that don't require input
struct EmptyInput: Encodable {}

