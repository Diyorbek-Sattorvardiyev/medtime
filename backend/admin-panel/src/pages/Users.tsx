import { Download, Trash2, UserPlus, Users as UsersIcon } from 'lucide-react';
import { useEffect, useState } from 'react';
import { EmptyState, ErrorState, LoadingState, PageHeader, Pagination, StatCard, StatusBadge } from '../components/Common';
import { usersApi } from '../services/api';
import type { Paginated, User } from '../types/api';
import { formatDate, formatNumber, getErrorMessage } from '../utils/format';

export function Users() {
  const [data, setData] = useState<Paginated<User> | null>(null);
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState('');
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [deletingId, setDeletingId] = useState<number | null>(null);

  const load = async () => {
    setLoading(true);
    try {
      setData(await usersApi.list({ page, limit: 10, status, search }));
      setError('');
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, [page, status]);

  const toggle = async (user: User) => {
    await usersApi.status(user.id, user.status === 'active' ? 'blocked' : 'active');
    load();
  };

  const remove = async (user: User) => {
    const confirmed = window.confirm(
      `${user.full_name} foydalanuvchisini o'chirasizmi? Unga tegishli dorilar, eslatmalar, kodlar va xabarlar ham o'chiriladi.`,
    );
    if (!confirmed) return;
    setDeletingId(user.id);
    try {
      await usersApi.remove(user.id);
      await load();
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setDeletingId(null);
    }
  };

  if (loading && !data) return <LoadingState />;
  if (error) return <ErrorState message={error} onRetry={load} />;

  return (
    <>
      <PageHeader
        title="Foydalanuvchilar boshqaruvi"
        subtitle="Tizimdagi barcha bemorlar va xodimlar ro'yxati"
        actions={
          <>
            <button className="outline">
              <Download size={20} /> Eksport
            </button>
            <button className="primary small">
              <UserPlus size={20} /> Yangi foydalanuvchi
            </button>
          </>
        }
      />
      <div className="stats four">
        <StatCard title="Jami foydalanuvchilar" value={formatNumber(data?.total)} icon={<UsersIcon />} />
        <StatCard title="Faol foydalanuvchilar" value={formatNumber(data?.items.filter((u) => u.status === 'active').length)} icon={<UsersIcon />} />
        <StatCard title="Tasdiqlangan" value={formatNumber(data?.items.filter((u) => u.email_verified).length)} icon={<UsersIcon />} />
        <StatCard title="Bloklanganlar" value={formatNumber(data?.items.filter((u) => u.status === 'blocked').length)} icon={<UsersIcon />} />
      </div>
      <div className="panel">
        <div className="filters">
          {[
            ['', 'Barchasi'],
            ['active', 'Faol'],
            ['blocked', 'Bloklangan'],
          ].map(([value, label]) => (
            <button key={value} className={status === value ? 'active' : ''} onClick={() => setStatus(value)}>
              {label}
            </button>
          ))}
          <input
            className="table-search"
            placeholder="Foydalanuvchi izlash..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && load()}
          />
        </div>
        {!data?.items.length ? (
          <EmptyState />
        ) : (
          <table>
            <thead>
              <tr>
                <th>ID</th>
                <th>Ism familiya</th>
                <th>Email</th>
                <th>Telefon</th>
                <th>Sana</th>
                <th>Email tasdiqlangan</th>
                <th>Holat</th>
                <th>Amal</th>
              </tr>
            </thead>
            <tbody>
              {data.items.map((user) => (
                <tr key={user.id}>
                  <td>#{user.id}</td>
                  <td>
                    <div className="user-cell">
                      <div className="mini-avatar">{user.full_name.slice(0, 1)}</div>
                      <strong>{user.full_name}</strong>
                    </div>
                  </td>
                  <td>{user.email}</td>
                  <td>{user.phone || '-'}</td>
                  <td>{formatDate(user.created_at)}</td>
                  <td>{user.email_verified ? 'Ha' : "Yo'q"}</td>
                  <td>
                    <StatusBadge status={user.status} />
                  </td>
                  <td>
                    <div className="row-actions">
                      <button className="link-btn" onClick={() => toggle(user)}>
                        {user.status === 'active' ? 'Bloklash' : 'Faollashtirish'}
                      </button>
                      <button className="link-btn danger" disabled={deletingId === user.id} onClick={() => remove(user)}>
                        <Trash2 size={16} />
                        {deletingId === user.id ? "O'chirilmoqda" : "O'chirish"}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        {data && <Pagination page={page} total={data.total} limit={data.limit} onPage={setPage} />}
      </div>
    </>
  );
}
