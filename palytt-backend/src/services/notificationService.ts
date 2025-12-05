//
//  notificationService.ts
//  Palytt Backend
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import { prisma } from '../db.js';
import { syncNotificationToConvex, recordFriendActivity, type ConvexNotificationType } from './convexSync.js';
import type pkg from '@prisma/client';
type NotificationType = pkg.NotificationType;

export interface NotificationData {
  postId?: string;
  commentId?: string;
  friendRequestId?: string;
  senderId?: string;
  senderName?: string;
  [key: string]: any;
}

/**
 * Creates a notification for a user
 * Also syncs to Convex for real-time delivery
 */
export async function createNotification(
  userClerkId: string,
  type: NotificationType,
  title: string,
  message: string,
  data: NotificationData = {}
): Promise<void> {
  try {
    // Don't send notifications to yourself
    if (data.senderId && data.senderId === userClerkId) {
      return;
    }

    // Check if user exists and get their database ID
    const user = await prisma.user.findUnique({
      where: { clerkId: userClerkId },
      select: { id: true }
    });

    if (!user) {
      console.warn(`User not found for notification: ${userClerkId}`);
      return;
    }

    // Create notification in PostgreSQL
    const notification = await prisma.notification.create({
      data: {
        userId: user.id,
        type,
        title,
        message,
        data: data || {},
      },
    });

    console.log(`✅ Notification created for user ${userClerkId}: ${type} - ${title}`);

    // Also push to Convex for real-time delivery
    // This runs async and doesn't block the main operation
    syncNotificationToConvex(
      notification.id,
      userClerkId,
      type as ConvexNotificationType,
      title,
      message,
      data.senderId,
      data.senderName,
      {
        postId: data.postId,
        commentId: data.commentId,
        friendRequestId: data.friendRequestId,
        userId: data.senderId,
      }
    ).catch((err) => {
      console.warn('⚠️ Failed to sync notification to Convex (non-blocking):', err);
    });
  } catch (error) {
    console.error('❌ Failed to create notification:', error);
    // Don't throw error to avoid breaking the main operation
  }
}

/**
 * Creates a notification when someone likes a post
 * Also records activity for real-time friend feed
 */
export async function createPostLikeNotification(
  postId: string,
  likerUserId: string
): Promise<void> {
  try {
    // Get post details and author
    const post = await prisma.post.findUnique({
      where: { id: postId },
      select: {
        title: true,
        caption: true,
        author: {
          select: {
            clerkId: true,
            name: true,
            username: true
          }
        }
      }
    });

    if (!post || !post.author) {
      return;
    }

    // Get liker details
    const liker = await prisma.user.findUnique({
      where: { clerkId: likerUserId },
      select: {
        name: true,
        username: true
      }
    });

    if (!liker) {
      return;
    }

    const likerName = liker.name || liker.username || 'Someone';
    const postTitle = post.title || 'your post';

    await createNotification(
      post.author.clerkId,
      'POST_LIKE',
      `${likerName} liked your post`,
      `${likerName} liked "${postTitle}"`,
      {
        postId,
        senderId: likerUserId,
        senderName: likerName,
        likerName,
        postTitle
      }
    );

    // Record activity for friend feed (non-blocking)
    recordFriendActivity(
      likerUserId,
      likerName,
      'liked_post',
      postId,
      'post',
      postTitle.substring(0, 50)
    ).catch((err) => {
      console.warn('⚠️ Failed to record like activity to Convex:', err);
    });
  } catch (error) {
    console.error('❌ Failed to create post like notification:', error);
  }
}

/**
 * Creates a notification when someone comments on a post
 * Also records activity for real-time friend feed
 */
export async function createPostCommentNotification(
  postId: string,
  commenterId: string,
  commentContent: string
): Promise<void> {
  try {
    // Get post details and author
    const post = await prisma.post.findUnique({
      where: { id: postId },
      select: {
        title: true,
        caption: true,
        author: {
          select: {
            clerkId: true,
            name: true,
            username: true
          }
        }
      }
    });

    if (!post || !post.author) {
      return;
    }

    // Get commenter details
    const commenter = await prisma.user.findUnique({
      where: { clerkId: commenterId },
      select: {
        name: true,
        username: true
      }
    });

    if (!commenter) {
      return;
    }

    const commenterName = commenter.name || commenter.username || 'Someone';
    const postTitle = post.title || 'your post';
    const truncatedComment = commentContent.length > 50 
      ? commentContent.substring(0, 50) + '...' 
      : commentContent;

    await createNotification(
      post.author.clerkId,
      'COMMENT',
      `${commenterName} commented on your post`,
      `${commenterName} commented: "${truncatedComment}"`,
      {
        postId,
        senderId: commenterId,
        senderName: commenterName,
        commenterName,
        postTitle,
        commentContent: truncatedComment
      }
    );

    // Record activity for friend feed (non-blocking)
    recordFriendActivity(
      commenterId,
      commenterName,
      'commented',
      postId,
      'post',
      truncatedComment
    ).catch((err) => {
      console.warn('⚠️ Failed to record comment activity to Convex:', err);
    });
  } catch (error) {
    console.error('❌ Failed to create post comment notification:', error);
  }
}

/**
 * Creates a notification when someone sends a friend request
 */
export async function createFriendRequestNotification(
  receiverId: string,
  senderId: string,
  friendRequestId: string
): Promise<void> {
  try {
    // Get sender details
    const sender = await prisma.user.findUnique({
      where: { clerkId: senderId },
      select: {
        name: true,
        username: true
      }
    });

    if (!sender) {
      return;
    }

    const senderName = sender.name || sender.username || 'Someone';

    await createNotification(
      receiverId,
      'FRIEND_REQUEST',
      'New friend request',
      `${senderName} sent you a friend request`,
      {
        friendRequestId,
        senderId,
        senderName
      }
    );
  } catch (error) {
    console.error('❌ Failed to create friend request notification:', error);
  }
}

/**
 * Creates a notification when someone accepts a friend request
 */
export async function createFriendRequestAcceptedNotification(
  senderId: string,
  accepterId: string
): Promise<void> {
  try {
    // Get accepter details
    const accepter = await prisma.user.findUnique({
      where: { clerkId: accepterId },
      select: {
        name: true,
        username: true
      }
    });

    if (!accepter) {
      return;
    }

    const accepterName = accepter.name || accepter.username || 'Someone';

    await createNotification(
      senderId,
      'FRIEND_ACCEPTED',
      'Friend request accepted',
      `${accepterName} accepted your friend request`,
      {
        senderId: accepterId,
        accepterName
      }
    );
  } catch (error) {
    console.error('❌ Failed to create friend request accepted notification:', error);
  }
}
