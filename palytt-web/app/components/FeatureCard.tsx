import { motion } from 'framer-motion'
import type { ReactNode } from 'react'

interface FeatureCardProps {
  icon: ReactNode
  title: string
  description: string
  delay?: number
}

export function FeatureCard({ icon, title, description, delay = 0 }: FeatureCardProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 30 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: '-50px' }}
      transition={{ duration: 0.5, delay }}
      whileHover={{ y: -5, scale: 1.02 }}
      className="card p-6 md:p-8 group cursor-default"
    >
      <motion.div
        className="w-14 h-14 rounded-2xl bg-gradient-to-br from-primary/10 to-secondary/10 flex items-center justify-center mb-5 group-hover:scale-110 transition-transform duration-300"
        whileHover={{ rotate: [0, -5, 5, 0] }}
        transition={{ duration: 0.5 }}
      >
        <div className="text-primary">{icon}</div>
      </motion.div>
      <h3 className="text-xl font-semibold text-coffee-dark dark:text-white mb-3">
        {title}
      </h3>
      <p className="text-light-text-secondary dark:text-dark-text-secondary leading-relaxed">
        {description}
      </p>
    </motion.div>
  )
}

