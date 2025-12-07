#!/usr/bin/env tsx

/**
 * Swift Type Generator
 * 
 * Generates Swift Codable structs from Zod schemas
 * This ensures iOS types stay in sync with backend schemas
 */

import * as fs from 'fs';
import * as path from 'path';
import { z } from 'zod';
import * as schemas from '../src/schemas/index.js';

const OUTPUT_DIR = path.join(process.cwd(), '../../palytt/Sources/PalyttApp/Generated');
const OUTPUT_FILE = path.join(OUTPUT_DIR, 'APITypes.swift');

/**
 * Convert Zod type to Swift type
 */
function zodToSwiftType(schema: z.ZodTypeAny, optional: boolean = false): string {
  const prefix = optional ? '' : '';
  const suffix = optional ? '?' : '';
  
  if (schema instanceof z.ZodString) {
    return `String${suffix}`;
  }
  if (schema instanceof z.ZodNumber) {
    return `Double${suffix}`;
  }
  if (schema instanceof z.ZodBoolean) {
    return `Bool${suffix}`;
  }
  if (schema instanceof z.ZodArray) {
    const elementType = zodToSwiftType(schema.element);
    return `[${elementType}]${suffix}`;
  }
  if (schema instanceof z.ZodObject) {
    // For objects, we'll generate a struct
    return `String${suffix}`; // Placeholder - would need recursive generation
  }
  if (schema instanceof z.ZodOptional) {
    return zodToSwiftType(schema.unwrap(), true);
  }
  if (schema instanceof z.ZodNullable) {
    return zodToSwiftType(schema.unwrap(), true);
  }
  if (schema instanceof z.ZodEnum) {
    return `String${suffix}`;
  }
  
  return `Any${suffix}`;
}

/**
 * Generate Swift struct from Zod schema
 */
function generateSwiftStruct(name: string, schema: z.ZodObject<any>): string {
  const shape = schema.shape;
  const properties: string[] = [];
  const codingKeys: string[] = [];
  
  for (const [key, value] of Object.entries(shape)) {
    const swiftKey = key.charAt(0).toUpperCase() + key.slice(1);
    const isOptional = value instanceof z.ZodOptional || value instanceof z.ZodNullable;
    const swiftType = zodToSwiftType(value as z.ZodTypeAny, isOptional);
    
    properties.push(`    let ${key}: ${swiftType}`);
    
    // Generate CodingKeys if needed (for snake_case to camelCase)
    if (key !== swiftKey) {
      codingKeys.push(`        case ${key} = "${swiftKey}"`);
    } else {
      codingKeys.push(`        case ${key}`);
    }
  }
  
  const codingKeysBlock = codingKeys.length > 0
    ? `\n    enum CodingKeys: String, CodingKey {\n${codingKeys.join('\n')}\n    }`
    : '';
  
  return `//
//  ${name}.swift
//  Palytt
//
//  Auto-generated from backend Zod schemas
//  DO NOT EDIT MANUALLY - This file is generated
//

import Foundation

struct ${name}: Codable {
${properties.join('\n')}${codingKeysBlock}
}
`;
}

/**
 * Main generation function
 */
function generateSwiftTypes() {
  console.log('🔨 Generating Swift types from Zod schemas...\n');
  
  // Ensure output directory exists
  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }
  
  const generatedTypes: string[] = [];
  
  // Generate User types
  if (schemas.UserSchema instanceof z.ZodObject) {
    generatedTypes.push(generateSwiftStruct('APIUser', schemas.UserSchema));
  }
  
  // Generate Post types
  if (schemas.PostResponseSchema instanceof z.ZodObject) {
    generatedTypes.push(generateSwiftStruct('APIPost', schemas.PostResponseSchema));
  }
  
  // Generate Location type
  if (schemas.LocationSchema instanceof z.ZodObject) {
    generatedTypes.push(generateSwiftStruct('APILocation', schemas.LocationSchema));
  }
  
  // Write to file
  const header = `//
//  APITypes.swift
//  Palytt
//
//  Auto-generated from backend Zod schemas
//  DO NOT EDIT MANUALLY - This file is generated
//  Run: npm run generate:types in palytt-backend/
//

import Foundation

`;
  
  const content = header + generatedTypes.join('\n\n');
  
  fs.writeFileSync(OUTPUT_FILE, content, 'utf-8');
  
  console.log(`✅ Generated Swift types to: ${OUTPUT_FILE}`);
  console.log(`📝 Generated ${generatedTypes.length} type definitions\n`);
  console.log('⚠️  Note: This is a basic generator. You may need to manually refine the generated types.');
}

// Run generator
try {
  generateSwiftTypes();
} catch (error) {
  console.error('❌ Error generating Swift types:', error);
  process.exit(1);
}

