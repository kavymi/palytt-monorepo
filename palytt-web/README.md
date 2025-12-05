# Palytt Web - Landing Page

A modern landing page for the Palytt iOS app, built with TanStack Start, React Query, and Framer Motion.

## Features

- 🚀 **TanStack Start** - Full-stack React framework with file-based routing
- 📊 **React Query** - Powerful data fetching and caching
- 🎨 **TailwindCSS** - Utility-first styling with custom Palytt theme
- ✨ **Framer Motion** - Smooth animations and transitions
- 📱 **Mobile Responsive** - Looks great on all devices
- 📝 **TanStack Form** - Type-safe form handling for early access signup

## Pages

- `/` - Landing page with hero, features, and early access signup
- `/privacy` - Privacy Policy
- `/support` - FAQ and contact form

## Color Theme

Using the same color palette as the iOS app:

- **Primary (Old Rose)**: `#d29985`
- **Secondary (Milk Tea)**: `#e3c4a8`
- **Dark (Coffee)**: `#3b2b2b`
- **Background (Light)**: `#fbf4e6`
- **Accent (Blue)**: `#9ac8eb`

## Getting Started

### Prerequisites

- Node.js 18+
- npm or pnpm

### Installation

```bash
# Install dependencies
npm install

# Start development server
npm run dev
```

The site will be available at `http://localhost:3000`

### Build for Production

```bash
npm run build
npm run start
```

## Project Structure

```
palytt-web/
├── src/
│   ├── components/       # Reusable UI components
│   │   ├── EarlyAccessForm.tsx
│   │   ├── FeatureCard.tsx
│   │   ├── Footer.tsx
│   │   ├── Navbar.tsx
│   │   └── PhoneMockup.tsx
│   ├── routes/           # File-based routing (TanStack Router)
│   │   ├── __root.tsx    # Root layout
│   │   ├── index.tsx     # Landing page
│   │   ├── privacy.tsx   # Privacy policy
│   │   └── support.tsx   # Support page
│   ├── styles/
│   │   └── globals.css   # Global styles and Tailwind
│   ├── main.tsx          # App entry point
│   └── routeTree.gen.ts  # Auto-generated route tree
├── public/
│   └── favicon.svg
├── index.html            # HTML template
├── vite.config.ts        # Vite configuration
├── tailwind.config.js    # Tailwind configuration
└── package.json
```

## Environment Variables

For production, you may want to set up:

```env
# Email service API keys (for early access signups)
MAILCHIMP_API_KEY=your_key
SENDGRID_API_KEY=your_key
```

## Deployment

The site can be deployed to:

- **Vercel** - Zero-config deployment
- **Netlify** - Static hosting with serverless functions
- **Railway** - Full-stack hosting
- **Any Node.js hosting** - Using the built output

## Contact

For questions or support:
- Email: kavyrattana@gmail.com

---

© 2025 Palytt Inc. All rights reserved.
