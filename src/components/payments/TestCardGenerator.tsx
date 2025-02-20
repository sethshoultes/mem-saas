import React from 'react';
import { Button } from '../ui/button';
import { CreditCard, Copy, Check } from 'lucide-react';
import { TEST_CARD_NUMBERS } from '../../lib/payment';

export function TestCardGenerator() {
  const [copiedCard, setCopiedCard] = React.useState<string | null>(null);

  const handleCopy = (card: string) => {
    navigator.clipboard.writeText(card);
    setCopiedCard(card);
    setTimeout(() => setCopiedCard(null), 2000);
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold text-gray-900">Test Card Numbers</h2>
        <div className="text-sm text-gray-500">Click to copy</div>
      </div>

      <div className="grid gap-4">
        {Object.entries(TEST_CARD_NUMBERS.descriptions).map(([card, description]) => (
          <div
            key={card}
            className="bg-white p-4 rounded-lg border border-gray-200 hover:border-blue-500 transition-colors cursor-pointer"
            onClick={() => handleCopy(card)}
          >
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <CreditCard className="h-5 w-5 text-gray-400" />
                <div>
                  <div className="font-mono text-gray-900">{card}</div>
                  <div className="text-sm text-gray-500">{description}</div>
                </div>
              </div>
              <Button
                variant="secondary"
                size="sm"
                className="p-1"
                onClick={(e) => {
                  e.stopPropagation();
                  handleCopy(card);
                }}
              >
                {copiedCard === card ? (
                  <Check className="h-4 w-4 text-green-500" />
                ) : (
                  <Copy className="h-4 w-4" />
                )}
              </Button>
            </div>
          </div>
        ))}
      </div>

      <div className="mt-6 p-4 bg-gray-50 rounded-lg">
        <h3 className="text-sm font-medium text-gray-900 mb-2">Testing Instructions</h3>
        <ul className="text-sm text-gray-600 space-y-1">
          <li>• Use these cards to simulate different payment scenarios</li>
          <li>• All test cards use any future expiry date</li>
          <li>• Any 3 digits can be used for CVC</li>
          <li>• Any valid postal code can be used</li>
        </ul>
      </div>
    </div>
  );
}