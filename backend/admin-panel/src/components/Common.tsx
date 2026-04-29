import { AlertCircle, CheckCircle2, Loader2 } from 'lucide-react';
import type React from 'react';

export function StatCard({ title, value, hint, icon }: { title: string; value: string; hint?: string; icon: React.ReactNode }) {
  return (
    <div className="stat-card">
      <div>
        <p className="stat-title">{title}</p>
        <strong>{value}</strong>
        {hint && <span>{hint}</span>}
      </div>
      <div className="stat-icon">{icon}</div>
    </div>
  );
}

export function StatusBadge({ status }: { status: string }) {
  const normalized = status.toLowerCase();
  const label =
    normalized === 'active'
      ? 'Faol'
      : normalized === 'blocked'
        ? 'Bloklangan'
        : normalized === 'finished'
          ? 'Tugallangan'
          : normalized === 'sent'
            ? 'Yuborildi'
            : normalized === 'failed'
              ? 'Xato'
              : normalized === 'taken'
                ? 'Muvaffaqiyatli'
                : 'Kutilmoqda';
  return <span className={`badge ${normalized}`}>{label}</span>;
}

export function PageHeader({
  title,
  subtitle,
  actions,
}: {
  title: string;
  subtitle?: string;
  actions?: React.ReactNode;
}) {
  return (
    <div className="page-header">
      <div>
        <h1>{title}</h1>
        {subtitle && <p>{subtitle}</p>}
      </div>
      {actions && <div className="page-actions">{actions}</div>}
    </div>
  );
}

export function LoadingState() {
  return (
    <div className="state-card">
      <Loader2 className="spin" size={28} />
      <p>Ma'lumotlar yuklanmoqda...</p>
    </div>
  );
}

export function ErrorState({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div className="state-card error">
      <AlertCircle size={28} />
      <p>{message}</p>
      {onRetry && <button onClick={onRetry}>Qayta urinish</button>}
    </div>
  );
}

export function EmptyState({ text = "Ma'lumot topilmadi" }: { text?: string }) {
  return (
    <div className="state-card">
      <CheckCircle2 size={28} />
      <p>{text}</p>
    </div>
  );
}

export function Pagination({
  page,
  total,
  limit,
  onPage,
}: {
  page: number;
  total: number;
  limit: number;
  onPage: (page: number) => void;
}) {
  const pages = Math.max(Math.ceil(total / limit), 1);
  return (
    <div className="pagination">
      <span>
        Jami {total} ta natijadan {(page - 1) * limit + 1}-{Math.min(page * limit, total)} ko'rsatilmoqda
      </span>
      <div>
        <button disabled={page <= 1} onClick={() => onPage(page - 1)}>
          ‹
        </button>
        {[page, page + 1, page + 2].filter((item) => item <= pages).map((item) => (
          <button key={item} className={item === page ? 'active' : ''} onClick={() => onPage(item)}>
            {item}
          </button>
        ))}
        <button disabled={page >= pages} onClick={() => onPage(page + 1)}>
          ›
        </button>
      </div>
    </div>
  );
}
