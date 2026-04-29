import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import type React from 'react';
import type { AdminUser } from '../types/api';
import { authApi, healthApi } from '../services/api';

interface AuthState {
  user: AdminUser | null;
  token: string | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [token, setToken] = useState(() => localStorage.getItem('admin_token'));
  const [user, setUser] = useState<AdminUser | null>(() => {
    const raw = localStorage.getItem('admin_user');
    return raw ? JSON.parse(raw) : null;
  });

  const value = useMemo<AuthState>(
    () => ({
      user,
      token,
      login: async (email, password) => {
        const result = await authApi.login(email, password);
        localStorage.setItem('admin_token', result.access_token);
        localStorage.setItem('admin_user', JSON.stringify(result.user));
        setToken(result.access_token);
        setUser(result.user);
      },
      logout: () => {
        localStorage.removeItem('admin_token');
        localStorage.removeItem('admin_user');
        setToken(null);
        setUser(null);
      },
    }),
    [token, user],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth AuthProvider ichida ishlatilishi kerak');
  return ctx;
}

export function useBackendKeepAlive(enabled: boolean) {
  useEffect(() => {
    if (!enabled) return;
    const ping = () => {
      healthApi.ping().catch(() => {
        // Keep-alive silent ishlaydi; foydalanuvchiga xato ko'rsatilmaydi.
      });
    };
    ping();
    const timer = window.setInterval(ping, 60_000);
    return () => window.clearInterval(timer);
  }, [enabled]);
}
