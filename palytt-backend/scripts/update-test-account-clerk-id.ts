/**
 * Update the test account with your actual Clerk User ID
 * 
 * Usage:
 * 1. Create a user in Clerk dashboard (https://dashboard.clerk.com/)
 * 2. Copy the User ID (starts with "user_")
 * 3. Run: pnpm tsx scripts/update-test-account-clerk-id.ts user_YOUR_ACTUAL_ID
 */

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('📝 Update Test Account with Real Clerk ID');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    console.log('Usage:');
    console.log('  pnpm tsx scripts/update-test-account-clerk-id.ts <CLERK_USER_ID>\n');
    console.log('Steps:');
    console.log('  1. Go to https://dashboard.clerk.com/');
    console.log('  2. Create a new user or copy an existing user\'s ID');
    console.log('  3. The User ID starts with "user_" (e.g., user_2a1b2c3d4e5f)');
    console.log('  4. Run this script with that ID\n');
    console.log('Example:');
    console.log('  pnpm tsx scripts/update-test-account-clerk-id.ts user_2a1b2c3d4e5f\n');
    
    // Show current test account
    const testUser = await prisma.user.findUnique({
      where: { email: 'test@palytt.app' },
    });
    
    if (testUser) {
      console.log('Current test account:');
      console.log(`  Email: ${testUser.email}`);
      console.log(`  Username: ${testUser.username}`);
      console.log(`  Clerk ID: ${testUser.clerkId}`);
      console.log(`  Database ID: ${testUser.id}\n`);
    }
    
    process.exit(0);
  }
  
  const newClerkId = args[0];
  
  // Validate Clerk ID format
  if (!newClerkId.startsWith('user_')) {
    console.error('❌ Error: Clerk User ID must start with "user_"');
    console.error(`   You provided: ${newClerkId}`);
    process.exit(1);
  }
  
  console.log('🔄 Updating test account...\n');
  
  // Check if a user with this Clerk ID already exists
  const existingUser = await prisma.user.findUnique({
    where: { clerkId: newClerkId },
  });
  
  if (existingUser) {
    console.log('⚠️  A user with this Clerk ID already exists:');
    console.log(`   Email: ${existingUser.email}`);
    console.log(`   Username: ${existingUser.username}`);
    console.log(`   Name: ${existingUser.name}\n`);
    console.log('This user is ready to use for testing!');
    console.log('\n📱 Login with:');
    console.log(`   Email: ${existingUser.email}`);
    console.log('   Password: <the password you set in Clerk>\n');
    process.exit(0);
  }
  
  // Update the test account with new Clerk ID
  const testAccount = await prisma.user.findUnique({
    where: { email: 'test@palytt.app' },
  });
  
  if (testAccount) {
    const updated = await prisma.user.update({
      where: { email: 'test@palytt.app' },
      data: { clerkId: newClerkId },
    });
    
    console.log('✅ Test account updated successfully!\n');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('📋 Account Details:');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`   Email:        ${updated.email}`);
    console.log(`   Username:     ${updated.username}`);
    console.log(`   Name:         ${updated.name}`);
    console.log(`   Clerk ID:     ${updated.clerkId}`);
    console.log(`   Database ID:  ${updated.id}`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  } else {
    // Create new test account if it doesn't exist
    const created = await prisma.user.create({
      data: {
        clerkId: newClerkId,
        email: 'test@palytt.app',
        username: 'test_user',
        name: 'Test User',
        bio: 'Test account for development and testing',
        profileImage: 'https://i.pravatar.cc/150?img=50',
      },
    });
    
    console.log('✅ Test account created successfully!\n');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('📋 Account Details:');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`   Email:        ${created.email}`);
    console.log(`   Username:     ${created.username}`);
    console.log(`   Name:         ${created.name}`);
    console.log(`   Clerk ID:     ${created.clerkId}`);
    console.log(`   Database ID:  ${created.id}`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }
  
  console.log('📱 Next Steps:');
  console.log('   1. Open the Palytt app on the simulator');
  console.log('   2. Sign in with:');
  console.log(`      Email: test@palytt.app`);
  console.log('      Password: <the password you set in Clerk>');
  console.log('   3. Start testing friend features!\n');
  
  // Show available users to connect with
  const otherUsers = await prisma.user.findMany({
    where: {
      clerkId: {
        startsWith: 'user_test_',
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
    console.log('👥 Test users available to connect with:');
    otherUsers.forEach((u) => {
      console.log(`   - ${u.username} (${u.name})`);
    });
    console.log('');
  }
}

main()
  .catch((e) => {
    console.error('❌ Error:', e.message);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

