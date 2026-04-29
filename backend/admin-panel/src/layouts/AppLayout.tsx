import { Bell, Bot, Grid2X2, HelpCircle, LogOut, Mail, Pill, Search, Settings, ShieldPlus, Users } from 'lucide-react';
import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';

const nav = [
  { to: '/dashboard', label: 'Bosh sahifa', icon: Grid2X2 },
  { to: '/users', label: 'Foydalanuvchilar', icon: Users },
  { to: '/medicines', label: 'Dorilar', icon: Pill },
  { to: '/messages', label: 'Xabarlar', icon: Mail },
  { to: '/gemini', label: 'Gemini AI', icon: Bot },
];

export function AppLayout() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const exit = () => {
    logout();
    navigate('/login');
  };

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-icon">
            <ShieldPlus size={25} />
          </div>
          <div>
            <strong>Shifonazorat</strong>
            <span>TIBBIY BOSHQARUV</span>
          </div>
        </div>
        <nav>
          {nav.map((item) => (
            <NavLink key={item.to} to={item.to}>
              <item.icon size={24} />
              {item.label}
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-bottom">
          <NavLink to="/settings">
            <Settings size={24} /> Sozlamalar
          </NavLink>
          <button onClick={exit}>
            <LogOut size={24} /> Chiqish
          </button>
          <div className="help-box">
            <span>Muammo bormi?</span>
            <button>Yordam so'rash</button>
          </div>
        </div>
      </aside>
      <main className="main">
        <header className="topbar">
          <label className="search">
            <Search size={20} />
            <input placeholder="Qidiruv..." />
          </label>
          <div className="top-actions">
            <Bell size={24} />
            <HelpCircle size={24} />
            <div className="profile">
              <div>
                <strong>{user?.full_name || 'Admin'}</strong>
                <span>Administrator</span>
              </div>
              <div className="avatar">{(user?.full_name || 'A').slice(0, 1)}</div>
            </div>
          </div>
        </header>
        <section className="content">
          <Outlet />
        </section>
      </main>
    </div>
  );
}
