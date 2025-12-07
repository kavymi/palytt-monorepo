#!/usr/bin/env tsx

/**
 * Convex-Backend Type Validation
 * 
 * Validates that Convex schema enums match backend enum schemas
 * This ensures type consistency between real-time (Convex) and REST (Backend) APIs
 */

import * as fs from 'fs';
import * as path from 'path';
import { z } from 'zod';
import * as schemas from '../src/schemas/enums.schema.js';

const CONVEX_SCHEMA_PATH = path.join(process.cwd(), '../../palytt-convex/convex/schema.ts');

console.log('🔍 Validating Convex-Backend type synchronization...\n');

// Read Convex schema
let convexSchemaContent: string;
try {
  convexSchemaContent = fs.readFileSync(CONVEX_SCHEMA_PATH, 'utf-8');
} catch (error) {
  console.error(`❌ Could not read Convex schema at ${CONVEX_SCHEMA_PATH}`);
  console.error('   Make sure the path is correct and the file exists.\n');
  process.exit(1);
}

// Extract enum values from Convex schema
function extractConvexEnumValues(schemaContent: string, enumName: string): string[] {
  // Look for v.union(v.literal("VALUE1"), v.literal("VALUE2"), ...)
  const regex = new RegExp(`${enumName}.*?v\\.union\\(([^)]+)\\)`, 's');
  const match = schemaContent.match(regex);
  
  if (!match) {
    return [];
  }
  
  // Extract literal values
  const literals = match[1].match(/v\.literal\("([^"]+)"\)/g);
  if (!literals) {
    return [];
  }
  
  return literals.map(l => {
    const valueMatch = l.match(/"([^"]+)"/);
    return valueMatch ? valueMatch[1] : '';
  }).filter(Boolean);
}

// Get backend enum values
function getBackendEnumValues(enumSchema: z.ZodEnum<any>): string[] {
  return enumSchema.options;
}

// Validate NotificationType enum
const backendNotificationTypes = getBackendEnumValues(schemas.NotificationTypeEnum);
const convexNotificationTypes = extractConvexEnumValues(convexSchemaContent, 'NotificationType');

console.log('📋 NotificationType Enum:');
console.log(`   Backend: ${backendNotificationTypes.join(', ')}`);
console.log(`   Convex:  ${convexNotificationTypes.join(', ')}`);

const notificationMismatches: string[] = [];
const backendOnly = backendNotificationTypes.filter(b => !convexNotificationTypes.includes(b));
const convexOnly = convexNotificationTypes.filter(c => !backendNotificationTypes.includes(c));

if (backendOnly.length > 0) {
  notificationMismatches.push(`Backend has types not in Convex: ${backendOnly.join(', ')}`);
}
if (convexOnly.length > 0) {
  notificationMismatches.push(`Convex has types not in Backend: ${convexOnly.join(', ')}`);
}

if (notificationMismatches.length === 0) {
  console.log('   ✅ NotificationType enums match!\n');
} else {
  console.log('   ❌ NotificationType enum mismatches:');
  notificationMismatches.forEach(m => console.log(`      - ${m}`));
  console.log();
}

// Validate MessageType enum
const backendMessageTypes = getBackendEnumValues(schemas.MessageTypeEnum);
const convexMessageTypes = extractConvexEnumValues(convexSchemaContent, 'MessageType');

console.log('📋 MessageType Enum:');
console.log(`   Backend: ${backendMessageTypes.join(', ')}`);
console.log(`   Convex:  ${convexMessageTypes.join(', ')}`);

const messageMismatches: string[] = [];
const backendMessageOnly = backendMessageTypes.filter(b => !convexMessageTypes.includes(b));
const convexMessageOnly = convexMessageTypes.filter(c => !backendMessageTypes.includes(c));

if (backendMessageOnly.length > 0) {
  messageMismatches.push(`Backend has types not in Convex: ${backendMessageOnly.join(', ')}`);
}
if (convexMessageOnly.length > 0) {
  messageMismatches.push(`Convex has types not in Backend: ${convexMessageOnly.join(', ')}`);
}

if (messageMismatches.length === 0) {
  console.log('   ✅ MessageType enums match!\n');
} else {
  console.log('   ❌ MessageType enum mismatches:');
  messageMismatches.forEach(m => console.log(`      - ${m}`));
  console.log();
}

// Summary
const allMismatches = [...notificationMismatches, ...messageMismatches];

if (allMismatches.length === 0) {
  console.log('✅ All Convex-Backend enums are synchronized!\n');
  process.exit(0);
} else {
  console.log('❌ Found enum mismatches. Please update Convex schema or backend enums to match.\n');
  process.exit(1);
}

