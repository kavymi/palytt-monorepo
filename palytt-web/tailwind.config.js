/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        // Primary Brand Colors (from iOS app)
        'old-rose': '#d29985',
        'milk-tea': '#e3c4a8',
        'coffee-dark': '#3b2b2b',
        'blue-accent': '#9ac8eb',
        'light-blue-accent': '#d4e4f2',
        
        // Light theme
        'light-bg': '#fbf4e6',
        'light-card': '#ffffff',
        'light-text': '#3b2b2b',
        'light-text-secondary': '#6B7280',
        'light-text-tertiary': '#9CA3AF',
        'light-divider': '#E5E7EB',
        
        // Dark theme  
        'dark-bg': '#1a1a1a',
        'dark-card': '#2d2d2d',
        'dark-text': '#ffffff',
        'dark-text-secondary': '#b3b3b3',
        'dark-text-tertiary': '#808080',
        'dark-divider': '#404040',
        'dark-surface': '#333333',
        
        // State colors
        'success': '#10B981',
        'warning': '#F59E0B',
        'error': '#EF4444',
        
        // Semantic aliases
        'primary': '#d29985',
        'primary-hover': '#c08874',
        'secondary': '#e3c4a8',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        display: ['SF Pro Display', 'Inter', 'system-ui', 'sans-serif'],
      },
      animation: {
        'float': 'float 6s ease-in-out infinite',
        'pulse-slow': 'pulse 4s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'gradient': 'gradient 8s ease infinite',
      },
      keyframes: {
        float: {
          '0%, 100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-20px)' },
        },
        gradient: {
          '0%, 100%': { backgroundPosition: '0% 50%' },
          '50%': { backgroundPosition: '100% 50%' },
        },
      },
      backgroundImage: {
        'gradient-radial': 'radial-gradient(var(--tw-gradient-stops))',
        'hero-pattern': 'radial-gradient(circle at 25% 25%, rgba(210, 153, 133, 0.15) 0%, transparent 50%), radial-gradient(circle at 75% 75%, rgba(227, 196, 168, 0.15) 0%, transparent 50%)',
      },
    },
  },
  plugins: [],
}
