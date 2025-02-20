export const WEBHOOK_EVENTS = {
  'payment_intent.succeeded': {
    description: 'Simulate a successful payment',
    data: {
      amount: 1000,
      currency: 'usd',
      status: 'succeeded'
    }
  },
  'payment_intent.failed': {
    description: 'Simulate a failed payment',
    data: {
      amount: 1000,
      currency: 'usd',
      status: 'failed',
      error: {
        code: 'card_declined',
        message: 'Your card was declined'
      }
    }
  },
  'charge.refunded': {
    description: 'Simulate a refund',
    data: {
      amount: 1000,
      currency: 'usd',
      status: 'refunded'
    }
  }
} as const;