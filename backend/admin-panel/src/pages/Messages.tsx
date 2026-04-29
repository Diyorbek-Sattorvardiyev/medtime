import { Mail, Send } from 'lucide-react';
import { FormEvent, useEffect, useState } from 'react';
import { EmptyState, ErrorState, LoadingState, PageHeader, Pagination, StatusBadge } from '../components/Common';
import { messagesApi } from '../services/api';
import type { MessageLog, Paginated } from '../types/api';
import { formatDate, getErrorMessage } from '../utils/format';

export function Messages() {
  const [history, setHistory] = useState<Paginated<MessageLog> | null>(null);
  const [page, setPage] = useState(1);
  const [recipientType, setRecipientType] = useState('all');
  const [customEmail, setCustomEmail] = useState('');
  const [subject, setSubject] = useState('Dori eslatmasi');
  const [message, setMessage] = useState("Assalomu alaykum! Bugungi dorilaringizni o'z vaqtida qabul qilishni unutmang.");
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [notice, setNotice] = useState('');
  const [error, setError] = useState('');

  const load = async () => {
    setLoading(true);
    try {
      setHistory(await messagesApi.history({ page, limit: 10 }));
      setError('');
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, [page]);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setSending(true);
    setNotice('');
    try {
      const result = await messagesApi.send({ recipient_type: recipientType, custom_email: customEmail, subject, message });
      setNotice(`Yuborildi: ${result.sent}, xato: ${result.failed}`);
      load();
    } catch (err) {
      setNotice(getErrorMessage(err));
    } finally {
      setSending(false);
    }
  };

  if (loading && !history) return <LoadingState />;
  if (error) return <ErrorState message={error} onRetry={load} />;

  return (
    <>
      <PageHeader title="Email xabarlar" subtitle="Foydalanuvchilarga email va xabar yuborish markazi" />
      <div className="grid two">
        <form className="panel form" onSubmit={submit}>
          <h2>Xabar yuborish</h2>
          {notice && <div className="alert success">{notice}</div>}
          <label>Kimga yuboriladi</label>
          <select value={recipientType} onChange={(e) => setRecipientType(e.target.value)}>
            <option value="all">Barcha foydalanuvchilar</option>
            <option value="active">Faol foydalanuvchilar</option>
            <option value="custom">Custom email</option>
          </select>
          {recipientType === 'custom' && <input value={customEmail} onChange={(e) => setCustomEmail(e.target.value)} placeholder="email@example.com" />}
          <label>Mavzu</label>
          <input value={subject} onChange={(e) => setSubject(e.target.value)} />
          <label>Xabar</label>
          <textarea value={message} onChange={(e) => setMessage(e.target.value)} rows={9} />
          <button className="primary" disabled={sending}>
            <Send size={20} /> {sending ? 'Yuborilmoqda...' : 'Yuborish'}
          </button>
        </form>
        <div className="panel preview">
          <div className="panel-head">
            <h2>Preview</h2>
            <Mail />
          </div>
          <h3>{subject}</h3>
          <p>{message}</p>
        </div>
      </div>
      <div className="panel">
        <h2>Yuborilgan xabarlar tarixi</h2>
        {!history?.items.length ? (
          <EmptyState />
        ) : (
          <table>
            <thead>
              <tr>
                <th>Kimga</th>
                <th>Mavzu</th>
                <th>Kanal</th>
                <th>Sana</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {history.items.map((item) => (
                <tr key={item.id}>
                  <td>{item.recipient}</td>
                  <td>{item.subject}</td>
                  <td>{item.channel}</td>
                  <td>{formatDate(item.created_at)}</td>
                  <td>
                    <StatusBadge status={item.status} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        {history && <Pagination page={page} total={history.total} limit={history.limit} onPage={setPage} />}
      </div>
    </>
  );
}
