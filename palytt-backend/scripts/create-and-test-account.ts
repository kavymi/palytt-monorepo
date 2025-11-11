/**
 * Create a Clerk user, sync to database, and test endpoints
 * 
 * Usage:
 * CLERK_SECRET_KEY=sk_test_xxx pnpm tsx scripts/create-and-test-account.ts
 */

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const BASE_URL = 'http://localhost:4000';

async function main() {
  console.log('🚀 Creating test account and testing endpoints...\n');
  
  const CLERK_SECRET_KEY = process.env.CLERK_SECRET_KEY;
  
  if (!CLERK_SECRET_KEY) {
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('⚠️  Clerk Secret Key Required');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    console.log('To create a user programmatically, you need your Clerk Secret Key.\n');
    console.log('📋 Quick Setup (Option 1 - Automated):');
    console.log('   1. Go to: https://dashboard.clerk.com/');
    console.log('   2. Navigate to: API Keys');
    console.log('   3. Copy your "Secret Key" (starts with sk_test_)');
    console.log('   4. Run:');
    console.log('      CLERK_SECRET_KEY=sk_test_xxx pnpm tsx scripts/create-and-test-account.ts\n');
    console.log('📱 Manual Setup (Option 2 - Via Dashboard):');
    console.log('   1. Go to: https://dashboard.clerk.com/');
    console.log('   2. Click "Users" → "Create User"');
    console.log('   3. Create user with:');
    console.log('      Email: test@palytt.app');
    console.log('      Password: TestPassword123!');
    console.log('   4. Copy the User ID (starts with user_)');
    console.log('   5. Run: pnpm update:test-clerk-id user_YOUR_ID');
    console.log('   6. Log into the iOS app to test\n');
    process.exit(0);
  }
  
  const testUserData = {
    email_address: ['test@palytt.app'],
    username: 'test_user',
    first_name: 'Test',
    last_name: 'User',
    password: 'TestPassword123!',
  };
  
  try {
    console.log('📝 Step 1: Creating user in Clerk...');
    
    // Check if user already exists in Clerk
    const checkResponse = await fetch(
      `https://api.clerk.com/v1/users?email_address=${testUserData.email_address[0]}`,
      {
        headers: {
          'Authorization': `Bearer ${CLERK_SECRET_KEY}`,
        },
      }
    );
    
    let clerkUser;
    const existingUsers = await checkResponse.json();
    
    if (existingUsers.length > 0) {
      clerkUser = existingUsers[0];
      console.log(`   ✅ User already exists in Clerk: ${clerkUser.id}`);
    } else {
      // Create new user in Clerk
      const createResponse = await fetch('https://api.clerk.com/v1/users', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${CLERK_SECRET_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(testUserData),
      });
      
      if (!createResponse.ok) {
        const errorData = await createResponse.text();
        throw new Error(`Clerk API error: ${createResponse.statusText}\n${errorData}`);
      }
      
      clerkUser = await createResponse.json();
      console.log(`   ✅ Created new user in Clerk: ${clerkUser.id}`);
    }
    
    console.log('\n📝 Step 2: Creating/updating user in database...');
    
    // Create or update user in database
    const dbUser = await prisma.user.upsert({
      where: { clerkId: clerkUser.id },
      update: {
        email: testUserData.email_address[0],
        username: testUserData.username,
        name: `${testUserData.first_name} ${testUserData.last_name}`,
      },
      create: {
        clerkId: clerkUser.id,
        email: testUserData.email_address[0],
        username: testUserData.username,
        name: `${testUserData.first_name} ${testUserData.last_name}`,
        bio: 'Test account for development and testing',
        profileImage: 'https://i.pravatar.cc/150?img=50',
      },
    });
    
    console.log(`   ✅ User synced to database: ${dbUser.id}`);
    
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('✅ Account Created Successfully!');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`📋 Login Credentials:`);
    console.log(`   Email:     ${testUserData.email_address[0]}`);
    console.log(`   Password:  ${testUserData.password}`);
    console.log(`   Clerk ID:  ${clerkUser.id}`);
    console.log(`   DB ID:     ${dbUser.id}`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    console.log('📱 Next Steps to Test Endpoints:\n');
    console.log('   Option A - Via iOS App (Recommended):');
    console.log('   1. Open the Palytt app on simulator');
    console.log('   2. Sign in with the credentials above');
    console.log('   3. Navigate to friend features');
    console.log('   4. Search for: alice_chef, bob_foodie, etc.');
    console.log('   5. Send friend requests and test features\n');
    
    console.log('   Option B - Via API with Token:');
    console.log('   1. Log into the iOS app first');
    console.log('   2. The app will generate an auth token');
    console.log('   3. Extract the token from network logs');
    console.log('   4. Use curl commands (see below)\n');
    
    console.log('🧪 Example API Calls (after getting token):\n');
    console.log('   # Get friends list');
    console.log('   curl -G "http://localhost:4000/trpc/friends.getFriends" \\');
    console.log('     -H "Authorization: Bearer YOUR_TOKEN_HERE" \\');
    console.log('     --data-urlencode \'input={}\'\n');
    
    console.log('   # Send friend request to Alice');
    console.log('   curl -X POST "http://localhost:4000/trpc/friends.sendRequest" \\');
    console.log('     -H "Authorization: Bearer YOUR_TOKEN_HERE" \\');
    console.log('     -H "Content-Type: application/json" \\');
    console.log('     -d \'{"json":{"receiverId":"user_test_001"}}\'\n');
    
    // Show available test users
    const testUsers = await prisma.user.findMany({
      where: {
        clerkId: {
          startsWith: 'user_test_',
        },
      },
      select: {
        username: true,
        name: true,
        clerkId: true,
        email: true,
      },
      take: 5,
    });
    
    if (testUsers.length > 0) {
      console.log('👥 Test Users Available to Connect With:\n');
      testUsers.forEach((u) => {
        console.log(`   ${u.name.padEnd(20)} @${u.username.padEnd(15)} (${u.clerkId})`);
      });
      console.log('');
    } else {
      console.log('⚠️  No test users found. Run: pnpm seed:users\n');
    }
    
    console.log('🔍 Backend Status:');
    console.log(`   API:          ${BASE_URL}`);
    console.log(`   Health:       ${BASE_URL}/health`);
    console.log(`   tRPC Panel:   ${BASE_URL}/trpc/panel`);
    console.log(`   Prisma:       pnpm prisma:studio\n`);
    
  } catch (error: any) {
    console.error('\n❌ Error:', error.message);
    
    if (error.message.includes('401') || error.message.includes('Unauthorized')) {
      console.error('\n⚠️  Your Clerk Secret Key may be invalid or expired.');
      console.error('   Get a new one from: https://dashboard.clerk.com/');
    }
    
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

main();

