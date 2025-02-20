import React, { useState } from 'react';
import { PaymentMethodForm } from './PaymentMethodForm';
import { PaymentResult } from './PaymentResult';
import { processPayment } from '../../lib/payment';
import { TestCardGenerator } from './TestCardGenerator';

export function PaymentTester() {
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<{
    success: boolean;
    amount: number;
    transactionId: string;
    error?: {
      code: string;
      message: string;
    };
  } | null>(null);

  const handleSubmit = async (cardNumber: string) => {
    setIsLoading(true);
    setError(null);
    setResult(null);

    try {
      const amount = 1000; // $10.00 for testing
      const result = await processPayment(amount, cardNumber);
      
      setResult({
        ...result,
        amount
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Payment processing failed');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-lg font-semibold text-gray-900">
          Payment Testing Tools
        </h2>
        <p className="text-sm text-gray-500">
          Use test card numbers to simulate different payment scenarios.
        </p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="space-y-6">
          <PaymentMethodForm
            onSubmit={handleSubmit}
            isLoading={isLoading}
            error={error}
          />

          {result && (
            <PaymentResult
              success={result.success}
              amount={result.amount}
              transactionId={result.transactionId}
              error={result.error}
            />
          )}
        </div>

        <div className="space-y-6">
          <TestCardGenerator />
        </div>
      </div>
    </div>
  );
}