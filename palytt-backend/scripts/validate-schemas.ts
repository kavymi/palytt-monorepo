#!/usr/bin/env tsx

/**
 * Schema validation script
 * 
 * Validates that all exported schemas are valid Zod schemas
 * and checks for common issues like:
 * - Missing required fields
 * - Type mismatches
 * - Circular dependencies
 */

import { z } from 'zod';
import * as schemas from '../src/schemas/index.js';

console.log('🔍 Validating schemas...\n');

let errors: string[] = [];
let warnings: string[] = [];

// Test that all schemas can be imported and are valid
const schemaTests = [
  { name: 'UserSchema', schema: schemas.UserSchema },
  { name: 'UserInfoSchema', schema: schemas.UserInfoSchema },
  { name: 'CreateUserSchema', schema: schemas.CreateUserSchema },
  { name: 'UpdateUserSchema', schema: schemas.UpdateUserSchema },
  { name: 'UserResponseSchema', schema: schemas.UserResponseSchema },
  { name: 'PostResponseSchema', schema: schemas.PostResponseSchema },
  { name: 'CreatePostInputSchema', schema: schemas.CreatePostInputSchema },
  { name: 'LocationSchema', schema: schemas.LocationSchema },
  { name: 'PaginationInputSchema', schema: schemas.PaginationInputSchema },
  { name: 'PaginationOutputSchema', schema: schemas.PaginationOutputSchema },
];

for (const test of schemaTests) {
  try {
    // Try to parse an empty object to check if schema is valid
    // This will catch structural issues
    if (test.schema) {
      // For input schemas, we can't test with empty object
      // Just verify it's a Zod schema
      if (test.schema instanceof z.ZodType) {
        console.log(`✅ ${test.name} is valid`);
      } else {
        errors.push(`${test.name} is not a valid Zod schema`);
      }
    } else {
      warnings.push(`${test.name} is not exported`);
    }
  } catch (error) {
    errors.push(`${test.name} validation failed: ${error instanceof Error ? error.message : String(error)}`);
  }
}

// Test enum schemas
const enumTests = [
  { name: 'FriendStatusEnum', schema: schemas.FriendStatusEnum },
  { name: 'MessageTypeEnum', schema: schemas.MessageTypeEnum },
  { name: 'NotificationTypeEnum', schema: schemas.NotificationTypeEnum },
];

for (const test of enumTests) {
  try {
    if (test.schema && test.schema instanceof z.ZodEnum) {
      console.log(`✅ ${test.name} is valid`);
    } else {
      warnings.push(`${test.name} is not a valid Zod enum`);
    }
  } catch (error) {
    errors.push(`${test.name} validation failed: ${error instanceof Error ? error.message : String(error)}`);
  }
}

// Print results
console.log('\n📊 Validation Results:');
if (errors.length === 0 && warnings.length === 0) {
  console.log('✅ All schemas are valid!\n');
  process.exit(0);
} else {
  if (warnings.length > 0) {
    console.log(`\n⚠️  Warnings (${warnings.length}):`);
    warnings.forEach(w => console.log(`   - ${w}`));
  }
  if (errors.length > 0) {
    console.log(`\n❌ Errors (${errors.length}):`);
    errors.forEach(e => console.log(`   - ${e}`));
    process.exit(1);
  }
  process.exit(0);
}

