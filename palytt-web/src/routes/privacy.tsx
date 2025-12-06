import { createFileRoute } from '@tanstack/react-router'
import { motion } from 'framer-motion'

export const Route = createFileRoute('/privacy')({
  component: PrivacyPage,
  head: () => ({
    meta: [
      { title: 'Privacy Policy - Palytt' },
      { name: 'description', content: 'Learn how Palytt protects your privacy and handles your data.' },
    ],
  }),
})

function PrivacyPage() {
  return (
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
                with this policy. If you do not agree with our policies and practices, please do
                not use our services.
              </p>
            </Section>

            <Section title="Information We Collect">
              <h4 className="text-lg font-semibold text-coffee-dark dark:text-white mt-4">
                Information You Provide
              </h4>
              <ul className="list-disc pl-6 space-y-2 text-light-text-secondary dark:text-dark-text-secondary">
                <li>
                  <strong>Account Information:</strong> When you create an account, we collect your
                  name, email address, username, and profile photo.
                </li>
                <li>
                  <strong>Profile Information:</strong> Information you add to your profile such as
                  bio, dietary preferences, and favorite cuisines.
                </li>
                <li>
                  <strong>Content:</strong> Photos, reviews, ratings, comments, and other content
                  you post on the platform.
                </li>
                <li>
                  <strong>Communications:</strong> Messages you send through our direct messaging
                  and group chat features.
                </li>
                <li>
                  <strong>Contacts:</strong> If you choose to sync your contacts, we may access your
                  contact list to help you find friends on Palytt.
                </li>
              </ul>

              <h4 className="text-lg font-semibold text-coffee-dark dark:text-white mt-6">
                Information Collected Automatically
              </h4>
              <ul className="list-disc pl-6 space-y-2 text-light-text-secondary dark:text-dark-text-secondary">
                <li>
                  <strong>Location Data:</strong> With your permission, we collect precise location
                  data to provide location-based restaurant recommendations and allow you to tag
                  posts with locations.
                </li>
                <li>
                  <strong>Device Information:</strong> Device type, operating system, unique device
                  identifiers, and mobile network information.
                </li>
                <li>
                  <strong>Usage Data:</strong> How you interact with our app, including pages viewed,
                  features used, and time spent on the platform.
                </li>
              </ul>
            </Section>

            <Section title="How We Use Your Information">
              <p>We use the information we collect to:</p>
              <ul className="list-disc pl-6 space-y-2 text-light-text-secondary dark:text-dark-text-secondary">
                <li>Provide, maintain, and improve our services</li>
                <li>Personalize your experience and show relevant content</li>
                <li>Enable social features like following, messaging, and sharing</li>
                <li>Send you notifications about activity on your account</li>
                <li>Provide location-based restaurant discovery features</li>
                <li>Analyze usage patterns to improve our platform</li>
                <li>Detect, prevent, and address technical issues and abuse</li>
                <li>Communicate with you about updates, features, and promotional offers</li>
              </ul>
            </Section>

            <Section title="Sharing of Information">
              <p>We may share your information in the following circumstances:</p>
              <ul className="list-disc pl-6 space-y-2 text-light-text-secondary dark:text-dark-text-secondary">
                <li>
                  <strong>With Other Users:</strong> Your profile information, posts, and public
                  activity are visible to other users of the platform.
                </li>
                <li>
                  <strong>Service Providers:</strong> We work with third-party companies to help us
                  operate our services (e.g., cloud hosting, analytics, customer support).
                </li>
                <li>
                  <strong>Legal Requirements:</strong> We may disclose information if required by law
                  or in response to valid legal requests.
                </li>
                <li>
                  <strong>Business Transfers:</strong> In connection with any merger, acquisition, or
                  sale of company assets.
                </li>
              </ul>
              <p className="mt-4">
                We do not sell your personal information to third parties.
              </p>
            </Section>

            <Section title="Data Security">
              <p>
                We implement appropriate technical and organizational security measures to protect
                your personal information against unauthorized access, alteration, disclosure, or
                destruction. These measures include:
              </p>
              <ul className="list-disc pl-6 space-y-2 text-light-text-secondary dark:text-dark-text-secondary">
                <li>Encryption of data in transit and at rest</li>
                <li>Regular security assessments and audits</li>
                <li>Access controls and authentication requirements</li>
                <li>Secure data centers and infrastructure</li>
              </ul>
            </Section>

            <Section title="Your Rights and Choices">
              <p>You have the following rights regarding your personal data:</p>
              <ul className="list-disc pl-6 space-y-2 text-light-text-secondary dark:text-dark-text-secondary">
                <li>
                  <strong>Access:</strong> Request a copy of your personal data
                </li>
                <li>
                  <strong>Correction:</strong> Update or correct inaccurate information
                </li>
                <li>
                  <strong>Deletion:</strong> Request deletion of your account and data
                </li>
                <li>
                  <strong>Portability:</strong> Export your data in a machine-readable format
                </li>
                <li>
                  <strong>Opt-out:</strong> Unsubscribe from marketing communications
                </li>
              </ul>
              <p className="mt-4">
                To exercise these rights, please contact us at{' '}
                <a href="mailto:kavyrattana@gmail.com" className="text-primary hover:underline">
                  kavyrattana@gmail.com
                </a>
              </p>
            </Section>

            <Section title="Children's Privacy">
              <p>
                Our services are not directed to children under 13 years of age. We do not
                knowingly collect personal information from children under 13. If you are a parent
                or guardian and believe your child has provided us with personal information,
                please contact us.
              </p>
            </Section>

            <Section title="International Data Transfers">
              <p>
                Your information may be transferred to and processed in countries other than your
                country of residence. These countries may have different data protection laws. We
                ensure appropriate safeguards are in place to protect your information in
                accordance with this Privacy Policy.
              </p>
            </Section>

            <Section title="Changes to This Policy">
              <p>
                We may update this Privacy Policy from time to time. We will notify you of any
                significant changes by posting the new Privacy Policy on this page and updating
                the "Last updated" date. Your continued use of the service after such changes
                constitutes your acceptance of the new Privacy Policy.
              </p>
            </Section>

            <Section title="Contact Us">
              <p>
                If you have any questions about this Privacy Policy or our privacy practices,
                please contact us at:
              </p>
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
