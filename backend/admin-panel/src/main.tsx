import React from 'react';
import ReactDOM from 'react-dom/client';
import { Navigate, Route, BrowserRouter as Router, Routes } from 'react-router-dom';
import { AuthProvider, useAuth, useBackendKeepAlive } from './hooks/useAuth';
import { AppLayout } from './layouts/AppLayout';
import { Dashboard } from './pages/Dashboard';
import { Gemini } from './pages/Gemini';
import { Login } from './pages/Login';
import { Medicines } from './pages/Medicines';
import { Messages } from './pages/Messages';
import { Settings } from './pages/Settings';
import { Users } from './pages/Users';
import './styles.css';

function Protected({ children }: { children: React.ReactNode }) {
  const { token } = useAuth();
  useBackendKeepAlive(Boolean(token));
  return token ? <>{children}</> : <Navigate to="/login" replace />;
}

function App() {
  return (
    <AuthProvider>
      <Router>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route
            path="/"
            element={
              <Protected>
                <AppLayout />
              </Protected>
            }
          >
            <Route index element={<Navigate to="/dashboard" replace />} />
            <Route path="dashboard" element={<Dashboard />} />
            <Route path="users" element={<Users />} />
            <Route path="medicines" element={<Medicines />} />
            <Route path="messages" element={<Messages />} />
            <Route path="gemini" element={<Gemini />} />
            <Route path="settings" element={<Settings />} />
          </Route>
        </Routes>
      </Router>
    </AuthProvider>
  );
}

ReactDOM.createRoot(document.getElementById('root')!).render(<App />);
