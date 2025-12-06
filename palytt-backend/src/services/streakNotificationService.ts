//
//  streakNotificationService.ts
//  Palytt Backend
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import { prisma } from '../db.js';
import { createNotification } from './notificationService.js';

// Streak milestone thresholds
const STREAK_MILESTONES = [3, 7, 14, 30, 60, 100, 365];

// Streak reminder timing (hours before midnight to remind users to post)
const STREAK_REMINDER_HOURS = 4; // 8 PM local time reminder

interface StreakStatus {
  currentStreak: number;
  longestStreak: number;
  lastPostDate: Date | null;
  isAtRisk: boolean;
  hoursUntilStreakLoss: number;
}

/**
 * Get user's current streak status
 */
export async function getStreakStatus(clerkId: string): Promise<StreakStatus | null> {
  const user = await prisma.user.findUnique({
    where: { clerkId },
    select: {
      currentStreak: true,
      longestStreak: true,
      lastPostDate: true,
    },
  });

  if (!user) return null;

  const now = new Date();
  const lastPost = user.lastPostDate;
  
  // Calculate hours until streak loss (midnight tonight + 24 hours)
  let hoursUntilStreakLoss = 0;
  let isAtRisk = false;

  if (lastPost) {
    const lastPostDate = new Date(lastPost);
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const lastPostDay = new Date(lastPostDate.getFullYear(), lastPostDate.getMonth(), lastPostDate.getDate());
    
    // If last post was yesterday, user needs to post today to maintain streak
    const daysSinceLastPost = Math.floor((today.getTime() - lastPostDay.getTime()) / (1000 * 60 * 60 * 24));
    
    if (daysSinceLastPost === 1) {
      // User needs to post today - calculate hours until midnight
      const midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
      hoursUntilStreakLoss = (midnight.getTime() - now.getTime()) / (1000 * 60 * 60);
      isAtRisk = hoursUntilStreakLoss <= STREAK_REMINDER_HOURS;
    } else if (daysSinceLastPost > 1) {
      // Streak already lost
      hoursUntilStreakLoss = 0;
      isAtRisk = false;
    }
  }

  return {
    currentStreak: user.currentStreak,
    longestStreak: user.longestStreak,
    lastPostDate: user.lastPostDate,
    isAtRisk,
    hoursUntilStreakLoss,
  };
}

/**
 * Send streak milestone notification
 */
export async function sendStreakMilestoneNotification(clerkId: string, streakCount: number): Promise<void> {
  // Only send for milestone numbers
  if (!STREAK_MILESTONES.includes(streakCount)) {
    return;
  }

  const messages: Record<number, { title: string; message: string }> = {
    3: {
      title: "🔥 3-Day Streak!",
      message: "You're building a great habit! Keep posting daily to grow your streak.",
    },
    7: {
      title: "🔥 One Week Streak!",
      message: "Amazing! You've posted every day for a week. You're on fire!",
    },
    14: {
      title: "🔥 Two Week Streak!",
      message: "Incredible dedication! 14 days of consistent posting. You're crushing it!",
    },
    30: {
      title: "🏆 30-Day Streak!",
      message: "A whole month of daily posts! You're a Palytt legend in the making!",
    },
    60: {
      title: "🏆 60-Day Streak!",
      message: "Two months strong! Your dedication is inspiring the community!",
    },
    100: {
      title: "👑 100-Day Streak!",
      message: "Triple digits! You've reached elite status. Absolutely incredible!",
    },
    365: {
      title: "🎉 365-Day Streak!",
      message: "A FULL YEAR of daily posts! You're a true Palytt champion! 🏆",
    },
  };

  const notification = messages[streakCount];
  if (notification) {
    await createNotification(
      clerkId,
      'GENERAL',
      notification.title,
      notification.message,
      {
        streakMilestone: true,
        streakCount,
      }
    );
    console.log(`✅ Sent streak milestone notification to ${clerkId} for ${streakCount}-day streak`);
  }
}

/**
 * Send streak at-risk reminder notification
 */
export async function sendStreakAtRiskNotification(clerkId: string, currentStreak: number, hoursLeft: number): Promise<void> {
  // Don't remind for very short streaks
  if (currentStreak < 2) {
    return;
  }

  const title = "⏰ Your streak is at risk!";
  const message = currentStreak >= 7
    ? `Don't lose your ${currentStreak}-day streak! Post before midnight to keep it going.`
    : `You have ${Math.floor(hoursLeft)} hours to post and keep your ${currentStreak}-day streak alive!`;

  await createNotification(
    clerkId,
    'GENERAL',
    title,
    message,
    {
      streakReminder: true,
      currentStreak,
      hoursLeft: Math.floor(hoursLeft),
    }
  );
  
  console.log(`✅ Sent streak at-risk notification to ${clerkId} (${currentStreak}-day streak, ${Math.floor(hoursLeft)}h left)`);
}

/**
 * Process streak reminders for all users at risk
 * This should be called periodically (e.g., every hour)
 */
export async function processStreakReminders(): Promise<{ processed: number; sent: number }> {
  const now = new Date();
  
  // Get users with active streaks who haven't posted today
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const yesterday = new Date(today.getTime() - 24 * 60 * 60 * 1000);

  try {
    const usersAtRisk = await prisma.user.findMany({
      where: {
        isActive: true,
        currentStreak: { gte: 2 }, // Only users with meaningful streaks
        lastPostDate: {
          gte: yesterday,
          lt: today, // Posted yesterday but not today
        },
      },
      select: {
        clerkId: true,
        currentStreak: true,
        lastPostDate: true,
      },
      take: 100,
    });

    let sentCount = 0;
    
    // Calculate hours until midnight
    const midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
    const hoursUntilMidnight = (midnight.getTime() - now.getTime()) / (1000 * 60 * 60);

    // Only send reminders in the evening (within STREAK_REMINDER_HOURS of midnight)
    if (hoursUntilMidnight <= STREAK_REMINDER_HOURS) {
      for (const user of usersAtRisk) {
        await sendStreakAtRiskNotification(user.clerkId, user.currentStreak, hoursUntilMidnight);
        sentCount++;
      }
    }

    console.log(`📊 Streak reminders: processed ${usersAtRisk.length} users, sent ${sentCount} notifications`);
    return { processed: usersAtRisk.length, sent: sentCount };
  } catch (error) {
    console.error('❌ Failed to process streak reminders:', error);
    return { processed: 0, sent: 0 };
  }
}

/**
 * Update user's streak when they create a post
 * Returns the new streak count if a milestone was reached
 */
export async function updateStreakOnPost(clerkId: string): Promise<{ newStreak: number; milestoneReached: boolean }> {
  const user = await prisma.user.findUnique({
    where: { clerkId },
    select: {
      id: true,
      currentStreak: true,
      longestStreak: true,
      lastPostDate: true,
    },
  });

  if (!user) {
    return { newStreak: 0, milestoneReached: false };
  }

  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  
  let newStreak = 1;
  
  if (user.lastPostDate) {
    const lastPostDate = new Date(user.lastPostDate);
    const lastPostDay = new Date(lastPostDate.getFullYear(), lastPostDate.getMonth(), lastPostDate.getDate());
    const daysSinceLastPost = Math.floor((today.getTime() - lastPostDay.getTime()) / (1000 * 60 * 60 * 24));

    if (daysSinceLastPost === 0) {
      // Already posted today - streak unchanged
      return { newStreak: user.currentStreak, milestoneReached: false };
    } else if (daysSinceLastPost === 1) {
      // Posted yesterday - increment streak
      newStreak = user.currentStreak + 1;
    } else {
      // Streak broken - start fresh
      newStreak = 1;
    }
  }

  const newLongestStreak = Math.max(newStreak, user.longestStreak);
  const milestoneReached = STREAK_MILESTONES.includes(newStreak);

  // Update user's streak
  await prisma.user.update({
    where: { clerkId },
    data: {
      currentStreak: newStreak,
      longestStreak: newLongestStreak,
      lastPostDate: now,
    },
  });

  // Send milestone notification if applicable
  if (milestoneReached) {
    await sendStreakMilestoneNotification(clerkId, newStreak);
  }

  return { newStreak, milestoneReached };
}

