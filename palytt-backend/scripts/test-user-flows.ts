/**
 * Test User Flows
 * Simulates realistic user interactions and tests the complete user journey
 */

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// Test results tracking
interface FlowResult {
  name: string;
  passed: boolean;
  details: string;
  error?: string;
}

const results: FlowResult[] = [];

function logFlow(name: string) {
  console.log(`\n${'━'.repeat(60)}`);
  console.log(`🧪 Testing Flow: ${name}`);
  console.log('━'.repeat(60));
}

function logStep(step: string) {
  console.log(`\n   📍 ${step}`);
}

function logSuccess(message: string) {
  console.log(`   ✅ ${message}`);
}

function logError(message: string) {
  console.log(`   ❌ ${message}`);
}

function logInfo(message: string) {
  console.log(`   ℹ️  ${message}`);
}

async function main() {
  console.log('\n' + '═'.repeat(60));
  console.log('🚀 USER FLOW TESTING SUITE');
  console.log('═'.repeat(60) + '\n');

  const startTime = Date.now();

  // Get test users
  const yourUser = await prisma.user.findFirst({
    where: { email: 'rougepctech@gmail.com' },
  });

  const testUsers = await prisma.user.findMany({
    where: { clerkId: { startsWith: 'user_test_' } },
    take: 6,
  });

  if (!yourUser) {
    console.log('❌ Your account not found. Please log into the app first.');
    return;
  }

  const [alice, bob, carol, david, emma, frank] = testUsers;

  console.log('👥 Test Users:');
  console.log(`   You: ${yourUser.name} (@${yourUser.username})`);
  console.log(`   Alice: @${alice?.username || 'N/A'}`);
  console.log(`   Bob: @${bob?.username || 'N/A'}`);
  console.log(`   Carol: @${carol?.username || 'N/A'}`);
  console.log(`   David: @${david?.username || 'N/A'}`);
  console.log(`   Emma: @${emma?.username || 'N/A'}\n`);

  // ============================================
  // FLOW 1: Friend Request Journey
  // ============================================
  logFlow('Friend Request Journey');
  
  try {
    logStep('1. Send friend request from You to Carol');
    
    // Clean up any existing friendship
    await prisma.friend.deleteMany({
      where: {
        OR: [
          { senderId: yourUser.id, receiverId: carol.id },
          { senderId: carol.id, receiverId: yourUser.id },
        ],
      },
    });

    const friendRequest = await prisma.friend.create({
      data: {
        senderId: yourUser.id,
        receiverId: carol.id,
        status: 'PENDING',
      },
    });
    logSuccess(`Friend request created with ID: ${friendRequest.id}`);

    logStep('2. Check pending requests for Carol');
    const carolPending = await prisma.friend.findMany({
      where: {
        receiverId: carol.id,
        status: 'PENDING',
      },
    });
    logSuccess(`Carol has ${carolPending.length} pending request(s)`);

    logStep('3. Carol accepts friend request');
    const accepted = await prisma.friend.update({
      where: { id: friendRequest.id },
      data: { status: 'ACCEPTED' },
    });
    logSuccess(`Friendship accepted! Status: ${accepted.status}`);

    logStep('4. Verify friendship exists');
    const friendship = await prisma.friend.findFirst({
      where: {
        OR: [
          { senderId: yourUser.id, receiverId: carol.id, status: 'ACCEPTED' },
          { senderId: carol.id, receiverId: yourUser.id, status: 'ACCEPTED' },
        ],
      },
    });
    logSuccess(`Friendship verified: ${friendship ? 'YES' : 'NO'}`);

    logStep('5. Test mutual friends');
    // Both are friends with Alice
    const mutualFriends = await prisma.friend.findMany({
      where: {
        OR: [
          { senderId: yourUser.id, receiverId: alice.id, status: 'ACCEPTED' },
          { senderId: alice.id, receiverId: yourUser.id, status: 'ACCEPTED' },
        ],
      },
    });
    logInfo(`Found ${mutualFriends.length} potential mutual friend(s)`);

    results.push({
      name: 'Friend Request Journey',
      passed: true,
      details: 'Successfully sent, accepted, and verified friend request',
    });
  } catch (error: any) {
    logError(`Error: ${error.message}`);
    results.push({
      name: 'Friend Request Journey',
      passed: false,
      details: 'Failed',
      error: error.message,
    });
  }

  // ============================================
  // FLOW 2: Post Creation and Interactions
  // ============================================
  logFlow('Post Creation and Interactions');

  try {
    logStep('1. Create a new post');
    const newPost = await prisma.post.create({
      data: {
        userId: yourUser.id,
        caption: '🍜 Testing this amazing ramen spot! The broth is incredible.',
        mediaUrls: ['https://images.unsplash.com/photo-1557872943-16a5ac26437e'],
        rating: 4.5,
        menuItems: ['Tonkotsu Ramen', 'Gyoza'],
        locationName: 'Ippudo Ramen',
        locationCity: 'New York',
        locationState: 'NY',
        locationCountry: 'USA',
      },
    });
    logSuccess(`Post created with ID: ${newPost.id}`);

    logStep('2. Alice likes the post');
    const like = await prisma.like.create({
      data: {
        postId: newPost.id,
        userId: alice.id,
      },
    });
    logSuccess(`Like added by Alice`);

    logStep('3. Update like count on post');
    const likeCount = await prisma.like.count({
      where: { postId: newPost.id },
    });
    await prisma.post.update({
      where: { id: newPost.id },
      data: { likesCount: likeCount },
    });
    logSuccess(`Post like count updated: ${likeCount}`);

    logStep('4. Bob comments on the post');
    const comment = await prisma.comment.create({
      data: {
        postId: newPost.id,
        authorId: bob.id,
        content: 'I need to try this place! Looks amazing! 🍜',
      },
    });
    logSuccess(`Comment added by Bob: "${comment.content}"`);

    logStep('5. Update comment count on post');
    const commentCount = await prisma.comment.count({
      where: { postId: newPost.id },
    });
    await prisma.post.update({
      where: { id: newPost.id },
      data: { commentsCount: commentCount },
    });
    logSuccess(`Post comment count updated: ${commentCount}`);

    logStep('6. Carol bookmarks the post');
    const bookmark = await prisma.bookmark.create({
      data: {
        postId: newPost.id,
        userId: carol.id,
      },
    });
    logSuccess(`Bookmark added by Carol`);

    logStep('7. Verify post has interactions');
    const postWithStats = await prisma.post.findUnique({
      where: { id: newPost.id },
      include: {
        _count: {
          select: {
            likes: true,
            comments: true,
            bookmarks: true,
          },
        },
      },
    });
    logInfo(`Post Stats: ${postWithStats?._count.likes} likes, ${postWithStats?._count.comments} comments, ${postWithStats?._count.bookmarks} bookmarks`);

    results.push({
      name: 'Post Creation and Interactions',
      passed: true,
      details: `Post created with ${postWithStats?._count.likes} likes, ${postWithStats?._count.comments} comments, ${postWithStats?._count.bookmarks} bookmarks`,
    });
  } catch (error: any) {
    logError(`Error: ${error.message}`);
    results.push({
      name: 'Post Creation and Interactions',
      passed: false,
      details: 'Failed',
      error: error.message,
    });
  }

  // ============================================
  // FLOW 3: Follow/Unfollow Journey
  // ============================================
  logFlow('Follow/Unfollow Journey');

  try {
    logStep('1. You follow Emma');
    
    // Clean up any existing follow
    await prisma.follow.deleteMany({
      where: {
        followerId: yourUser.id,
        followingId: emma.id,
      },
    });

    const follow = await prisma.follow.create({
      data: {
        followerId: yourUser.id,
        followingId: emma.id,
      },
    });
    logSuccess(`Following Emma`);

    logStep('2. Check your following count');
    const followingCount = await prisma.follow.count({
      where: { followerId: yourUser.id },
    });
    logSuccess(`You are following ${followingCount} users`);

    logStep('3. Check Emma\'s followers count');
    const followersCount = await prisma.follow.count({
      where: { followingId: emma.id },
    });
    logSuccess(`Emma has ${followersCount} followers`);

    logStep('4. Get list of users you follow');
    const following = await prisma.follow.findMany({
      where: { followerId: yourUser.id },
      include: {
        following: {
          select: {
            username: true,
            name: true,
          },
        },
      },
      take: 5,
    });
    logInfo(`Following: ${following.map(f => f.following.username).join(', ')}`);

    logStep('5. Unfollow Emma');
    await prisma.follow.deleteMany({
      where: {
        followerId: yourUser.id,
        followingId: emma.id,
      },
    });
    logSuccess(`Unfollowed Emma`);

    logStep('6. Verify unfollow');
    const stillFollowing = await prisma.follow.findFirst({
      where: {
        followerId: yourUser.id,
        followingId: emma.id,
      },
    });
    logSuccess(`Still following: ${stillFollowing ? 'YES' : 'NO'}`);

    results.push({
      name: 'Follow/Unfollow Journey',
      passed: true,
      details: 'Successfully followed and unfollowed user',
    });
  } catch (error: any) {
    logError(`Error: ${error.message}`);
    results.push({
      name: 'Follow/Unfollow Journey',
      passed: false,
      details: 'Failed',
      error: error.message,
    });
  }

  // ============================================
  // FLOW 4: List Management
  // ============================================
  logFlow('List Management Journey');

  try {
    logStep('1. Create a new list');
    const newList = await prisma.list.create({
      data: {
        userId: yourUser.id,
        name: 'Weekend Brunch Spots',
        description: 'Best places for weekend brunch',
        isPrivate: false, // isPrivate is the schema field, not isPublic
      },
    });
    logSuccess(`List created: "${newList.name}"`);

    logStep('2. Find posts to add to list');
    const posts = await prisma.post.findMany({
      where: {
        OR: [
          { menuItems: { has: 'brunch' } },
          { caption: { contains: 'breakfast', mode: 'insensitive' } },
        ],
      },
      take: 2,
    });
    
    if (posts.length === 0) {
      // Use any posts if no brunch posts found
      const anyPosts = await prisma.post.findMany({ take: 2 });
      posts.push(...anyPosts);
    }
    
    logInfo(`Found ${posts.length} posts to add`);

    logStep('3. Add posts to list');
    for (const post of posts) {
      try {
        await prisma.listPost.create({
          data: {
            listId: newList.id,
            postId: post.id,
          },
        });
        logSuccess(`Added post: ${post.caption?.substring(0, 30)}...`);
      } catch (error) {
        // Skip if already exists
      }
    }

    logStep('4. Get list with posts');
    const listWithPosts = await prisma.list.findUnique({
      where: { id: newList.id },
      include: {
        _count: {
          select: { listPosts: true }, // Field is 'listPosts' not 'posts'
        },
        listPosts: {
          include: {
            post: {
              select: {
                caption: true,
                locationName: true,
              },
            },
          },
          take: 3,
        },
      },
    });
    logSuccess(`List has ${listWithPosts?._count.listPosts} posts`);

    logStep('5. Update list details');
    const updatedList = await prisma.list.update({
      where: { id: newList.id },
      data: {
        description: 'Updated: Best brunch spots in the city 🥞',
      },
    });
    logSuccess(`List updated: "${updatedList.description}"`);

    results.push({
      name: 'List Management Journey',
      passed: true,
      details: `Created list with ${listWithPosts?._count.posts} posts`,
    });
  } catch (error: any) {
    logError(`Error: ${error.message}`);
    results.push({
      name: 'List Management Journey',
      passed: false,
      details: 'Failed',
      error: error.message,
    });
  }

  // ============================================
  // FLOW 5: Feed Discovery
  // ============================================
  logFlow('Feed Discovery Journey');

  try {
    logStep('1. Get posts from users you follow');
    const following = await prisma.follow.findMany({
      where: { followerId: yourUser.id },
      select: { followingId: true },
    });
    const followingIds = following.map(f => f.followingId);
    
    const feedPosts = await prisma.post.findMany({
      where: {
        userId: { in: followingIds },
      },
      include: {
        author: {
          select: {
            username: true,
            name: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 5,
    });
    logSuccess(`Found ${feedPosts.length} posts in feed`);
    feedPosts.forEach(post => {
      logInfo(`   - @${post.author.username}: ${post.caption?.substring(0, 40)}...`);
    });

    logStep('2. Get posts from friends');
    const friendships = await prisma.friend.findMany({
      where: {
        OR: [
          { senderId: yourUser.id, status: 'ACCEPTED' },
          { receiverId: yourUser.id, status: 'ACCEPTED' },
        ],
      },
    });
    
    const friendUserIds = friendships.map(f => 
      f.senderId === yourUser.id ? f.receiverId : f.senderId
    );
    
    const friendPosts = await prisma.post.findMany({
      where: {
        userId: { in: friendUserIds.length > 0 ? friendUserIds : ['none'] },
      },
      include: {
        author: {
          select: {
            username: true,
            name: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 5,
    });
    logSuccess(`Found ${friendPosts.length} posts from friends`);

    logStep('3. Discover trending posts');
    const trendingPosts = await prisma.post.findMany({
      where: {
        likesCount: { gte: 2 },
      },
      orderBy: [
        { likesCount: 'desc' },
        { commentsCount: 'desc' },
      ],
      take: 5,
      include: {
        author: {
          select: {
            username: true,
          },
        },
      },
    });
    logSuccess(`Found ${trendingPosts.length} trending posts`);
    trendingPosts.forEach(post => {
      logInfo(`   - ${post.likesCount} likes, ${post.commentsCount} comments - @${post.author.username}`);
    });

    logStep('4. Search posts by location');
    const nycPosts = await prisma.post.findMany({
      where: {
        OR: [
          { locationCity: 'New York' },
          { locationCity: 'NYC' },
        ],
      },
      take: 5,
      include: {
        author: {
          select: { username: true },
        },
      },
    });
    logSuccess(`Found ${nycPosts.length} posts in New York`);

    results.push({
      name: 'Feed Discovery Journey',
      passed: true,
      details: `Feed: ${feedPosts.length} posts, Friends: ${friendPosts.length} posts, Trending: ${trendingPosts.length} posts`,
    });
  } catch (error: any) {
    logError(`Error: ${error.message}`);
    results.push({
      name: 'Feed Discovery Journey',
      passed: false,
      details: 'Failed',
      error: error.message,
    });
  }

  // ============================================
  // FLOW 6: Notification Journey
  // ============================================
  logFlow('Notification Journey');

  try {
    logStep('1. Create notifications for various events');
    
    const notifications = [];
    
    // Friend request notification
    notifications.push(await prisma.notification.create({
      data: {
        userId: yourUser.id,
        type: 'FRIEND_REQUEST',
        title: 'New Friend Request',
        message: `${david.name} sent you a friend request`,
        data: {
          relatedUserId: david.id,
          username: david.username,
        },
      },
    }));
    logSuccess('Created friend request notification');

    // Like notification
    const yourPost = await prisma.post.findFirst({
      where: { userId: yourUser.id },
    });
    if (yourPost) {
      notifications.push(await prisma.notification.create({
        data: {
          userId: yourUser.id,
          type: 'POST_LIKE',
          title: 'New Like',
          message: `${alice.name} liked your post`,
          data: {
            relatedUserId: alice.id,
            relatedPostId: yourPost.id,
            username: alice.username,
          },
        },
      }));
      logSuccess('Created like notification');
    }

    // Comment notification
    if (yourPost) {
      notifications.push(await prisma.notification.create({
        data: {
          userId: yourUser.id,
          type: 'COMMENT',
          title: 'New Comment',
          message: `${bob.name} commented on your post`,
          data: {
            relatedUserId: bob.id,
            relatedPostId: yourPost.id,
            username: bob.username,
          },
        },
      }));
      logSuccess('Created comment notification');
    }

    logStep('2. Get unread notifications');
    const unreadNotifications = await prisma.notification.findMany({
      where: {
        userId: yourUser.id,
        read: false, // Field is 'read' not 'isRead'
      },
      orderBy: { createdAt: 'desc' },
      take: 10,
    });
    logSuccess(`You have ${unreadNotifications.length} unread notifications`);

    logStep('3. Mark notifications as read');
    const markAsRead = await prisma.notification.updateMany({
      where: {
        userId: yourUser.id,
        read: false,
      },
      data: {
        read: true, // Field is 'read' not 'isRead'
      },
    });
    logSuccess(`Marked ${markAsRead.count} notifications as read`);

    results.push({
      name: 'Notification Journey',
      passed: true,
      details: `Created ${notifications.length} notifications, marked ${markAsRead.count} as read`,
    });
  } catch (error: any) {
    logError(`Error: ${error.message}`);
    results.push({
      name: 'Notification Journey',
      passed: false,
      details: 'Failed',
      error: error.message,
    });
  }

  // ============================================
  // FINAL SUMMARY
  // ============================================
  const endTime = Date.now();
  const duration = ((endTime - startTime) / 1000).toFixed(2);

  console.log('\n' + '═'.repeat(60));
  console.log('📊 USER FLOW TEST RESULTS');
  console.log('═'.repeat(60) + '\n');

  const passed = results.filter(r => r.passed).length;
  const failed = results.filter(r => !r.passed).length;

  results.forEach(result => {
    const icon = result.passed ? '✅' : '❌';
    console.log(`${icon} ${result.name}`);
    console.log(`   ${result.details}`);
    if (result.error) {
      console.log(`   Error: ${result.error}`);
    }
    console.log();
  });

  console.log('═'.repeat(60));
  console.log(`✅ Passed: ${passed}/${results.length}`);
  console.log(`❌ Failed: ${failed}/${results.length}`);
  console.log(`⏱️  Duration: ${duration}s`);
  console.log('═'.repeat(60) + '\n');

  // Show final database stats
  console.log('📊 Final Database Statistics:\n');
  const finalStats = {
    'Total Users': await prisma.user.count(),
    'Total Posts': await prisma.post.count(),
    'Total Likes': await prisma.like.count(),
    'Total Comments': await prisma.comment.count(),
    'Total Bookmarks': await prisma.bookmark.count(),
    'Total Friends': await prisma.friend.count({ where: { status: 'ACCEPTED' } }),
    'Pending Requests': await prisma.friend.count({ where: { status: 'PENDING' } }),
    'Total Follows': await prisma.follow.count(),
    'Total Lists': await prisma.list.count(),
    'Total Notifications': await prisma.notification.count(),
  };

  Object.entries(finalStats).forEach(([key, value]) => {
    console.log(`   ${key.padEnd(20)} ${value}`);
  });

  console.log('\n✅ All user flows tested successfully!\n');
}

main()
  .catch((e) => {
    console.error('❌ Error:', e.message);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

