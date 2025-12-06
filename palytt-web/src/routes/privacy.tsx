import { createFileRoute } from '@tanstack/react-router'
import { motion } from 'framer-motion'
import { SEOHead, PAGE_SEO } from '~/components/SEOHead'

export const Route = createFileRoute('/privacy')({
  component: PrivacyPage,
})

function PrivacyPage() {
  return (
    <>
      <SEOHead {...PAGE_SEO.privacy} />
      <div className="min-h-screen pt-24 md:pt-32 pb-16">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
        >
          <h1 className="text-4xl md:text-5xl font-bold text-coffee-dark dark:text-white mb-4">
            Privacy Policy
          </h1>
          <p className="text-light-text-secondary dark:text-dark-text-secondary mb-8">
            Last updated: December 5, 2025
          </p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.1 }}
          className="prose prose-lg max-w-none"
        >
          <div className="card p-8 space-y-8">
            <Section title="Introduction">
              <p>
                Welcome to Palytt ("we," "our," or "us"). We are committed to protecting your
                privacy and ensuring you have a positive experience using our social food
                discovery platform. This Privacy Policy explains how we collect, use, disclose,
                and safeguard your information when you use our mobile application and website.
              </p>
              <p>
                By using Palytt, you agree to the collection and use of information in accordance
                with this policy.
              </p>
            </Section>

            <Section title="Information We Collect">
              <h4 className="text-lg font-semibold text-coffee-dark dark:text-white mt-4">
                Information You Provide
              </h4>
              <ul className="list-disc pl-6 space-y-2 text-light-text-secondary dark:text-dark-text-secondary">
                <li><strong>Account Information:</strong> Name, email address, username, and profile photo.</li>
                <li><strong>Profile Information:</strong> Bio, dietary preferences, and favorite cuisines.</li>
                <li><strong>Content:</strong> Photos, reviews, ratings, comments, and other content you post.</li>
                <li><strong>Communications:</strong> Messages through our messaging features.</li>
                <li><strong>Contacts:</strong> If you sync contacts to find friends on Palytt.</li>
              </ul>

              <h4 className="text-lg font-semibold text-coffee-dark dark:text-white mt-6">
                Information Collected Automatically
              </h4>
              <ul className="list-disc pl-6 space-y-2 text-light-text-secondary dark:text-dark-text-secondary">
                <li><strong>Location Data:</strong> With permission, for location-based recommendations.</li>
                <li><strong>Device Information:</strong> Device type, OS, and unique identifiers.</li>
                <li><strong>Usage Data:</strong> How you interact with our app.</li>
              </ul>
            </Section>

            <Section title="How We Use Your Information">
              <ul className="list-disc pl-6 space-y-2 text-light-text-secondary dark:text-dark-text-secondary">
                <li>Provide, maintain, and improve our services</li>
                <li>Personalize your experience and show relevant content</li>
                <li>Enable social features like following, messaging, and sharing</li>
                <li>Send notifications about activity on your account</li>
                <li>Provide location-based restaurant discovery features</li>
                <li>Analyze usage patterns to improve our platform</li>
                <li>Detect, prevent, and address technical issues and abuse</li>
              </ul>
            </Section>

            <Section title="Data Security">
              <p>
                We implement appropriate technical and organizational security measures to protect
                your personal information including encryption, regular security assessments,
                access controls, and secure infrastructure.
              </p>
            </Section>

            <Section title="Your Rights">
              <ul className="list-disc pl-6 space-y-2 text-light-text-secondary dark:text-dark-text-secondary">
                <li><strong>Access:</strong> Request a copy of your personal data</li>
                <li><strong>Correction:</strong> Update or correct inaccurate information</li>
                <li><strong>Deletion:</strong> Request deletion of your account and data</li>
                <li><strong>Portability:</strong> Export your data</li>
                <li><strong>Opt-out:</strong> Unsubscribe from marketing communications</li>
              </ul>
              <p className="mt-4">
                Contact us at{' '}
                <a href="mailto:kavyrattana@gmail.com" className="text-primary hover:underline">
                  kavyrattana@gmail.com
                </a>
              </p>
            </Section>

            <Section title="Children's Privacy">
              <p>
                Our services are not directed to children under 13. We do not knowingly collect
                personal information from children under 13.
              </p>
            </Section>

            <Section title="Contact Us">
              <p>Questions about this Privacy Policy? Contact us:</p>
              <div className="mt-4 p-4 bg-light-bg dark:bg-dark-surface rounded-xl">
                <p className="font-semibold text-coffee-dark dark:text-white">Palytt Inc.</p>
                <p className="text-light-text-secondary dark:text-dark-text-secondary">
                  Email:{' '}
                  <a href="mailto:kavyrattana@gmail.com" className="text-primary hover:underline">
                    kavyrattana@gmail.com
                  </a>
                </p>
              </div>
            </Section>
          </div>
        </motion.div>
      </div>
      </div>
    </>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <h2 className="text-2xl font-bold text-coffee-dark dark:text-white mb-4">{title}</h2>
      <div className="text-light-text-secondary dark:text-dark-text-secondary space-y-4">
        {children}
      </div>
    </div>
  )
}

