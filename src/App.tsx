import React from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { Layout } from './components/layout/layout';

function App() {
  return (
    <BrowserRouter>
      <div className="min-h-screen bg-gray-50">
        <Layout>
          <Routes>
            <Route path="/" element={<div>Dashboard Coming Soon</div>} />
            <Route path="/users" element={<div>Users Coming Soon</div>} />
            <Route path="/tenants" element={<div>Tenants Coming Soon</div>} />
            <Route path="/payments" element={<div>Payments Coming Soon</div>} />
            <Route path="/settings" element={<div>Settings Coming Soon</div>} />
            <Route path="/help" element={<div>Help Coming Soon</div>} />
          </Routes>
        </Layout>
      </div>
    </BrowserRouter>
  );
}

export default App;
