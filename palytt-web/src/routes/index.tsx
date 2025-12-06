import { createFileRoute } from '@tanstack/react-router'
import { motion } from 'framer-motion'
import { PhoneMockup } from '~/components/PhoneMockup'
import { FeatureCard } from '~/components/FeatureCard'
import { EarlyAccessForm } from '~/components/EarlyAccessForm'

export const Route = createFileRoute('/')({
  component: HomePage,
})

function HomePage() {
  return (
    <div className="overflow-hidden">
      {/* Hero Section */}
      <section className="relative min-h-screen flex items-center pt-20 md:pt-0">
        {/* Background */}
        <div className="absolute inset-0 bg-hero-pattern" />
        <div className="absolute top-0 right-0 w-1/2 h-1/2 bg-gradient-radial from-primary/10 via-transparent to-transparent blur-3xl" />
        <div className="absolute bottom-0 left-0 w-1/2 h-1/2 bg-gradient-radial from-secondary/10 via-transparent to-transparent blur-3xl" />

        <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 md:py-24">
          <div className="grid lg:grid-cols-2 gap-12 lg:gap-8 items-center">
            {/* Text Content */}
            <motion.div
              initial={{ opacity: 0, x: -50 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.6 }}
              className="text-center lg:text-left"
            >
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.2 }}
                className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-primary/10 text-primary text-sm font-medium mb-6"
              >
                <span className="relative flex h-2 w-2">
                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-primary opacity-75" />
                  <span className="relative inline-flex rounded-full h-2 w-2 bg-primary" />
                </span>
                Coming Soon to iOS
              </motion.div>

              <h1 className="text-4xl sm:text-5xl md:text-6xl lg:text-7xl font-bold tracking-tight text-coffee-dark dark:text-white mb-6">
                Discover &{' '}
                <span className="text-gradient">Share</span>
                <br />
                Amazing Food
              </h1>

              <p className="text-lg md:text-xl text-light-text-secondary dark:text-dark-text-secondary max-w-xl mx-auto lg:mx-0 mb-8">
                Join thousands of food lovers discovering restaurants, sharing culinary
                experiences, and connecting with friends who share your taste.
              </p>

              <div className="flex flex-col sm:flex-row gap-4 justify-center lg:justify-start">
                <motion.a
                  href="#early-access"
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  className="btn-primary text-lg px-8 py-4"
                >
                  Get Early Access
                </motion.a>
                <motion.a
                  href="#features"
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  className="btn-secondary text-lg px-8 py-4"
                >
                  Learn More
                </motion.a>
              </div>

              {/* Social Proof */}
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: 0.6 }}
                className="mt-12 flex items-center justify-center lg:justify-start gap-4"
              >
                <div className="flex -space-x-3">
                  {[1, 2, 3, 4, 5].map((i) => (
                    <div
                      key={i}
                      className="w-10 h-10 rounded-full border-2 border-white bg-gradient-to-br from-primary/50 to-secondary/50"
                      style={{ zIndex: 5 - i }}
                    />
                  ))}
                </div>
                <div className="text-sm">
                  <span className="font-semibold text-coffee-dark dark:text-white">500+</span>
                  <span className="text-light-text-secondary dark:text-dark-text-secondary">
                    {' '}people joined the waitlist
                  </span>
                </div>
              </motion.div>
            </motion.div>

            {/* Phone Mockup */}
            <div className="flex justify-center lg:justify-end">
              <PhoneMockup />
            </div>
          </div>
        </div>

        {/* Scroll indicator */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 1 }}
          className="absolute bottom-8 left-1/2 -translate-x-1/2 hidden md:block"
        >
          <motion.div
            animate={{ y: [0, 10, 0] }}
            transition={{ duration: 1.5, repeat: Infinity }}
            className="w-6 h-10 rounded-full border-2 border-light-text-tertiary flex items-start justify-center p-2"
          >
            <div className="w-1.5 h-3 bg-light-text-tertiary rounded-full" />
          </motion.div>
        </motion.div>
      </section>

      {/* Features Section */}
      <section id="features" className="py-20 md:py-32 bg-white/50 dark:bg-dark-card/50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="text-center mb-16"
          >
            <h2 className="section-title text-coffee-dark dark:text-white mb-4">
              Everything You Need to
              <br />
              <span className="text-gradient">Explore Food</span>
            </h2>
            <p className="section-subtitle">
              From discovering hidden gems to sharing your culinary adventures, Palytt has it all.
            </p>
          </motion.div>

          <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-6 md:gap-8">
            <FeatureCard
              icon={<MapIcon />}
              title="Discover Nearby"
              description="Find trending restaurants and hidden gems in your area with location-based recommendations tailored to your taste."
              delay={0}
            />
            <FeatureCard
              icon={<CameraIcon />}
              title="Share Experiences"
              description="Capture beautiful food photos, rate dishes, and share your culinary journey with the community."
              delay={0.1}
            />
            <FeatureCard
              icon={<UsersIcon />}
              title="Connect with Foodies"
              description="Follow friends, join food-focused groups, and discover new spots through people who share your taste."
              delay={0.2}
            />
            <FeatureCard
              icon={<ChatIcon />}
              title="Group Messaging"
              description="Plan food adventures with friends, share restaurant recommendations, and discuss your favorite dishes."
              delay={0.3}
            />
            <FeatureCard
              icon={<BookmarkIcon />}
              title="Save & Organize"
              description="Create custom lists of your favorite spots, save posts for later, and build your personal food diary."
              delay={0.4}
            />
            <FeatureCard
              icon={<SparklesIcon />}
              title="Personalized Feed"
              description="Get recommendations based on your preferences, dining history, and what's popular among friends."
              delay={0.5}
            />
          </div>
        </div>
      </section>

      {/* How It Works Section */}
      <section id="how-it-works" className="py-20 md:py-32">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="text-center mb-16"
          >
            <h2 className="section-title text-coffee-dark dark:text-white mb-4">
              How <span className="text-gradient">Palytt</span> Works
            </h2>
            <p className="section-subtitle">
              Getting started is easy. Here's how you can begin your food discovery journey.
            </p>
          </motion.div>

          <div className="grid md:grid-cols-3 gap-8 md:gap-12">
            {[
              {
                step: '01',
                title: 'Create Your Profile',
                description: 'Sign up in seconds and tell us about your food preferences and dietary needs.',
              },
              {
                step: '02',
                title: 'Discover & Connect',
                description: 'Explore nearby restaurants, follow friends, and join communities that match your taste.',
              },
              {
                step: '03',
                title: 'Share & Enjoy',
                description: 'Post your food adventures, save favorite spots, and inspire others with your discoveries.',
              },
            ].map((item, index) => (
              <motion.div
                key={item.step}
                initial={{ opacity: 0, y: 30 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: index * 0.2 }}
                className="relative text-center"
              >
                {/* Connecting line */}
                {index < 2 && (
                  <div className="hidden md:block absolute top-12 left-[60%] w-[80%] h-px bg-gradient-to-r from-primary/50 to-transparent" />
                )}
                
                <motion.div
                  whileHover={{ scale: 1.1, rotate: 5 }}
                  className="inline-flex items-center justify-center w-24 h-24 rounded-3xl bg-gradient-to-br from-primary to-secondary text-white text-3xl font-bold mb-6 shadow-lg shadow-primary/30"
                >
                  {item.step}
                </motion.div>
                <h3 className="text-xl font-semibold text-coffee-dark dark:text-white mb-3">
                  {item.title}
                </h3>
                <p className="text-light-text-secondary dark:text-dark-text-secondary max-w-xs mx-auto">
                  {item.description}
                </p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA / Early Access Section */}
      <section
        id="early-access"
        className="py-20 md:py-32 bg-gradient-to-br from-coffee-dark via-coffee-dark to-primary/20"
      >
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
          >
            <motion.div
              animate={{ rotate: [0, 5, -5, 0] }}
              transition={{ duration: 2, repeat: Infinity }}
              className="text-6xl mb-6"
            >
              🍽️
            </motion.div>
            <h2 className="section-title text-white mb-4">
              Be First to <span className="text-primary">Experience</span> Palytt
            </h2>
            <p className="text-xl text-gray-300 max-w-2xl mx-auto mb-10">
              Join our early access list and be among the first to discover amazing food
              experiences. We'll notify you as soon as we launch!
            </p>
          </motion.div>

          <EarlyAccessForm />

          <motion.div
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
            transition={{ delay: 0.4 }}
            className="mt-12 flex flex-wrap justify-center gap-8 text-gray-400 text-sm"
          >
            <div className="flex items-center gap-2">
              <CheckIcon />
              <span>Free to use</span>
            </div>
            <div className="flex items-center gap-2">
              <CheckIcon />
              <span>No spam, ever</span>
            </div>
            <div className="flex items-center gap-2">
              <CheckIcon />
              <span>Exclusive early features</span>
            </div>
          </motion.div>
        </div>
      </section>
    </div>
  )
}

// Icon components
function MapIcon() {
  return (
    <svg className="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={1.5}
        d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
      />
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={1.5}
        d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"
      />
    </svg>
  )
}

function CameraIcon() {
  return (
    <svg className="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={1.5}
        d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"
      />
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={1.5}
        d="M15 13a3 3 0 11-6 0 3 3 0 016 0z"
      />
    </svg>
  )
}

function UsersIcon() {
  return (
    <svg className="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={1.5}
        d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"
      />
    </svg>
  )
}

function ChatIcon() {
  return (
    <svg className="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={1.5}
        d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
      />
    </svg>
  )
}

function BookmarkIcon() {
  return (
    <svg className="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={1.5}
        d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z"
      />
    </svg>
  )
}

function SparklesIcon() {
  return (
    <svg className="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={1.5}
        d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z"
      />
    </svg>
  )
}

function CheckIcon() {
  return (
    <svg className="w-5 h-5 text-success" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
    </svg>
  )
}
