import { useEffect } from 'react'

interface SEOHeadProps {
  title?: string
  description?: string
  keywords?: string[]
  canonicalUrl?: string
  ogImage?: string
  ogType?: 'website' | 'article' | 'product'
  twitterCard?: 'summary' | 'summary_large_image'
  noIndex?: boolean
  structuredData?: object
}

// Default SEO values based on keyword research for food discovery apps
const DEFAULT_KEYWORDS = [
  // Primary keywords (high intent)
  'food discovery app',
  'restaurant finder',
  'best restaurants near me',
  'food recommendation app',
  'restaurant recommendation app',
  
  // Social/Community keywords
  'foodie social network',
  'food sharing app',
  'social food app',
  'food community',
  'restaurant reviews',
  'food reviews app',
  
  // Feature-specific keywords
  'AI food recommendations',
  'personalized restaurant suggestions',
  'discover new restaurants',
  'local food spots',
  'hidden gem restaurants',
  'trending restaurants',
  
  // Long-tail keywords (lower competition, higher conversion)
  'where to eat near me',
  'best food spots in my area',
  'share food experiences',
  'food diary app',
  'restaurant bucket list app',
  'foodie friends',
  'group dining planning',
  
  // Lifestyle keywords
  'culinary experiences',
  'food adventures',
  'dining experiences',
  'food lover app',
  'gourmet food discovery',
]

const DEFAULT_TITLE = 'Palytt - Discover & Share Amazing Food Experiences | AI-Powered Restaurant Finder'
const DEFAULT_DESCRIPTION = 
  'Join thousands of food lovers on Palytt! Discover the best restaurants near you, share culinary experiences with friends, and get AI-powered personalized food recommendations. Your social food discovery journey starts here.'

export function SEOHead({
  title = DEFAULT_TITLE,
  description = DEFAULT_DESCRIPTION,
  keywords = DEFAULT_KEYWORDS,
  canonicalUrl = 'https://palytt.com',
  ogImage = 'https://palytt.com/og-image.png',
  ogType = 'website',
  twitterCard = 'summary_large_image',
  noIndex = false,
  structuredData,
}: SEOHeadProps) {
  useEffect(() => {
    // Update document title
    document.title = title

    // Helper to update or create meta tags
    const updateMeta = (name: string, content: string, isProperty = false) => {
      const attr = isProperty ? 'property' : 'name'
      let meta = document.querySelector(`meta[${attr}="${name}"]`) as HTMLMetaElement
      if (!meta) {
        meta = document.createElement('meta')
        meta.setAttribute(attr, name)
        document.head.appendChild(meta)
      }
      meta.content = content
    }

    // Helper to update or create link tags
    const updateLink = (rel: string, href: string) => {
      let link = document.querySelector(`link[rel="${rel}"]`) as HTMLLinkElement
      if (!link) {
        link = document.createElement('link')
        link.rel = rel
        document.head.appendChild(link)
      }
      link.href = href
    }

    // Basic meta tags
    updateMeta('description', description)
    updateMeta('keywords', keywords.join(', '))
    updateMeta('author', 'Palytt Inc.')
    
    // Robots
    if (noIndex) {
      updateMeta('robots', 'noindex, nofollow')
    } else {
      updateMeta('robots', 'index, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1')
    }

    // Open Graph tags
    updateMeta('og:title', title, true)
    updateMeta('og:description', description, true)
    updateMeta('og:type', ogType, true)
    updateMeta('og:url', canonicalUrl, true)
    updateMeta('og:image', ogImage, true)
    updateMeta('og:image:width', '1200', true)
    updateMeta('og:image:height', '630', true)
    updateMeta('og:image:alt', 'Palytt - Food Discovery App', true)
    updateMeta('og:site_name', 'Palytt', true)
    updateMeta('og:locale', 'en_US', true)

    // Twitter Card tags
    updateMeta('twitter:card', twitterCard)
    updateMeta('twitter:title', title)
    updateMeta('twitter:description', description)
    updateMeta('twitter:image', ogImage)
    updateMeta('twitter:site', '@palytt_app')
    updateMeta('twitter:creator', '@palytt_app')

    // Additional SEO meta tags
    updateMeta('application-name', 'Palytt')
    updateMeta('apple-mobile-web-app-title', 'Palytt')
    updateMeta('apple-mobile-web-app-capable', 'yes')
    updateMeta('apple-mobile-web-app-status-bar-style', 'default')
    updateMeta('format-detection', 'telephone=no')
    updateMeta('mobile-web-app-capable', 'yes')

    // Canonical URL
    updateLink('canonical', canonicalUrl)

    // Structured data (JSON-LD)
    const defaultStructuredData = {
      '@context': 'https://schema.org',
      '@graph': [
        // Organization
        {
          '@type': 'Organization',
          '@id': 'https://palytt.com/#organization',
          name: 'Palytt',
          url: 'https://palytt.com',
          logo: {
            '@type': 'ImageObject',
            url: 'https://palytt.com/logo.png',
            width: 512,
            height: 512,
          },
          sameAs: [
            'https://twitter.com/palytt_app',
            'https://instagram.com/palytt_app',
            'https://www.linkedin.com/company/palytt',
          ],
          contactPoint: {
            '@type': 'ContactPoint',
            email: 'kavyrattana@gmail.com',
            contactType: 'customer support',
          },
        },
        // WebSite
        {
          '@type': 'WebSite',
          '@id': 'https://palytt.com/#website',
          url: 'https://palytt.com',
          name: 'Palytt',
          description: DEFAULT_DESCRIPTION,
          publisher: {
            '@id': 'https://palytt.com/#organization',
          },
          potentialAction: {
            '@type': 'SearchAction',
            target: {
              '@type': 'EntryPoint',
              urlTemplate: 'https://palytt.com/search?q={search_term_string}',
            },
            'query-input': 'required name=search_term_string',
          },
        },
        // MobileApplication
        {
          '@type': 'MobileApplication',
          '@id': 'https://palytt.com/#app',
          name: 'Palytt',
          operatingSystem: 'iOS',
          applicationCategory: 'FoodEstablishmentReservation',
          description: 'Discover and share amazing food experiences with AI-powered recommendations',
          offers: {
            '@type': 'Offer',
            price: '0',
            priceCurrency: 'USD',
          },
          aggregateRating: {
            '@type': 'AggregateRating',
            ratingValue: '4.8',
            ratingCount: '500',
            bestRating: '5',
            worstRating: '1',
          },
          featureList: [
            'AI-powered food recommendations',
            'Restaurant discovery',
            'Social food sharing',
            'Group messaging',
            'Personalized feed',
            'Save and organize favorites',
          ],
        },
        // WebPage
        {
          '@type': 'WebPage',
          '@id': `${canonicalUrl}#webpage`,
          url: canonicalUrl,
          name: title,
          description: description,
          isPartOf: {
            '@id': 'https://palytt.com/#website',
          },
          about: {
            '@id': 'https://palytt.com/#app',
          },
          primaryImageOfPage: {
            '@type': 'ImageObject',
            url: ogImage,
          },
        },
      ],
    }

    // Update or create JSON-LD script
    let jsonLdScript = document.querySelector('script[type="application/ld+json"]') as HTMLScriptElement
    if (!jsonLdScript) {
      jsonLdScript = document.createElement('script')
      jsonLdScript.type = 'application/ld+json'
      document.head.appendChild(jsonLdScript)
    }
    jsonLdScript.textContent = JSON.stringify(structuredData || defaultStructuredData)

    // Cleanup function
    return () => {
      // Optionally clean up meta tags on unmount
    }
  }, [title, description, keywords, canonicalUrl, ogImage, ogType, twitterCard, noIndex, structuredData])

  return null // This component only manages head tags
}

// Pre-configured SEO for specific pages
export const PAGE_SEO = {
  home: {
    title: 'Palytt - Discover & Share Amazing Food Experiences | AI-Powered Restaurant Finder',
    description:
      'Join thousands of food lovers on Palytt! Discover the best restaurants near you, share culinary experiences with friends, and get AI-powered personalized food recommendations. Download now!',
    canonicalUrl: 'https://palytt.com',
  },
  privacy: {
    title: 'Privacy Policy | Palytt - Your Data, Your Control',
    description:
      'Learn how Palytt protects your privacy. We are committed to safeguarding your personal information while you discover and share amazing food experiences.',
    canonicalUrl: 'https://palytt.com/privacy',
    keywords: [
      'Palytt privacy policy',
      'food app privacy',
      'data protection',
      'user privacy',
      'GDPR compliance',
      'data security',
    ],
  },
  support: {
    title: 'Help & Support | Palytt - We\'re Here to Help',
    description:
      'Get help with Palytt. Find answers to frequently asked questions, contact our support team, or learn how to make the most of your food discovery experience.',
    canonicalUrl: 'https://palytt.com/support',
    keywords: [
      'Palytt support',
      'Palytt help',
      'food app support',
      'customer service',
      'FAQ',
      'contact us',
    ],
  },
}

export default SEOHead

