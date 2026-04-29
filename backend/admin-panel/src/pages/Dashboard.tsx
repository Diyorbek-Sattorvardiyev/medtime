import { Bot, Calendar, Download, Mail, Pill, ShieldCheck, UserCheck, Users } from 'lucide-react';
import { useEffect, useState } from 'react';
import { EmptyState, ErrorState, LoadingState, PageHeader, StatCard, StatusBadge } from '../components/Common';
import { dashboardApi } from '../services/api';
import type { DashboardData } from '../types/api';
import { formatNumber, getErrorMessage } from '../utils/format';

export function Dashboard() {
  const [data, setData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = async () => {
    setLoading(true);
    try {
      setData(await dashboardApi.get());
      setError('');
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  if (loading) return <LoadingState />;
  if (error) return <ErrorState message={error} onRetry={load} />;
  if (!data) return <EmptyState />;

  return (
    <>
      <PageHeader
        title="Dashboard"
        subtitle="Tizimdagi so'nggi holatlar va ko'rsatkichlar"
        actions={
          <>
            <button className="outline">
              <Calendar size={20} /> Bugun
            </button>
            <button className="primary small">
              <Download size={20} /> Hisobot yuklash
            </button>
          </>
        }
      />
      <div className="stats five">
        <StatCard title="Jami foydalanuvchilar" value={formatNumber(data.stats.total_users)} hint="+12% o'sish" icon={<Users />} />
        <StatCard title="Faol foydalanuvchilar" value={formatNumber(data.stats.active_users)} hint="72% faollik" icon={<UserCheck />} />
        <StatCard title="Jami dorilar" value={formatNumber(data.stats.total_medicines)} hint="Tizimda mavjud" icon={<Pill />} />
        <StatCard title="Bugun yuborilgan" value={formatNumber(data.stats.sent_reminders_today)} hint="98% yetkazildi" icon={<ShieldCheck />} />
        <StatCard title="Email xabarlari" value={formatNumber(data.stats.email_messages)} hint={`${data.stats.pending_emails} tasi kutilmoqda`} icon={<Mail />} />
      </div>
      <div className="grid two">
        <div className="panel">
          <div className="panel-head">
            <h2>Oxirgi ro'yxatdan o'tgan foydalanuvchilar</h2>
            <a>Barchasini ko'rish</a>
          </div>
          <table>
            <thead>
              <tr>
                <th>Foydalanuvchi</th>
                <th>Sana</th>
                <th>Holati</th>
              </tr>
            </thead>
            <tbody>
              {data.recent_users.map((user) => (
                <tr key={user.id}>
                  <td>
                    <div className="user-cell">
                      <div className="mini-avatar">{user.full_name.slice(0, 1)}</div>
                      <div>
                        <strong>{user.full_name}</strong>
                        <span>{user.email}</span>
                      </div>
                    </div>
                  </td>
                  <td>{new Date(user.created_at).toLocaleDateString('uz-UZ')}</td>
                  <td>
                    <StatusBadge status={user.status} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="side-stack">
          <div className="ai-card dark">
            <div className="ai-head">
              <div className="brand-icon">
                <Bot />
              </div>
              <div>
                <h3>Gemini AI Status</h3>
                <p>Aqlli tibbiy yordamchi</p>
              </div>
              <span className={`pill ${data.gemini.status}`}>{data.gemini.status}</span>
            </div>
            <dl>
              <dt>Model versiyasi</dt>
              <dd>{data.gemini.model}</dd>
              <dt>Bog'lanish turi</dt>
              <dd>REST API / Secure</dd>
              <dt>Oxirgi so'rov</dt>
              <dd>{data.gemini.last_request}</dd>
            </dl>
          </div>
          <div className="security-card">
            <h2>Xavfsizlik tizimi</h2>
            <p>SSL va 256-bit shifrlash faol</p>
          </div>
        </div>
      </div>
      <div className="panel">
        <div className="panel-head">
          <div>
            <h2>Bugungi dori eslatmalari</h2>
            <p>Yuborilgan va kutilayotgan eslatmalar ro'yxati</p>
          </div>
        </div>
        <table>
          <thead>
            <tr>
              <th>Dori nomi</th>
              <th>Bemor</th>
              <th>Vaqti</th>
              <th>Dozasi</th>
              <th>Holati</th>
            </tr>
          </thead>
          <tbody>
            {data.today_reminders.map((item) => (
              <tr key={item.id}>
                <td>{item.medicine}</td>
                <td>{item.user}</td>
                <td>{item.time}</td>
                <td>{item.dose}</td>
                <td>
                  <StatusBadge status={item.status} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
