export type Status = 'active' | 'blocked' | 'finished' | 'pending' | 'sent' | 'failed';

export interface ApiEnvelope<T> {
  success: boolean;
  message: string;
  data: T;
  errors?: unknown;
}

export interface AdminUser {
  id: number;
  full_name: string;
  email: string;
  role: string;
  avatar_url?: string | null;
}

export interface User {
  id: number;
  full_name: string;
  email: string;
  phone?: string;
  role?: string;
  avatar_url?: string | null;
  email_verified: boolean;
  status: 'active' | 'blocked';
  created_at: string;
  medicines?: Medicine[];
}

export interface Medicine {
  id: number;
  name: string;
  dose: string;
  dosage?: string;
  schedule: string;
  start_date?: string;
  end_date?: string | null;
  status: 'active' | 'finished';
  notes?: string | null;
  user?: Pick<User, 'id' | 'full_name' | 'email' | 'avatar_url'>;
}

export interface Paginated<T> {
  items: T[];
  total: number;
  page: number;
  limit: number;
}

export interface DashboardData {
  stats: {
    total_users: number;
    active_users: number;
    total_medicines: number;
    sent_reminders_today: number;
    email_messages: number;
    pending_emails: number;
  };
  recent_users: User[];
  today_reminders: Array<{ id: number; medicine: string; user: string; time: string; dose: string; status: string }>;
  gemini: { status: string; model: string; last_request: string };
}

export interface MessageLog {
  id: number;
  recipient: string;
  channel: string;
  subject: string;
  message: string;
  status: string;
  created_at: string;
}

export interface AiStatus {
  connected: boolean;
  model: string;
  latency_ms: number;
  last_message: string;
  monthly_usage_percent: number;
}
