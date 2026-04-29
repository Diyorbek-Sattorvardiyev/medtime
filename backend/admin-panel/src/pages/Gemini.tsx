import { Bot, Copy, Mail, MessageSquare, RefreshCcw, Send, Sparkles, Zap } from 'lucide-react';
import { useEffect, useState } from 'react';
import { ErrorState, LoadingState, PageHeader, StatCard } from '../components/Common';
import { aiApi, usersApi } from '../services/api';
import type { AiStatus, User } from '../types/api';
import { getErrorMessage } from '../utils/format';

export function Gemini() {
  const [status, setStatus] = useState<AiStatus | null>(null);
  const [users, setUsers] = useState<User[]>([]);
  const [selected, setSelected] = useState<number | null>(null);
  const [detail, setDetail] = useState<User | null>(null);
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(true);
  const [working, setWorking] = useState(false);
  const [notice, setNotice] = useState('');
  const [error, setError] = useState('');

  const load = async () => {
    setLoading(true);
    try {
      const [ai, list] = await Promise.all([aiApi.status(), usersApi.list({ page: 1, limit: 50 })]);
      setStatus(ai);
      setUsers(list.items);
      const first = list.items[0]?.id || null;
      setSelected(first);
      if (first) setDetail(await usersApi.detail(first));
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

  const choose = async (id: number) => {
    setSelected(id);
    setDetail(await usersApi.detail(id));
  };

  const generate = async () => {
    if (!selected) return;
    setWorking(true);
    setNotice('');
    try {
      const result = await aiApi.generate(selected);
      setMessage(result.message);
    } catch (err) {
      setNotice(getErrorMessage(err));
    } finally {
      setWorking(false);
    }
  };

  const sendEmail = async () => {
    if (!selected) return;
    setWorking(true);
    try {
      await aiApi.sendEmail({ user_id: selected, subject: "Dori qabul qilish bo'yicha eslatma", message });
      setNotice('Email yuborildi');
    } catch (err) {
      setNotice(getErrorMessage(err));
    } finally {
      setWorking(false);
    }
  };

  const sendSms = async () => {
    if (!selected) return;
    setWorking(true);
    try {
      await aiApi.sendSms({ user_id: selected, message });
      setNotice("SMS navbatga qo'shildi");
    } catch (err) {
      setNotice(getErrorMessage(err));
    } finally {
      setWorking(false);
    }
  };

  if (loading) return <LoadingState />;
  if (error) return <ErrorState message={error} onRetry={load} />;

  return (
    <>
      <PageHeader title="Gemini AI" subtitle="Foydalanuvchi dorilari asosida aqlli xabar yaratish" />
      <div className="stats four">
        <StatCard title="Gemini Status" value={status?.connected ? 'Gemini 2.5 Flash' : 'Ulanmagan'} hint={status?.connected ? 'CONNECTED' : 'OFFLINE'} icon={<Zap />} />
        <StatCard title="API Latency" value={`${status?.latency_ms || 0}ms`} icon={<Sparkles />} />
        <StatCard title="Oxirgi xabar" value={status?.last_message || '-'} icon={<RefreshCcw />} />
        <StatCard title="Oylik limit" value={`${status?.monthly_usage_percent || 0}%`} icon={<Bot />} />
      </div>
      <div className="grid gemini-grid">
        <div className="panel form">
          <h2>Bemor tanlash</h2>
          <label>Foydalanuvchini tanlang</label>
          <select value={selected || ''} onChange={(e) => choose(Number(e.target.value))}>
            {users.map((user) => (
              <option key={user.id} value={user.id}>
                {user.full_name} (ID: {user.id})
              </option>
            ))}
          </select>
          <div className="medicine-box">
            <h3>Joriy dorilar</h3>
            {detail?.medicines?.length ? (
              detail.medicines.map((item) => (
                <p key={item.id}>
                  <span>✓</span> {item.name} {item.dose}
                </p>
              ))
            ) : (
              <p>Faol dori topilmadi</p>
            )}
          </div>
          <button className="primary" onClick={generate} disabled={working || !selected}>
            <Sparkles size={20} /> {working ? 'Yaratilmoqda...' : 'AI xabar yaratish'}
          </button>
          <div className="security-card mini">
            <h2>AI Maslahat</h2>
            <p>Gemini 2.5 Flash modeli dorilar bo'yicha tushunarli eslatmalar yaratishda yordam beradi.</p>
          </div>
        </div>
        <div className="panel editor">
          <div className="panel-head">
            <h2>Xabar tahriri</h2>
            <div className="inline-actions">
              <button className="link-btn" onClick={() => navigator.clipboard.writeText(message)}>
                <Copy size={16} /> Nusxa olish
              </button>
              <button className="link-btn" onClick={generate}>
                <RefreshCcw size={16} /> Qayta yaratish
              </button>
            </div>
          </div>
          {notice && <div className="alert success">{notice}</div>}
          <textarea value={message} onChange={(e) => setMessage(e.target.value)} placeholder="AI yaratgan xabar shu yerda ko'rinadi..." />
          <div className="editor-footer">
            <span>Oxirgi tahrir: hozir</span>
            <button className="outline" onClick={sendSms} disabled={!message || working}>
              <MessageSquare size={20} /> SMS yuborish
            </button>
            <button className="primary small" onClick={sendEmail} disabled={!message || working}>
              <Mail size={20} /> Emailga yuborish
            </button>
          </div>
        </div>
      </div>
      <div className="panel safe">
        <Bot />
        <div>
          <h3>Xavfsiz tahlil kafolati</h3>
          <p>Barcha ma'lumotlar backend orqali qayta ishlanadi. Gemini API key frontendga chiqarilmaydi.</p>
        </div>
        <Send />
      </div>
    </>
  );
}
