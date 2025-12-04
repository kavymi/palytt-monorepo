/**
 * Create Rich Test Data
 * Populates database with posts, friendships, follows, likes, comments, and lists
 */

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('🎨 Creating Rich Test Data');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  const startTime = Date.now();

  // Get all users
  const users = await prisma.user.findMany();
  console.log(`📊 Found ${users.length} users in database\n`);

  const yourUser = users.find(u => u.email === 'rougepctech@gmail.com');
  const testUsers = users.filter(u => u.clerkId.startsWith('user_test_'));

  if (!yourUser) {
    console.log('❌ Your account not found. Please log into the app first.');
    return;
  }

  console.log(`✅ Your account: ${yourUser.name} (@${yourUser.username})\n`);

  // ============================================
  // STEP 1: Create Posts for Test Users
  // ============================================
  console.log('📝 Step 1: Creating posts for test users...\n');

  const postTemplates = [
    {
      user: 'alice_chef',
      posts: [
        {
          caption: '🍕 Finally tried the famous NY-style pizza! The thin crust is everything. #pizza #nyc',
          mediaUrls: ['https://images.unsplash.com/photo-1513104890138-7c749659a591'],
          rating: 5.0,
          menuItems: ['Margherita Pizza', 'Garlic Knots'],
          locationName: "Joe's Pizza",
          locationCity: 'New York',
          locationState: 'NY',
        },
        {
          caption: '🥗 Best caesar salad in the city! Fresh romaine, perfect dressing.',
          mediaUrls: ['https://images.unsplash.com/photo-1546793665-c74683f339c1'],
          rating: 4.5,
          menuItems: ['Caesar Salad'],
          locationName: 'The Salad Spot',
          locationCity: 'New York',
          locationState: 'NY',
        },
      ],
    },
    {
      user: 'bob_foodie',
      posts: [
        {
          caption: '☕ This espresso art is incredible! Best coffee in SF.',
          mediaUrls: ['https://images.unsplash.com/photo-1514066558159-fc8c737ef259'],
          rating: 5.0,
          menuItems: ['Double Espresso', 'Croissant'],
          locationName: 'Blue Bottle Coffee',
          locationCity: 'San Francisco',
          locationState: 'CA',
        },
        {
          caption: '🍔 Impossible burger that actually tastes amazing! Must try.',
          mediaUrls: ['https://images.unsplash.com/photo-1550547660-d9450f859349'],
          rating: 4.5,
          menuItems: ['Impossible Burger', 'Sweet Potato Fries'],
          locationName: 'Gott\'s Roadside',
          locationCity: 'San Francisco',
          locationState: 'CA',
        },
      ],
    },
    {
      user: 'carol_eats',
      posts: [
        {
          caption: '🌮 Found the best street tacos in LA! Authentic and delicious.',
          mediaUrls: ['https://images.unsplash.com/photo-1565299585323-38d6b0865b47'],
          rating: 5.0,
          menuItems: ['Carne Asada Tacos', 'Al Pastor Tacos'],
          locationName: 'Leo\'s Tacos',
          locationCity: 'Los Angeles',
          locationState: 'CA',
        },
      ],
    },
    {
      user: 'david_dines',
      posts: [
        {
          caption: '🍣 Omakase night! Every piece was perfection. Worth every penny.',
          mediaUrls: ['https://images.unsplash.com/photo-1579584425555-c3ce17fd4351'],
          rating: 5.0,
          menuItems: ['Omakase Course'],
          locationName: 'Sushi Kashiba',
          locationCity: 'Seattle',
          locationState: 'WA',
        },
      ],
    },
    {
      user: 'emma_tastes',
      posts: [
        {
          caption: '🍰 This chocolate cake is heavenly! Best dessert in Boston.',
          mediaUrls: ['https://images.unsplash.com/photo-1578985545062-69928b1d9587'],
          rating: 5.0,
          menuItems: ['Chocolate Cake', 'Espresso'],
          locationName: 'Flour Bakery',
          locationCity: 'Boston',
          locationState: 'MA',
        },
      ],
    },
  ];

  const createdPosts: any[] = [];
  
  for (const template of postTemplates) {
    const user = testUsers.find(u => u.username === template.user);
    if (!user) continue;

    for (const postData of template.posts) {
      try {
        const post = await prisma.post.create({
          data: {
            userId: user.id,
            caption: postData.caption,
            mediaUrls: postData.mediaUrls,
            rating: postData.rating,
            menuItems: postData.menuItems,
            locationName: postData.locationName,
            locationCity: postData.locationCity,
            locationState: postData.locationState,
            locationCountry: 'USA',
          },
        });
        createdPosts.push(post);
        console.log(`✅ Created post by @${user.username}: ${postData.caption.substring(0, 40)}...`);
      } catch (error) {
        // Skip if already exists
      }
    }
  }

  console.log(`\n✅ Created ${createdPosts.length} new posts\n`);

  // ============================================
  // STEP 2: Create Friend Relationships
  // ============================================
  console.log('📝 Step 2: Creating friend relationships...\n');

  // Helper to get user by clerkId prefix
  const getUserByClerkPrefix = (prefix: string) => testUsers.find(u => u.clerkId === prefix);

  const friendshipDefs: Array<{
    senderId?: string;
    receiverId?: string;
    senderClerk?: string;
    receiverClerk?: string;
    status: string;
  }> = [
    // Your friendships (using user IDs, not clerkIds)
    { senderId: yourUser.id, receiverClerk: 'user_test_001', status: 'ACCEPTED' }, // alice
    { senderId: yourUser.id, receiverClerk: 'user_test_002', status: 'ACCEPTED' }, // bob
    { senderId: yourUser.id, receiverClerk: 'user_test_003', status: 'PENDING' },  // carol (pending)
    { senderClerk: 'user_test_004', receiverId: yourUser.id, status: 'PENDING' },  // david sent you request
    
    // Between test users
    { senderClerk: 'user_test_001', receiverClerk: 'user_test_002', status: 'ACCEPTED' }, // alice <-> bob
    { senderClerk: 'user_test_001', receiverClerk: 'user_test_003', status: 'ACCEPTED' }, // alice <-> carol
    { senderClerk: 'user_test_002', receiverClerk: 'user_test_004', status: 'ACCEPTED' }, // bob <-> david
    { senderClerk: 'user_test_003', receiverClerk: 'user_test_005', status: 'ACCEPTED' }, // carol <-> emma
  ];

  let friendCount = 0;
  for (const def of friendshipDefs) {
    try {
      // Resolve IDs
      const senderId = def.senderId || getUserByClerkPrefix(def.senderClerk!)?.id;
      const receiverId = def.receiverId || getUserByClerkPrefix(def.receiverClerk!)?.id;
      
      if (!senderId || !receiverId) {
        console.log(`⚠️ Skipping friendship: could not resolve user IDs`);
        continue;
      }

      const existing = await prisma.friend.findFirst({
        where: {
          OR: [
            { senderId, receiverId },
            { senderId: receiverId, receiverId: senderId },
          ],
        },
      });

      if (!existing) {
        await prisma.friend.create({
          data: {
            senderId,
            receiverId,
            status: def.status as any,
          },
        });
        friendCount++;
        const statusEmoji = def.status === 'ACCEPTED' ? '✅' : '⏳';
        console.log(`${statusEmoji} Created friendship: ${senderId.substring(0, 8)}... <-> ${receiverId.substring(0, 8)}...`);
      }
    } catch (error) {
      // Skip duplicates
    }
  }

  console.log(`\n✅ Created ${friendCount} new friendships\n`);

  // ============================================
  // STEP 3: Create Follows
  // ============================================
  console.log('📝 Step 3: Creating follow relationships...\n');

  const follows = [
    // You follow test users
    { follower: yourUser.id, following: testUsers[0]?.id },
    { follower: yourUser.id, following: testUsers[1]?.id },
    { follower: yourUser.id, following: testUsers[2]?.id },
    { follower: yourUser.id, following: testUsers[4]?.id },
    
    // Test users follow you
    { follower: testUsers[0]?.id, following: yourUser.id },
    { follower: testUsers[1]?.id, following: yourUser.id },
    { follower: testUsers[3]?.id, following: yourUser.id },
    
    // Between test users
    { follower: testUsers[0]?.id, following: testUsers[1]?.id },
    { follower: testUsers[1]?.id, following: testUsers[0]?.id },
    { follower: testUsers[2]?.id, following: testUsers[4]?.id },
  ];

  let followCount = 0;
  for (const follow of follows) {
    if (!follow.follower || !follow.following) continue;
    
    try {
      await prisma.follow.create({
        data: {
          followerId: follow.follower,
          followingId: follow.following,
        },
      });
      followCount++;
      console.log(`✅ Created follow relationship`);
    } catch (error) {
      // Skip duplicates
    }
  }

  console.log(`\n✅ Created ${followCount} new follows\n`);

  // ============================================
  // STEP 4: Create Likes
  // ============================================
  console.log('📝 Step 4: Creating likes on posts...\n');

  const allPosts = await prisma.post.findMany();
  let likeCount = 0;

  for (const post of allPosts) {
    // Random 2-4 users like each post
    const numLikes = Math.floor(Math.random() * 3) + 2;
    const randomUsers = testUsers.sort(() => 0.5 - Math.random()).slice(0, numLikes);
    
    for (const user of randomUsers) {
      try {
        await prisma.like.create({
          data: {
            postId: post.id,
            userId: user.id,
          },
        });
        likeCount++;
      } catch (error) {
        // Skip duplicates
      }
    }
  }

  // Update like counts
  for (const post of allPosts) {
    const count = await prisma.like.count({ where: { postId: post.id } });
    await prisma.post.update({
      where: { id: post.id },
      data: { likesCount: count },
    });
  }

  console.log(`✅ Created ${likeCount} likes\n`);

  // ============================================
  // STEP 5: Create Comments
  // ============================================
  console.log('📝 Step 5: Creating comments on posts...\n');

  const commentTemplates = [
    'This looks amazing! 😍',
    'I need to try this place!',
    'Best recommendation ever! 🙌',
    'Adding this to my list!',
    'Wow! How was it?',
    'This made me hungry! 😋',
    'Great photo! 📸',
    'Thanks for sharing!',
  ];

  let commentCount = 0;
  for (const post of allPosts.slice(0, 5)) {
    // 1-3 comments per post
    const numComments = Math.floor(Math.random() * 3) + 1;
    const randomUsers = testUsers.sort(() => 0.5 - Math.random()).slice(0, numComments);
    
    for (const user of randomUsers) {
      const comment = commentTemplates[Math.floor(Math.random() * commentTemplates.length)];
      try {
        await prisma.comment.create({
          data: {
            postId: post.id,
            authorId: user.id,
            content: comment,
          },
        });
        commentCount++;
      } catch (error) {
        // Continue
      }
    }
  }

  // Update comment counts
  for (const post of allPosts) {
    const count = await prisma.comment.count({ where: { postId: post.id } });
    await prisma.post.update({
      where: { id: post.id },
      data: { commentsCount: count },
    });
  }

  console.log(`✅ Created ${commentCount} comments\n`);

  // ============================================
  // STEP 6: Create Lists
  // ============================================
  console.log('📝 Step 6: Creating lists...\n');

  const listTemplates = [
    {
      name: 'Best Pizza Places',
      description: 'My favorite pizza spots in NYC',
      userId: yourUser.id,
    },
    {
      name: 'Coffee Shops',
      description: 'Great coffee places to work from',
      userId: yourUser.id,
    },
    {
      name: 'Must Try Restaurants',
      description: 'Places I want to visit',
      userId: testUsers[0]?.id,
    },
  ];

  let listCount = 0;
  for (const listData of listTemplates) {
    if (!listData.userId) continue;
    
    try {
      const list = await prisma.list.create({
        data: listData,
      });
      listCount++;
      console.log(`✅ Created list: ${listData.name}`);
      
      // Add some posts to the list
      const postsToAdd = allPosts.slice(0, 2);
      for (const post of postsToAdd) {
        try {
          await prisma.listPost.create({
            data: {
              listId: list.id,
              postId: post.id,
            },
          });
        } catch (error) {
          // Skip
        }
      }
    } catch (error) {
      // Skip duplicates
    }
  }

  console.log(`\n✅ Created ${listCount} lists\n`);

  // ============================================
  // FINAL STATISTICS
  // ============================================
  const endTime = Date.now();
  const duration = ((endTime - startTime) / 1000).toFixed(2);

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📊 Test Data Creation Complete!');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  const stats = {
    users: await prisma.user.count(),
    posts: await prisma.post.count(),
    comments: await prisma.comment.count(),
    likes: await prisma.like.count(),
    bookmarks: await prisma.bookmark.count(),
    friends: await prisma.friend.count(),
    follows: await prisma.follow.count(),
    lists: await prisma.list.count(),
    chatrooms: await prisma.chatroom.count(),
    notifications: await prisma.notification.count(),
  };

  console.log('📊 Database Statistics:\n');
  Object.entries(stats).forEach(([key, count]) => {
    const icon = count > 0 ? '✅' : '⭕';
    console.log(`   ${icon} ${key.padEnd(15)} ${count}`);
  });

  console.log(`\n⏱️  Completed in ${duration}s\n`);

  // Show your account stats
  const yourFriends = await prisma.friend.count({
    where: {
      OR: [
        { senderId: yourUser.clerkId, status: 'ACCEPTED' },
        { receiverId: yourUser.clerkId, status: 'ACCEPTED' },
      ],
    },
  });

  const yourFollowers = await prisma.follow.count({
    where: { followingId: yourUser.id },
  });

  const yourFollowing = await prisma.follow.count({
    where: { followerId: yourUser.id },
  });

  console.log('👤 Your Account Stats:\n');
  console.log(`   Friends:         ${yourFriends}`);
  console.log(`   Followers:       ${yourFollowers}`);
  console.log(`   Following:       ${yourFollowing}`);
  console.log(`   Posts:           ${await prisma.post.count({ where: { userId: yourUser.id } })}`);
  console.log(`   Lists:           ${await prisma.list.count({ where: { userId: yourUser.id } })}\n`);

  console.log('📱 Test in iOS App:');
  console.log('   1. Log in with: rougepctech@gmail.com');
  console.log('   2. View your friends (Alice, Bob)');
  console.log('   3. See pending requests (Carol sent, David received)');
  console.log('   4. Browse posts in feed');
  console.log('   5. See likes and comments');
  console.log('   6. View your lists\n');

  console.log('✅ Rich test data created successfully!\n');
}

main()
  .catch((e) => {
    console.error('❌ Error:', e.message);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

