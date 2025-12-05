import { Link } from '@tanstack/react-router'
import { motion } from 'framer-motion'
import { useState } from 'react'

export function Navbar() {
  const [isOpen, setIsOpen] = useState(false)

  return (
    <motion.header
      initial={{ y: -100 }}
      animate={{ y: 0 }}
      transition={{ duration: 0.5, ease: 'easeOut' }}
      className="fixed top-0 left-0 right-0 z-50 glass"
    >
      <nav className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16 md:h-20">
          {/* Logo */}
          <Link to="/" className="flex items-center gap-2 group">
            <motion.div
              whileHover={{ rotate: [0, -10, 10, 0] }}
              transition={{ duration: 0.5 }}
              className="w-10 h-10 bg-gradient-to-br from-primary to-secondary rounded-xl flex items-center justify-center shadow-lg shadow-primary/20"
            >
              <span className="text-white font-bold text-xl">P</span>
            </motion.div>
            <span className="text-xl font-bold text-coffee-dark dark:text-white">
              Palytt
            </span>
          </Link>

          {/* Desktop Navigation */}
          <div className="hidden md:flex items-center gap-8">
            <NavLink href="#features">Features</NavLink>
            <NavLink href="#how-it-works">How It Works</NavLink>
            <Link 
              to="/support" 
              className="text-light-text-secondary hover:text-coffee-dark transition-colors"
            >
              Support
            </Link>
            <a href="#early-access">
              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                className="btn-primary"
              >
                Get Early Access
              </motion.button>
            </a>
          </div>

          {/* Mobile Menu Button */}
          <button
            onClick={() => setIsOpen(!isOpen)}
            className="md:hidden p-2 rounded-lg hover:bg-white/50 transition-colors"
            aria-label="Toggle menu"
          >
            <svg
              className="w-6 h-6 text-coffee-dark"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              {isOpen ? (
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M6 18L18 6M6 6l12 12"
                />
              ) : (
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M4 6h16M4 12h16M4 18h16"
                />
              )}
            </svg>
          </button>
        </div>

        {/* Mobile Menu */}
        <motion.div
          initial={false}
          animate={isOpen ? { height: 'auto', opacity: 1 } : { height: 0, opacity: 0 }}
          className="md:hidden overflow-hidden"
        >
          <div className="py-4 space-y-4 border-t border-light-divider">
            <MobileNavLink href="#features" onClick={() => setIsOpen(false)}>
              Features
            </MobileNavLink>
            <MobileNavLink href="#how-it-works" onClick={() => setIsOpen(false)}>
              How It Works
            </MobileNavLink>
            <Link
              to="/support"
              onClick={() => setIsOpen(false)}
              className="block px-4 py-2 text-light-text-secondary hover:text-coffee-dark transition-colors"
            >
              Support
            </Link>
            <div className="px-4 pt-2">
              <a href="#early-access" onClick={() => setIsOpen(false)}>
                <button className="btn-primary w-full">Get Early Access</button>
              </a>
            </div>
          </div>
        </motion.div>
      </nav>
    </motion.header>
  )
}

function NavLink({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <a
      href={href}
      className="relative text-light-text-secondary hover:text-coffee-dark transition-colors group"
    >
      {children}
      <span className="absolute -bottom-1 left-0 w-0 h-0.5 bg-primary transition-all duration-300 group-hover:w-full" />
    </a>
  )
}

function MobileNavLink({
  href,
  onClick,
  children,
}: {
  href: string
  onClick: () => void
  children: React.ReactNode
}) {
  return (
    <a
      href={href}
      onClick={onClick}
      className="block px-4 py-2 text-light-text-secondary hover:text-coffee-dark hover:bg-white/50 rounded-lg transition-all"
    >
      {children}
    </a>
  )
}
