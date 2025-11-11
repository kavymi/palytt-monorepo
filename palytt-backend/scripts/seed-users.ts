/**
 * Seed script to populate the database with test users
 */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const testUsers = [
  {
    clerkId: 'user_test_001',
    email: 'alice@test.com',
    username: 'alice_chef',
    name: 'Alice Chen',
    bio: 'Food enthusiast | NYC | Love trying new restaurants 🍕',
    profileImage: 'https://i.pravatar.cc/150?img=1',
  },
  {
    clerkId: 'user_test_002',
    email: 'bob@test.com',
    username: 'bob_foodie',
    name: 'Bob Martinez',
    bio: 'Foodie & Photographer | San Francisco | Coffee addict ☕',
    profileImage: 'https://i.pravatar.cc/150?img=2',
  },
  {
    clerkId: 'user_test_003',
    email: 'carol@test.com',
    username: 'carol_eats',
    name: 'Carol Johnson',
    bio: 'Restaurant blogger | LA | Always hunting for the best tacos 🌮',
    profileImage: 'https://i.pravatar.cc/150?img=3',
  },
  {
    clerkId: 'user_test_004',
    email: 'david@test.com',
    username: 'david_dines',
    name: 'David Kim',
    bio: 'Tech & Food | Seattle | Sushi lover 🍣',
    profileImage: 'https://i.pravatar.cc/150?img=4',
  },
  {
    clerkId: 'user_test_005',
    email: 'emma@test.com',
    username: 'emma_tastes',
    name: 'Emma Wilson',
    bio: 'Pastry chef | Boston | Sweet tooth 🍰',
    profileImage: 'https://i.pravatar.cc/150?img=5',
  },
  {
    clerkId: 'user_test_006',
    email: 'frank@test.com',
    username: 'frank_plates',
    name: 'Frank Lopez',
    bio: 'Food critic | Miami | BBQ enthusiast 🥩',
    profileImage: 'https://i.pravatar.cc/150?img=6',
  },
  {
    clerkId: 'user_test_007',
    email: 'grace@test.com',
    username: 'grace_grubs',
    name: 'Grace Taylor',
    bio: 'Vegetarian foodie | Portland | Farm to table advocate 🥗',
    profileImage: 'https://i.pravatar.cc/150?img=7',
  },
  {
    clerkId: 'user_test_008',
    email: 'henry@test.com',
    username: 'henry_eats',
    name: 'Henry Brown',
    bio: 'International cuisine explorer | Chicago | Spicy food lover 🌶️',
    profileImage: 'https://i.pravatar.cc/150?img=8',
  },
  {
    clerkId: 'user_test_009',
    email: 'iris@test.com',
    username: 'iris_dishes',
    name: 'Iris Anderson',
    bio: 'Food writer | Denver | Wine & dine enthusiast 🍷',
    profileImage: 'https://i.pravatar.cc/150?img=9',
  },
  {
    clerkId: 'user_test_010',
    email: 'jack@test.com',
    username: 'jack_meals',
    name: 'Jack Robinson',
    bio: 'Home cook sharing my journey | Austin | Tex-Mex expert 🌯',
    profileImage: 'https://i.pravatar.cc/150?img=10',
  },
];

async function main() {
  console.log('🌱 Starting to seed test users...');
  
  // Clear existing test users
  console.log('🧹 Cleaning up existing test users...');
  await prisma.user.deleteMany({
    where: {
      clerkId: {
        startsWith: 'user_test_',
      },
    },
  });
  
  // Create test users
  console.log('👥 Creating test users...');
  for (const userData of testUsers) {
    const user = await prisma.user.create({
      data: userData,
    });
    console.log(`✅ Created user: ${user.username} (${user.email})`);
  }
  
  console.log('\n🎉 Seeding completed successfully!');
  console.log(`📊 Total users created: ${testUsers.length}`);
  
  // Show some example friend suggestions
  console.log('\n💡 You can now test friend operations with these users:');
  console.log('   - Search for users: "alice", "bob", "food", etc.');
  console.log('   - Send friend requests between users');
  console.log('   - Accept/reject friend requests');
}

main()
  .catch((e) => {
    console.error('❌ Error seeding database:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

