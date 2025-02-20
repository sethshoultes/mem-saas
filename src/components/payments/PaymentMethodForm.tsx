import React, { useState } from 'react';
import { Button } from '../ui/button';
import { CreditCard, AlertCircle } from 'lucide-react';
import { TEST_CARD_NUMBERS } from '../../lib/payment';

interface PaymentMethodFormProps {
  onSubmit: (cardNumber: string) => void;
  isLoading?: boolean;
  error?: string | null;
}

export function PaymentMethodForm({
  onSubmit,
  isLoading = false,
  error = null
}: PaymentMethodFormProps) {
  const [cardNumber, setCardNumber] = useState(TEST_CARD_NUMBERS.success);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(cardNumber);
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div>
        <label className="block text-sm font-medium text-gray-700">
          Test Card Number
        </label>
        <select
          className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2"
          value={cardNumber}
          onChange={(e) => setCardNumber(e.target.value)}
        >
          {Object.entries(TEST_CARD_NUMBERS.descriptions).map(([number, description]) => (
            <option key={number} value={number}>
              {number} - {description}
            </option>
          ))}
        </select>
      </div>

      {error && (
        <div className="p-4 bg-red-50 rounded-lg flex items-start gap-3">
          <AlertCircle className="h-5 w-5 text-red-500 mt-0.5" />
          <p className="text-sm text-red-600">{error}</p>
        </div>
      )}

      <Button
        type="submit"
        disabled={isLoading}
        className="w-full"
      >
        <CreditCard className="h-4 w-4 mr-2" />
        {isLoading ? 'Processing...' : 'Process Payment'}
      </Button>
    </form>
  );
}