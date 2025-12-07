# Type Safety Audit: iOS DTOs vs Backend Schemas

This document tracks mismatches between iOS DTOs and backend Zod schemas.

## User DTO Mismatches

### Field Name Differences

| iOS DTO Field | Backend Schema Field | Status | Notes |
|--------------|----------------------|--------|-------|
| `displayName` | `name` | ⚠️ Mismatch | iOS uses `displayName`, backend uses `name` |
| `followersCount` | `followerCount` | ⚠️ Mismatch | Plural vs singular |
| `friendsCount` | N/A | ⚠️ Missing | Backend doesn't have this field |
| `avatarUrl` | `profileImage` | ⚠️ Mismatch | iOS sends `avatarUrl`, backend expects `profileImage` |
| `phoneNumber` | N/A | ⚠️ Missing | Backend doesn't expose phone number |
| `instagramHandle` | N/A | ⚠️ Missing | Backend doesn't have social handles |
| `twitterHandle` | N/A | ⚠️ Missing | Backend doesn't have social handles |
| `tikTokHandle` | N/A | ⚠️ Missing | Backend doesn't have social handles |
| `dateOfBirth` | N/A | ⚠️ Missing | Backend doesn't have date of birth |

### Recommended Fixes

1. **Add CodingKeys mapping** in iOS DTOs:
   ```swift
   enum CodingKeys: String, CodingKey {
       case displayName = "name"
       case followersCount = "followerCount"
       case avatarUrl = "profileImage"
   }
   ```

2. **Backend transformation layer** - Add field mapping in backend responses to match iOS expectations

3. **Add missing fields** to backend schema if needed by iOS app

## Post DTO Mismatches

### Field Name Differences

| iOS DTO Field | Backend Schema Field | Status | Notes |
|--------------|----------------------|--------|-------|
| `shopName` | `title` | ⚠️ Mismatch | Backend stores as `title`, iOS expects `shopName` |
| `foodItem` | `menuItems[0]` | ⚠️ Mismatch | Backend uses array, iOS expects single string |
| `description` | `caption` | ⚠️ Mismatch | Backend uses `caption` |
| `savesCount` | `savesCount` | ✅ Match | Both use same name |
| `isBookmarked` | `isBookmarked` | ✅ Match | Both use same name |

### Current Backend Transformation

The backend already transforms fields in responses:
- `title` → `shopName`
- `menuItems[0]` → `foodItem`
- `caption` → `description`

This is good, but it means the backend output schema doesn't match the actual database schema.

## Recommendations

### Short-term (Quick Fixes)
1. Add `CodingKeys` to iOS DTOs for field name mapping
2. Document all field transformations in backend responses
3. Add comments in backend code explaining field mappings

### Long-term (Type Safety)
1. Generate iOS DTOs from backend schemas automatically
2. Use consistent naming across backend and iOS
3. Consider using a shared type definition (e.g., OpenAPI/JSON Schema)

## Action Items

- [ ] Add CodingKeys to UserDTO.swift
- [ ] Add CodingKeys to PostDTO.swift
- [ ] Document all field transformations in backend
- [ ] Create automated type generation pipeline
- [ ] Align field names between iOS and backend (breaking change - requires migration)

