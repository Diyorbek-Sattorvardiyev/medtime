import { Eye, LogIn, LockKeyhole, ShieldPlus, UserRound } from 'lucide-react';
import { FormEvent, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';
import { getErrorMessage } from '../utils/format';

export function Login() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState('admin@shifonazorat.uz');
  const [password, setPassword] = useState('admin12345');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setLoading(true);
    setError('');
    try {
      await login(email, password);
      navigate('/dashboard');
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-logo">
        <ShieldPlus size={36} />
      </div>
      <h1>Shifonazorat</h1>
      <p>Tibbiy boshqaruv tizimiga xush kelibsiz</p>
      <form className="login-card" onSubmit={submit}>
        {error && <div className="alert">{error}</div>}
        <label>Login yoki Email</label>
        <div className="input">
          <UserRound size={22} />
          <input value={email} onChange={(e) => setEmail(e.target.value)} placeholder="admin@shifonazorat.uz" />
        </div>
        <div className="row-label">
          <label>Parol</label>
          <a>Parolni unutdingizmi?</a>
        </div>
        <div className="input">
          <LockKeyhole size={22} />
          <input value={password} onChange={(e) => setPassword(e.target.value)} type={showPassword ? 'text' : 'password'} placeholder="••••••••" />
          <button className="icon-btn" type="button" onClick={() => setShowPassword((value) => !value)} aria-label="Parolni ko'rsatish">
            <Eye size={22} />
          </button>
        </div>
        <label className="check">
          <input type="checkbox" /> Meni eslab qol
        </label>
        <button className="primary" disabled={loading}>
          {loading ? 'Kirilmoqda...' : 'Kirish'} <LogIn size={20} />
        </button>
      </form>
    </div>
  );
}
