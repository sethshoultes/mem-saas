import { processMockPayment, setupMockWebhookListener, TEST_CARDS } from './mock-payment';

export interface PaymentResult {
  success: boolean;
  transactionId: string;
  error?: {
    code: string;
    message: string;
  };
}

export async function processPayment(
  amount: number,
  cardNumber: string = TEST_CARDS.success,
  metadata: Record<string, any> = {}
): Promise<PaymentResult> {
  try {
    const result = await processMockPayment(amount, cardNumber, metadata);
    
    return {
      success: result.status === 'completed',
      transactionId: result.id,
      error: result.error
    };
  } catch (error) {
    return {
      success: false,
      transactionId: '',
      error: {
        code: 'processing_error',
        message: error instanceof Error ? error.message : 'Payment processing failed'
      }
    };
  }
}

export function setupPaymentWebhooks(
  onPaymentSuccess: (data: any) => void,
  onPaymentFailure: (data: any) => void
) {
  return setupMockWebhookListener((event) => {
    switch (event.type) {
      case 'payment_intent.succeeded':
        onPaymentSuccess(event.data);
        break;
      case 'payment_intent.failed':
        onPaymentFailure(event.data);
        break;
    }
  });
}

export const TEST_CARD_NUMBERS = {
  ...TEST_CARDS,
  descriptions: {
    [TEST_CARDS.success]: 'Always succeeds',
    [TEST_CARDS.decline]: 'Always declined',
    [TEST_CARDS.insufficient_funds]: 'Insufficient funds error',
    [TEST_CARDS.expired]: 'Expired card error',
    [TEST_CARDS.incorrect_cvc]: 'Incorrect CVC error',
    [TEST_CARDS.processing_error]: 'Processing error'
  }
};