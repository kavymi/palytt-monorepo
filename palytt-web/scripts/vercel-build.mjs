import { execSync } from 'child_process';
import { cpSync, mkdirSync, writeFileSync, existsSync, rmSync } from 'fs';
import { join } from 'path';

const outputDir = '.vercel/output';

// Clean and create output directory
if (existsSync(outputDir)) {
  rmSync(outputDir, { recursive: true });
}
mkdirSync(outputDir, { recursive: true });
mkdirSync(join(outputDir, 'static'), { recursive: true });
mkdirSync(join(outputDir, 'functions/index.func'), { recursive: true });

// Run the vite build
console.log('Building with Vite...');
execSync('npm run build', { stdio: 'inherit' });

// Copy static assets
console.log('Copying static assets...');
cpSync('dist/client', join(outputDir, 'static'), { recursive: true });

// Copy server files
console.log('Setting up serverless function...');
cpSync('dist/server', join(outputDir, 'functions/index.func'), { recursive: true });

// Create an entry point wrapper for Vercel Node.js runtime
const entryWrapper = `
import server from './server.js';

export default async function handler(req, res) {
  // Convert Node.js request to Web Request
  const protocol = req.headers['x-forwarded-proto'] || 'https';
  const host = req.headers['x-forwarded-host'] || req.headers.host;
  const url = new URL(req.url, \`\${protocol}://\${host}\`);
  
  const headers = new Headers();
  for (const [key, value] of Object.entries(req.headers)) {
    if (value) {
      if (Array.isArray(value)) {
        value.forEach(v => headers.append(key, v));
      } else {
        headers.set(key, value);
      }
    }
  }

  const body = ['GET', 'HEAD'].includes(req.method) ? undefined : req;
  
  const request = new Request(url.toString(), {
    method: req.method,
    headers,
    body,
    duplex: 'half'
  });

  try {
    const response = await server.fetch(request);
    
    // Set response status
    res.statusCode = response.status;
    res.statusMessage = response.statusText;
    
    // Set response headers
    response.headers.forEach((value, key) => {
      res.setHeader(key, value);
    });
    
    // Stream the response body
    if (response.body) {
      const reader = response.body.getReader();
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        res.write(value);
      }
    }
    res.end();
  } catch (error) {
    console.error('Server error:', error);
    res.statusCode = 500;
    res.end('Internal Server Error');
  }
}
`;

writeFileSync(
  join(outputDir, 'functions/index.func/index.mjs'),
  entryWrapper
);

// Create function config for Node.js Runtime
writeFileSync(
  join(outputDir, 'functions/index.func/.vc-config.json'),
  JSON.stringify({
    runtime: 'nodejs22.x',
    handler: 'index.mjs',
    launcherType: 'Nodejs',
    shouldAddHelpers: true,
    supportsResponseStreaming: true
  }, null, 2)
);

// Create package.json for the function
writeFileSync(
  join(outputDir, 'functions/index.func/package.json'),
  JSON.stringify({
    type: 'module'
  }, null, 2)
);

// Create config.json
writeFileSync(
  join(outputDir, 'config.json'),
  JSON.stringify({
    version: 3,
    routes: [
      {
        src: '/assets/(.*)',
        headers: { 'Cache-Control': 'public, max-age=31536000, immutable' },
        continue: true
      },
      {
        handle: 'filesystem'
      },
      {
        src: '/(.*)',
        dest: '/index'
      }
    ]
  }, null, 2)
);

console.log('Vercel build output created successfully!');
