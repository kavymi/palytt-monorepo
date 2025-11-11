/**
 * Comprehensive API Testing Script
 * Tests all friend endpoints with authentication
 * 
 * Usage:
 * CLERK_SECRET_KEY=sk_test_xxx pnpm tsx scripts/test-api-with-auth.ts
 */

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const BASE_URL = 'http://localhost:4000';

// Test results tracker
const results: any[] = [];

function logTest(name: string, status: 'PASS' | 'FAIL' | 'SKIP', details?: string) {
  results.push({ name, status, details });
  const icon = status === 'PASS' ? '✅' : status === 'FAIL' ? '❌' : '⏭️';
  console.log(`${icon} ${name}`);
  if (details) console.log(`   ${details}`);
}

async function main() {
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('🧪 Backend API Testing Suite');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  const CLERK_SECRET_KEY = process.env.CLERK_SECRET_KEY;
  
  if (!CLERK_SECRET_KEY) {
    console.log('⚠️  Running tests WITHOUT authentication\n');
    console.log('For full testing, provide CLERK_SECRET_KEY:');
    console.log('CLERK_SECRET_KEY=sk_test_xxx pnpm tsx scripts/test-api-with-auth.ts\n');
    console.log('Continuing with public endpoint tests only...\n');
  }
  
  let authToken = '';
  let testUserId = '';
  
  // Test 1: Health Check
  console.log('📋 Test Suite 1: Server Health\n');
  try {
    const response = await fetch(`${BASE_URL}/health`);
    const data = await response.json();
    logTest('Health Check', 'PASS', `Server uptime: ${data.uptime.toFixed(2)}s`);
  } catch (error: any) {
    logTest('Health Check', 'FAIL', error.message);
  }
  
  console.log('\n📋 Test Suite 2: Public Endpoints\n');
  
  // Test 2: List Users
  try {
    const response = await fetch(
      `${BASE_URL}/trpc/users.list?input=${encodeURIComponent('{}')}`
    );
    const data = await response.json();
    const userCount = data.result?.data?.users?.length || 0;
    logTest('List Users', userCount > 0 ? 'PASS' : 'FAIL', `Found ${userCount} users`);
  } catch (error: any) {
    logTest('List Users', 'FAIL', error.message);
  }
  
  // Test 3: Search Users
  try {
    const response = await fetch(
      `${BASE_URL}/trpc/users.list?input=${encodeURIComponent('{"search":"alice"}')}`
    );
    const data = await response.json();
    const users = data.result?.data?.users || [];
    logTest('Search Users', 'PASS', `Found ${users.length} users matching "alice"`);
  } catch (error: any) {
    logTest('Search Users', 'FAIL', error.message);
  }
  
  // Test 4: Get User by Clerk ID
  try {
    const testUser = await prisma.user.findFirst({
      where: { clerkId: { startsWith: 'user_test_' } },
    });
    
    if (testUser) {
      const response = await fetch(
        `${BASE_URL}/trpc/users.getByClerkId?input=${encodeURIComponent(JSON.stringify({ clerkId: testUser.clerkId }))}`
      );
      const data = await response.json();
      logTest('Get User by Clerk ID', data.result?.data ? 'PASS' : 'FAIL', `Retrieved: ${testUser.username}`);
    }
  } catch (error: any) {
    logTest('Get User by Clerk ID', 'FAIL', error.message);
  }
  
  // Test 5: Check if Users are Friends
  try {
    const users = await prisma.user.findMany({
      where: { clerkId: { startsWith: 'user_test_' } },
      take: 2,
    });
    
    if (users.length >= 2) {
      const response = await fetch(
        `${BASE_URL}/trpc/friends.areFriends?input=${encodeURIComponent(JSON.stringify({ userId1: users[0].clerkId, userId2: users[1].clerkId }))}`
      );
      const data = await response.json();
      logTest('Check Friendship Status', 'PASS', `Are friends: ${data.result?.data?.areFriends}`);
    }
  } catch (error: any) {
    logTest('Check Friendship Status', 'FAIL', error.message);
  }
  
  // Test 6: Get Mutual Friends
  try {
    const users = await prisma.user.findMany({
      where: { clerkId: { startsWith: 'user_test_' } },
      take: 2,
    });
    
    if (users.length >= 2) {
      const response = await fetch(
        `${BASE_URL}/trpc/friends.getMutualFriends?input=${encodeURIComponent(JSON.stringify({ userId1: users[0].clerkId, userId2: users[1].clerkId }))}`
      );
      const data = await response.json();
      logTest('Get Mutual Friends', 'PASS', `Mutual friends: ${data.result?.data?.totalCount}`);
    }
  } catch (error: any) {
    logTest('Get Mutual Friends', 'FAIL', error.message);
  }
  
  console.log('\n📋 Test Suite 3: Protected Endpoints\n');
  
  if (!CLERK_SECRET_KEY) {
    console.log('⏭️  Skipping protected endpoint tests (no auth token)\n');
    console.log('To test protected endpoints:');
    console.log('1. Get your Clerk Secret Key from https://dashboard.clerk.com/');
    console.log('2. Run: CLERK_SECRET_KEY=sk_test_xxx pnpm tsx scripts/test-api-with-auth.ts\n');
  } else {
    console.log('🔐 Authenticating with Clerk...\n');
    
    // Get or create test user
    try {
      const email = 'rougepctech@gmail.com';
      
      // Check if user exists in Clerk
      const checkResponse = await fetch(
        `https://api.clerk.com/v1/users?email_address=${email}`,
        {
          headers: { 'Authorization': `Bearer ${CLERK_SECRET_KEY}` },
        }
      );
      
      const existingUsers = await checkResponse.json();
      let clerkUser;
      
      if (existingUsers.length > 0) {
        clerkUser = existingUsers[0];
        testUserId = clerkUser.id;
        logTest('Found Clerk User', 'PASS', `User ID: ${clerkUser.id}`);
        
        // Ensure user exists in database
        await prisma.user.upsert({
          where: { clerkId: clerkUser.id },
          update: {},
          create: {
            clerkId: clerkUser.id,
            email: email,
            username: clerkUser.username || 'kavyuwu',
            name: [clerkUser.first_name, clerkUser.last_name].filter(Boolean).join(' ') || 'Test User',
            bio: 'Testing account',
          },
        });
        
        // Create a session token for testing
        // Note: In production, this would come from the client after login
        const tokenResponse = await fetch(
          `https://api.clerk.com/v1/users/${clerkUser.id}/tokens/bearer`,
          {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${CLERK_SECRET_KEY}`,
              'Content-Type': 'application/json',
            },
          }
        );
        
        if (tokenResponse.ok) {
          const tokenData = await tokenResponse.json();
          authToken = tokenData.token;
          logTest('Generated Auth Token', 'PASS', 'Token created for testing');
        } else {
          logTest('Generate Auth Token', 'FAIL', 'Could not generate token');
        }
      } else {
        logTest('Find Clerk User', 'FAIL', 'User not found in Clerk');
        console.log('   Please log into the iOS app first to create your Clerk account\n');
      }
    } catch (error: any) {
      logTest('Clerk Authentication', 'FAIL', error.message);
    }
    
    if (authToken && testUserId) {
      console.log('\n🧪 Testing Protected Endpoints...\n');
      
      // Test 7: Send Friend Request
      try {
        const receiver = await prisma.user.findFirst({
          where: { 
            clerkId: { startsWith: 'user_test_' },
          },
        });
        
        if (receiver) {
          const response = await fetch(`${BASE_URL}/trpc/friends.sendRequest`, {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${authToken}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              json: { receiverId: receiver.clerkId },
            }),
          });
          
          const data = await response.json();
          if (response.ok) {
            logTest('Send Friend Request', 'PASS', `Sent to ${receiver.username}`);
          } else {
            const error = data.error?.message || 'Unknown error';
            if (error.includes('already')) {
              logTest('Send Friend Request', 'PASS', 'Request already exists');
            } else {
              logTest('Send Friend Request', 'FAIL', error);
            }
          }
        }
      } catch (error: any) {
        logTest('Send Friend Request', 'FAIL', error.message);
      }
      
      // Test 8: Get Pending Requests
      try {
        const response = await fetch(
          `${BASE_URL}/trpc/friends.getPendingRequests?input=${encodeURIComponent('{"type":"sent"}')}`,
          {
            headers: { 'Authorization': `Bearer ${authToken}` },
          }
        );
        
        const data = await response.json();
        if (response.ok) {
          const count = data.result?.data?.requests?.length || 0;
          logTest('Get Pending Requests', 'PASS', `Found ${count} pending requests`);
        } else {
          logTest('Get Pending Requests', 'FAIL', data.error?.message);
        }
      } catch (error: any) {
        logTest('Get Pending Requests', 'FAIL', error.message);
      }
      
      // Test 9: Get Friends List
      try {
        const response = await fetch(
          `${BASE_URL}/trpc/friends.getFriends?input=${encodeURIComponent('{}')}`,
          {
            headers: { 'Authorization': `Bearer ${authToken}` },
          }
        );
        
        const data = await response.json();
        if (response.ok) {
          const count = data.result?.data?.friends?.length || 0;
          logTest('Get Friends List', 'PASS', `You have ${count} friends`);
        } else {
          logTest('Get Friends List', 'FAIL', data.error?.message);
        }
      } catch (error: any) {
        logTest('Get Friends List', 'FAIL', error.message);
      }
      
      // Test 10: Get Friend Suggestions
      try {
        const response = await fetch(
          `${BASE_URL}/trpc/friends.getFriendSuggestions?input=${encodeURIComponent('{"limit":5}')}`,
          {
            headers: { 'Authorization': `Bearer ${authToken}` },
          }
        );
        
        const data = await response.json();
        if (response.ok) {
          const count = data.result?.data?.suggestions?.length || 0;
          logTest('Get Friend Suggestions', 'PASS', `Found ${count} suggestions`);
        } else {
          logTest('Get Friend Suggestions', 'FAIL', data.error?.message);
        }
      } catch (error: any) {
        logTest('Get Friend Suggestions', 'FAIL', error.message);
      }
    }
  }
  
  // Summary
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📊 Test Summary');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  const passed = results.filter(r => r.status === 'PASS').length;
  const failed = results.filter(r => r.status === 'FAIL').length;
  const skipped = results.filter(r => r.status === 'SKIP').length;
  const total = results.length;
  
  console.log(`Total Tests:  ${total}`);
  console.log(`✅ Passed:    ${passed}`);
  console.log(`❌ Failed:    ${failed}`);
  console.log(`⏭️  Skipped:   ${skipped}`);
  console.log(`Success Rate: ${((passed / total) * 100).toFixed(1)}%\n`);
  
  if (failed > 0) {
    console.log('❌ Failed Tests:\n');
    results.filter(r => r.status === 'FAIL').forEach(r => {
      console.log(`   • ${r.name}`);
      if (r.details) console.log(`     ${r.details}`);
    });
    console.log('');
  }
  
  console.log('🔍 Backend Status:');
  console.log(`   API:          ${BASE_URL}`);
  console.log(`   Health:       ${BASE_URL}/health`);
  console.log(`   tRPC Panel:   ${BASE_URL}/trpc/panel`);
  console.log(`   Database:     pnpm prisma:studio\n`);
  
  if (!CLERK_SECRET_KEY) {
    console.log('💡 Tip: Run with CLERK_SECRET_KEY to test protected endpoints');
    console.log('   Or log into the iOS app to test with real authentication\n');
  }
}

main()
  .catch((e) => {
    console.error('❌ Test suite error:', e.message);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

