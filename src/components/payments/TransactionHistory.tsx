import React, { useState, useEffect } from 'react';
import { getTransactionHistory } from '../../lib/mock-payment';
import { formatCurrency, formatDate } from '../../lib/utils';
import { Button } from '../ui/button';
import { Filter, Download, RefreshCw, AlertCircle } from 'lucide-react';
import { useAdminStore } from '../../store';

interface Transaction {
  id: string;
  amount: number;
  currency: string;
  status: string;
  payment_method_id: string;
  error_code: string | null;
  error_message: string | null;
  created_at: string;
}

export function TransactionHistory() {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [statusFilter, setStatusFilter] = useState<string[]>([]);
  const [dateRange, setDateRange] = useState<{
    startDate: Date | null;
    endDate: Date | null;
  }>({
    startDate: null,
    endDate: null
  });
  const { currentUser } = useAdminStore();

  useEffect(() => {
    if (currentUser?.profile?.tenant_id) {
      fetchTransactions();
    }
  }, [currentUser, statusFilter, dateRange]);

  const fetchTransactions = async () => {
    if (!currentUser?.profile?.tenant_id) return;

    setIsLoading(true);
    setError(null);

    try {
      const data = await getTransactionHistory(
        currentUser.profile.tenant_id,
        {
          status: statusFilter.length ? statusFilter : undefined,
          startDate: dateRange.startDate || undefined,
          endDate: dateRange.endDate || undefined
        }
      );
      setTransactions(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch transactions');
    } finally {
      setIsLoading(false);
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'completed':
        return 'bg-green-100 text-green-700';
      case 'failed':
        return 'bg-red-100 text-red-700';
      case 'refunded':
        return 'bg-yellow-100 text-yellow-700';
      default:
        return 'bg-gray-100 text-gray-700';
    }
  };

  const exportTransactions = () => {
    const csvContent = [
      ['ID', 'Amount', 'Currency', 'Status', 'Payment Method', 'Error', 'Created At'].join(','),
      ...transactions.map(tx => [
        tx.id,
        tx.amount,
        tx.currency,
        tx.status,
        tx.payment_method_id,
        tx.error_message || '',
        tx.created_at
      ].join(','))
    ].join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `transactions-${new Date().toISOString().split('T')[0]}.csv`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    window.URL.revokeObjectURL(url);
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold text-gray-900">
          Transaction History
        </h2>
        <div className="flex items-center gap-2">
          <Button
            variant="secondary"
            size="sm"
            onClick={fetchTransactions}
          >
            <RefreshCw className="h-4 w-4 mr-2" />
            Refresh
          </Button>
          <Button
            variant="secondary"
            size="sm"
            onClick={exportTransactions}
            disabled={transactions.length === 0}
          >
            <Download className="h-4 w-4 mr-2" />
            Export CSV
          </Button>
        </div>
      </div>

      <div className="flex gap-4">
        <div className="flex items-center gap-2">
          <Filter className="h-4 w-4 text-gray-400" />
          <select
            className="border border-gray-200 rounded-lg px-3 py-2"
            value={statusFilter.join(',')}
            onChange={(e) => setStatusFilter(
              e.target.value ? e.target.value.split(',') : []
            )}
          >
            <option value="">All Status</option>
            <option value="completed">Completed</option>
            <option value="failed">Failed</option>
            <option value="refunded">Refunded</option>
          </select>
        </div>

        <div className="flex items-center gap-2">
          <input
            type="date"
            className="border border-gray-200 rounded-lg px-3 py-2"
            value={dateRange.startDate?.toISOString().split('T')[0] || ''}
            onChange={(e) => setDateRange(prev => ({
              ...prev,
              startDate: e.target.value ? new Date(e.target.value) : null
            }))}
          />
          <span className="text-gray-500">to</span>
          <input
            type="date"
            className="border border-gray-200 rounded-lg px-3 py-2"
            value={dateRange.endDate?.toISOString().split('T')[0] || ''}
            onChange={(e) => setDateRange(prev => ({
              ...prev,
              endDate: e.target.value ? new Date(e.target.value) : null
            }))}
          />
        </div>
      </div>

      {error && (
        <div className="p-4 bg-red-50 rounded-lg flex items-start gap-3">
          <AlertCircle className="h-5 w-5 text-red-500 mt-0.5" />
          <p className="text-sm text-red-600">{error}</p>
        </div>
      )}

      <div className="bg-white shadow rounded-lg overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Transaction ID
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Amount
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Payment Method
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Date
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Error
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {isLoading ? (
                <tr>
                  <td colSpan={6} className="px-6 py-4 text-center text-gray-500">
                    Loading transactions...
                  </td>
                </tr>
              ) : transactions.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-6 py-4 text-center text-gray-500">
                    No transactions found
                  </td>
                </tr>
              ) : (
                transactions.map((tx) => (
                  <tr key={tx.id}>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {tx.id}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {formatCurrency(tx.amount)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getStatusColor(tx.status)}`}>
                        {tx.status}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {tx.payment_method_id}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {formatDate(new Date(tx.created_at))}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-red-600">
                      {tx.error_message}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}