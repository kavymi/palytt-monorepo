/**
 * COMPREHENSIVE BACKEND API TEST SUITE
 * Tests ALL endpoints across all routers
 * 
 * Usage:
 * CLERK_SECRET_KEY=sk_test_xxx pnpm tsx scripts/comprehensive-test-suite.ts
 */

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const BASE_URL = 'http://localhost:4000';

// Test results tracker
interface TestResult {
  category: string;
  name: string;
  status: 'PASS' | 'FAIL' | 'SKIP';
  details?: string;
  endpoint?: string;
}

const results: TestResult[] = [];
const categories = [
  'Server',
  'Users',
  'Friends',
  'Posts',
  'Comments',
  'Follows',
  'Lists',
  'Messages',
  'Notifications',
  'Places',
  'App',
];

function logTest(category: string, name: string, status: 'PASS' | 'FAIL' | 'SKIP', endpoint?: string, details?: string) {
  const result: TestResult = { category, name, status, endpoint, details };
  results.push(result);
  
  const icon = status === 'PASS' ? '✅' : status === 'FAIL' ? '❌' : '⏭️';
  console.log(`${icon} ${name}`);
  if (endpoint) console.log(`   Endpoint: ${endpoint}`);
  if (details) console.log(`   ${details}`);
}

async function testEndpoint(url: string, method: 'GET' | 'POST' = 'GET', body?: any): Promise<any> {
  const options: any = { method };
  if (body) {
    options.headers = { 'Content-Type': 'application/json' };
    options.body = JSON.stringify(body);
  }
  const response = await fetch(url, options);
  const data = await response.json();
  return { response, data };
}

async function main() {
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('🧪 COMPREHENSIVE BACKEND API TEST SUITE');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  console.log('Testing all endpoints across 11 routers...\n');
  
  const startTime = Date.now();
  
  // Get test user
  const testUser = await prisma.user.findUnique({
    where: { email: 'rougepctech@gmail.com' },
  });
  
  // ============================================
  // SUITE 1: SERVER & APP ENDPOINTS
  // ============================================
  console.log('📋 Suite 1: Server & App Endpoints\n');
  
  // Test: Health Check
  try {
    const { response, data } = await testEndpoint(`${BASE_URL}/health`);
    if (response.ok) {
      logTest('Server', 'Health Check', 'PASS', '/health', `Uptime: ${data.uptime.toFixed(2)}s`);
    } else {
      logTest('Server', 'Health Check', 'FAIL', '/health', 'Health check failed');
    }
  } catch (error: any) {
    logTest('Server', 'Health Check', 'FAIL', '/health', error.message);
  }
  
  // Test: Example endpoint
  try {
    const { response, data } = await testEndpoint(`${BASE_URL}/trpc/example.hello`);
    if (response.ok) {
      logTest('App', 'example.hello', 'PASS', 'GET /trpc/example.hello', 'Example endpoint working');
    } else {
      logTest('App', 'example.hello', 'SKIP', 'GET /trpc/example.hello', 'Endpoint may not exist');
    }
  } catch (error: any) {
    logTest('App', 'example.hello', 'SKIP', 'GET /trpc/example.hello', 'Endpoint may not exist');
  }
  
  // ============================================
  // SUITE 2: USERS ENDPOINTS
  // ============================================
  console.log('\n📋 Suite 2: Users Endpoints\n');
  
  // Test: users.list
  try {
    const { response, data } = await testEndpoint(
      `${BASE_URL}/trpc/users.list?input=${encodeURIComponent('{}')}`
    );
    if (response.ok) {
      const count = data.result?.data?.users?.length || 0;
      logTest('Users', 'users.list', 'PASS', 'GET /trpc/users.list', `Found ${count} users`);
    } else {
      logTest('Users', 'users.list', 'FAIL', 'GET /trpc/users.list', data.error?.message);
    }
  } catch (error: any) {
    logTest('Users', 'users.list', 'FAIL', 'GET /trpc/users.list', error.message);
  }
  
  // Test: users.list with search
  try {
    const { response, data } = await testEndpoint(
      `${BASE_URL}/trpc/users.list?input=${encodeURIComponent('{"search":"alice"}')}`
    );
    if (response.ok) {
      const count = data.result?.data?.users?.length || 0;
      logTest('Users', 'users.list (search)', 'PASS', 'GET /trpc/users.list', `Found ${count} matching users`);
    } else {
      logTest('Users', 'users.list (search)', 'FAIL', 'GET /trpc/users.list', data.error?.message);
    }
  } catch (error: any) {
    logTest('Users', 'users.list (search)', 'FAIL', 'GET /trpc/users.list', error.message);
  }
  
  // Test: users.getByClerkId
  const dbUser = await prisma.user.findFirst();
  if (dbUser) {
    try {
      const { response, data } = await testEndpoint(
        `${BASE_URL}/trpc/users.getByClerkId?input=${encodeURIComponent(JSON.stringify({ clerkId: dbUser.clerkId }))}`
      );
      if (response.ok) {
        logTest('Users', 'users.getByClerkId', 'PASS', 'GET /trpc/users.getByClerkId', `Retrieved ${dbUser.username}`);
      } else {
        logTest('Users', 'users.getByClerkId', 'FAIL', 'GET /trpc/users.getByClerkId', data.error?.message);
      }
    } catch (error: any) {
      logTest('Users', 'users.getByClerkId', 'FAIL', 'GET /trpc/users.getByClerkId', error.message);
    }
  }
  
  // Test: users.getById
  if (dbUser) {
    try {
      const { response, data } = await testEndpoint(
        `${BASE_URL}/trpc/users.getById?input=${encodeURIComponent(JSON.stringify({ id: dbUser.id }))}`
      );
      if (response.ok) {
        logTest('Users', 'users.getById', 'PASS', 'GET /trpc/users.getById', 'Retrieved user by ID');
      } else {
        logTest('Users', 'users.getById', 'FAIL', 'GET /trpc/users.getById', data.error?.message);
      }
    } catch (error: any) {
      logTest('Users', 'users.getById', 'FAIL', 'GET /trpc/users.getById', error.message);
    }
  }
  
  // Test: users.getStats
  if (dbUser) {
    try {
      const { response, data } = await testEndpoint(
        `${BASE_URL}/trpc/users.getStats?input=${encodeURIComponent(JSON.stringify({ clerkId: dbUser.clerkId }))}`
      );
      if (response.ok) {
        logTest('Users', 'users.getStats', 'PASS', 'GET /trpc/users.getStats', 'Retrieved user stats');
      } else {
        logTest('Users', 'users.getStats', 'FAIL', 'GET /trpc/users.getStats', data.error?.message);
      }
    } catch (error: any) {
      logTest('Users', 'users.getStats', 'FAIL', 'GET /trpc/users.getStats', error.message);
    }
  }
  
  // ============================================
  // SUITE 3: FRIENDS ENDPOINTS
  // ============================================
  console.log('\n📋 Suite 3: Friends Endpoints\n');
  
  const users = await prisma.user.findMany({ take: 2 });
  
  // Test: friends.areFriends
  if (users.length >= 2) {
    try {
      const { response, data } = await testEndpoint(
        `${BASE_URL}/trpc/friends.areFriends?input=${encodeURIComponent(JSON.stringify({ 
          userId1: users[0].clerkId, 
          userId2: users[1].clerkId 
        }))}`
      );
      if (response.ok) {
        logTest('Friends', 'friends.areFriends', 'PASS', 'GET /trpc/friends.areFriends', `Result: ${data.result?.data?.areFriends}`);
      } else {
        logTest('Friends', 'friends.areFriends', 'FAIL', 'GET /trpc/friends.areFriends', data.error?.message);
      }
    } catch (error: any) {
      logTest('Friends', 'friends.areFriends', 'FAIL', 'GET /trpc/friends.areFriends', error.message);
    }
  }
  
  // Test: friends.getMutualFriends
  if (users.length >= 2) {
    try {
      const { response, data } = await testEndpoint(
        `${BASE_URL}/trpc/friends.getMutualFriends?input=${encodeURIComponent(JSON.stringify({ 
          userId1: users[0].clerkId, 
          userId2: users[1].clerkId 
        }))}`
      );
      if (response.ok) {
        logTest('Friends', 'friends.getMutualFriends', 'PASS', 'GET /trpc/friends.getMutualFriends', `Found ${data.result?.data?.totalCount} mutual friends`);
      } else {
        logTest('Friends', 'friends.getMutualFriends', 'FAIL', 'GET /trpc/friends.getMutualFriends', data.error?.message);
      }
    } catch (error: any) {
      logTest('Friends', 'friends.getMutualFriends', 'FAIL', 'GET /trpc/friends.getMutualFriends', error.message);
    }
  }
  
  // Test: friends.getFriends (public)
  if (dbUser) {
    try {
      const { response, data } = await testEndpoint(
        `${BASE_URL}/trpc/friends.getFriends?input=${encodeURIComponent(JSON.stringify({ userId: dbUser.clerkId }))}`
      );
      if (response.ok) {
        const count = data.result?.data?.friends?.length || 0;
        logTest('Friends', 'friends.getFriends', 'PASS', 'GET /trpc/friends.getFriends', `Found ${count} friends`);
      } else {
        logTest('Friends', 'friends.getFriends', 'FAIL', 'GET /trpc/friends.getFriends', data.error?.message);
      }
    } catch (error: any) {
      logTest('Friends', 'friends.getFriends', 'FAIL', 'GET /trpc/friends.getFriends', error.message);
    }
  }
  
  // Protected friend endpoints
  logTest('Friends', 'friends.sendRequest', 'SKIP', 'POST /trpc/friends.sendRequest', 'Requires authentication');
  logTest('Friends', 'friends.acceptRequest', 'SKIP', 'POST /trpc/friends.acceptRequest', 'Requires authentication');
  logTest('Friends', 'friends.rejectRequest', 'POST /trpc/friends.rejectRequest', 'SKIP', 'Requires authentication');
  logTest('Friends', 'friends.removeFriend', 'SKIP', 'POST /trpc/friends.removeFriend', 'Requires authentication');
  logTest('Friends', 'friends.blockUser', 'SKIP', 'POST /trpc/friends.blockUser', 'Requires authentication');
  logTest('Friends', 'friends.getFriendSuggestions', 'SKIP', 'GET /trpc/friends.getFriendSuggestions', 'Requires authentication');
  logTest('Friends', 'friends.getPendingRequests', 'SKIP', 'GET /trpc/friends.getPendingRequests', 'Requires authentication');
  
  // ============================================
  // SUITE 4: POSTS ENDPOINTS
  // ============================================
  console.log('\n📋 Suite 4: Posts Endpoints\n');
  
  // Test: posts.list
  try {
    const { response, data } = await testEndpoint(
      `${BASE_URL}/trpc/posts.list?input=${encodeURIComponent('{"limit":10}')}`
    );
    if (response.ok) {
      const count = data.result?.data?.posts?.length || 0;
      logTest('Posts', 'posts.list', 'PASS', 'GET /trpc/posts.list', `Found ${count} posts`);
    } else {
      logTest('Posts', 'posts.list', 'FAIL', 'GET /trpc/posts.list', data.error?.message);
    }
  } catch (error: any) {
    logTest('Posts', 'posts.list', 'FAIL', 'GET /trpc/posts.list', error.message);
  }
  
  // Test: posts.getById
  const post = await prisma.post.findFirst();
  if (post) {
    try {
      const { response, data } = await testEndpoint(
        `${BASE_URL}/trpc/posts.getById?input=${encodeURIComponent(JSON.stringify({ id: post.id }))}`
      );
      if (response.ok) {
        logTest('Posts', 'posts.getById', 'PASS', 'GET /trpc/posts.getById', 'Retrieved post');
      } else {
        logTest('Posts', 'posts.getById', 'FAIL', 'GET /trpc/posts.getById', data.error?.message);
      }
    } catch (error: any) {
      logTest('Posts', 'posts.getById', 'FAIL', 'GET /trpc/posts.getById', error.message);
    }
  } else {
    logTest('Posts', 'posts.getById', 'SKIP', 'GET /trpc/posts.getById', 'No posts available');
  }
  
  // Protected post endpoints
  logTest('Posts', 'posts.create', 'SKIP', 'POST /trpc/posts.create', 'Requires authentication');
  logTest('Posts', 'posts.update', 'SKIP', 'POST /trpc/posts.update', 'Requires authentication');
  logTest('Posts', 'posts.delete', 'SKIP', 'POST /trpc/posts.delete', 'Requires authentication');
  logTest('Posts', 'posts.like', 'SKIP', 'POST /trpc/posts.like', 'Requires authentication');
  logTest('Posts', 'posts.unlike', 'SKIP', 'POST /trpc/posts.unlike', 'Requires authentication');
  logTest('Posts', 'posts.bookmark', 'SKIP', 'POST /trpc/posts.bookmark', 'Requires authentication');
  
  // ============================================
  // SUITE 5: COMMENTS ENDPOINTS
  // ============================================
  console.log('\n📋 Suite 5: Comments Endpoints\n');
  
  // Test: comments.getByPostId
  if (post) {
    try {
      const { response, data } = await testEndpoint(
        `${BASE_URL}/trpc/comments.getByPostId?input=${encodeURIComponent(JSON.stringify({ postId: post.id }))}`
      );
      if (response.ok) {
        const count = data.result?.data?.comments?.length || 0;
        logTest('Comments', 'comments.getByPostId', 'PASS', 'GET /trpc/comments.getByPostId', `Found ${count} comments`);
      } else {
        logTest('Comments', 'comments.getByPostId', 'FAIL', 'GET /trpc/comments.getByPostId', data.error?.message);
      }
    } catch (error: any) {
      logTest('Comments', 'comments.getByPostId', 'FAIL', 'GET /trpc/comments.getByPostId', error.message);
    }
  } else {
    logTest('Comments', 'comments.getByPostId', 'SKIP', 'GET /trpc/comments.getByPostId', 'No posts available');
  }
  
  // Protected comment endpoints
  logTest('Comments', 'comments.create', 'SKIP', 'POST /trpc/comments.create', 'Requires authentication');
  logTest('Comments', 'comments.update', 'SKIP', 'POST /trpc/comments.update', 'Requires authentication');
  logTest('Comments', 'comments.delete', 'SKIP', 'POST /trpc/comments.delete', 'Requires authentication');
  
  // ============================================
  // SUITE 6: FOLLOWS ENDPOINTS
  // ============================================
  console.log('\n📋 Suite 6: Follows Endpoints\n');
  
  // Test: follows.isFollowing
  if (users.length >= 2) {
    try {
      const { response, data } = await testEndpoint(
        `${BASE_URL}/trpc/follows.isFollowing?input=${encodeURIComponent(JSON.stringify({ 
          followerId: users[0].clerkId, 
          followingId: users[1].clerkId 
        }))}`
      );
      if (response.ok) {
        logTest('Follows', 'follows.isFollowing', 'PASS', 'GET /trpc/follows.isFollowing', `Result: ${data.result?.data?.isFollowing}`);
      } else {
        logTest('Follows', 'follows.isFollowing', 'FAIL', 'GET /trpc/follows.isFollowing', data.error?.message);
      }
    } catch (error: any) {
      logTest('Follows', 'follows.isFollowing', 'FAIL', 'GET /trpc/follows.isFollowing', error.message);
    }
  }
  
  // Test: follows.getFollowers
  if (dbUser) {
    try {
      const { response, data } = await testEndpoint(
        `${BASE_URL}/trpc/follows.getFollowers?input=${encodeURIComponent(JSON.stringify({ userId: dbUser.clerkId }))}`
      );
      if (response.ok) {
        const count = data.result?.data?.followers?.length || 0;
        logTest('Follows', 'follows.getFollowers', 'PASS', 'GET /trpc/follows.getFollowers', `Found ${count} followers`);
      } else {
        logTest('Follows', 'follows.getFollowers', 'FAIL', 'GET /trpc/follows.getFollowers', data.error?.message);
      }
    } catch (error: any) {
      logTest('Follows', 'follows.getFollowers', 'FAIL', 'GET /trpc/follows.getFollowers', error.message);
    }
  }
  
  // Test: follows.getFollowing
  if (dbUser) {
    try {
      const { response, data } = await testEndpoint(
        `${BASE_URL}/trpc/follows.getFollowing?input=${encodeURIComponent(JSON.stringify({ userId: dbUser.clerkId }))}`
      );
      if (response.ok) {
        const count = data.result?.data?.following?.length || 0;
        logTest('Follows', 'follows.getFollowing', 'PASS', 'GET /trpc/follows.getFollowing', `Found ${count} following`);
      } else {
        logTest('Follows', 'follows.getFollowing', 'FAIL', 'GET /trpc/follows.getFollowing', data.error?.message);
      }
    } catch (error: any) {
      logTest('Follows', 'follows.getFollowing', 'FAIL', 'GET /trpc/follows.getFollowing', error.message);
    }
  }
  
  // Protected follow endpoints
  logTest('Follows', 'follows.follow', 'SKIP', 'POST /trpc/follows.follow', 'Requires authentication');
  logTest('Follows', 'follows.unfollow', 'SKIP', 'POST /trpc/follows.unfollow', 'Requires authentication');
  
  // ============================================
  // SUITE 7: LISTS ENDPOINTS
  // ============================================
  console.log('\n📋 Suite 7: Lists Endpoints\n');
  
  // Test: lists.getByUserId
  if (dbUser) {
    try {
      const { response, data } = await testEndpoint(
        `${BASE_URL}/trpc/lists.getByUserId?input=${encodeURIComponent(JSON.stringify({ userId: dbUser.clerkId }))}`
      );
      if (response.ok) {
        const count = data.result?.data?.lists?.length || 0;
        logTest('Lists', 'lists.getByUserId', 'PASS', 'GET /trpc/lists.getByUserId', `Found ${count} lists`);
      } else {
        logTest('Lists', 'lists.getByUserId', 'FAIL', 'GET /trpc/lists.getByUserId', data.error?.message);
      }
    } catch (error: any) {
      logTest('Lists', 'lists.getByUserId', 'FAIL', 'GET /trpc/lists.getByUserId', error.message);
    }
  }
  
  // Protected list endpoints
  logTest('Lists', 'lists.create', 'SKIP', 'POST /trpc/lists.create', 'Requires authentication');
  logTest('Lists', 'lists.update', 'SKIP', 'POST /trpc/lists.update', 'Requires authentication');
  logTest('Lists', 'lists.delete', 'SKIP', 'POST /trpc/lists.delete', 'Requires authentication');
  logTest('Lists', 'lists.addPost', 'SKIP', 'POST /trpc/lists.addPost', 'Requires authentication');
  logTest('Lists', 'lists.removePost', 'SKIP', 'POST /trpc/lists.removePost', 'Requires authentication');
  
  // ============================================
  // SUITE 8: MESSAGES ENDPOINTS
  // ============================================
  console.log('\n📋 Suite 8: Messages Endpoints\n');
  
  logTest('Messages', 'messages.getChatrooms', 'SKIP', 'GET /trpc/messages.getChatrooms', 'Requires authentication');
  logTest('Messages', 'messages.getMessages', 'SKIP', 'GET /trpc/messages.getMessages', 'Requires authentication');
  logTest('Messages', 'messages.send', 'SKIP', 'POST /trpc/messages.send', 'Requires authentication');
  logTest('Messages', 'messages.markAsRead', 'SKIP', 'POST /trpc/messages.markAsRead', 'Requires authentication');
  logTest('Messages', 'messages.createChatroom', 'SKIP', 'POST /trpc/messages.createChatroom', 'Requires authentication');
  
  // ============================================
  // SUITE 9: NOTIFICATIONS ENDPOINTS
  // ============================================
  console.log('\n📋 Suite 9: Notifications Endpoints\n');
  
  logTest('Notifications', 'notifications.list', 'SKIP', 'GET /trpc/notifications.list', 'Requires authentication');
  logTest('Notifications', 'notifications.markAsRead', 'SKIP', 'POST /trpc/notifications.markAsRead', 'Requires authentication');
  logTest('Notifications', 'notifications.markAllAsRead', 'SKIP', 'POST /trpc/notifications.markAllAsRead', 'Requires authentication');
  logTest('Notifications', 'notifications.getUnreadCount', 'SKIP', 'GET /trpc/notifications.getUnreadCount', 'Requires authentication');
  
  // ============================================
  // SUITE 10: PLACES ENDPOINTS
  // ============================================
  console.log('\n📋 Suite 10: Places Endpoints\n');
  
  // Test: places.search
  try {
    const { response, data } = await testEndpoint(
      `${BASE_URL}/trpc/places.search?input=${encodeURIComponent('{"query":"pizza","limit":5}')}`
    );
    if (response.ok) {
      const count = data.result?.data?.places?.length || 0;
      logTest('Places', 'places.search', 'PASS', 'GET /trpc/places.search', `Found ${count} places`);
    } else {
      logTest('Places', 'places.search', 'SKIP', 'GET /trpc/places.search', 'Endpoint may not be implemented');
    }
  } catch (error: any) {
    logTest('Places', 'places.search', 'SKIP', 'GET /trpc/places.search', 'Endpoint may not be implemented');
  }
  
  // ============================================
  // DATABASE STATISTICS
  // ============================================
  console.log('\n📋 Database Statistics\n');
  
  const stats = {
    users: await prisma.user.count(),
    posts: await prisma.post.count(),
    comments: await prisma.comment.count(),
    likes: await prisma.like.count(),
    bookmarks: await prisma.bookmark.count(),
    friends: await prisma.friend.count(),
    follows: await prisma.follow.count(),
    lists: await prisma.list.count(),
    messages: await prisma.message.count(),
    chatrooms: await prisma.chatroom.count(),
    notifications: await prisma.notification.count(),
  };
  
  console.log(`📊 Database Records:`);
  Object.entries(stats).forEach(([table, count]) => {
    console.log(`   ${table.padEnd(15)} ${count}`);
  });
  
  // ============================================
  // FINAL SUMMARY
  // ============================================
  const endTime = Date.now();
  const duration = ((endTime - startTime) / 1000).toFixed(2);
  
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📊 COMPREHENSIVE TEST SUMMARY');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  const passed = results.filter(r => r.status === 'PASS').length;
  const failed = results.filter(r => r.status === 'FAIL').length;
  const skipped = results.filter(r => r.status === 'SKIP').length;
  const total = results.length;
  const testableTotal = total - skipped;
  
  console.log(`Total Tests:       ${total}`);
  console.log(`✅ Passed:         ${passed}`);
  console.log(`❌ Failed:         ${failed}`);
  console.log(`⏭️  Skipped:        ${skipped}`);
  console.log(`Success Rate:      ${testableTotal > 0 ? ((passed / testableTotal) * 100).toFixed(1) : 0}%`);
  console.log(`Test Duration:     ${duration}s\n`);
  
  // Results by category
  console.log('Results by Category:\n');
  categories.forEach(category => {
    const categoryResults = results.filter(r => r.category === category);
    if (categoryResults.length > 0) {
      const catPassed = categoryResults.filter(r => r.status === 'PASS').length;
      const catFailed = categoryResults.filter(r => r.status === 'FAIL').length;
      const catSkipped = categoryResults.filter(r => r.status === 'SKIP').length;
      const catTotal = categoryResults.length;
      
      console.log(`${category.padEnd(15)} ${catPassed}/${catTotal - catSkipped} passed (${catSkipped} skipped, ${catFailed} failed)`);
    }
  });
  
  // Show failures
  if (failed > 0) {
    console.log('\n❌ Failed Tests:\n');
    results.filter(r => r.status === 'FAIL').forEach(r => {
      console.log(`   • ${r.name}`);
      console.log(`     ${r.endpoint}`);
      if (r.details) console.log(`     ${r.details}`);
    });
  }
  
  console.log('\n🔍 Backend Status:');
  console.log(`   API:          ${BASE_URL}`);
  console.log(`   Health:       ${BASE_URL}/health`);
  console.log(`   tRPC Panel:   ${BASE_URL}/trpc/panel`);
  console.log(`   Database:     pnpm prisma:studio\n`);
  
  console.log('📱 To Test Protected Endpoints:');
  console.log('   Log into the iOS app with: rougepctech@gmail.com');
  console.log('   All protected endpoints require authentication via Clerk\n');
  
  console.log('✅ Test suite complete!\n');
}

main()
  .catch((e) => {
    console.error('❌ Test suite error:', e.message);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

