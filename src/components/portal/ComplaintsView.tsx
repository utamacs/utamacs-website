import { useState, useEffect } from 'react';

interface Complaint {
  id: string;
  ticket_number: string;
  title: string;
  category: string;
  priority: string;
  status: string;
  created_at: string;
  units?: { unit_number: string };
}

interface Props {
  role: string;
  userId: string;
}

const STATUS_BADGE: Record<string, string> = {
  Open: 'bg-red-100 text-red-700',
  Assigned: 'bg-blue-100 text-blue-700',
  In_Progress: 'bg-yellow-100 text-yellow-700',
  Waiting_for_User: 'bg-orange-100 text-orange-700',
  Resolved: 'bg-green-100 text-green-700',
  Closed: 'bg-gray-100 text-gray-600',
  Reopened: 'bg-purple-100 text-purple-700',
};

const PRIORITY_DOT: Record<string, string> = {
  Critical: 'bg-red-500',
  High: 'bg-orange-500',
  Medium: 'bg-yellow-500',
  Low: 'bg-green-500',
};

export default function ComplaintsView({ role, userId }: Props) {
  const [complaints, setComplaints] = useState<Complaint[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('');

  const fetchComplaints = async () => {
    setLoading(true);
    const params = new URLSearchParams({ limit: '20' });
    if (statusFilter) params.set('status', statusFilter);
    const res = await fetch(`/api/v1/complaints?${params}`, { credentials: 'include' });
    const data = await res.json();
    setComplaints(data.data ?? []);
    setTotal(data.total ?? 0);
    setLoading(false);
  };

  useEffect(() => { fetchComplaints(); }, [statusFilter]);

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-text-primary">Complaints</h1>
          <p className="text-sm text-text-secondary mt-1">{total} total</p>
        </div>
        <a href="/portal/complaints/new" className="btn-primary flex items-center gap-2 text-sm">
          <i className="fas fa-plus" aria-hidden="true" />
          New Complaint
        </a>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-2 mb-4">
        {['', 'Open', 'Assigned', 'In_Progress', 'Resolved', 'Closed'].map((s) => (
          <button
            key={s}
            onClick={() => setStatusFilter(s)}
            className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-colors ${
              statusFilter === s
                ? 'bg-primary-600 text-white'
                : 'bg-white border border-border-light text-text-secondary hover:text-text-primary'
            }`}
          >
            {s || 'All'}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-32 text-text-secondary">
          <i className="fas fa-spinner fa-spin mr-2" aria-hidden="true" />
          Loading…
        </div>
      ) : complaints.length === 0 ? (
        <div className="bg-white rounded-xl border border-border-light p-12 text-center">
          <i className="fas fa-check-circle text-4xl text-green-500 mb-3" aria-hidden="true" />
          <p className="text-text-secondary">No complaints found.</p>
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-border-light overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-border-light">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-text-secondary">Ticket</th>
                <th className="px-4 py-3 text-left font-medium text-text-secondary">Title</th>
                <th className="px-4 py-3 text-left font-medium text-text-secondary hidden md:table-cell">Category</th>
                <th className="px-4 py-3 text-left font-medium text-text-secondary hidden md:table-cell">Priority</th>
                <th className="px-4 py-3 text-left font-medium text-text-secondary">Status</th>
                <th className="px-4 py-3 text-left font-medium text-text-secondary hidden lg:table-cell">Date</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border-light">
              {complaints.map((c) => (
                <tr key={c.id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-4 py-3">
                    <a href={`/portal/complaints/${c.id}`} className="text-primary-600 hover:underline font-mono text-xs">
                      {c.ticket_number}
                    </a>
                  </td>
                  <td className="px-4 py-3">
                    <a href={`/portal/complaints/${c.id}`} className="font-medium text-text-primary hover:text-primary-600">
                      {c.title}
                    </a>
                    {c.units && <div className="text-xs text-text-secondary mt-0.5">{c.units.unit_number}</div>}
                  </td>
                  <td className="px-4 py-3 hidden md:table-cell text-text-secondary">{c.category}</td>
                  <td className="px-4 py-3 hidden md:table-cell">
                    <span className="flex items-center gap-1.5">
                      <span className={`w-2 h-2 rounded-full ${PRIORITY_DOT[c.priority] ?? 'bg-gray-400'}`} />
                      {c.priority}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${STATUS_BADGE[c.status] ?? 'bg-gray-100 text-gray-600'}`}>
                      {c.status.replace('_', ' ')}
                    </span>
                  </td>
                  <td className="px-4 py-3 hidden lg:table-cell text-text-secondary text-xs">
                    {new Date(c.created_at).toLocaleDateString('en-IN')}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
