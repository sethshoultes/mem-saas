import React, { useState } from 'react';
import { Button } from '../ui/button';
import { AlertCircle, CreditCard, Loader2, Trash2 } from 'lucide-react';
import { bulkUpdateSubscriptionStatus, bulkCancelSubscriptions, bulkConvertTrials } from '../../lib/subscriptions';
import { BulkOperationStatus } from './BulkOperationStatus';

interface BulkActionsProps {
  selectedSubscriptions: string[];
  onClearSelection: () => void;
  onRefresh: () => void;
}

export function BulkActions({
  selectedSubscriptions,
  onClearSelection,
  onRefresh
}: BulkActionsProps) {
  const [isProcessing, setIsProcessing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [currentOperation, setCurrentOperation] = useState<string | null>(null);

  const handleBulkAction = async (
    action: 'activate' | 'cancel' | 'convert',
    immediate: boolean = false
  ) => {
    setIsProcessing(true);
    setError(null);

    try {
      let result;
      switch (action) {
        case 'activate':
          result = await bulkUpdateSubscriptionStatus(selectedSubscriptions, 'active');
          break;
        case 'cancel':
          result = await bulkCancelSubscriptions(selectedSubscriptions, immediate);
          break;
        case 'convert':
          result = await bulkConvertTrials(selectedSubscriptions);
          break;
      }
      setCurrentOperation(result.operation_id);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Operation failed');
      setIsProcessing(false);
    }
  };

  const handleOperationComplete = () => {
    setCurrentOperation(null);
    setIsProcessing(false);
    onRefresh();
    onClearSelection();
  };

  if (currentOperation) {
    return (
      <div className="bg-white shadow rounded-lg p-4 mb-6">
        <BulkOperationStatus
          operationId={currentOperation}
          onComplete={handleOperationComplete}
        />
      </div>
    );
  }

  return (
    <div className="bg-white shadow rounded-lg p-4 mb-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium text-gray-700">
            {selectedSubscriptions.length} subscriptions selected
          </span>
          <Button
            variant="secondary"
            size="sm"
            onClick={onClearSelection}
            disabled={isProcessing}
          >
            Clear Selection
          </Button>
        </div>

        <div className="flex items-center gap-2">
          <Button
            variant="secondary"
            size="sm"
            onClick={() => handleBulkAction('activate')}
            disabled={isProcessing}
          >
            {isProcessing ? (
              <Loader2 className="h-4 w-4 mr-2 animate-spin" />
            ) : (
              <CreditCard className="h-4 w-4 mr-2" />
            )}
            Activate Selected
          </Button>

          <Button
            variant="secondary"
            size="sm"
            onClick={() => handleBulkAction('convert')}
            disabled={isProcessing}
          >
            {isProcessing ? (
              <Loader2 className="h-4 w-4 mr-2 animate-spin" />
            ) : (
              <CreditCard className="h-4 w-4 mr-2" />
            )}
            Convert to Paid
          </Button>

          <Button
            variant="danger"
            size="sm"
            onClick={() => handleBulkAction('cancel', true)}
            disabled={isProcessing}
          >
            {isProcessing ? (
              <Loader2 className="h-4 w-4 mr-2 animate-spin" />
            ) : (
              <Trash2 className="h-4 w-4 mr-2" />
            )}
            Cancel Selected
          </Button>
        </div>
      </div>

      {error && (
        <div className="mt-4 p-4 bg-red-50 rounded-lg flex items-start gap-3">
          <AlertCircle className="h-5 w-5 text-red-500 mt-0.5" />
          <p className="text-sm text-red-600">{error}</p>
        </div>
      )}
    </div>
  );
}