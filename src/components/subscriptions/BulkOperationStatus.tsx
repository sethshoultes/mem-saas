import React, { useEffect, useState } from 'react';
import { getBulkOperationStatus } from '../../lib/subscriptions';
import { Loader2, CheckCircle2, XCircle } from 'lucide-react';

interface BulkOperationStatusProps {
  operationId: string;
  onComplete?: () => void;
}

interface OperationStatus {
  operation_type: string;
  total_items: number;
  processed_items: number;
  failed_items: number;
  details: any[];
  created_at: string;
}

export function BulkOperationStatus({ operationId, onComplete }: BulkOperationStatusProps) {
  const [status, setStatus] = useState<OperationStatus | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const checkStatus = async () => {
      try {
        const data = await getBulkOperationStatus(operationId);
        setStatus(data);
        
        if (data && data.processed_items + data.failed_items >= data.total_items) {
          onComplete?.();
        } else {
          // Continue polling if operation is not complete
          setTimeout(checkStatus, 2000);
        }
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to check operation status');
      } finally {
        setIsLoading(false);
      }
    };

    checkStatus();
  }, [operationId, onComplete]);

  if (isLoading) {
    return (
      <div className="flex items-center gap-2 text-gray-600">
        <Loader2 className="h-4 w-4 animate-spin" />
        <span>Checking operation status...</span>
      </div>
    );
  }

  if (error) {
    return (
      <div className="text-red-600 flex items-center gap-2">
        <XCircle className="h-4 w-4" />
        <span>{error}</span>
      </div>
    );
  }

  if (!status) {
    return null;
  }

  const isComplete = status.processed_items + status.failed_items >= status.total_items;
  const operationName = status.operation_type.replace('bulk_', '').replace('_', ' ');

  return (
    <div className="space-y-2">
      <div className="flex items-center gap-4">
        <div className="flex items-center gap-2">
          {isComplete ? (
            <CheckCircle2 className="h-4 w-4 text-green-500" />
          ) : (
            <Loader2 className="h-4 w-4 animate-spin text-blue-500" />
          )}
          <span className="font-medium">
            {isComplete ? 'Operation Complete' : 'Processing...'}
          </span>
        </div>
        <span className="text-sm text-gray-500">
          {operationName}
        </span>
      </div>

      <div className="grid grid-cols-3 gap-4">
        <div className="bg-gray-50 p-3 rounded-lg">
          <div className="text-sm text-gray-500">Total</div>
          <div className="text-lg font-semibold">{status.total_items}</div>
        </div>
        <div className="bg-green-50 p-3 rounded-lg">
          <div className="text-sm text-green-600">Processed</div>
          <div className="text-lg font-semibold text-green-700">
            {status.processed_items}
          </div>
        </div>
        <div className="bg-red-50 p-3 rounded-lg">
          <div className="text-sm text-red-600">Failed</div>
          <div className="text-lg font-semibold text-red-700">
            {status.failed_items}
          </div>
        </div>
      </div>

      {status.failed_items > 0 && (
        <div className="mt-4">
          <div className="text-sm font-medium text-gray-900 mb-2">Failed Operations</div>
          <div className="space-y-1">
            {status.details
              .filter(detail => detail.error)
              .map((detail, index) => (
                <div key={index} className="text-sm text-red-600">
                  {detail.error}
                </div>
              ))}
          </div>
        </div>
      )}
    </div>
  );
}