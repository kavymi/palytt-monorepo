/**
 * Create a test account for manual testing
 * This creates a user in the database that can be used with Clerk authentication
 */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🔧 Creating test account for manual testing...\n');
  
  // You can customize this user's details
  const testAccount = {
    clerkId: 'user_test_manual',
    email: 'test@palytt.app',
    username: 'test_user',
    name: 'Test User',
    bio: 'Test account for development and testing',
    profileImage: 'https://i.pravatar.cc/150?img=50',
  };

  // Check if user already exists
  const existingUser = await prisma.user.findUnique({
    where: { clerkId: testAccount.clerkId },
  });

  if (existingUser) {
    console.log('⚠️  Test account already exists!');
    console.log('Updating existing account...\n');
    
    const updatedUser = await prisma.user.update({
      where: { clerkId: testAccount.clerkId },
      data: testAccount,
    });
    
    console.log('✅ Test account updated:');
  } else {
    const newUser = await prisma.user.create({
      data: testAccount,
    });
    
    console.log('✅ Test account created:');
  }

  // Fetch the final user data
  const user = await prisma.user.findUnique({
    where: { clerkId: testAccount.clerkId },
  });

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📋 Account Details:');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`   ID:           ${user!.id}`);
  console.log(`   Clerk ID:     ${user!.clerkId}`);
  console.log(`   Email:        ${user!.email}`);
  console.log(`   Username:     ${user!.username}`);
  console.log(`   Name:         ${user!.name}`);
  console.log(`   Bio:          ${user!.bio}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  // Show some friend request possibilities
  console.log('💡 Testing Ideas:');
  console.log('   1. Log in to the iOS app with this account');
  console.log('   2. Search for other test users (alice_chef, bob_foodie, etc.)');
  console.log('   3. Send friend requests to test users');
  console.log('   4. Use the API to create friend requests TO this user');
  console.log('   5. Accept/reject friend requests in the app\n');

  // Show available test users to connect with
  const otherUsers = await prisma.user.findMany({
    where: {
      clerkId: {
        startsWith: 'user_test_',
        not: testAccount.clerkId,
      },
    },
    select: {
      username: true,
      name: true,
      clerkId: true,
    },
    take: 5,
  });

  if (otherUsers.length > 0) {
    console.log('👥 Available test users to connect with:');
    otherUsers.forEach((u) => {
      console.log(`   - ${u.username} (${u.name})`);
    });
    console.log('');
  }

  console.log('📱 Next Steps:');
  console.log('   1. Make sure Clerk is configured in your iOS app');
  console.log('   2. You may need to create a matching Clerk account');
  console.log('   3. Or configure Clerk to accept this test user');
  console.log('   4. Log in and start testing friend features!\n');
}

main()
  .catch((e) => {
    console.error('❌ Error creating test account:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

