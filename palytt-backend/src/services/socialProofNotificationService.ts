//
//  socialProofNotificationService.ts
//  Palytt Backend
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import { prisma } from '../db.js';
import { createNotification } from './notificationService.js';

// Thresholds for social proof notifications
const ENGAGEMENT_THRESHOLDS = {
  FIRST_LIKE: 1,          // Notify on first like
  LIKES_MILESTONE_5: 5,    // "5 people liked your post"
  LIKES_MILESTONE_10: 10,  // "10 people liked your post"
  LIKES_MILESTONE_25: 25,  // "25 people liked your post"
  LIKES_MILESTONE_50: 50,  // Going viral
  LIKES_MILESTONE_100: 100, // Truly viral
};

// Time window for "in the last hour" notifications (in minutes)
const ENGAGEMENT_WINDOW_MINUTES = 60;

// Minimum time between social proof notifications for the same post (in minutes)
// Will be used when notification throttling is implemented
// const MIN_NOTIFICATION_INTERVAL_MINUTES = 30;

interface PostEngagementStats {
  totalLikes: number;
  recentLikes: number;
  totalComments: number;
  recentComments: number;
  uniqueEngagers: number;
}

/**
 * Get engagement stats for a post
 * Exported for use in engagement analytics
 */
export async function getPostEngagementStats(postId: string): Promise<PostEngagementStats | null> {
  const cutoffTime = new Date();
  cutoffTime.setMinutes(cutoffTime.getMinutes() - ENGAGEMENT_WINDOW_MINUTES);

  try {
    const [totalLikes, recentLikes, totalComments, recentComments] = await Promise.all([
      prisma.like.count({ where: { postId } }),
      prisma.like.count({ where: { postId, createdAt: { gte: cutoffTime } } }),
      prisma.comment.count({ where: { postId } }),
      prisma.comment.count({ where: { postId, createdAt: { gte: cutoffTime } } }),
    ]);

    // Get unique engagers (likes + comments)
    const [likers, commenters] = await Promise.all([
      prisma.like.findMany({
        where: { postId },
        select: { userId: true },
        distinct: ['userId'],
      }),
      prisma.comment.findMany({
        where: { postId },
        select: { authorId: true },
        distinct: ['authorId'],
      }),
    ]);

    const uniqueEngagerIds = new Set([
      ...likers.map(l => l.userId),
      ...commenters.map(c => c.authorId),
    ]);

    return {
      totalLikes,
      recentLikes,
      totalComments,
      recentComments,
      uniqueEngagers: uniqueEngagerIds.size,
    };
  } catch (error) {
    console.error('❌ Failed to get post engagement stats:', error);
    return null;
  }
}

/**
 * Get the name(s) of recent engagers for personalization
 */
async function getRecentEngagerNames(postId: string, limit: number = 3): Promise<string[]> {
  const cutoffTime = new Date();
  cutoffTime.setMinutes(cutoffTime.getMinutes() - ENGAGEMENT_WINDOW_MINUTES);

  const recentLikes = await prisma.like.findMany({
    where: { postId, createdAt: { gte: cutoffTime } },
    orderBy: { createdAt: 'desc' },
    take: limit,
    select: {
      user: {
        select: { name: true, username: true },
      },
    },
  });

  return recentLikes
    .map(like => like.user.name || like.user.username || 'Someone')
    .filter(Boolean) as string[];
}

/**
 * Format names for notification message
 * e.g., "Sarah", "Sarah and 2 others", "Sarah, John, and 3 others"
 */
function formatEngagerNames(names: string[], totalCount: number): string {
  if (names.length === 0) return 'Someone';
  if (names.length === 1 && totalCount === 1) return names[0];
  if (names.length === 1 && totalCount > 1) return `${names[0]} and ${totalCount - 1} others`;
  if (names.length === 2 && totalCount === 2) return `${names[0]} and ${names[1]}`;
  if (names.length >= 2 && totalCount > 2) {
    return `${names[0]}, ${names[1]}, and ${totalCount - 2} others`;
  }
  return names.join(' and ');
}

/**
 * Check if a social proof notification should be sent for a post
 * and send it if appropriate
 */
export async function checkAndSendSocialProofNotification(
  postId: string,
  newLikeCount: number
): Promise<boolean> {
  // Get post and author info
  const post = await prisma.post.findUnique({
    where: { id: postId },
    select: {
      title: true,
      caption: true,
      author: {
        select: { clerkId: true },
      },
    },
  });

  if (!post || !post.author) return false;

  // Determine if we should send a notification based on milestone
  let shouldNotify = false;
  let notificationTitle = '';
  let notificationMessage = '';

  const postTitle = post.title || post.caption?.substring(0, 30) || 'your post';

  // Check which milestone we've hit
  if (newLikeCount === ENGAGEMENT_THRESHOLDS.FIRST_LIKE) {
    shouldNotify = true;
    const names = await getRecentEngagerNames(postId, 1);
    notificationTitle = "Your post is getting attention!";
    notificationMessage = `${names[0] || 'Someone'} liked "${postTitle}"`;
  } else if (newLikeCount === ENGAGEMENT_THRESHOLDS.LIKES_MILESTONE_5) {
    shouldNotify = true;
    notificationTitle = "5 likes and counting!";
    notificationMessage = `Your post "${postTitle}" is gaining traction!`;
  } else if (newLikeCount === ENGAGEMENT_THRESHOLDS.LIKES_MILESTONE_10) {
    shouldNotify = true;
    notificationTitle = "10 people liked your post!";
    notificationMessage = `"${postTitle}" is getting popular!`;
  } else if (newLikeCount === ENGAGEMENT_THRESHOLDS.LIKES_MILESTONE_25) {
    shouldNotify = true;
    notificationTitle = "🔥 25 likes!";
    notificationMessage = `Your post "${postTitle}" is on fire!`;
  } else if (newLikeCount === ENGAGEMENT_THRESHOLDS.LIKES_MILESTONE_50) {
    shouldNotify = true;
    notificationTitle = "🚀 50 likes - Going viral!";
    notificationMessage = `"${postTitle}" is blowing up! Keep creating great content!`;
  } else if (newLikeCount === ENGAGEMENT_THRESHOLDS.LIKES_MILESTONE_100) {
    shouldNotify = true;
    notificationTitle = "🎉 100 likes!";
    notificationMessage = `Your post "${postTitle}" hit 100 likes! You're a star!`;
  }

  if (shouldNotify) {
    await createNotification(
      post.author.clerkId,
      'POST_LIKE',
      notificationTitle,
      notificationMessage,
      {
        postId,
        socialProof: true,
        likesCount: newLikeCount,
        milestone: newLikeCount,
      }
    );
    console.log(`✅ Sent social proof notification for post ${postId} (${newLikeCount} likes)`);
    return true;
  }

  return false;
}

/**
 * Send a batched "X people liked your post" notification
 * This is for when multiple likes come in quickly
 */
export async function sendBatchedLikesNotification(
  postId: string,
  authorClerkId: string,
  likeCount: number
): Promise<void> {
  const names = await getRecentEngagerNames(postId, 3);
  const formattedNames = formatEngagerNames(names, likeCount);

  const post = await prisma.post.findUnique({
    where: { id: postId },
    select: { title: true, caption: true },
  });

  const postTitle = post?.title || post?.caption?.substring(0, 30) || 'your post';

  await createNotification(
    authorClerkId,
    'POST_LIKE',
    `${formattedNames} liked your post`,
    `"${postTitle}" received ${likeCount} new likes`,
    {
      postId,
      batchedLikes: true,
      likesCount: likeCount,
    }
  );

  console.log(`✅ Sent batched likes notification for post ${postId} (${likeCount} likes from ${formattedNames})`);
}

/**
 * Send a "friends are active" notification when multiple friends are online
 */
export async function sendFriendsActiveNotification(
  userClerkId: string,
  activeFriendsCount: number,
  topFriendName: string | null
): Promise<void> {
  if (activeFriendsCount < 3) return; // Only notify if significant activity

  const title = topFriendName
    ? `${topFriendName} and ${activeFriendsCount - 1} others are active`
    : `${activeFriendsCount} friends are active now`;
  
  const message = "Join the conversation and share what you're up to!";

  await createNotification(
    userClerkId,
    'GENERAL',
    title,
    message,
    {
      friendsActive: true,
      activeFriendsCount,
    }
  );

  console.log(`✅ Sent friends active notification to ${userClerkId} (${activeFriendsCount} friends active)`);
}

/**
 * Get engagement summary for a user's posts
 * Useful for weekly recap notifications
 */
export async function getWeeklyEngagementSummary(userClerkId: string): Promise<{
  totalLikes: number;
  totalComments: number;
  topPost: { id: string; title: string; likes: number } | null;
  newFollowers: number;
} | null> {
  const user = await prisma.user.findUnique({
    where: { clerkId: userClerkId },
    select: { id: true },
  });

  if (!user) return null;

  const weekAgo = new Date();
  weekAgo.setDate(weekAgo.getDate() - 7);

  try {
    // Get all likes on user's posts this week
    const likesThisWeek = await prisma.like.count({
      where: {
        post: { userId: user.id },
        createdAt: { gte: weekAgo },
      },
    });

    // Get all comments on user's posts this week
    const commentsThisWeek = await prisma.comment.count({
      where: {
        post: { userId: user.id },
        createdAt: { gte: weekAgo },
      },
    });

    // Get top post of the week
    const topPost = await prisma.post.findFirst({
      where: {
        userId: user.id,
        createdAt: { gte: weekAgo },
      },
      orderBy: { likesCount: 'desc' },
      select: {
        id: true,
        title: true,
        caption: true,
        likesCount: true,
      },
    });

    // Get new followers this week
    const newFollowers = await prisma.follow.count({
      where: {
        followingId: user.id,
        createdAt: { gte: weekAgo },
      },
    });

    return {
      totalLikes: likesThisWeek,
      totalComments: commentsThisWeek,
      topPost: topPost ? {
        id: topPost.id,
        title: topPost.title || topPost.caption?.substring(0, 30) || 'Untitled',
        likes: topPost.likesCount,
      } : null,
      newFollowers,
    };
  } catch (error) {
    console.error('❌ Failed to get weekly engagement summary:', error);
    return null;
  }
}

/**
 * Send weekly recap notification
 */
export async function sendWeeklyRecapNotification(userClerkId: string): Promise<void> {
  const summary = await getWeeklyEngagementSummary(userClerkId);
  
  if (!summary) return;

  // Only send if there was meaningful engagement
  if (summary.totalLikes === 0 && summary.totalComments === 0 && summary.newFollowers === 0) {
    return;
  }

  let title = "📊 Your Weekly Recap";
  let message = "";

  if (summary.topPost && summary.topPost.likes > 0) {
    message = `Your top post got ${summary.topPost.likes} likes! `;
  }

  if (summary.newFollowers > 0) {
    message += `You gained ${summary.newFollowers} new followers. `;
  }

  if (summary.totalLikes > 0 || summary.totalComments > 0) {
    message += `Total: ${summary.totalLikes} likes and ${summary.totalComments} comments this week.`;
  }

  if (message.trim()) {
    await createNotification(
      userClerkId,
      'GENERAL',
      title,
      message.trim(),
      {
        weeklyRecap: true,
        ...summary,
      }
    );
    console.log(`✅ Sent weekly recap notification to ${userClerkId}`);
  }
}

