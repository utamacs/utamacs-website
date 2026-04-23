import { useState, useEffect } from 'react';

interface MemberKPIs {
  open_complaints: number;
  pending_dues: number;
  upcoming_events: number;
  active_polls: number;
  unread_notices: number;
  unread_notifications: number;
}

interface Complaint {
  id: string;
  ticket_number: string;
  title: string;
  status: string;
  priority: string;
  created_at: string;
}

interface Notice {
  id: string;
  title: string;
  category: string;
  created_at: string;
}

interface Props {
  userId: string;
}

const STATUS_COLORS: Record<string, string> = {
  Open: 'bg-red-100 text-red-700',
  Assigned: 'bg-blue-100 text-blue-700',
  In_Progress: 'bg-yellow-100 text-yellow-700',
  Resolved: 'bg-green-100 text-green-700',
  Closed: 'bg-gray-100 text-gray-600',
};

const PRIORITY_COLORS: Record<string, string> = {
  Critical: 'text-red-600',
  High: 'text-orange-500',
  Medium: 'text-yellow-600',
  Low: 'text-green-600',
};

async function apiFetch<T>(path: string): Promise<T> {
  const res = await fetch(path, { credentials: 'include' });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}

export default function MemberDashboard({ userId }: Props) {
  const [kpis, setKpis] = useState<MemberKPIs | null>(null);
  const [complaints, setComplaints] = useState<Complaint[]>([]);
  const [notices, setNotices] = useState<Notice[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      apiFetch<MemberKPIs>('/api/v1/admin/kpis'),
      apiFetch<{ data: Complaint[] }>('/api/v1/complaints?limit=5'),
      apiFetch<Notice[]>('/api/v1/notices'),
    ])
      .then(([k, c, n]) => {
        setKpis(k);
        setComplaints(c.data?.slice(0, 5) ?? []);
        setNotices(n.slice(0, 4));
      })
      .finally(() => setLoading(false));
  }, [userId]);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-48">
        <div className="flex items-center gap-3 text-text-secondary">
          <i className="fas fa-spinner fa-spin text-xl" aria-hidden="true" />
          <span>Loading your dashboard…</span>
        </div>
      </div>
    );
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-text-primary">My Dashboard</h1>
        <p className="text-sm text-text-secondary mt-1">Welcome back! Here's a summary of your account.</p>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4 mb-8">
        {[
          { label: 'Open Complaints', value: kpis?.open_complaints ?? 0, icon: 'fa-tools', color: 'text-red-600', bg: 'bg-red-50', href: '/portal/complaints' },
          { label: 'Pending Dues', value: `₹${(kpis?.pending_dues ?? 0).toLocaleString('en-IN')}`, icon: 'fa-rupee-sign', color: 'text-amber-600', bg: 'bg-amber-50', href: '/portal/finance' },
          { label: 'Upcoming Events', value: kpis?.upcoming_events ?? 0, icon: 'fa-calendar-alt', color: 'text-blue-600', bg: 'bg-blue-50', href: '/portal/events' },
          { label: 'Active Polls', value: kpis?.active_polls ?? 0, icon: 'fa-vote-yea', color: 'text-purple-600', bg: 'bg-purple-50', href: '/portal/polls' },
          { label: 'Unread Notices', value: kpis?.unread_notices ?? 0, icon: 'fa-bell', color: 'text-green-600', bg: 'bg-green-50', href: '/portal/notices' },
          { label: 'Notifications', value: kpis?.unread_notifications ?? 0, icon: 'fa-envelope', color: 'text-primary-600', bg: 'bg-primary-50', href: '/portal/notifications' },
        ].map((item) => (
          <a
            key={item.label}
            href={item.href}
            className="bg-white rounded-xl border border-border-light p-4 hover:shadow-soft transition-shadow"
          >
            <div className={`w-8 h-8 ${item.bg} rounded-lg flex items-center justify-center mb-3`}>
              <i className={`fas ${item.icon} ${item.color} text-sm`} aria-hidden="true" />
            </div>
            <div className="text-xl font-bold text-text-primary">{item.value}</div>
            <div className="text-xs text-text-secondary mt-0.5">{item.label}</div>
          </a>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Complaints */}
        <div className="bg-white rounded-xl border border-border-light p-5">
          <div className="flex items-center justify-between mb-4">
            <h2 className="font-semibold text-text-primary">My Complaints</h2>
            <a href="/portal/complaints" className="text-sm text-primary-600 hover:underline">View all</a>
          </div>
          {complaints.length === 0 ? (
            <div className="text-center py-8">
              <i className="fas fa-check-circle text-3xl text-green-500 mb-2" aria-hidden="true" />
              <p className="text-sm text-text-secondary">No open complaints. All is well!</p>
            </div>
          ) : (
            <div className="space-y-3">
              {complaints.map((c) => (
                <a
                  key={c.id}
                  href={`/portal/complaints/${c.id}`}
                  className="flex items-start gap-3 p-3 rounded-lg hover:bg-gray-50 transition-colors"
                >
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-medium text-text-primary truncate">{c.title}</div>
                    <div className="text-xs text-text-secondary mt-0.5">{c.ticket_number}</div>
                  </div>
                  <span className={`flex-shrink-0 text-xs px-2 py-1 rounded-full font-medium ${STATUS_COLORS[c.status] ?? 'bg-gray-100 text-gray-600'}`}>
                    {c.status.replace('_', ' ')}
                  </span>
                </a>
              ))}
            </div>
          )}
          <div className="mt-4 pt-4 border-t border-border-light">
            <a href="/portal/complaints/new" className="btn-primary text-sm w-full text-center block py-2">
              <i className="fas fa-plus mr-2" aria-hidden="true" />
              Raise New Complaint
            </a>
          </div>
        </div>

        {/* Recent Notices */}
        <div className="bg-white rounded-xl border border-border-light p-5">
          <div className="flex items-center justify-between mb-4">
            <h2 className="font-semibold text-text-primary">Recent Notices</h2>
            <a href="/portal/notices" className="text-sm text-primary-600 hover:underline">View all</a>
          </div>
          {notices.length === 0 ? (
            <p className="text-sm text-text-secondary text-center py-8">No recent notices.</p>
          ) : (
            <div className="space-y-3">
              {notices.map((n) => (
                <a
                  key={n.id}
                  href={`/portal/notices/${n.id}`}
                  className="flex items-start gap-3 p-3 rounded-lg hover:bg-gray-50 transition-colors"
                >
                  <div className={`flex-shrink-0 w-2 h-2 rounded-full mt-1.5 ${n.category === 'Urgent' ? 'bg-red-500' : 'bg-primary-500'}`} />
                  <div>
                    <div className="text-sm font-medium text-text-primary">{n.title}</div>
                    <div className="text-xs text-text-secondary mt-0.5">{n.category} · {new Date(n.created_at).toLocaleDateString('en-IN')}</div>
                  </div>
                </a>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
