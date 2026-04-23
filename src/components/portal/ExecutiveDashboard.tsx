import { useState, useEffect } from 'react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell, Legend } from 'recharts';

interface ExecKPIs {
  total_complaints: number;
  open_complaints: number;
  sla_breached: number;
  pending_dues_total: number;
  collection_rate: number;
  active_members: number;
  upcoming_events: number;
  pending_bookings: number;
}

interface Props {
  role: string;
}

const COLORS = ['#1E3A8A', '#10B981', '#F59E0B', '#EF4444'];

async function apiFetch<T>(path: string): Promise<T> {
  const res = await fetch(path, { credentials: 'include' });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}

export default function ExecutiveDashboard({ role }: Props) {
  const [kpis, setKpis] = useState<ExecKPIs | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    apiFetch<ExecKPIs>('/api/v1/admin/kpis')
      .then(setKpis)
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-48">
        <div className="flex items-center gap-3 text-text-secondary">
          <i className="fas fa-spinner fa-spin text-xl" aria-hidden="true" />
          <span>Loading dashboard…</span>
        </div>
      </div>
    );
  }

  const complaintStatusData = [
    { name: 'Open', value: (kpis?.open_complaints ?? 0) - (kpis?.sla_breached ?? 0) },
    { name: 'SLA Breached', value: kpis?.sla_breached ?? 0 },
    { name: 'Resolved', value: (kpis?.total_complaints ?? 0) - (kpis?.open_complaints ?? 0) },
  ].filter((d) => d.value > 0);

  const collectionData = [
    { name: 'Collected', value: kpis?.collection_rate ?? 0 },
    { name: 'Pending', value: 100 - (kpis?.collection_rate ?? 0) },
  ];

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-text-primary capitalize">
          {role} Dashboard
        </h1>
        <p className="text-sm text-text-secondary mt-1">Society overview at a glance.</p>
      </div>

      {/* KPI Grid */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        {[
          { label: 'Total Complaints', value: kpis?.total_complaints ?? 0, icon: 'fa-tools', color: 'text-primary-600', bg: 'bg-primary-50', href: '/portal/complaints' },
          { label: 'SLA Breached', value: kpis?.sla_breached ?? 0, icon: 'fa-exclamation-triangle', color: 'text-red-600', bg: 'bg-red-50', href: '/portal/complaints?sla=breached' },
          { label: 'Collection Rate', value: `${kpis?.collection_rate ?? 0}%`, icon: 'fa-chart-pie', color: 'text-green-600', bg: 'bg-green-50', href: '/portal/finance' },
          { label: 'Pending Dues', value: `₹${((kpis?.pending_dues_total ?? 0) / 1000).toFixed(0)}K`, icon: 'fa-rupee-sign', color: 'text-amber-600', bg: 'bg-amber-50', href: '/portal/finance' },
          { label: 'Active Members', value: kpis?.active_members ?? 0, icon: 'fa-users', color: 'text-blue-600', bg: 'bg-blue-50', href: '/portal/members' },
          { label: 'Upcoming Events', value: kpis?.upcoming_events ?? 0, icon: 'fa-calendar-alt', color: 'text-purple-600', bg: 'bg-purple-50', href: '/portal/events' },
          { label: 'Pending Bookings', value: kpis?.pending_bookings ?? 0, icon: 'fa-building', color: 'text-teal-600', bg: 'bg-teal-50', href: '/portal/facilities' },
          { label: 'Open Complaints', value: kpis?.open_complaints ?? 0, icon: 'fa-clock', color: 'text-orange-600', bg: 'bg-orange-50', href: '/portal/complaints?status=Open' },
        ].map((item) => (
          <a
            key={item.label}
            href={item.href}
            className="bg-white rounded-xl border border-border-light p-4 hover:shadow-soft transition-shadow"
          >
            <div className={`w-8 h-8 ${item.bg} rounded-lg flex items-center justify-center mb-3`}>
              <i className={`fas ${item.icon} ${item.color} text-sm`} aria-hidden="true" />
            </div>
            <div className="text-2xl font-bold text-text-primary">{item.value}</div>
            <div className="text-xs text-text-secondary mt-0.5">{item.label}</div>
          </a>
        ))}
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        {/* Complaint Status Pie */}
        <div className="bg-white rounded-xl border border-border-light p-5">
          <h2 className="font-semibold text-text-primary mb-4">Complaint Status</h2>
          {complaintStatusData.length > 0 ? (
            <ResponsiveContainer width="100%" height={200}>
              <PieChart>
                <Pie
                  data={complaintStatusData}
                  cx="50%"
                  cy="50%"
                  outerRadius={70}
                  dataKey="value"
                  label={({ name, value }) => `${name}: ${value}`}
                  labelLine={false}
                >
                  {complaintStatusData.map((_, i) => (
                    <Cell key={i} fill={COLORS[i % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip />
                <Legend />
              </PieChart>
            </ResponsiveContainer>
          ) : (
            <div className="flex items-center justify-center h-48 text-text-secondary text-sm">
              No complaint data available.
            </div>
          )}
        </div>

        {/* Dues Collection */}
        <div className="bg-white rounded-xl border border-border-light p-5">
          <h2 className="font-semibold text-text-primary mb-4">Dues Collection Rate</h2>
          <div className="flex items-center justify-center h-[200px]">
            <div className="text-center">
              <div className="text-5xl font-bold text-primary-600">{kpis?.collection_rate ?? 0}%</div>
              <p className="text-sm text-text-secondary mt-2">of dues collected this period</p>
              <div className="mt-4 w-48 bg-gray-200 rounded-full h-3">
                <div
                  className="bg-primary-600 h-3 rounded-full transition-all duration-500"
                  style={{ width: `${kpis?.collection_rate ?? 0}%` }}
                />
              </div>
              <p className="text-xs text-text-secondary mt-2">
                Pending: ₹{((kpis?.pending_dues_total ?? 0) / 1000).toFixed(1)}K
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="bg-white rounded-xl border border-border-light p-5">
        <h2 className="font-semibold text-text-primary mb-4">Quick Actions</h2>
        <div className="flex flex-wrap gap-3">
          {[
            { label: 'Post Notice', icon: 'fa-bell', href: '/portal/notices/new' },
            { label: 'Create Event', icon: 'fa-calendar-plus', href: '/portal/events/new' },
            { label: 'Start Poll', icon: 'fa-vote-yea', href: '/portal/polls/new' },
            { label: 'Record Payment', icon: 'fa-money-bill-wave', href: '/portal/finance/payments/new' },
            { label: 'Assign Complaint', icon: 'fa-tools', href: '/portal/complaints' },
            { label: 'Book Facility', icon: 'fa-building', href: '/portal/facilities' },
          ].map((action) => (
            <a
              key={action.label}
              href={action.href}
              className="flex items-center gap-2 px-4 py-2 bg-gray-50 hover:bg-primary-50 hover:text-primary-600 rounded-lg text-sm font-medium text-text-secondary transition-colors border border-border-light"
            >
              <i className={`fas ${action.icon} text-sm`} aria-hidden="true" />
              {action.label}
            </a>
          ))}
        </div>
      </div>
    </div>
  );
}
