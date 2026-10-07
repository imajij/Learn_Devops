import React, { useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';

const API = '/api';
const NEXT_STATUS = { OPEN: 'IN_PROGRESS', IN_PROGRESS: 'RESOLVED', RESOLVED: 'OPEN' };
const FILTERS = ['ALL', 'OPEN', 'IN_PROGRESS', 'RESOLVED'];
const pretty = (s) => s.replace('_', ' ').toLowerCase();

async function api(path, options = {}) {
  const res = await fetch(`${API}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  if (!res.ok) throw new Error(`${options.method || 'GET'} ${path} -> HTTP ${res.status}`);
  return res.status === 204 ? null : res.json();
}

function App() {
  const [tickets, setTickets] = useState([]);
  const [stats, setStats] = useState({ total: 0, open: 0, inProgress: 0, resolved: 0, urgent: 0 });
  const [info, setInfo] = useState(null);
  const [filter, setFilter] = useState('ALL');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  const load = async () => {
    try {
      setError('');
      const [t, s, i] = await Promise.all([api('/tickets'), api('/tickets/stats'), api('/info')]);
      setTickets(t);
      setStats(s);
      setInfo(i);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, []);

  const advance = async (t) => {
    await api(`/tickets/${t.id}`, { method: 'PUT', body: JSON.stringify({ status: NEXT_STATUS[t.status] }) });
    load();
  };

  const remove = async (t) => {
    await api(`/tickets/${t.id}`, { method: 'DELETE' });
    load();
  };

  const create = async (e) => {
    e.preventDefault();
    const form = e.currentTarget;
    const data = Object.fromEntries(new FormData(form));
    try {
      await api('/tickets', { method: 'POST', body: JSON.stringify(data) });
      form.reset();
      load();
    } catch (err) {
      setError(err.message);
    }
  };

  const visible = filter === 'ALL' ? tickets : tickets.filter((t) => t.status === filter);

  return (
    <div className="page">
      <header className="topbar">
        <div className="logo"><span>CD</span>CampusDesk</div>
        <p>Campus IT Helpdesk</p>
        {info && <span className={`env env-${info.environment}`}>{info.environment}</span>}
      </header>

      {info && <div className="banner">{info.banner}</div>}
      {error && <div className="alert">Backend problem: {error}</div>}

      <section className="kpis">
        <Kpi label="Total tickets" value={stats.total} />
        <Kpi label="Open" value={stats.open} tone="open" />
        <Kpi label="In progress" value={stats.inProgress} tone="progress" />
        <Kpi label="Resolved" value={stats.resolved} tone="resolved" />
        <Kpi label="Urgent (not resolved)" value={stats.urgent} tone="urgent" />
      </section>

      <main className="grid">
        <section className="card">
          <div className="card-head">
            <h2>Tickets</h2>
            <div className="filters">
              {FILTERS.map((f) => (
                <button key={f} className={filter === f ? 'on' : ''} onClick={() => setFilter(f)}>
                  {f === 'ALL' ? 'All' : pretty(f)}
                </button>
              ))}
            </div>
          </div>
          {loading ? <p className="empty">Loading tickets...</p> : (
            <table>
              <thead>
                <tr><th>#</th><th>Issue</th><th>Category</th><th>Priority</th><th>Status</th><th></th></tr>
              </thead>
              <tbody>
                {visible.map((t) => (
                  <tr key={t.id}>
                    <td className="id">{t.id}</td>
                    <td>
                      <b>{t.title}</b>
                      <small>{t.requester}{t.location ? ` - ${t.location}` : ''}</small>
                    </td>
                    <td>{pretty(t.category)}</td>
                    <td><span className={`pill p-${t.priority.toLowerCase()}`}>{t.priority}</span></td>
                    <td><span className={`pill s-${t.status.toLowerCase()}`}>{pretty(t.status)}</span></td>
                    <td className="actions">
                      <button title="Move to next status" onClick={() => advance(t)}>Next</button>
                      <button title="Delete ticket" className="danger" onClick={() => remove(t)}>Delete</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          {!loading && !visible.length && <p className="empty">No tickets here.</p>}
        </section>

        <form className="card form" onSubmit={create}>
          <h2>Raise a ticket</h2>
          <label>What is wrong?<input name="title" required minLength={3} placeholder="e.g. Wi-Fi drops in Library 2nd floor" /></label>
          <label>Details<textarea name="description" rows={3} placeholder="Anything that helps us fix it" /></label>
          <div className="row">
            <label>Category
              <select name="category" defaultValue="SOFTWARE">
                <option>HARDWARE</option><option>SOFTWARE</option><option>NETWORK</option><option>ACCOUNT</option>
              </select>
            </label>
            <label>Priority
              <select name="priority" defaultValue="MEDIUM">
                <option>LOW</option><option>MEDIUM</option><option>HIGH</option><option>URGENT</option>
              </select>
            </label>
          </div>
          <div className="row">
            <label>Your name<input name="requester" required defaultValue="Ajij Uttam" /></label>
            <label>Location<input name="location" placeholder="Block / room" /></label>
          </div>
          <button className="primary">Submit ticket</button>
        </form>
      </main>

      <footer>
        {info ? `${info.service} v${info.version} - served by pod ${info.pod}` : 'connecting to API...'}
      </footer>
    </div>
  );
}

function Kpi({ label, value, tone = '' }) {
  return (
    <div className={`kpi ${tone}`}>
      <small>{label}</small>
      <strong>{value}</strong>
    </div>
  );
}

createRoot(document.getElementById('root')).render(<App />);
