import React, { useState } from 'react';
import { UserActivity } from '../../types';
import { Button } from '../ui/button';
import { Clock, Filter } from 'lucide-react';
import { formatDate } from '../../lib/utils';

interface UserActivityLogProps {
  activities: UserActivity[];
}

export function UserActivityLog({ activities }: UserActivityLogProps) {
  const [filter, setFilter] = useState<string>('all');

  const getActionColor = (action: string) => {
    switch (action) {
      case 'profile_updated':
        return 'bg-blue-100 text-blue-700';
      case 'status_changed':
        return 'bg-yellow-100 text-yellow-700';
      case 'role_changed':
        return 'bg-purple-100 text-purple-700';
      default:
        return 'bg-gray-100 text-gray-700';
    }
  };

  const formatDetails = (details: Record<string, any>) => {
    return Object.entries(details)
      .map(([key, value]) => `${key.replace(/_/g, ' ')}: ${value}`)
      .join(', ');
  };

  const filteredActivities = activities.filter(activity => 
    filter === 'all' || activity.action === filter
  );

  const uniqueActions = Array.from(new Set(activities.map(a => a.action)));

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold text-gray-900">Activity Log</h2>
        <div className="flex items-center gap-2">
          <Filter className="h-4 w-4 text-gray-400" />
          <select
            className="text-sm border-0 bg-transparent focus:ring-0"
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
          >
            <option value="all">All Activities</option>
            {uniqueActions.map(action => (
              <option key={action} value={action}>
                {action.replace(/_/g, ' ')}
              </option>
            ))}
          </select>
        </div>
      </div>

      <div className="bg-white shadow rounded-lg divide-y divide-gray-200">
        {filteredActivities.length === 0 ? (
          <div className="p-4 text-center text-gray-500">
            No activities found
          </div>
        ) : (
          filteredActivities.map((activity) => (
            <div key={activity.id} className="p-4 hover:bg-gray-50">
              <div className="flex items-start justify-between">
                <div className="flex items-start space-x-3">
                  <div className="mt-0.5">
                    <Clock className="h-5 w-5 text-gray-400" />
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getActionColor(activity.action)}`}>
                        {activity.action.replace(/_/g, ' ')}
                      </span>
                      <span className="text-sm text-gray-500">
                        {formatDate(new Date(activity.created_at))}
                      </span>
                    </div>
                    {activity.details && Object.keys(activity.details).length > 0 && (
                      <p className="mt-1 text-sm text-gray-600">
                        {formatDetails(activity.details)}
                      </p>
                    )}
                  </div>
                </div>
              </div>
            </div>
          ))
        )}
      </div>

      {filteredActivities.length > 10 && (
        <div className="flex justify-center">
          <Button variant="secondary" size="sm">
            Load More
          </Button>
        </div>
      )}
    </div>
  );
}