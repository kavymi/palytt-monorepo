import { createFileRoute } from '@tanstack/react-router'
import { useForm } from '@tanstack/react-form'
import { useMutation } from '@tanstack/react-query'
import { motion, AnimatePresence } from 'framer-motion'
import { z } from 'zod'
import { useState } from 'react'
import { SEOHead, PAGE_SEO } from '~/components/SEOHead'

export const Route = createFileRoute('/support')({
  component: SupportPage,
})

const contactSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  email: z.string().email('Please enter a valid email address'),
  subject: z.string().min(5, 'Subject must be at least 5 characters'),
  message: z.string().min(20, 'Message must be at least 20 characters'),
})

async function submitContactForm(data: z.infer<typeof contactSchema>) {
  await new Promise((resolve) => setTimeout(resolve, 1000))
  console.log('Support request submitted:', data)
  console.log('Email would be sent to: kavyrattana@gmail.com')
  return { success: true }
}

function SupportPage() {
  const [openFaq, setOpenFaq] = useState<number | null>(null)

  const mutation = useMutation({
    mutationFn: submitContactForm,
  })

  const form = useForm({
    defaultValues: {
      name: '',
      email: '',
      subject: '',
      message: '',
    },
    onSubmit: async ({ value }) => {
      const validation = contactSchema.safeParse(value)
      if (validation.success) {
        mutation.mutate(value)
      }
    },
  })

  const faqs = [
    {
      question: 'When will Palytt be available?',
      answer:
        'Palytt is currently in development and will be launching soon on iOS. Sign up for early access on our homepage to be notified when we launch!',
    },
    {
      question: 'Is Palytt free to use?',
      answer:
        'Yes! Palytt is free to download and use. We may introduce optional premium features in the future, but the core experience will always remain free.',
    },
    {
      question: 'How do I delete my account?',
      answer:
        'You can delete your account from the Settings page in the app. Go to Settings > Account > Delete Account. This will permanently remove all your data.',
    },
    {
      question: 'Is my data secure?',
      answer:
        'Absolutely. We use industry-standard encryption and security measures to protect your data. Read our Privacy Policy for more details on how we handle your information.',
    },
    {
      question: 'Can I use Palytt on Android?',
      answer:
        'We are initially launching on iOS, but Android support is on our roadmap. Sign up for updates to know when Android becomes available.',
    },
    {
      question: 'How do I report inappropriate content?',
      answer:
        'You can report any post, comment, or user by tapping the three-dot menu and selecting "Report". Our team reviews all reports within 24 hours.',
    },
  ]

  return (
    <>
      <SEOHead {...PAGE_SEO.support} />
      <div className="min-h-screen pt-24 md:pt-32 pb-16">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          {/* Header */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
            className="text-center mb-16"
          >
            <h1 className="text-4xl md:text-5xl font-bold text-coffee-dark dark:text-white mb-4">
              How Can We <span className="text-gradient">Help?</span>
            </h1>
            <p className="text-xl text-light-text-secondary dark:text-dark-text-secondary max-w-2xl mx-auto">
              Have a question or need assistance? We're here to help you get the most out of Palytt.
            </p>
          </motion.div>

          <div className="grid lg:grid-cols-2 gap-12 lg:gap-16">
            {/* FAQ Section */}
            <motion.div
              initial={{ opacity: 0, x: -30 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.5, delay: 0.1 }}
            >
              <h2 className="text-2xl font-bold text-coffee-dark dark:text-white mb-6">
                Frequently Asked Questions
              </h2>
              <div className="space-y-4">
                {faqs.map((faq, index) => (
                  <motion.div
                    key={index}
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.1 + index * 0.05 }}
                    className="card overflow-hidden"
                  >
                    <button
                      onClick={() => setOpenFaq(openFaq === index ? null : index)}
                      className="w-full px-6 py-4 flex items-center justify-between text-left"
                    >
                      <span className="font-medium text-coffee-dark dark:text-white pr-4">
                        {faq.question}
                      </span>
                      <motion.span
                        animate={{ rotate: openFaq === index ? 180 : 0 }}
                        transition={{ duration: 0.2 }}
                        className="flex-shrink-0"
                      >
                        <svg
                          className="w-5 h-5 text-light-text-tertiary"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth={2}
                            d="M19 9l-7 7-7-7"
                          />
                        </svg>
                      </motion.span>
                    </button>
                    <AnimatePresence>
                      {openFaq === index && (
                        <motion.div
                          initial={{ height: 0, opacity: 0 }}
                          animate={{ height: 'auto', opacity: 1 }}
                          exit={{ height: 0, opacity: 0 }}
                          transition={{ duration: 0.2 }}
                          className="overflow-hidden"
                        >
                          <p className="px-6 pb-4 text-light-text-secondary dark:text-dark-text-secondary">
                            {faq.answer}
                          </p>
                        </motion.div>
                      )}
                    </AnimatePresence>
                  </motion.div>
                ))}
              </div>
            </motion.div>

            {/* Contact Form */}
            <motion.div
              initial={{ opacity: 0, x: 30 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.5, delay: 0.2 }}
            >
              <h2 className="text-2xl font-bold text-coffee-dark dark:text-white mb-6">
                Contact Support
              </h2>
              <div className="card p-6 md:p-8">
                <AnimatePresence mode="wait">
                  {mutation.isSuccess ? (
                    <motion.div
                      key="success"
                      initial={{ opacity: 0, scale: 0.95 }}
                      animate={{ opacity: 1, scale: 1 }}
                      className="text-center py-8"
                    >
                      <motion.div
                        initial={{ scale: 0 }}
                        animate={{ scale: 1 }}
                        transition={{ type: 'spring', delay: 0.2 }}
                        className="w-16 h-16 mx-auto mb-4 bg-success/10 rounded-full flex items-center justify-center"
                      >
                        <svg
                          className="w-8 h-8 text-success"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth={2}
                            d="M5 13l4 4L19 7"
                          />
                        </svg>
                      </motion.div>
                      <h3 className="text-xl font-semibold text-coffee-dark dark:text-white mb-2">
                        Message Sent!
                      </h3>
                      <p className="text-light-text-secondary dark:text-dark-text-secondary">
                        Thank you for reaching out. We'll get back to you as soon as possible.
                      </p>
                    </motion.div>
                  ) : (
                    <motion.form
                      key="form"
                      onSubmit={(e) => {
                        e.preventDefault()
                        e.stopPropagation()
                        form.handleSubmit()
                      }}
                      className="space-y-6"
                    >
                      <form.Field
                        name="name"
                        validators={{
                          onChange: ({ value }) =>
                            value.length < 2 ? 'Name must be at least 2 characters' : undefined,
                        }}
                      >
                        {(field) => (
                          <FormField
                            label="Name"
                            error={
                              field.state.meta.isTouched && field.state.meta.errors[0]
                                ? String(field.state.meta.errors[0])
                                : undefined
                            }
                          >
                            <input
                              type="text"
                              placeholder="Your name"
                              value={field.state.value}
                              onChange={(e) => field.handleChange(e.target.value)}
                              onBlur={field.handleBlur}
                              className="input-field"
                            />
                          </FormField>
                        )}
                      </form.Field>

                      <form.Field
                        name="email"
                        validators={{
                          onChange: ({ value }) => {
                            const result = z.string().email().safeParse(value)
                            return result.success ? undefined : 'Please enter a valid email'
                          },
                        }}
                      >
                        {(field) => (
                          <FormField
                            label="Email"
                            error={
                              field.state.meta.isTouched && field.state.meta.errors[0]
                                ? String(field.state.meta.errors[0])
                                : undefined
                            }
                          >
                            <input
                              type="email"
                              placeholder="your@email.com"
                              value={field.state.value}
                              onChange={(e) => field.handleChange(e.target.value)}
                              onBlur={field.handleBlur}
                              className="input-field"
                            />
                          </FormField>
                        )}
                      </form.Field>

                      <form.Field
                        name="subject"
                        validators={{
                          onChange: ({ value }) =>
                            value.length < 5
                              ? 'Subject must be at least 5 characters'
                              : undefined,
                        }}
                      >
                        {(field) => (
                          <FormField
                            label="Subject"
                            error={
                              field.state.meta.isTouched && field.state.meta.errors[0]
                                ? String(field.state.meta.errors[0])
                                : undefined
                            }
                          >
                            <input
                              type="text"
                              placeholder="What can we help you with?"
                              value={field.state.value}
                              onChange={(e) => field.handleChange(e.target.value)}
                              onBlur={field.handleBlur}
                              className="input-field"
                            />
                          </FormField>
                        )}
                      </form.Field>

                      <form.Field
                        name="message"
                        validators={{
                          onChange: ({ value }) =>
                            value.length < 20
                              ? 'Message must be at least 20 characters'
                              : undefined,
                        }}
                      >
                        {(field) => (
                          <FormField
                            label="Message"
                            error={
                              field.state.meta.isTouched && field.state.meta.errors[0]
                                ? String(field.state.meta.errors[0])
                                : undefined
                            }
                          >
                            <textarea
                              placeholder="Please describe your issue or question in detail..."
                              rows={5}
                              value={field.state.value}
                              onChange={(e) => field.handleChange(e.target.value)}
                              onBlur={field.handleBlur}
                              className="input-field resize-none"
                            />
                          </FormField>
                        )}
                      </form.Field>

                      <motion.button
                        type="submit"
                        disabled={mutation.isPending}
                        whileHover={{ scale: 1.02 }}
                        whileTap={{ scale: 0.98 }}
                        className="btn-primary w-full"
                      >
                        {mutation.isPending ? (
                          <span className="flex items-center justify-center gap-2">
                            <svg
                              className="animate-spin w-5 h-5"
                              fill="none"
                              viewBox="0 0 24 24"
                            >
                              <circle
                                className="opacity-25"
                                cx="12"
                                cy="12"
                                r="10"
                                stroke="currentColor"
                                strokeWidth="4"
                              />
                              <path
                                className="opacity-75"
                                fill="currentColor"
                                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                              />
                            </svg>
                            Sending...
                          </span>
                        ) : (
                          'Send Message'
                        )}
                      </motion.button>
                    </motion.form>
                  )}
                </AnimatePresence>
              </div>

              {/* Direct Contact */}
              <div className="mt-8 p-6 bg-light-bg dark:bg-dark-surface rounded-2xl">
                <h3 className="font-semibold text-coffee-dark dark:text-white mb-4">
                  Other Ways to Reach Us
                </h3>
                <div className="space-y-3">
                  <a
                    href="mailto:kavyrattana@gmail.com"
                    className="flex items-center gap-3 text-light-text-secondary dark:text-dark-text-secondary hover:text-primary transition-colors"
                  >
                    <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
                      <svg
                        className="w-5 h-5 text-primary"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                        />
                      </svg>
                    </div>
                    <span>kavyrattana@gmail.com</span>
                  </a>
                  <a
                    href="https://twitter.com/palytt_app"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center gap-3 text-light-text-secondary dark:text-dark-text-secondary hover:text-primary transition-colors"
                  >
                    <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
                      <svg className="w-5 h-5 text-primary" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
                      </svg>
                    </div>
                    <span>@palytt_app on X</span>
                  </a>
                </div>
              </div>
            </motion.div>
          </div>
        </div>
      </div>
    </>
  )
}

function FormField({
  label,
  error,
  children,
}: {
  label: string
  error?: string
  children: React.ReactNode
}) {
  return (
    <div className="space-y-2">
      <label className="block text-sm font-medium text-coffee-dark dark:text-white">
        {label}
      </label>
      {children}
      <AnimatePresence>
        {error && (
          <motion.p
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            className="text-sm text-error"
          >
            {error}
          </motion.p>
        )}
      </AnimatePresence>
    </div>
  )
}

