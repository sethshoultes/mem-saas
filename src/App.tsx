import React from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { Layout } from './components/layout/layout';
import { UserList } from './components/users/UserList';
import { Dashboard } from './components/dashboard/Dashboard';
import { TenantList } from './components/tenants/TenantList';
import { MembershipList } from './components/membership/MembershipList';
import { ResetPassword } from './components/auth/ResetPassword';
import { Login } from './components/auth/Login';
import { ProtectedRoute } from './components/auth/ProtectedRoute';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/reset-password" element={<ResetPassword />} />
        <Route
          path="/*"
          element={
            <ProtectedRoute>
              <div className="min-h-screen bg-gray-50">
                <Layout>
                  <Routes>
                    <Route path="/" element={<Dashboard />} />
                    <Route path="/users" element={<UserList />} />
                    <Route path="/tenants" element={<TenantList />} />
                    <Route path="/membership" element={<MembershipList />} />
                    <Route path="/payments" element={<div>Payments Coming Soon</div>} />
                    <Route path="/settings" element={<div>Settings Coming Soon</div>} />
                    <Route path="/help" element={<div>Help Coming Soon</div>} />
                  </Routes>
                </Layout>
              </div>
            </ProtectedRoute>
          }
        />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
