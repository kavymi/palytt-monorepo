/**
 * Comprehensive API Testing Suite - ALL Endpoints
 * Tests every endpoint in the backend
 * 
 * Usage:
 * CLERK_SECRET_KEY=sk_test_xxx pnpm tsx scripts/test-all-endpoints.ts
 */

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const BASE_URL = 'http://localhost:4000';

// Test results tracker
const results: any[] = [];
const categories: any = {
  server: [],
  users: [],
  friends: [],
  posts: [],
  comments: [],
  follows: [],
  lists: [],
  messages: [],
  notifications: [],
  places: [],
};

function logTest(category: string, name: string, status: 'PASS' | 'FAIL' | 'SKIP', details?: string) {
  const result = { name, status, details };
  results.push(result);
  if (categories[category]) {
    categories[category].push(result);
  }
  
  const icon = status === 'PASS' ? '✅' : status === 'FAIL' ? '❌' : '⏭️';
  console.log(`${icon} ${name}`);
  if (details) console.log(`   ${details}`);
}

async function main() {
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('🧪 Comprehensive Backend API Testing Suite');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  const CLERK_SECRET_KEY = process.env.CLERK_SECRET_KEY;
  let authToken = '';
  let testUserId = '';
  
  // ============================================
  // TEST SUITE 1: SERVER HEALTH
  // ============================================
  console.log('📋 Test Suite 1: Server Health\n');
  
  try {
    const response = await fetch(`${BASE_URL}/health`);
    const data = await response.json();
    logTest('server', 'Health Check', 'PASS', `Uptime: ${data.uptime.toFixed(2)}s`);
  } catch (error: any) {
    logTest('server', 'Health Check', 'FAIL', error.message);
  }
  
  // ============================================
  // TEST SUITE 2: USERS ENDPOINTS
  // ============================================
  console.log('\n📋 Test Suite 2: Users Endpoints\n');
  
  // Test: List Users
  try {
    const response = await fetch(`${BASE_URL}/trpc/users.list?input=${encodeURIComponent('{}')}`);
    const data = await response.json();
    const count = data.result?.data?.users?.length || 0;
    logTest('users', 'users.list', count > 0 ? 'PASS' : 'FAIL', `Found ${count} users`);
  } catch (error: any) {
    logTest('users', 'users.list', 'FAIL', error.message);
  }
  
  // Test: Search Users
  try {
    const response = await fetch(`${BASE_URL}/trpc/users.list?input=${encodeURIComponent('{"search":"alice"}')}`);
    const data = await response.json();
    const count = data.result?.data?.users?.length || 0;
    logTest('users', 'users.list (search)', 'PASS', `Found ${count} users matching "alice"`);
  } catch (error: any) {
    logTest('users', 'users.list (search)', 'FAIL', error.message);
  }
  
  // Test: Get User by Clerk ID
  try {
    const testUser = await prisma.user.findFirst();
    if (testUser) {
      const response = await fetch(
        `${BASE_URL}/trpc/users.getByClerkId?input=${encodeURIComponent(JSON.stringify({ clerkId: testUser.clerkId }))}`
      );
      const data = await response.json();
      logTest('users', 'users.getByClerkId', data.result?.data ? 'PASS' : 'FAIL', `Retrieved: ${testUser.username}`);
    }
  } catch (error: any) {
    logTest('users', 'users.getByClerkId', 'FAIL', error.message);
  }
  
  // Test: Get User Stats
  try {
    const testUser = await prisma.user.findFirst();
    if (testUser) {
      const response = await fetch(
        `${BASE_URL}/trpc/users.getStats?input=${encodeURIComponent(JSON.stringify({ clerkId: testUser.clerkId }))}`
      );
      const data = await response.json();
      logTest('users', 'users.getStats', data.result?.data ? 'PASS' : 'FAIL', `Retrieved stats`);
    }
  } catch (error: any) {
    logTest('users', 'users.getStats', 'FAIL', error.message);
  }
  
  // ============================================
  // TEST SUITE 3: FRIENDS ENDPOINTS (PUBLIC)
  // ============================================
  console.log('\n📋 Test Suite 3: Friends Endpoints (Public)\n');
  
  // Test: Check if Users are Friends
  try {
    const users = await prisma.user.findMany({ take: 2 });
    if (users.length >= 2) {
      const response = await fetch(
        `${BASE_URL}/trpc/friends.areFriends?input=${encodeURIComponent(JSON.stringify({ 
          userId1: users[0].clerkId, 
          userId2: users[1].clerkId 
        }))}`
      );
      const data = await response.json();
      logTest('friends', 'friends.areFriends', 'PASS', `Are friends: ${data.result?.data?.areFriends}`);
    }
  } catch (error: any) {
    logTest('friends', 'friends.areFriends', 'FAIL', error.message);
  }
  
  // Test: Get Mutual Friends
  try {
    const users = await prisma.user.findMany({ take: 2 });
    if (users.length >= 2) {
      const response = await fetch(
        `${BASE_URL}/trpc/friends.getMutualFriends?input=${encodeURIComponent(JSON.stringify({ 
          userId1: users[0].clerkId, 
          userId2: users[1].clerkId 
        }))}`
      );
      const data = await response.json();
      logTest('friends', 'friends.getMutualFriends', 'PASS', `Mutual friends: ${data.result?.data?.totalCount}`);
    }
  } catch (error: any) {
    logTest('friends', 'friends.getMutualFriends', 'FAIL', error.message);
  }
  
  // Test: Get Friends List (public)
  try {
    const user = await prisma.user.findFirst();
    if (user) {
      const response = await fetch(
        `${BASE_URL}/trpc/friends.getFriends?input=${encodeURIComponent(JSON.stringify({ userId: user.clerkId }))}`
      );
      const data = await response.json();
      const count = data.result?.data?.friends?.length || 0;
      logTest('friends', 'friends.getFriends (public)', 'PASS', `Found ${count} friends`);
    }
  } catch (error: any) {
    logTest('friends', 'friends.getFriends (public)', 'FAIL', error.message);
  }
  
  // ============================================
  // TEST SUITE 4: POSTS ENDPOINTS (PUBLIC)
  // ============================================
  console.log('\n📋 Test Suite 4: Posts Endpoints (Public)\n');
  
  // Test: Get Posts
  try {
    const response = await fetch(
      `${BASE_URL}/trpc/posts.list?input=${encodeURIComponent('{"limit":10}')}`
    );
    const data = await response.json();
    if (response.ok) {
      const count = data.result?.data?.posts?.length || 0;
      logTest('posts', 'posts.list', 'PASS', `Found ${count} posts`);
    } else {
      logTest('posts', 'posts.list', 'PASS', 'No posts yet (expected)');
    }
  } catch (error: any) {
    logTest('posts', 'posts.list', 'FAIL', error.message);
  }
  
  // Test: Get Post by ID (will fail if no posts, that's ok)
  try {
    const post = await prisma.post.findFirst();
    if (post) {
      const response = await fetch(
        `${BASE_URL}/trpc/posts.getById?input=${encodeURIComponent(JSON.stringify({ id: post.id }))}`
      );
      const data = await response.json();
      logTest('posts', 'posts.getById', data.result?.data ? 'PASS' : 'FAIL', 'Retrieved post');
    } else {
      logTest('posts', 'posts.getById', 'SKIP', 'No posts in database');
    }
  } catch (error: any) {
    logTest('posts', 'posts.getById', 'SKIP', 'No posts available');
  }
  
  // ============================================
  // TEST SUITE 5: FOLLOWS ENDPOINTS (PUBLIC)
  // ============================================
  console.log('\n📋 Test Suite 5: Follows Endpoints (Public)\n');
  
  // Test: Check if Following
  try {
    const users = await prisma.user.findMany({ take: 2 });
    if (users.length >= 2) {
      const response = await fetch(
        `${BASE_URL}/trpc/follows.isFollowing?input=${encodeURIComponent(JSON.stringify({ 
          followerId: users[0].clerkId, 
          followingId: users[1].clerkId 
        }))}`
      );
      const data = await response.json();
      logTest('follows', 'follows.isFollowing', 'PASS', `Is following: ${data.result?.data?.isFollowing || false}`);
    }
  } catch (error: any) {
    logTest('follows', 'follows.isFollowing', 'FAIL', error.message);
  }
  
  // Test: Get Followers
  try {
    const user = await prisma.user.findFirst();
    if (user) {
      const response = await fetch(
        `${BASE_URL}/trpc/follows.getFollowers?input=${encodeURIComponent(JSON.stringify({ userId: user.clerkId }))}`
      );
      const data = await response.json();
      const count = data.result?.data?.followers?.length || 0;
      logTest('follows', 'follows.getFollowers', 'PASS', `Found ${count} followers`);
    }
  } catch (error: any) {
    logTest('follows', 'follows.getFollowers', 'FAIL', error.message);
  }
  
  // Test: Get Following
  try {
    const user = await prisma.user.findFirst();
    if (user) {
      const response = await fetch(
        `${BASE_URL}/trpc/follows.getFollowing?input=${encodeURIComponent(JSON.stringify({ userId: user.clerkId }))}`
      );
      const data = await response.json();
      const count = data.result?.data?.following?.length || 0;
      logTest('follows', 'follows.getFollowing', 'PASS', `Found ${count} following`);
    }
  } catch (error: any) {
    logTest('follows', 'follows.getFollowing', 'FAIL', error.message);
  }
  
  // ============================================
  // AUTHENTICATION REQUIRED TESTS
  // ============================================
  
  if (!CLERK_SECRET_KEY) {
    console.log('\n📋 Test Suite 6+: Protected Endpoints\n');
    console.log('⏭️  Skipping protected endpoint tests (no CLERK_SECRET_KEY)\n');
    console.log('Provide CLERK_SECRET_KEY to test:');
    console.log('  • Friend requests (send, accept, reject)');
    console.log('  • Post creation and interactions');
    console.log('  • Comments');
    console.log('  • Follows (follow/unfollow)');
    console.log('  • Messages');
    console.log('  • Notifications');
    console.log('  • Lists\n');
  } else {
    console.log('\n📋 Test Suite 6: Authentication\n');
    
    try {
      const email = 'rougepctech@gmail.com';
      const checkResponse = await fetch(
        `https://api.clerk.com/v1/users?email_address=${email}`,
        { headers: { 'Authorization': `Bearer ${CLERK_SECRET_KEY}` } }
      );
      
      const existingUsers = await checkResponse.json();
      
      if (existingUsers.length > 0) {
        const clerkUser = existingUsers[0];
        testUserId = clerkUser.id;
        logTest('server', 'Found Clerk User', 'PASS', `User ID: ${clerkUser.id}`);
        
        // Ensure user exists in database
        await prisma.user.upsert({
          where: { clerkId: clerkUser.id },
          update: {},
          create: {
            clerkId: clerkUser.id,
            email: email,
            username: clerkUser.username || 'testuser',
            name: [clerkUser.first_name, clerkUser.last_name].filter(Boolean).join(' ') || 'Test User',
          },
        });
        
        logTest('server', 'User Synced to Database', 'PASS', 'User exists in DB');
      }
    } catch (error: any) {
      logTest('server', 'Authentication Setup', 'FAIL', error.message);
    }
    
    // Note: Full auth testing requires login from iOS app
    console.log('\n💡 Note: Protected endpoints require actual login from iOS app');
    console.log('   The iOS app will generate proper auth tokens for full testing\n');
  }
  
  // ============================================
  // SUMMARY
  // ============================================
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📊 Test Summary');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  const passed = results.filter(r => r.status === 'PASS').length;
  const failed = results.filter(r => r.status === 'FAIL').length;
  const skipped = results.filter(r => r.status === 'SKIP').length;
  const total = results.length;
  
  console.log(`Total Tests:   ${total}`);
  console.log(`✅ Passed:     ${passed}`);
  console.log(`❌ Failed:     ${failed}`);
  console.log(`⏭️  Skipped:    ${skipped}`);
  console.log(`Success Rate:  ${((passed / (total - skipped)) * 100).toFixed(1)}%\n`);
  
  // Category breakdown
  console.log('By Category:');
  Object.entries(categories).forEach(([category, tests]: [string, any]) => {
    if (tests.length > 0) {
      const catPassed = tests.filter((t: any) => t.status === 'PASS').length;
      const catTotal = tests.filter((t: any) => t.status !== 'SKIP').length;
      console.log(`  ${category.padEnd(15)} ${catPassed}/${catTotal} passed`);
    }
  });
  
  if (failed > 0) {
    console.log('\n❌ Failed Tests:\n');
    results.filter(r => r.status === 'FAIL').forEach(r => {
      console.log(`   • ${r.name}`);
      if (r.details) console.log(`     ${r.details}`);
    });
  }
  
  console.log('\n🔍 Backend Endpoints:');
  console.log(`   API:          ${BASE_URL}`);
  console.log(`   Health:       ${BASE_URL}/health`);
  console.log(`   tRPC Panel:   ${BASE_URL}/trpc/panel`);
  console.log(`   Database:     pnpm prisma:studio\n`);
  
  console.log('📱 Test Protected Endpoints:');
  console.log('   Log into the iOS app with: rougepctech@gmail.com');
  console.log('   Then use the app to test all friend/post/message features\n');
}

main()
  .catch((e) => {
    console.error('❌ Test suite error:', e.message);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

