/**
 * Prefill Test Data for kavyuwu
 * This script populates the database with test friends, posts, likes, comments, etc.
 * specifically for the kavyuwu user account.
 */

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// Target user's clerkId (kavyuwu)
const KAVYUWU_CLERK_ID = 'user_35KEqmF7tbWeHKWa1oP3PRTpBDX';

// Test users to create
const testUsers = [
  {
    clerkId: 'user_test_alice_001',
    email: 'alice.foodie@test.com',
    username: 'alice_foodie',
    name: 'Alice Chen',
    bio: 'Food photographer 📸 | NYC based | Always hunting for the perfect shot 🍕',
    profileImage: 'https://i.pravatar.cc/150?img=1',
  },
  {
    clerkId: 'user_test_bob_002',
    email: 'bob.eats@test.com',
    username: 'bob_eats',
    name: 'Bob Martinez',
    bio: 'Coffee enthusiast ☕ | SF Bay Area | Brunch is my cardio 🥞',
    profileImage: 'https://i.pravatar.cc/150?img=2',
  },
  {
    clerkId: 'user_test_carol_003',
    email: 'carol.taste@test.com',
    username: 'carol_tastes',
    name: 'Carol Johnson',
    bio: 'Restaurant blogger | LA | Tacos are life 🌮',
    profileImage: 'https://i.pravatar.cc/150?img=3',
  },
  {
    clerkId: 'user_test_david_004',
    email: 'david.dines@test.com',
    username: 'david_dines',
    name: 'David Kim',
    bio: 'Sushi connoisseur 🍣 | Seattle | Tech by day, foodie by night',
    profileImage: 'https://i.pravatar.cc/150?img=4',
  },
  {
    clerkId: 'user_test_emma_005',
    email: 'emma.bakes@test.com',
    username: 'emma_bakes',
    name: 'Emma Wilson',
    bio: 'Pastry chef 🍰 | Boston | Sweet tooth extraordinaire',
    profileImage: 'https://i.pravatar.cc/150?img=5',
  },
  {
    clerkId: 'user_test_frank_006',
    email: 'frank.grills@test.com',
    username: 'frank_grills',
    name: 'Frank Lopez',
    bio: 'BBQ master 🔥 | Austin, TX | Smoke & fire enthusiast',
    profileImage: 'https://i.pravatar.cc/150?img=6',
  },
  {
    clerkId: 'user_test_grace_007',
    email: 'grace.greens@test.com',
    username: 'grace_greens',
    name: 'Grace Taylor',
    bio: 'Plant-based foodie 🥗 | Portland | Farm to table advocate',
    profileImage: 'https://i.pravatar.cc/150?img=7',
  },
  {
    clerkId: 'user_test_henry_008',
    email: 'henry.spice@test.com',
    username: 'henry_spice',
    name: 'Henry Brown',
    bio: 'Spice hunter 🌶️ | Chicago | International cuisine explorer',
    profileImage: 'https://i.pravatar.cc/150?img=8',
  },
];

// Posts to create for test users
const postTemplates = [
  {
    username: 'alice_foodie',
    posts: [
      {
        caption: '🍕 The perfect slice doesn\'t exi— wait, yes it does! Found this gem in Brooklyn. Crispy crust, fresh mozzarella, and that perfect cheese pull. 10/10 would queue again! #pizza #nyc #foodie',
        mediaUrls: ['https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800'],
        rating: 5.0,
        menuItems: ['Margherita Pizza', 'Pepperoni Pizza'],
        locationName: "Luigi's Authentic Pizza",
        locationCity: 'New York',
        locationState: 'NY',
        locationLatitude: 40.6892,
        locationLongitude: -73.9442,
      },
      {
        caption: '🥗 This caesar salad hit different. Homemade croutons, aged parmesan, and that anchovy dressing is *chef\'s kiss*. Simple done right.',
        mediaUrls: ['https://images.unsplash.com/photo-1546793665-c74683f339c1?w=800'],
        rating: 4.5,
        menuItems: ['Classic Caesar Salad'],
        locationName: 'The Garden Bistro',
        locationCity: 'New York',
        locationState: 'NY',
        locationLatitude: 40.7128,
        locationLongitude: -74.0060,
      },
    ],
  },
  {
    username: 'bob_eats',
    posts: [
      {
        caption: '☕ Third wave coffee done RIGHT. This single origin Ethiopian has notes of blueberry and chocolate. The latte art is just showing off at this point.',
        mediaUrls: ['https://images.unsplash.com/photo-1514066558159-fc8c737ef259?w=800'],
        rating: 5.0,
        menuItems: ['Single Origin Pour Over', 'Almond Croissant'],
        locationName: 'Ritual Coffee Roasters',
        locationCity: 'San Francisco',
        locationState: 'CA',
        locationLatitude: 37.7749,
        locationLongitude: -122.4194,
      },
      {
        caption: '🍔 Impossible burger that fooled even this meat lover. Juicy, flavorful, and those sweet potato fries? Addictive.',
        mediaUrls: ['https://images.unsplash.com/photo-1550547660-d9450f859349?w=800'],
        rating: 4.5,
        menuItems: ['Impossible Burger', 'Sweet Potato Fries', 'Craft Beer'],
        locationName: 'Gott\'s Roadside',
        locationCity: 'San Francisco',
        locationState: 'CA',
        locationLatitude: 37.8024,
        locationLongitude: -122.4058,
      },
    ],
  },
  {
    username: 'carol_tastes',
    posts: [
      {
        caption: '🌮 Street tacos at 2am hit different. Al pastor with fresh pineapple, homemade salsa verde, and the most perfect corn tortillas. This is the way.',
        mediaUrls: ['https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=800'],
        rating: 5.0,
        menuItems: ['Al Pastor Tacos', 'Carne Asada Tacos', 'Horchata'],
        locationName: 'Leo\'s Tacos Truck',
        locationCity: 'Los Angeles',
        locationState: 'CA',
        locationLatitude: 34.0522,
        locationLongitude: -118.2437,
      },
      {
        caption: '🌯 This burrito is the size of my head and I\'m not complaining. Carnitas, guac, fresh pico, and the most perfect rice. Food coma incoming.',
        mediaUrls: ['https://images.unsplash.com/photo-1626700051175-6818013e1d4f?w=800'],
        rating: 4.8,
        menuItems: ['Carnitas Burrito', 'Chips & Guac'],
        locationName: 'La Taqueria',
        locationCity: 'Los Angeles',
        locationState: 'CA',
        locationLatitude: 34.0195,
        locationLongitude: -118.4912,
      },
    ],
  },
  {
    username: 'david_dines',
    posts: [
      {
        caption: '🍣 Omakase night! 18 courses of pure perfection. The otoro melted like butter, and that uni was straight from Hokkaido. Worth every penny.',
        mediaUrls: ['https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=800'],
        rating: 5.0,
        menuItems: ['Omakase Course', 'Sake Pairing'],
        locationName: 'Sushi Kashiba',
        locationCity: 'Seattle',
        locationState: 'WA',
        locationLatitude: 47.6062,
        locationLongitude: -122.3321,
      },
    ],
  },
  {
    username: 'emma_bakes',
    posts: [
      {
        caption: '🍰 This chocolate lava cake is literally lava. Molten center, vanilla bean ice cream, and a sprinkle of sea salt. Dessert perfection.',
        mediaUrls: ['https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=800'],
        rating: 5.0,
        menuItems: ['Chocolate Lava Cake', 'Espresso'],
        locationName: 'Flour Bakery',
        locationCity: 'Boston',
        locationState: 'MA',
        locationLatitude: 42.3601,
        locationLongitude: -71.0589,
      },
      {
        caption: '🥐 Croissant game strong at this new French bakery. Layers upon layers of buttery goodness. The pain au chocolat is life-changing.',
        mediaUrls: ['https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=800'],
        rating: 4.9,
        menuItems: ['Butter Croissant', 'Pain au Chocolat', 'Café au Lait'],
        locationName: 'Maison Kayser',
        locationCity: 'Boston',
        locationState: 'MA',
        locationLatitude: 42.3554,
        locationLongitude: -71.0640,
      },
    ],
  },
  {
    username: 'frank_grills',
    posts: [
      {
        caption: '🔥 14 hours of smoking and it was WORTH IT. Brisket with the perfect bark, pulled pork that melts in your mouth, and homemade pickles. Texas BBQ forever.',
        mediaUrls: ['https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?w=800'],
        rating: 5.0,
        menuItems: ['Smoked Brisket', 'Pulled Pork', 'Mac & Cheese'],
        locationName: 'Franklin Barbecue',
        locationCity: 'Austin',
        locationState: 'TX',
        locationLatitude: 30.2672,
        locationLongitude: -97.7431,
      },
    ],
  },
  {
    username: 'grace_greens',
    posts: [
      {
        caption: '🥗 This Buddha bowl is everything! Quinoa, roasted veggies, tahini dressing, and the most beautiful presentation. Healthy never looked so good.',
        mediaUrls: ['https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800'],
        rating: 4.8,
        menuItems: ['Buddha Bowl', 'Green Smoothie'],
        locationName: 'Harlow PDX',
        locationCity: 'Portland',
        locationState: 'OR',
        locationLatitude: 45.5152,
        locationLongitude: -122.6784,
      },
    ],
  },
  {
    username: 'henry_spice',
    posts: [
      {
        caption: '🌶️ This Thai curry set my mouth on fire and I loved every second. Authentic flavors, fresh herbs, and that coconut milk balance. Spice level: YES.',
        mediaUrls: ['https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=800'],
        rating: 4.9,
        menuItems: ['Green Curry', 'Pad Thai', 'Thai Iced Tea'],
        locationName: 'Aroy Thai',
        locationCity: 'Chicago',
        locationState: 'IL',
        locationLatitude: 41.8781,
        locationLongitude: -87.6298,
      },
    ],
  },
];

const commentTemplates = [
  'This looks absolutely amazing! 😍',
  'I need to try this place ASAP!',
  'Omg the presentation is everything 🤤',
  'Adding this to my must-try list!',
  'How was the wait time?',
  'Best rec ever! 🙌',
  'This made me so hungry 😋',
  'Great shot! What camera do you use?',
  'The vibes look immaculate ✨',
  'You always find the best spots!',
  'Is this place reservation only?',
  'That looks incredible! 🔥',
  'Worth the hype?',
  'My mouth is watering rn',
  'Need this in my life immediately',
];

async function main() {
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('🎨 Prefilling Test Data for kavyuwu');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  const startTime = Date.now();

  // Find kavyuwu user
  const kavyuwu = await prisma.user.findUnique({
    where: { clerkId: KAVYUWU_CLERK_ID },
  });

  if (!kavyuwu) {
    console.log('❌ kavyuwu user not found. Please log into the app first.');
    return;
  }

  console.log(`✅ Found kavyuwu: ${kavyuwu.name} (@${kavyuwu.username})\n`);

  // ============================================
  // STEP 1: Create/Update Test Users
  // ============================================
  console.log('📝 Step 1: Creating test users...\n');

  const createdUsers: any[] = [];
  for (const userData of testUsers) {
    try {
      const user = await prisma.user.upsert({
        where: { clerkId: userData.clerkId },
        update: {
          email: userData.email,
          username: userData.username,
          name: userData.name,
          bio: userData.bio,
          profileImage: userData.profileImage,
        },
        create: userData,
      });
      createdUsers.push(user);
      console.log(`✅ Created/Updated user: @${user.username}`);
    } catch (error: any) {
      console.log(`⚠️ Skipping ${userData.username}: ${error.message}`);
    }
  }

  console.log(`\n✅ ${createdUsers.length} test users ready\n`);

  // ============================================
  // STEP 2: Create Friend Relationships
  // ============================================
  console.log('📝 Step 2: Creating friendships...\n');

  // kavyuwu's friends (ACCEPTED)
  const friendUsernames = ['alice_foodie', 'bob_eats', 'carol_tastes', 'david_dines'];
  // Pending requests TO kavyuwu
  const pendingFromUsernames = ['emma_bakes', 'frank_grills'];
  // Pending requests FROM kavyuwu
  const pendingToUsernames = ['grace_greens'];

  let friendCount = 0;

  // Create ACCEPTED friendships
  for (const username of friendUsernames) {
    const friend = createdUsers.find(u => u.username === username);
    if (!friend) continue;

    try {
      const existing = await prisma.friend.findFirst({
        where: {
          OR: [
            { senderId: kavyuwu.id, receiverId: friend.id },
            { senderId: friend.id, receiverId: kavyuwu.id },
          ],
        },
      });

      if (!existing) {
        await prisma.friend.create({
          data: {
            senderId: friend.id,
            receiverId: kavyuwu.id,
            status: 'ACCEPTED',
          },
        });
        friendCount++;
        console.log(`✅ Friendship: @${username} <-> @${kavyuwu.username}`);
      } else {
        console.log(`⏭️ Friendship already exists: @${username}`);
      }
    } catch (error) {
      // Skip duplicates
    }
  }

  // Create PENDING requests TO kavyuwu
  for (const username of pendingFromUsernames) {
    const friend = createdUsers.find(u => u.username === username);
    if (!friend) continue;

    try {
      const existing = await prisma.friend.findFirst({
        where: {
          OR: [
            { senderId: kavyuwu.id, receiverId: friend.id },
            { senderId: friend.id, receiverId: kavyuwu.id },
          ],
        },
      });

      if (!existing) {
        await prisma.friend.create({
          data: {
            senderId: friend.id,
            receiverId: kavyuwu.id,
            status: 'PENDING',
          },
        });
        friendCount++;
        console.log(`⏳ Pending request from: @${username} -> @${kavyuwu.username}`);
      }
    } catch (error) {
      // Skip duplicates
    }
  }

  // Create PENDING requests FROM kavyuwu
  for (const username of pendingToUsernames) {
    const friend = createdUsers.find(u => u.username === username);
    if (!friend) continue;

    try {
      const existing = await prisma.friend.findFirst({
        where: {
          OR: [
            { senderId: kavyuwu.id, receiverId: friend.id },
            { senderId: friend.id, receiverId: kavyuwu.id },
          ],
        },
      });

      if (!existing) {
        await prisma.friend.create({
          data: {
            senderId: kavyuwu.id,
            receiverId: friend.id,
            status: 'PENDING',
          },
        });
        friendCount++;
        console.log(`⏳ Pending request from: @${kavyuwu.username} -> @${username}`);
      }
    } catch (error) {
      // Skip duplicates
    }
  }

  console.log(`\n✅ Created ${friendCount} new friend relationships\n`);

  // ============================================
  // STEP 3: Create Follow Relationships
  // ============================================
  console.log('📝 Step 3: Creating follow relationships...\n');

  let followCount = 0;

  // kavyuwu follows all test users
  for (const user of createdUsers) {
    try {
      await prisma.follow.upsert({
        where: {
          followerId_followingId: {
            followerId: kavyuwu.id,
            followingId: user.id,
          },
        },
        update: {},
        create: {
          followerId: kavyuwu.id,
          followingId: user.id,
        },
      });
      followCount++;
    } catch (error) {
      // Skip duplicates
    }
  }

  // Some test users follow kavyuwu back
  const followBackUsers = createdUsers.slice(0, 5);
  for (const user of followBackUsers) {
    try {
      await prisma.follow.upsert({
        where: {
          followerId_followingId: {
            followerId: user.id,
            followingId: kavyuwu.id,
          },
        },
        update: {},
        create: {
          followerId: user.id,
          followingId: kavyuwu.id,
        },
      });
      followCount++;
    } catch (error) {
      // Skip duplicates
    }
  }

  // Update follower/following counts
  await prisma.user.update({
    where: { id: kavyuwu.id },
    data: {
      followingCount: createdUsers.length,
      followerCount: followBackUsers.length,
    },
  });

  console.log(`✅ Created ${followCount} follow relationships\n`);

  // ============================================
  // STEP 4: Create Posts for Test Users
  // ============================================
  console.log('📝 Step 4: Creating posts for test users...\n');

  const createdPosts: any[] = [];

  for (const template of postTemplates) {
    const user = createdUsers.find(u => u.username === template.username);
    if (!user) continue;

    for (const postData of template.posts) {
      try {
        // Check if similar post exists
        const existing = await prisma.post.findFirst({
          where: {
            userId: user.id,
            caption: postData.caption.substring(0, 50),
          },
        });

        if (!existing) {
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
              locationLatitude: postData.locationLatitude,
              locationLongitude: postData.locationLongitude,
            },
          });
          createdPosts.push(post);
          console.log(`✅ Created post by @${user.username}: ${postData.caption.substring(0, 40)}...`);
        }
      } catch (error) {
        // Skip if already exists
      }
    }
  }

  console.log(`\n✅ Created ${createdPosts.length} new posts\n`);

  // ============================================
  // STEP 5: Create Likes
  // ============================================
  console.log('📝 Step 5: Creating likes on posts...\n');

  const allPosts = await prisma.post.findMany({
    where: {
      userId: { in: createdUsers.map(u => u.id) },
    },
  });

  let likeCount = 0;

  // kavyuwu likes some posts
  for (const post of allPosts.slice(0, 8)) {
    try {
      await prisma.like.upsert({
        where: {
          postId_userId: {
            postId: post.id,
            userId: kavyuwu.id,
          },
        },
        update: {},
        create: {
          postId: post.id,
          userId: kavyuwu.id,
        },
      });
      likeCount++;
    } catch (error) {
      // Skip duplicates
    }
  }

  // Test users like each other's posts
  for (const post of allPosts) {
    const numLikes = Math.floor(Math.random() * 4) + 2;
    const randomUsers = createdUsers.sort(() => 0.5 - Math.random()).slice(0, numLikes);

    for (const user of randomUsers) {
      if (user.id === post.userId) continue; // Don't like own posts
      try {
        await prisma.like.upsert({
          where: {
            postId_userId: {
              postId: post.id,
              userId: user.id,
            },
          },
          update: {},
          create: {
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
  // STEP 6: Create Comments
  // ============================================
  console.log('📝 Step 6: Creating comments on posts...\n');

  let commentCount = 0;

  for (const post of allPosts) {
    const numComments = Math.floor(Math.random() * 3) + 1;
    const randomUsers = [...createdUsers, kavyuwu].sort(() => 0.5 - Math.random()).slice(0, numComments);

    for (const user of randomUsers) {
      if (user.id === post.userId) continue; // Don't comment on own posts
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
        // Continue on error
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
  // STEP 7: Create Lists for kavyuwu
  // ============================================
  console.log('📝 Step 7: Creating lists for kavyuwu...\n');

  const listTemplates = [
    {
      name: 'Must Try Spots 🔥',
      description: 'Places I absolutely need to visit',
    },
    {
      name: 'Coffee Havens ☕',
      description: 'Best coffee shops for remote work',
    },
    {
      name: 'Date Night Ideas 💕',
      description: 'Perfect spots for special occasions',
    },
  ];

  let listCount = 0;
  for (const listData of listTemplates) {
    try {
      const existing = await prisma.list.findFirst({
        where: {
          userId: kavyuwu.id,
          name: listData.name,
        },
      });

      if (!existing) {
        const list = await prisma.list.create({
          data: {
            userId: kavyuwu.id,
            name: listData.name,
            description: listData.description,
          },
        });

        // Add some posts to the list
        const postsToAdd = allPosts.slice(0, 3);
        for (const post of postsToAdd) {
          try {
            await prisma.listPost.create({
              data: {
                listId: list.id,
                postId: post.id,
              },
            });
          } catch (error) {
            // Skip duplicates
          }
        }

        listCount++;
        console.log(`✅ Created list: ${listData.name}`);
      }
    } catch (error) {
      // Skip duplicates
    }
  }

  console.log(`\n✅ Created ${listCount} lists\n`);

  // ============================================
  // STEP 8: Create Notifications for kavyuwu
  // ============================================
  console.log('📝 Step 8: Creating notifications for kavyuwu...\n');

  const notificationTypes = [
    {
      type: 'FRIEND_REQUEST' as const,
      title: 'New Friend Request',
      message: 'Emma Wilson sent you a friend request',
    },
    {
      type: 'FRIEND_REQUEST' as const,
      title: 'New Friend Request',
      message: 'Frank Lopez sent you a friend request',
    },
    {
      type: 'POST_LIKE' as const,
      title: 'New Like',
      message: 'Alice Chen liked your post',
    },
    {
      type: 'COMMENT' as const,
      title: 'New Comment',
      message: 'Bob Martinez commented on your post',
    },
    {
      type: 'FOLLOW' as const,
      title: 'New Follower',
      message: 'Carol Johnson started following you',
    },
  ];

  let notifCount = 0;
  for (const notif of notificationTypes) {
    try {
      await prisma.notification.create({
        data: {
          userId: kavyuwu.id,
          type: notif.type,
          title: notif.title,
          message: notif.message,
          read: false,
        },
      });
      notifCount++;
    } catch (error) {
      // Continue on error
    }
  }

  console.log(`✅ Created ${notifCount} notifications\n`);

  // ============================================
  // STEP 9: Update User Post Counts
  // ============================================
  console.log('📝 Step 9: Updating user statistics...\n');

  for (const user of createdUsers) {
    const postCount = await prisma.post.count({ where: { userId: user.id } });
    await prisma.user.update({
      where: { id: user.id },
      data: { postsCount: postCount },
    });
  }

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
    friends: await prisma.friend.count(),
    follows: await prisma.follow.count(),
    lists: await prisma.list.count(),
    notifications: await prisma.notification.count(),
  };

  console.log('📊 Database Statistics:\n');
  Object.entries(stats).forEach(([key, count]) => {
    const icon = count > 0 ? '✅' : '⭕';
    console.log(`   ${icon} ${key.padEnd(15)} ${count}`);
  });

  // kavyuwu specific stats
  const kavyuwuFriends = await prisma.friend.count({
    where: {
      OR: [
        { senderId: kavyuwu.id, status: 'ACCEPTED' },
        { receiverId: kavyuwu.id, status: 'ACCEPTED' },
      ],
    },
  });

  const kavyuwuPending = await prisma.friend.count({
    where: {
      receiverId: kavyuwu.id,
      status: 'PENDING',
    },
  });

  const kavyuwuFollowers = await prisma.follow.count({
    where: { followingId: kavyuwu.id },
  });

  const kavyuwuFollowing = await prisma.follow.count({
    where: { followerId: kavyuwu.id },
  });

  console.log(`\n👤 kavyuwu's Account Stats:\n`);
  console.log(`   Friends:          ${kavyuwuFriends}`);
  console.log(`   Pending Requests: ${kavyuwuPending}`);
  console.log(`   Followers:        ${kavyuwuFollowers}`);
  console.log(`   Following:        ${kavyuwuFollowing}`);
  console.log(`   Notifications:    ${await prisma.notification.count({ where: { userId: kavyuwu.id, read: false } })} unread\n`);

  console.log(`⏱️  Completed in ${duration}s\n`);

  console.log('📱 What to test in the iOS app:');
  console.log('   1. Friends tab - see 4 accepted friends');
  console.log('   2. Friend requests - 2 pending requests to accept');
  console.log('   3. Home feed - posts from followed users');
  console.log('   4. Notifications - friend requests, likes, comments');
  console.log('   5. Lists - 3 curated lists with posts');
  console.log('   6. Profile - follower/following counts\n');

  console.log('✅ Test data prefilled successfully for @kavyuwu!\n');
}

main()
  .catch((e) => {
    console.error('❌ Error:', e.message);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

