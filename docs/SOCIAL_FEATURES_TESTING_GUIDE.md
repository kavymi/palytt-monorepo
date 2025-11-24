# Social Features Testing Guide - Palytt

**Date:** November 19, 2025  
**App Version:** Debug Build  
**Simulator:** iPhone 16 Pro (iOS 18.6)  
**Status:** ✅ App Built and Running

---

## 🎯 Quick Start

The Palytt app is now **running on the iPhone 16 Pro simulator** and ready for testing all social features.

### Current Status
- ✅ **App Built Successfully** - No compilation errors
- ✅ **Installed on Simulator** - Ready to test
- ✅ **Backend Available** - http://localhost:4000 (if running)
- ✅ **All Social Features Implemented** - 41+ endpoints, 6 major areas

---

## 📱 Manual Testing Checklist

### 1. Friends System Testing (Priority: High)

#### Add Friends Flow
1. **Launch the app** on simulator
2. **Navigate to Profile** → tap on "Friends" or similar
3. **Tap "Add Friends"** button
4. **Test Search:**
   - Type a username in search bar
   - Verify debounced search (500ms delay)
   - Check results display with avatars
5. **Test Filters:**
   - Tap filter icon
   - Enable "Verified users only"
   - Test location filtering (if available)
   - Test dietary preference filters
6. **Send Friend Request:**
   - Tap "Add Friend" on a user
   - Verify loading state
   - Check for success feedback
7. **View Suggested Friends:**
   - Check "Suggested" tab
   - Verify mutual friends count shows
   - Check "friends-of-friends" algorithm

#### Friend Requests Management
1. **Navigate to Friend Requests**
2. **View Pending Requests:**
   - Check "Received" tab
   - Check "Sent" tab
3. **Accept a Request:**
   - Tap "Accept" button
   - Verify user moves to friends list
   - Check notification sent
4. **Reject a Request:**
   - Tap "Reject" button
   - Verify request disappears
5. **Test Edge Cases:**
   - Try sending request to yourself (should fail)
   - Try duplicate requests (should prevent)
   - Test block functionality

#### Friends List
1. **View All Friends**
2. **Check Pagination** (if >20 friends)
3. **Test Search** in friends list
4. **Tap on a Friend:**
   - View their profile
   - Check mutual friends display
   - Verify friend actions available

**Expected Results:**
- ✅ Smooth animations and transitions
- ✅ Real-time updates on friend status
- ✅ Proper error messages
- ✅ Haptic feedback on button taps
- ✅ Skeleton loading states

---

### 2. Follow System Testing (Priority: High)

#### Follow/Unfollow Flow
1. **Navigate to any user profile** (not yours)
2. **Check Follow Button State:**
   - Shows "Follow" if not following
   - Shows "Following" if already following
3. **Tap Follow Button:**
   - Verify optimistic UI update
   - Check button changes to "Following"
   - Verify follower count increases
4. **Tap Unfollow:**
   - Verify confirmation or immediate unfollow
   - Check follower count decreases
5. **Test on Multiple Users** to verify state management

#### Followers/Following Lists
1. **Navigate to Profile** → tap "Followers"
2. **Verify List Display:**
   - Check user avatars load
   - Check usernames display
   - Verify bio snippets (if available)
3. **Test Pagination** (scroll to load more)
4. **Tap "Following" Tab:**
   - Verify different list loads
   - Check following status indicators
5. **Test Follow from Lists:**
   - Follow/unfollow from within lists
   - Verify real-time updates

#### Social Stats Display
1. **Check Profile Stats Card:**
   - Followers count
   - Following count
   - Posts count
2. **Verify Stats are Clickable:**
   - Tap followers → opens followers list
   - Tap following → opens following list
3. **Check Color Coding** and visual hierarchy

**Expected Results:**
- ✅ Asymmetric following (can follow without reciprocation)
- ✅ Real-time count updates
- ✅ Smooth list scrolling
- ✅ Proper empty states

---

### 3. Messaging System Testing (Priority: High)

#### Direct Messages
1. **Navigate to Messages Tab**
2. **Tap "New Message":**
   - Search for a user
   - Select user
   - Start conversation
3. **Send Various Message Types:**
   - **Text:** Type and send a message
   - **Image:** Attach and send an image (if available)
   - **Location:** Share location (if available)
   - **Post:** Share a post (test if implemented)
4. **Test Message Features:**
   - Verify messages appear in chronological order
   - Check sender/receiver alignment
   - Test message bubbles styling
   - Verify timestamps display
5. **Read Receipts:**
   - Send a message
   - Check if "Read" status shows

#### Group Chats
1. **Create Group Chat:**
   - Tap "New Group"
   - Select 2+ users
   - Set group name
   - Add group description (optional)
   - Create group
2. **Test Group Features:**
   - Send messages to group
   - Verify all members see messages
   - Check group info screen
3. **Admin Functions:**
   - Add new members
   - Remove members (if admin)
   - Change group name
   - Change group image
   - Make someone else admin
4. **Leave Group:**
   - Tap "Leave Group"
   - Verify confirmation
   - Check you're removed from group

#### Conversation Management
1. **Test Conversation List:**
   - Verify last message preview
   - Check unread count badges
   - Verify timestamp of last message
2. **Test Pull to Refresh**
3. **Test Search in Messages** (if available)
4. **Test Message History:**
   - Scroll up to load older messages
   - Verify pagination works
5. **Test Shared Media:**
   - Access shared photos/videos
   - Verify media gallery

**Expected Results:**
- ✅ Real-time message delivery
- ✅ Proper message ordering
- ✅ Unread counts accurate
- ✅ Smooth scrolling performance
- ✅ Media preview thumbnails

---

### 4. Comments System Testing (Priority: Medium)

#### Post Comments
1. **Navigate to Home Feed**
2. **Tap on a Post** to view details
3. **View Comments:**
   - Check comment list loads
   - Verify user avatars
   - Check timestamps
4. **Add Comment:**
   - Tap comment input field
   - Type a comment
   - Tap "Send" or "Post"
   - Verify comment appears
5. **Test Comment Features:**
   - Like a comment (if available)
   - Reply to comment (if nested)
   - Delete your own comment
6. **Test Edge Cases:**
   - Empty comment (should block)
   - Very long comment (check validation)
   - Special characters

#### Comment Notifications
1. **Post a Comment on Another User's Post**
2. **Check if Notification is Created**
3. **Verify Notification Content:**
   - Shows commenter name
   - Shows comment preview
   - Tapping navigates to post

**Expected Results:**
- ✅ Comments appear immediately (optimistic update)
- ✅ Proper validation feedback
- ✅ Smooth keyboard handling
- ✅ Comment count updates on post

---

### 5. Notifications System Testing (Priority: High)

#### Notifications Feed
1. **Navigate to Notifications Tab**
2. **View All Notifications:**
   - Check notification types
   - Verify icons/colors per type
   - Check timestamps ("2h ago", etc.)
3. **Test Notification Types:**
   - **Friend Request** (red/green icon)
   - **Friend Accepted** (checkmark)
   - **Post Like** (heart icon)
   - **Comment** (bubble icon)
   - **Follow** (person icon)
   - **Message** (message icon)
4. **Tap on Notification:**
   - Verify navigation to relevant content
   - Check notification marks as read
5. **Test Badge Count:**
   - Verify unread count on tab bar
   - Check updates in real-time

#### Notification Actions
1. **Mark as Read:**
   - Swipe or tap to mark read
   - Verify badge count decreases
2. **Mark All as Read:**
   - Use bulk action (if available)
   - Verify all notifications update
3. **Delete Notification:**
   - Swipe to delete (if available)
   - Verify removal

**Expected Results:**
- ✅ 10 notification types supported
- ✅ Real-time badge updates
- ✅ Proper navigation from notifications
- ✅ Read/unread visual distinction

---

### 6. Post Interactions Testing (Priority: Medium)

#### Like System
1. **Navigate to Home Feed**
2. **Like a Post:**
   - Tap heart icon
   - Verify animation (if any)
   - Check icon turns filled/red
   - Verify like count increases
3. **Unlike Post:**
   - Tap heart again
   - Verify count decreases
4. **Test on Multiple Posts:**
   - Verify state persists
   - Check optimistic updates

#### Bookmark/Save System
1. **Bookmark a Post:**
   - Tap bookmark icon
   - Verify visual feedback
2. **View Saved Posts:**
   - Navigate to Saved/Bookmarks
   - Verify post appears
3. **Unbookmark:**
   - Tap bookmark again
   - Verify removal from saved list

#### Post Sharing (if implemented)
1. **Tap Share Button**
2. **Test Share Options:**
   - Share to messages
   - Share to other apps
   - Copy link

**Expected Results:**
- ✅ Instant UI feedback
- ✅ Accurate counts
- ✅ State persistence across app restarts

---

## 🔧 Backend Integration Testing

### Prerequisites
Start the backend server:
```bash
cd palytt-backend
pnpm run dev
```

### API Endpoint Testing

#### 1. Friends Endpoints
```bash
# Test friend request
curl -X POST http://localhost:4000/trpc/friends.sendRequest \
  -H "Content-Type: application/json" \
  -d '{"receiverId": "user_abc123"}'

# Get friends list
curl http://localhost:4000/trpc/friends.getFriends

# Get mutual friends
curl http://localhost:4000/trpc/friends.getMutualFriends?userId1=user_1&userId2=user_2
```

#### 2. Follow Endpoints
```bash
# Follow user
curl -X POST http://localhost:4000/trpc/follows.follow \
  -H "Content-Type: application/json" \
  -d '{"userId": "user_abc123"}'

# Get followers
curl http://localhost:4000/trpc/follows.getFollowers?userId=user_123

# Get follow stats
curl http://localhost:4000/trpc/follows.getFollowStats?userId=user_123
```

#### 3. Messaging Endpoints
```bash
# Get chatrooms
curl http://localhost:4000/trpc/messages.getChatrooms

# Send message
curl -X POST http://localhost:4000/trpc/messages.sendMessage \
  -H "Content-Type: application/json" \
  -d '{"chatroomId": "room_123", "content": "Hello!"}'

# Get messages
curl http://localhost:4000/trpc/messages.getMessages?chatroomId=room_123
```

#### 4. Notifications Endpoints
```bash
# Get notifications
curl http://localhost:4000/trpc/notifications.getNotifications

# Mark as read
curl -X POST http://localhost:4000/trpc/notifications.markAsRead \
  -H "Content-Type: application/json" \
  -d '{"notificationIds": ["notif_1", "notif_2"]}'

# Get unread count
curl http://localhost:4000/trpc/notifications.getUnreadCount
```

---

## 🐛 Common Issues & Troubleshooting

### Issue 1: "User not found" Error
**Solution:** Ensure you're authenticated with Clerk. Check user exists in database.

### Issue 2: Messages Not Appearing
**Solution:** 
- Verify backend is running (`http://localhost:4000/health`)
- Check network connection in simulator
- Verify WebSocket connection (if implemented)

### Issue 3: Friend Requests Failing
**Solution:**
- Can't send request to yourself
- Check if request already exists
- Verify both users exist in system

### Issue 4: Notifications Not Updating
**Solution:**
- Pull to refresh notifications list
- Check notification service is running
- Verify user permissions for push notifications

### Issue 5: Slow Performance
**Solution:**
- Clear image cache
- Restart simulator
- Check for memory leaks in console

---

## 📊 Performance Benchmarks

### Expected Response Times
- **Friends list load:** < 100ms (for 50 friends)
- **Send message:** < 50ms (text only)
- **Load notifications:** < 150ms (20 notifications)
- **Search users:** < 200ms (with debounce)
- **Post interaction:** < 100ms (like/comment)

### Memory Usage
- **Normal:** 80-120 MB
- **With large image cache:** 150-200 MB
- **Peak during scroll:** 200-250 MB

### Network Efficiency
- **Pagination:** 20 items per request
- **Image optimization:** Cached with Kingfisher
- **API calls:** Batched where possible

---

## ✅ Test Completion Checklist

Mark off as you test each feature:

### Core Social Features
- [ ] **Friends System**
  - [ ] Add friends via search
  - [ ] Accept/reject friend requests
  - [ ] View friends list
  - [ ] See mutual friends
  - [ ] Block users
  
- [ ] **Follow System**
  - [ ] Follow/unfollow users
  - [ ] View followers list
  - [ ] View following list
  - [ ] See follow stats
  - [ ] Get follow suggestions

- [ ] **Messaging**
  - [ ] Send direct messages
  - [ ] Create group chats
  - [ ] Add/remove group members
  - [ ] View message history
  - [ ] See read receipts
  - [ ] Share media in chat

- [ ] **Comments**
  - [ ] Add comments to posts
  - [ ] View comment threads
  - [ ] Delete own comments
  - [ ] Like comments (if available)

- [ ] **Notifications**
  - [ ] Receive all 10 notification types
  - [ ] Navigate from notifications
  - [ ] Mark as read
  - [ ] See unread badge count

- [ ] **Post Interactions**
  - [ ] Like/unlike posts
  - [ ] Bookmark/save posts
  - [ ] Share posts (if available)
  - [ ] View saved posts

---

## 🚀 Advanced Testing Scenarios

### Scenario 1: Complete Friend Connection Flow
1. User A sends friend request to User B
2. User B receives notification
3. User B accepts request
4. User A receives acceptance notification
5. Both users see each other in friends list
6. Mutual friends count updates on profiles

### Scenario 2: Group Chat with Multiple Interactions
1. Create group with 3+ members
2. Each member sends messages
3. Admin adds new member
4. New member sees only messages after joining
5. Admin changes group name
6. All members see update

### Scenario 3: Notification Cascade
1. User posts content
2. Friend likes post → notification created
3. Friend comments → another notification
4. Another friend also likes → third notification
5. User taps on comment notification → navigates to post
6. All notifications mark as read

### Scenario 4: Follow Discovery Chain
1. User follows Friend A
2. System suggests Friend B (friend of Friend A)
3. User follows Friend B
4. System suggests Friend C (mutual connection)
5. Check mutual follows between all users

---

## 📸 Screenshot Checklist

Capture these screens for documentation:

1. **Friends List** - showing populated friends with avatars
2. **Add Friends View** - showing search and suggestions
3. **Friend Requests** - showing pending requests
4. **Messages List** - showing conversations with unread badges
5. **Chat View** - showing message thread
6. **Group Chat Info** - showing members and settings
7. **Notifications Feed** - showing various notification types
8. **User Profile** - showing social stats and mutual friends
9. **Comments Section** - showing comment thread
10. **Saved Posts** - showing bookmarked content

---

## 🎯 Success Criteria

The social features are working correctly if:

✅ **Functionality**
- All CRUD operations work (Create, Read, Update, Delete)
- Data persists across app restarts
- Real-time updates appear within 2 seconds
- Pagination works smoothly
- Search returns relevant results

✅ **User Experience**
- Loading states show before content
- Error messages are clear and helpful
- Animations are smooth (60 FPS)
- Haptic feedback on interactions
- Intuitive navigation

✅ **Performance**
- No crashes or freezes
- Smooth scrolling on lists
- Quick response to user actions
- Efficient memory usage
- Proper image caching

✅ **Data Integrity**
- Counts are accurate (friends, followers, messages)
- No duplicate entries
- Proper state management
- Consistent data across screens

---

## 📝 Notes

- **Authentication Required:** Most social features require Clerk authentication
- **Backend Dependency:** Ensure backend is running for full functionality
- **Test Data:** Use test accounts for comprehensive testing
- **Network:** Simulator must have internet access

---

## 🔗 Related Documentation

- [Social Features Analysis](./SOCIAL_FEATURES_ANALYSIS.md) - Complete feature breakdown
- [API Documentation](../palytt-backend/README.md) - Backend API reference
- [Architecture Guide](../palytt/docs/architecture/ARCHITECTURE_ANALYSIS.md) - System design

---

**Last Updated:** November 19, 2025  
**Tested By:** Automated Build + Manual Testing Required  
**Status:** ✅ Ready for Testing

