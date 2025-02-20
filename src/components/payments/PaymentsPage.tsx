import React, { useState } from 'react';
import { PaymentTester } from './PaymentTester';
import { TransactionHistory } from './TransactionHistory';
import { WebhookLogViewer } from './WebhookLogViewer';
import { Button } from '../ui/button';
import { CreditCard, History, Webhook } from 'lucide-react';

type ActiveTab = 'tester' | 'history' | 'webhooks';

export function PaymentsPage() {
  const [activeTab, setActiveTab] = useState<ActiveTab>('tester');

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Payments</h1>
        <div className="flex items-center gap-2">
          <Button
            variant={activeTab === 'tester' ? 'primary' : 'secondary'}
            onClick={() => setActiveTab('tester')}
          >
            <CreditCard className="h-4 w-4 mr-2" />
            Payment Tester
          </Button>
          <Button
            variant={activeTab === 'history' ? 'primary' : 'secondary'}
            onClick={() => setActiveTab('history')}
          >
            <History className="h-4 w-4 mr-2" />
            Transaction History
          </Button>
          <Button
            variant={activeTab === 'webhooks' ? 'primary' : 'secondary'}
            onClick={() => setActiveTab('webhooks')}
          >
            <Webhook className="h-4 w-4 mr-2" />
            Webhooks
          </Button>
        </div>
      </div>

      {activeTab === 'tester' && <PaymentTester />}
      {activeTab === 'history' && <TransactionHistory />}
      {activeTab === 'webhooks' && <WebhookLogViewer />}
    </div>
  );
}