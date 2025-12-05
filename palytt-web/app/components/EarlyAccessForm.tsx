import { useForm } from '@tanstack/react-form'
import { useMutation } from '@tanstack/react-query'
import { motion, AnimatePresence } from 'framer-motion'
import { z } from 'zod'

const emailSchema = z.string().email('Please enter a valid email address')

interface SubmitResponse {
  success: boolean
  message: string
}

async function submitEarlyAccess(email: string): Promise<SubmitResponse> {
  // In production, this would call your actual API endpoint
  // For now, we'll simulate a successful submission
  await new Promise((resolve) => setTimeout(resolve, 1000))
  
  // You could integrate with services like:
  // - Mailchimp
  // - ConvertKit
  // - SendGrid
  // - Your own backend
  
  console.log(`Early access signup: ${email}`)
  console.log(`Notification email would be sent to: kavyrattana@gmail.com`)
  
  return {
    success: true,
    message: "You're on the list! We'll notify you when Palytt launches.",
  }
}

export function EarlyAccessForm() {
  const mutation = useMutation({
    mutationFn: submitEarlyAccess,
  })

  const form = useForm({
    defaultValues: {
      email: '',
    },
    onSubmit: async ({ value }) => {
      const validation = emailSchema.safeParse(value.email)
      if (!validation.success) {
        return
      }
      mutation.mutate(value.email)
    },
  })

  return (
    <div className="w-full max-w-md mx-auto">
      <AnimatePresence mode="wait">
        {mutation.isSuccess ? (
          <motion.div
            key="success"
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.95 }}
            className="text-center p-6 card"
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
              You're on the list! 🎉
            </h3>
            <p className="text-light-text-secondary dark:text-dark-text-secondary">
              We'll send you an email when Palytt launches. Get ready to discover amazing food experiences!
            </p>
          </motion.div>
        ) : (
          <motion.form
            key="form"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            onSubmit={(e) => {
              e.preventDefault()
              e.stopPropagation()
              form.handleSubmit()
            }}
            className="space-y-4"
          >
            <form.Field
              name="email"
              validators={{
                onChange: ({ value }) => {
                  if (!value) return 'Email is required'
                  const result = emailSchema.safeParse(value)
                  if (!result.success) return result.error.errors[0].message
                  return undefined
                },
              }}
            >
              {(field) => (
                <div className="space-y-2">
                  <div className="relative">
                    <input
                      type="email"
                      placeholder="Enter your email address"
                      value={field.state.value}
                      onChange={(e) => field.handleChange(e.target.value)}
                      onBlur={field.handleBlur}
                      className={`input-field pr-12 ${
                        field.state.meta.isTouched && field.state.meta.errors.length
                          ? 'border-error focus:ring-error/50'
                          : ''
                      }`}
                      disabled={mutation.isPending}
                    />
                    <div className="absolute right-3 top-1/2 -translate-y-1/2">
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
                          d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                        />
                      </svg>
                    </div>
                  </div>
                  <AnimatePresence>
                    {field.state.meta.isTouched && field.state.meta.errors.length > 0 && (
                      <motion.p
                        initial={{ opacity: 0, height: 0 }}
                        animate={{ opacity: 1, height: 'auto' }}
                        exit={{ opacity: 0, height: 0 }}
                        className="text-sm text-error pl-1"
                      >
                        {field.state.meta.errors[0]}
                      </motion.p>
                    )}
                  </AnimatePresence>
                </div>
              )}
            </form.Field>

            <motion.button
              type="submit"
              disabled={mutation.isPending}
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              className="btn-primary w-full relative overflow-hidden"
            >
              <AnimatePresence mode="wait">
                {mutation.isPending ? (
                  <motion.span
                    key="loading"
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    className="flex items-center justify-center gap-2"
                  >
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
                    Joining...
                  </motion.span>
                ) : (
                  <motion.span
                    key="text"
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                  >
                    Get Early Access
                  </motion.span>
                )}
              </AnimatePresence>
            </motion.button>

            {mutation.isError && (
              <motion.p
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                className="text-sm text-error text-center"
              >
                Something went wrong. Please try again.
              </motion.p>
            )}

            <p className="text-xs text-center text-light-text-tertiary dark:text-dark-text-tertiary">
              By signing up, you agree to our{' '}
              <a href="/privacy" className="text-primary hover:underline">
                Privacy Policy
              </a>
              . No spam, ever.
            </p>
          </motion.form>
        )}
      </AnimatePresence>
    </div>
  )
}
