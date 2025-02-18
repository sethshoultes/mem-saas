import { Bell, Menu, Settings, User } from 'lucide-react';
import { Button } from '../ui/button';
import { useAdminStore } from '../../store';

export function Header() {
  const { currentUser } = useAdminStore();

  return (
    <header className="bg-white border-b border-gray-200 fixed w-full z-10">
      <div className="px-4 sm:px-6 lg:px-8">
        <div className="flex h-16 items-center justify-between">
          <div className="flex items-center">
            <Button
              variant="secondary"
              size="sm"
              className="lg:hidden"
              aria-label="Open menu"
            >
              <Menu className="h-5 w-5" />
            </Button>
            <div className="ml-4 text-xl font-semibold text-gray-900">
              Admin Dashboard
            </div>
          </div>
          <div className="flex items-center gap-4">
            <Button
              variant="secondary"
              size="sm"
              className="relative"
              aria-label="View notifications"
            >
              <Bell className="h-5 w-5" />
              <span className="absolute -top-1 -right-1 h-4 w-4 rounded-full bg-red-600 text-[10px] font-medium text-white flex items-center justify-center">
                3
              </span>
            </Button>
            <Button
              variant="secondary"
              size="sm"
              aria-label="Open settings"
            >
              <Settings className="h-5 w-5" />
            </Button>
            <div className="flex items-center gap-2">
              <div className="h-8 w-8 rounded-full bg-gray-200 flex items-center justify-center">
                <User className="h-5 w-5 text-gray-500" />
              </div>
              <div className="hidden sm:block">
                <div className="text-sm font-medium text-gray-900">
                  {currentUser?.full_name}
                </div>
                <div className="text-xs text-gray-500">{currentUser?.role}</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </header>
  );
}