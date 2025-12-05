import { motion } from 'framer-motion'

interface PhoneMockupProps {
  className?: string
}

export function PhoneMockup({ className = '' }: PhoneMockupProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 50, rotateY: -15 }}
      animate={{ opacity: 1, y: 0, rotateY: 0 }}
      transition={{ duration: 0.8, ease: 'easeOut' }}
      className={`relative ${className}`}
      style={{ perspective: '1000px' }}
    >
      {/* Glow effect */}
      <div className="absolute inset-0 blur-3xl bg-gradient-to-r from-primary/30 via-secondary/30 to-primary/30 opacity-50 scale-110" />
      
      {/* Phone Frame */}
      <motion.div
        animate={{ y: [0, -10, 0] }}
        transition={{ duration: 4, repeat: Infinity, ease: 'easeInOut' }}
        className="relative z-10"
      >
        <div className="relative w-[280px] sm:w-[320px] h-[580px] sm:h-[650px] bg-coffee-dark rounded-[3rem] p-2 shadow-2xl shadow-coffee-dark/30">
          {/* Screen */}
          <div className="relative w-full h-full bg-light-bg rounded-[2.5rem] overflow-hidden">
            {/* Dynamic Island */}
            <div className="absolute top-4 left-1/2 -translate-x-1/2 w-32 h-8 bg-coffee-dark rounded-full z-20" />
            
            {/* App Content Preview */}
            <div className="pt-16 px-4 pb-4 h-full flex flex-col">
              {/* Header */}
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-primary to-secondary" />
                  <span className="font-semibold text-coffee-dark text-sm">Palytt</span>
                </div>
                <div className="flex gap-2">
                  <div className="w-8 h-8 rounded-full bg-light-divider" />
                  <div className="w-8 h-8 rounded-full bg-light-divider" />
                </div>
              </div>

              {/* Stories Row */}
              <div className="flex gap-3 mb-4 overflow-hidden">
                {[1, 2, 3, 4].map((i) => (
                  <motion.div
                    key={i}
                    initial={{ opacity: 0, scale: 0.8 }}
                    animate={{ opacity: 1, scale: 1 }}
                    transition={{ delay: 0.2 + i * 0.1 }}
                    className="flex-shrink-0"
                  >
                    <div className="w-14 h-14 rounded-full bg-gradient-to-br from-primary to-secondary p-0.5">
                      <div className="w-full h-full rounded-full bg-light-bg p-0.5">
                        <div className="w-full h-full rounded-full bg-gradient-to-br from-milk-tea to-primary/30" />
                      </div>
                    </div>
                  </motion.div>
                ))}
              </div>

              {/* Feed Cards */}
              <div className="flex-1 space-y-3 overflow-hidden">
                {[1, 2].map((i) => (
                  <motion.div
                    key={i}
                    initial={{ opacity: 0, x: 20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: 0.4 + i * 0.2 }}
                    className="bg-white rounded-2xl p-3 shadow-sm"
                  >
                    <div className="flex items-center gap-2 mb-2">
                      <div className="w-8 h-8 rounded-full bg-gradient-to-br from-primary/30 to-secondary/30" />
                      <div className="flex-1">
                        <div className="h-2.5 w-20 bg-light-divider rounded-full" />
                        <div className="h-2 w-12 bg-light-divider/60 rounded-full mt-1" />
                      </div>
                    </div>
                    <div className={`h-24 rounded-xl bg-gradient-to-br ${
                      i === 1 
                        ? 'from-primary/20 via-secondary/20 to-milk-tea/30' 
                        : 'from-blue-accent/20 via-light-blue-accent/30 to-milk-tea/20'
                    }`} />
                    <div className="flex items-center gap-4 mt-2">
                      <div className="flex items-center gap-1">
                        <div className="w-5 h-5 rounded-full bg-primary/20" />
                        <div className="h-2 w-6 bg-light-divider rounded-full" />
                      </div>
                      <div className="flex items-center gap-1">
                        <div className="w-5 h-5 rounded-full bg-blue-accent/20" />
                        <div className="h-2 w-6 bg-light-divider rounded-full" />
                      </div>
                    </div>
                  </motion.div>
                ))}
              </div>

              {/* Tab Bar */}
              <div className="mt-auto pt-2">
                <div className="flex justify-around items-center bg-white/80 backdrop-blur-sm rounded-2xl py-2 px-4">
                  {['home', 'search', 'plus', 'heart', 'user'].map((tab, i) => (
                    <motion.div
                      key={tab}
                      whileHover={{ scale: 1.1 }}
                      className={`w-6 h-6 rounded-lg ${
                        i === 0 ? 'bg-primary' : 'bg-light-divider'
                      }`}
                    />
                  ))}
                </div>
              </div>
            </div>
          </div>
          
          {/* Side buttons */}
          <div className="absolute -left-0.5 top-28 w-1 h-8 bg-gray-600 rounded-l-full" />
          <div className="absolute -left-0.5 top-44 w-1 h-12 bg-gray-600 rounded-l-full" />
          <div className="absolute -left-0.5 top-60 w-1 h-12 bg-gray-600 rounded-l-full" />
          <div className="absolute -right-0.5 top-36 w-1 h-16 bg-gray-600 rounded-r-full" />
        </div>
      </motion.div>
    </motion.div>
  )
}
