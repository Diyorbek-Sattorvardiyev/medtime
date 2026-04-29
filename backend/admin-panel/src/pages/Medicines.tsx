import { Filter, Plus, Pill } from 'lucide-react';
import { useEffect, useState } from 'react';
import { EmptyState, ErrorState, LoadingState, PageHeader, Pagination, StatCard, StatusBadge } from '../components/Common';
import { medicinesApi } from '../services/api';
import type { Medicine, Paginated } from '../types/api';
import { formatDate, formatNumber, getErrorMessage } from '../utils/format';

export function Medicines() {
  const [data, setData] = useState<Paginated<Medicine> | null>(null);
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState('');
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = async () => {
    setLoading(true);
    try {
      setData(await medicinesApi.list({ page, limit: 10, status, search }));
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

  if (loading && !data) return <LoadingState />;
  if (error) return <ErrorState message={error} onRetry={load} />;

  return (
    <>
      <PageHeader title="Dorilar Boshqaruvi" subtitle="Barcha bemorlar uchun dorilar va qabul qilish jadvallarini kuzatib boring." />
      <div className="stats two-cards">
        <StatCard title="Jami aktiv" value={`${formatNumber(data?.items.filter((m) => m.status === 'active').length)} ta`} icon={<Pill />} />
        <StatCard title="Tugallangan" value={`${formatNumber(data?.items.filter((m) => m.status === 'finished').length)} ta`} icon={<Pill />} />
      </div>
      <div className="panel">
        <div className="filters">
          <span>Status:</span>
          {[
            ['', 'Hammasi'],
            ['active', 'Aktiv'],
            ['finished', 'Tugallangan'],
          ].map(([value, label]) => (
            <button key={value} className={status === value ? 'active' : ''} onClick={() => setStatus(value)}>
              {label}
            </button>
          ))}
          <input
            className="table-search"
            placeholder="Dori yoki foydalanuvchi..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && load()}
          />
          <button className="outline">
            <Filter size={18} /> Filtrlar
          </button>
          <button className="primary small">
            <Plus size={20} /> Yangi dori qo'shish
          </button>
        </div>
        {!data?.items.length ? (
          <EmptyState />
        ) : (
          <table>
            <thead>
              <tr>
                <th>Dori nomi</th>
                <th>Dozasi</th>
                <th>Qabul vaqti</th>
                <th>Foydalanuvchi</th>
                <th>Muddati</th>
                <th>Status</th>
                <th>Amallar</th>
              </tr>
            </thead>
            <tbody>
              {data.items.map((item) => (
                <tr key={item.id}>
                  <td>
                    <div className="user-cell">
                      <div className="medicine-icon">
                        <Pill size={18} />
                      </div>
                      <strong>{item.name}</strong>
                    </div>
                  </td>
                  <td>{item.dose}</td>
                  <td>{item.schedule}</td>
                  <td>{item.user?.full_name || '-'}</td>
                  <td>
                    {formatDate(item.start_date)}
                    <br />
                    <span>{item.end_date ? `${formatDate(item.end_date)} gacha` : 'Davomli'}</span>
                  </td>
                  <td>
                    <StatusBadge status={item.status} />
                  </td>
                  <td>
                    <button className="outline compact">Dori ko'rish</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        {data && <Pagination page={page} total={data.total} limit={data.limit} onPage={setPage} />}
      </div>
      <div className="grid two">
        <div className="panel">
          <h2>Eng ko'p tayinlangan dorilar</h2>
          {data?.items.slice(0, 3).map((item, index) => (
            <div className="rank" key={item.id}>
              <span>{index + 1}</span>
              <Pill />
              <strong>{item.name}</strong>
              <div className="bar">
                <i style={{ width: `${80 - index * 15}%` }} />
              </div>
              <b>{452 - index * 111} ta</b>
            </div>
          ))}
        </div>
        <div className="security-card">
          <h2>Gemini AI Yordamchi</h2>
          <p>Dorilar o'rtasidagi o'zaro ta'sirni yoki nojo'ya ta'sirlarni AI orqali tekshirib ko'ring.</p>
          <button className="white-btn">AI Tahlilini Boshlash</button>
        </div>
      </div>
    </>
  );
}
