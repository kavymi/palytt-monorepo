import { execSync } from 'child_process';
import { cpSync, mkdirSync, writeFileSync, existsSync, rmSync, readFileSync, readdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const rootDir = join(__dirname, '..');
const outputDir = join(rootDir, '.vercel/output');

// Clean and create output directory
if (existsSync(outputDir)) {
  rmSync(outputDir, { recursive: true });
}
mkdirSync(outputDir, { recursive: true });
mkdirSync(join(outputDir, 'static'), { recursive: true });

// Run the vite build
console.log('Building with Vite...');
execSync('npm run build', { stdio: 'inherit', cwd: rootDir });

// Copy static assets
console.log('Copying static assets...');
cpSync(join(rootDir, 'dist/client'), join(outputDir, 'static'), { recursive: true });

// Find the main JS and CSS files
const assetsDir = join(rootDir, 'dist/client/assets');
const assetFiles = readdirSync(assetsDir);
const mainJs = assetFiles.find(f => f.startsWith('main-') && f.endsWith('.js'));
const globalsCss = assetFiles.find(f => f.startsWith('globals-') && f.endsWith('.css'));

if (!mainJs) {
  throw new Error('Could not find main JS bundle');
}

// Create index.html for SPA
const indexHtml = `<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Palytt - Discover & Share Amazing Food Experiences</title>
    <meta name="description" content="Join thousands of food lovers discovering restaurants, sharing culinary experiences, and connecting with friends on Palytt." />
    <meta property="og:title" content="Palytt - Discover & Share Amazing Food Experiences" />
    <meta property="og:description" content="Join thousands of food lovers discovering restaurants, sharing culinary experiences, and connecting with friends on Palytt." />
    <meta property="og:type" content="website" />
    <meta name="theme-color" content="#d29985" />
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap" />
    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
    ${globalsCss ? `<link rel="stylesheet" href="/assets/${globalsCss}" />` : ''}
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/assets/${mainJs}"></script>
  </body>
</html>`;

writeFileSync(join(outputDir, 'static/index.html'), indexHtml);
console.log('Created index.html');

// Create config.json for SPA routing
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
        dest: '/index.html'
      }
    ]
  }, null, 2)
);

console.log('Vercel build output created successfully!');
console.log('Output directory:', outputDir);
