import React, { useEffect, useState } from 'react';
import { Tenant } from '../../types';
import { getTenants } from '../../lib/tenants';
import { Building2, Search } from 'lucide-react';

interface TenantSelectorProps {
  value: string;
  onChange: (tenantId: string) => void;
  className?: string;
}

export function TenantSelector({ value, onChange, className = '' }: TenantSelectorProps) {
  const [tenants, setTenants] = useState<Tenant[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [isOpen, setIsOpen] = useState(false);

  useEffect(() => {
    fetchTenants();
  }, []);

  async function fetchTenants() {
    try {
      const data = await getTenants();
      setTenants(data);
    } catch (error) {
      console.error('Error fetching tenants:', error);
    } finally {
      setIsLoading(false);
    }
  }

  const filteredTenants = tenants.filter(tenant =>
    tenant.name.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const selectedTenant = tenants.find(t => t.id === value);

  return (
    <div className={`relative ${className}`}>
      <div
        className="flex items-center gap-2 w-full px-3 py-2 border border-gray-300 rounded-md cursor-pointer hover:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500"
        onClick={() => setIsOpen(!isOpen)}
      >
        <Building2 className="h-4 w-4 text-gray-400" />
        <span className="flex-1 text-gray-700">
          {isLoading ? 'Loading tenants...' :
           selectedTenant ? selectedTenant.name :
           'Select a tenant'}
        </span>
      </div>

      {isOpen && (
        <div className="absolute z-10 w-full mt-1 bg-white border border-gray-200 rounded-md shadow-lg">
          <div className="p-2 border-b border-gray-200">
            <div className="relative">
              <Search className="absolute left-2 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                className="w-full pl-8 pr-3 py-1 border border-gray-200 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="Search tenants..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onClick={(e) => e.stopPropagation()}
              />
            </div>
          </div>
          
          <div className="max-h-60 overflow-y-auto">
            <div 
              className="px-3 py-2 hover:bg-gray-100 cursor-pointer text-sm text-gray-500"
              onClick={() => {
                onChange('');
                setIsOpen(false);
              }}
            >
              No tenant
            </div>
            {filteredTenants.map(tenant => (
              <div
                key={tenant.id}
                className={`px-3 py-2 cursor-pointer text-sm hover:bg-gray-100 ${
                  tenant.id === value ? 'bg-blue-50 text-blue-600' : 'text-gray-700'
                }`}
                onClick={() => {
                  onChange(tenant.id);
                  setIsOpen(false);
                }}
              >
                <div className="font-medium">{tenant.name}</div>
                <div className="text-xs text-gray-500">ID: {tenant.id}</div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}