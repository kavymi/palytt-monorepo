/**
 * Setup your personal account in the database
 * This checks if your Clerk user exists and creates/updates the database entry
 */

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🔧 Setting up your account...\n');
  
  const email = 'rougepctech@gmail.com';
  const username = 'kavyuwu';
  
  // Check if user already exists in database
  const existingUser = await prisma.user.findUnique({
    where: { email: email },
  });
  
  if (existingUser) {
    console.log('✅ Your account already exists in the database!\n');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('📋 Account Details:');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`   Email:        ${existingUser.email}`);
    console.log(`   Username:     ${existingUser.username}`);
    console.log(`   Name:         ${existingUser.name}`);
    console.log(`   Clerk ID:     ${existingUser.clerkId}`);
    console.log(`   Database ID:  ${existingUser.id}`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    console.log('📱 You can now test the app!');
    console.log('   1. Look at the iOS Simulator');
    console.log('   2. Sign in with your credentials');
    console.log('   3. Start testing friend features!\n');
  } else {
    console.log('⚠️  Your account is not in the database yet.\n');
    console.log('This is normal! Here\'s what will happen:\n');
    console.log('1. When you log into the iOS app with your Clerk credentials');
    console.log('2. The app will automatically create your database entry');
    console.log('3. This happens via the BackendService.syncUserFromClerk() function\n');
    
    console.log('📱 Next Steps:');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('1. Look at the iOS Simulator (should be running)');
    console.log('2. Click "Sign In" or "Get Started"');
    console.log('3. Enter your Clerk credentials:');
    console.log(`   Email: ${email}`);
    console.log('   Password: [your password]');
    console.log('4. The app will sync your account automatically!');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    console.log('💡 After logging in, you can:');
    console.log('   ✅ Search for users (alice_chef, bob_foodie, etc.)');
    console.log('   ✅ Send friend requests');
    console.log('   ✅ Accept/reject requests');
    console.log('   ✅ View friends list');
    console.log('   ✅ Get friend suggestions\n');
  }
  
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
      email: true,
    },
    take: 10,
  });
  
  if (testUsers.length > 0) {
    console.log('👥 Test Users You Can Friend:\n');
    testUsers.forEach((u, i) => {
      console.log(`   ${(i + 1).toString().padStart(2)}. ${u.name.padEnd(20)} @${u.username.padEnd(15)} ${u.email}`);
    });
    console.log('');
  }
  
  console.log('🔍 Monitor Your Activity:');
  console.log('   Backend Logs:  Watch the terminal running "pnpm dev"');
  console.log('   Database:      pnpm prisma:studio (http://localhost:5555)');
  console.log('   API Panel:     http://localhost:4000/trpc/panel\n');
}

main()
  .catch((e) => {
    console.error('❌ Error:', e.message);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

