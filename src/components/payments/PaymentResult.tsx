import React from 'react';
import { CheckCircle, XCircle } from 'lucide-react';
import { formatCurrency } from '../../lib/utils';

interface PaymentResultProps {
  success: boolean;
  amount: number;
  transactionId: string;
  error?: {
    code: string;
    message: string;
  };
}

export function PaymentResult({
  success,
  amount,
  transactionId,
  error
}: PaymentResultProps) {
  return (
    <div className="rounded-lg p-6 space-y-4">
      <div className="flex items-center gap-3">
        {success ? (
          <>
            <CheckCircle className="h-8 w-8 text-green-500" />
            <div>
              <h3 className="text-lg font-semibold text-gray-900">
                Payment Successful
              </h3>
              <p className="text-sm text-gray-500">
                Amount: {formatCurrency(amount)}
              </p>
            </div>
          </>
        ) : (
          <>
            <XCircle className="h-8 w-8 text-red-500" />
            <div>
              <h3 className="text-lg font-semibold text-gray-900">
                Payment Failed
              </h3>
              {error && (
                <p className="text-sm text-red-600">
                  {error.message} (Code: {error.code})
                </p>
              )}
            </div>
          </>
        )}
      </div>

      <div className="text-sm text-gray-500">
        Transaction ID: {transactionId}
      </div>
    </div>
  );
}