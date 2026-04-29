import { useEffect, useState } from 'react';
import { ErrorState, LoadingState, PageHeader } from '../components/Common';
import { settingsApi } from '../services/api';
import { getErrorMessage } from '../utils/format';

export function Settings() {
  const [data, setData] = useState<Record<string, unknown> | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = async () => {
    setLoading(true);
    try {
      setData(await settingsApi.get());
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

  return (
    <>
      <PageHeader title="Sozlamalar" subtitle="Admin panel va integratsiya holati" />
      <div className="panel settings-list">
        {Object.entries(data || {}).map(([key, value]) => (
          <div key={key}>
            <span>{key}</span>
            <strong>{String(value)}</strong>
          </div>
        ))}
      </div>
    </>
  );
}
