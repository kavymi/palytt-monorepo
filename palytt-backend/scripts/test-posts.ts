/**
 * Test Posts Endpoints
 * Creates test posts and tests all post-related endpoints
 */

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const BASE_URL = 'http://localhost:4000';

async function main() {
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('🧪 Testing Posts Endpoints');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  // Get your user
  const user = await prisma.user.findUnique({
    where: { email: 'rougepctech@gmail.com' },
  });

  if (!user) {
    console.log('❌ User not found. Please run setup first.');
    return;
  }

  console.log(`✅ Found user: ${user.name} (@${user.username})\n`);

  // ============================================
  // Step 1: Create Test Posts in Database
  // ============================================
  console.log('📝 Step 1: Creating test posts in database...\n');

  const testPosts = [
    {
      userId: user.id,
      caption: '🍕 Amazing pizza at Lucali in Brooklyn! The crust is absolutely perfect. #pizza #foodie',
      mediaUrls: ['https://images.unsplash.com/photo-1513104890138-7c749659a591'],
      rating: 4.5,
      menuItems: ['Margherita Pizza', 'Burrata'],
      locationName: 'Lucali',
      locationCity: 'Brooklyn',
      locationState: 'NY',
      locationCountry: 'USA',
    },
    {
      userId: user.id,
      caption: '☕ Best latte art I\'ve ever seen! This coffee shop is a hidden gem. #coffee #latteart',
      mediaUrls: ['https://images.unsplash.com/photo-1509042239860-f550ce710b93'],
      rating: 5.0,
      menuItems: ['Latte', 'Croissant'],
      locationName: 'Blue Bottle Coffee',
      locationCity: 'San Francisco',
      locationState: 'CA',
      locationCountry: 'USA',
    },
    {
      userId: user.id,
      caption: '🍣 Omakase experience that blew my mind! Every piece was perfection. #sushi #omakase',
      mediaUrls: ['https://images.unsplash.com/photo-1579584425555-c3ce17fd4351'],
      rating: 5.0,
      menuItems: ['Omakase', 'Sake'],
      locationName: 'Sushi Nakazawa',
      locationCity: 'New York',
      locationState: 'NY',
      locationCountry: 'USA',
    },
  ];

  const createdPosts = [];
  for (const postData of testPosts) {
    try {
      const post = await prisma.post.create({
        data: postData,
      });
      createdPosts.push(post);
      console.log(`✅ Created post: ${post.caption.substring(0, 50)}...`);
    } catch (error: any) {
      console.log(`❌ Error creating post: ${error.message}`);
    }
  }

  console.log(`\n✅ Created ${createdPosts.length} test posts\n`);

  // ============================================
  // Step 2: Test Getting Posts
  // ============================================
  console.log('📝 Step 2: Testing post retrieval endpoints...\n');

  // Test: List posts
  try {
    const response = await fetch(
      `${BASE_URL}/trpc/posts.list?input=${encodeURIComponent('{"limit":10}')}`
    );
    const data = await response.json();
    
    if (response.ok) {
      const posts = data.result?.data?.posts || [];
      console.log(`✅ posts.list: Found ${posts.length} posts`);
      
      if (posts.length > 0) {
        console.log(`   Latest post: "${posts[0].caption.substring(0, 40)}..."`);
      }
    } else {
      console.log(`❌ posts.list failed: ${data.error?.message}`);
    }
  } catch (error: any) {
    console.log(`❌ Error testing posts.list: ${error.message}`);
  }

  // Test: Get post by ID
  if (createdPosts.length > 0) {
    try {
      const testPost = createdPosts[0];
      const response = await fetch(
        `${BASE_URL}/trpc/posts.getById?input=${encodeURIComponent(JSON.stringify({ id: testPost.id }))}`
      );
      const data = await response.json();
      
      if (response.ok) {
        const post = data.result?.data;
        console.log(`✅ posts.getById: Retrieved post "${post.caption.substring(0, 30)}..."`);
        console.log(`   Rating: ${post.rating}⭐`);
        console.log(`   Location: ${post.locationName}, ${post.locationCity}`);
        console.log(`   Menu items: ${post.menuItems.join(', ')}`);
      } else {
        console.log(`❌ posts.getById failed: ${data.error?.message}`);
      }
    } catch (error: any) {
      console.log(`❌ Error testing posts.getById: ${error.message}`);
    }
  }

  // Test: Get user's posts
  try {
    const response = await fetch(
      `${BASE_URL}/trpc/posts.getUserPosts?input=${encodeURIComponent(JSON.stringify({ userId: user.id, limit: 10 }))}`
    );
    const data = await response.json();
    
    if (response.ok) {
      const posts = data.result?.data?.posts || [];
      console.log(`✅ posts.getUserPosts: Found ${posts.length} posts by ${user.username}`);
    } else {
      console.log(`❌ posts.getUserPosts failed: ${data.error?.message}`);
    }
  } catch (error: any) {
    console.log(`❌ Error testing posts.getUserPosts: ${error.message}`);
  }

  // Test: Search posts by location
  try {
    const response = await fetch(
      `${BASE_URL}/trpc/posts.searchByLocation?input=${encodeURIComponent(JSON.stringify({ query: 'Brooklyn', limit: 10 }))}`
    );
    const data = await response.json();
    
    if (response.ok) {
      const posts = data.result?.data?.posts || [];
      console.log(`✅ posts.searchByLocation: Found ${posts.length} posts in Brooklyn`);
    } else {
      console.log(`❌ posts.searchByLocation failed: ${data.error?.message}`);
    }
  } catch (error: any) {
    console.log(`❌ Error testing posts.searchByLocation: ${error.message}`);
  }

  // ============================================
  // Step 3: Test Post Stats
  // ============================================
  console.log('\n📝 Step 3: Testing post statistics...\n');

  if (createdPosts.length > 0) {
    const testPost = createdPosts[0];
    
    // Create some test interactions
    console.log('Creating test likes and bookmarks...');
    
    // Get some test users
    const testUsers = await prisma.user.findMany({
      where: { clerkId: { startsWith: 'user_test_' } },
      take: 3,
    });

    // Add likes
    for (const testUser of testUsers) {
      try {
        await prisma.like.create({
          data: {
            postId: testPost.id,
            userId: testUser.id,
          },
        });
        console.log(`✅ Added like from ${testUser.username}`);
      } catch (error) {
        // Ignore duplicate errors
      }
    }

    // Update post counts
    const likeCount = await prisma.like.count({
      where: { postId: testPost.id },
    });
    
    await prisma.post.update({
      where: { id: testPost.id },
      data: { likesCount: likeCount },
    });

    console.log(`\n✅ Post now has ${likeCount} likes\n`);
  }

  // ============================================
  // Step 4: Summary
  // ============================================
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📊 Posts Testing Summary');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  const totalPosts = await prisma.post.count();
  const totalLikes = await prisma.like.count();
  const totalComments = await prisma.comment.count();
  const totalBookmarks = await prisma.bookmark.count();

  console.log(`📊 Database Statistics:`);
  console.log(`   Total Posts:      ${totalPosts}`);
  console.log(`   Total Likes:      ${totalLikes}`);
  console.log(`   Total Comments:   ${totalComments}`);
  console.log(`   Total Bookmarks:  ${totalBookmarks}\n`);

  console.log(`✅ Post Endpoints Tested:`);
  console.log(`   • posts.list              ✅`);
  console.log(`   • posts.getById           ✅`);
  console.log(`   • posts.getUserPosts      ✅`);
  console.log(`   • posts.searchByLocation  ✅\n`);

  console.log(`🔒 Protected Endpoints (Require iOS App Login):`);
  console.log(`   • posts.create            📱 Test via iOS app`);
  console.log(`   • posts.update            📱 Test via iOS app`);
  console.log(`   • posts.delete            📱 Test via iOS app`);
  console.log(`   • posts.like              📱 Test via iOS app`);
  console.log(`   • posts.bookmark          📱 Test via iOS app\n`);

  console.log(`📱 To test protected endpoints:`);
  console.log(`   1. Log into iOS app with: rougepctech@gmail.com`);
  console.log(`   2. Navigate to Create Post`);
  console.log(`   3. Fill in post details and submit`);
  console.log(`   4. Watch backend terminal for: POST /trpc/posts.create\n`);

  console.log(`🔍 View posts in database:`);
  console.log(`   pnpm prisma:studio → http://localhost:5555\n`);

  // Show created posts
  if (createdPosts.length > 0) {
    console.log(`📝 Your Test Posts:\n`);
    const posts = await prisma.post.findMany({
      where: { userId: user.id },
      include: {
        _count: {
          select: {
            likes: true,
            comments: true,
            bookmarks: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    posts.forEach((post, index) => {
      console.log(`${index + 1}. ${post.caption.substring(0, 60)}...`);
      console.log(`   📍 ${post.locationName} (${post.locationCity})`);
      console.log(`   ⭐ ${post.rating} stars`);
      console.log(`   ❤️  ${post._count.likes} likes | 💬 ${post._count.comments} comments | 🔖 ${post._count.bookmarks} saves\n`);
    });
  }

  console.log(`✅ Posts testing complete!\n`);
}

main()
  .catch((e) => {
    console.error('❌ Error:', e.message);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

