import { createFileRoute, Link } from '@tanstack/react-router'
import { useForm } from '@tanstack/react-form'
import { useMutation } from '@tanstack/react-query'
import { motion, AnimatePresence } from 'framer-motion'
import { z } from 'zod'
import { useState } from 'react'

export const Route = createFileRoute('/support')({
  component: SupportPage,
})

async function submitContactForm(data: { name: string; email: string; subject: string; message: string }) {
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
      mutation.mutate(value)
    },
  })

  const faqs = [
    {
      question: 'When will Palytt be available?',
      answer: 'Palytt is currently in development and will be launching soon on iOS. Sign up for early access to be notified!',
    },
    {
      question: 'Is Palytt free to use?',
      answer: 'Yes! Palytt is free to download and use. We may introduce optional premium features in the future.',
    },
    {
      question: 'How do I delete my account?',
      answer: 'You can delete your account from Settings > Account > Delete Account in the app.',
    },
    {
      question: 'Is my data secure?',
      answer: 'Yes. We use industry-standard encryption and security measures. See our Privacy Policy for details.',
    },
    {
      question: 'Can I use Palytt on Android?',
      answer: 'We are initially launching on iOS, but Android support is planned. Sign up for updates!',
    },
    {
      question: 'How do I report inappropriate content?',
      answer: 'Tap the three-dot menu on any post or user and select "Report". We review all reports within 24 hours.',
    },
  ]

  return (
    <div className="min-h-screen pt-24 md:pt-32 pb-16">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-center mb-16"
        >
          <h1 className="text-4xl md:text-5xl font-bold text-coffee-dark dark:text-white mb-4">
            How Can We <span className="text-gradient">Help?</span>
          </h1>
          <p className="text-xl text-light-text-secondary max-w-2xl mx-auto">
            Have a question or need assistance? We're here to help.
          </p>
        </motion.div>

        <div className="grid lg:grid-cols-2 gap-12 lg:gap-16">
          {/* FAQ Section */}
          <motion.div initial={{ opacity: 0, x: -30 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: 0.1 }}>
            <h2 className="text-2xl font-bold text-coffee-dark mb-6">Frequently Asked Questions</h2>
            <div className="space-y-4">
              {faqs.map((faq, index) => (
                <div key={index} className="card overflow-hidden">
                  <button
                    onClick={() => setOpenFaq(openFaq === index ? null : index)}
                    className="w-full px-6 py-4 flex items-center justify-between text-left"
                  >
                    <span className="font-medium text-coffee-dark pr-4">{faq.question}</span>
                    <motion.span animate={{ rotate: openFaq === index ? 180 : 0 }}>
                      <svg className="w-5 h-5 text-light-text-tertiary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                      </svg>
                    </motion.span>
                  </button>
                  <AnimatePresence>
                    {openFaq === index && (
                      <motion.div
                        initial={{ height: 0, opacity: 0 }}
                        animate={{ height: 'auto', opacity: 1 }}
                        exit={{ height: 0, opacity: 0 }}
                        className="overflow-hidden"
                      >
                        <p className="px-6 pb-4 text-light-text-secondary">{faq.answer}</p>
                      </motion.div>
                    )}
                  </AnimatePresence>
                </div>
              ))}
            </div>
          </motion.div>

          {/* Contact Form */}
          <motion.div initial={{ opacity: 0, x: 30 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: 0.2 }}>
            <h2 className="text-2xl font-bold text-coffee-dark mb-6">Contact Support</h2>
            <div className="card p-6 md:p-8">
              <AnimatePresence mode="wait">
                {mutation.isSuccess ? (
                  <motion.div key="success" initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="text-center py-8">
                    <div className="w-16 h-16 mx-auto mb-4 bg-success/10 rounded-full flex items-center justify-center">
                      <svg className="w-8 h-8 text-success" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                      </svg>
                    </div>
                    <h3 className="text-xl font-semibold text-coffee-dark mb-2">Message Sent!</h3>
                    <p className="text-light-text-secondary">We'll get back to you as soon as possible.</p>
                  </motion.div>
                ) : (
                  <motion.form
                    key="form"
                    onSubmit={(e) => {
                      e.preventDefault()
                      form.handleSubmit()
                    }}
                    className="space-y-6"
                  >
                    <form.Field name="name">
                      {(field) => (
                        <div className="space-y-2">
                          <label className="block text-sm font-medium text-coffee-dark">Name</label>
                          <input
                            type="text"
                            placeholder="Your name"
                            value={field.state.value}
                            onChange={(e) => field.handleChange(e.target.value)}
                            className="input-field"
                            required
                          />
                        </div>
                      )}
                    </form.Field>

                    <form.Field name="email">
                      {(field) => (
                        <div className="space-y-2">
                          <label className="block text-sm font-medium text-coffee-dark">Email</label>
                          <input
                            type="email"
                            placeholder="your@email.com"
                            value={field.state.value}
                            onChange={(e) => field.handleChange(e.target.value)}
                            className="input-field"
                            required
                          />
                        </div>
                      )}
                    </form.Field>

                    <form.Field name="subject">
                      {(field) => (
                        <div className="space-y-2">
                          <label className="block text-sm font-medium text-coffee-dark">Subject</label>
                          <input
                            type="text"
                            placeholder="What can we help you with?"
                            value={field.state.value}
                            onChange={(e) => field.handleChange(e.target.value)}
                            className="input-field"
                            required
                          />
                        </div>
                      )}
                    </form.Field>

                    <form.Field name="message">
                      {(field) => (
                        <div className="space-y-2">
                          <label className="block text-sm font-medium text-coffee-dark">Message</label>
                          <textarea
                            placeholder="Please describe your issue..."
                            rows={5}
                            value={field.state.value}
                            onChange={(e) => field.handleChange(e.target.value)}
                            className="input-field resize-none"
                            required
                          />
                        </div>
                      )}
                    </form.Field>

                    <motion.button
                      type="submit"
                      disabled={mutation.isPending}
                      whileHover={{ scale: 1.02 }}
                      whileTap={{ scale: 0.98 }}
                      className="btn-primary w-full"
                    >
                      {mutation.isPending ? 'Sending...' : 'Send Message'}
                    </motion.button>
                  </motion.form>
                )}
              </AnimatePresence>
            </div>

            <div className="mt-8 p-6 bg-light-bg rounded-2xl">
              <h3 className="font-semibold text-coffee-dark mb-4">Other Ways to Reach Us</h3>
              <a
                href="mailto:kavyrattana@gmail.com"
                className="flex items-center gap-3 text-light-text-secondary hover:text-primary transition-colors"
              >
                <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
                  <svg className="w-5 h-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                  </svg>
                </div>
                <span>kavyrattana@gmail.com</span>
              </a>
            </div>
          </motion.div>
        </div>
      </div>
    </div>
  )
}
