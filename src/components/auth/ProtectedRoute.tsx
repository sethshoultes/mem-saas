import { ReactNode, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAdminStore } from '../../store';

interface ProtectedRouteProps {
  children: ReactNode;
}

export function ProtectedRoute({ children }: ProtectedRouteProps) {
  const { currentUser, isLoading, initializeUser } = useAdminStore();
  const navigate = useNavigate();

  useEffect(() => {
    if (!currentUser && !isLoading) {
      initializeUser().then(user => {
        if (!user) {
          navigate('/login');
        }
      });
    }
  }, [currentUser, isLoading, initializeUser, navigate]);

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-gray-500">Loading...</div>
      </div>
    );
  }

  if (!currentUser) {
    return null;
  }

  return <>{children}</>;
}