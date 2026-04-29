import axios from 'axios';
import type { AdminUser, AiStatus, DashboardData, Medicine, MessageLog, Paginated, User } from '../types/api';

const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || '',
  headers: { 'Content-Type': 'application/json' },
});

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('admin_token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('admin_token');
      localStorage.removeItem('admin_user');
      if (!window.location.pathname.includes('/login')) window.location.href = '/login';
    }
    return Promise.reject(error);
  },
);

const unwrap = <T>(promise: Promise<{ data: { data: T } }>) => promise.then((response) => response.data.data);

export const authApi = {
  login: (email: string, password: string) =>
    unwrap<{ access_token: string; user: AdminUser }>(api.post('/api/admin/login', { email, password })),
};

export const dashboardApi = {
  get: () => unwrap<DashboardData>(api.get('/api/admin/dashboard')),
};

export const usersApi = {
  list: (params: Record<string, string | number | undefined>) => unwrap<Paginated<User>>(api.get('/api/admin/users', { params })),
  detail: (id: number) => unwrap<User>(api.get(`/api/admin/users/${id}`)),
  status: (id: number, status: 'active' | 'blocked') => unwrap<User>(api.patch(`/api/admin/users/${id}/status`, { status })),
  remove: (id: number) => unwrap<{ id: number }>(api.delete(`/api/admin/users/${id}`)),
};

export const medicinesApi = {
  list: (params: Record<string, string | number | undefined>) => unwrap<Paginated<Medicine>>(api.get('/api/admin/medicines', { params })),
  detail: (id: number) => unwrap<Medicine>(api.get(`/api/admin/medicines/${id}`)),
  create: (payload: Partial<Medicine> & { user_id: number }) => unwrap<Medicine>(api.post('/api/admin/medicines', payload)),
  update: (id: number, payload: Partial<Medicine>) => unwrap<Medicine>(api.patch(`/api/admin/medicines/${id}`, payload)),
  remove: (id: number) => unwrap<{ id: number }>(api.delete(`/api/admin/medicines/${id}`)),
};

export const messagesApi = {
  history: (params: Record<string, string | number | undefined>) =>
    unwrap<Paginated<MessageLog>>(api.get('/api/admin/messages/history', { params })),
  send: (payload: Record<string, unknown>) => unwrap<{ sent: number; failed: number }>(api.post('/api/admin/messages/send', payload)),
};

export const aiApi = {
  status: () => unwrap<AiStatus>(api.get('/api/admin/ai/status')),
  generate: (user_id: number) => unwrap<{ message: string }>(api.post('/api/admin/ai/generate-medicine-message', { user_id })),
  sendEmail: (payload: { user_id: number; subject: string; message: string }) =>
    unwrap<{ sent: boolean }>(api.post('/api/admin/ai/send-generated-email', payload)),
  sendSms: (payload: { user_id: number; message: string }) => unwrap<{ queued: boolean }>(api.post('/api/admin/ai/send-generated-sms', payload)),
};

export const settingsApi = {
  get: () => unwrap<Record<string, unknown>>(api.get('/api/admin/settings')),
};

export const healthApi = {
  ping: () => api.get('/health', { timeout: 8000 }),
};
