// Date/time utilities — all display in IST (Asia/Kolkata, UTC+5:30)
// The server stores all timestamps as UTC in the database

const IST = 'Asia/Kolkata';

const DATE_FORMATTER = new Intl.DateTimeFormat('en-IN', { timeZone: IST, day: '2-digit', month: 'short', year: 'numeric' });
const TIME_FORMATTER = new Intl.DateTimeFormat('en-IN', { timeZone: IST, hour: '2-digit', minute: '2-digit', hour12: true });
const DATETIME_FORMATTER = new Intl.DateTimeFormat('en-IN', { timeZone: IST, day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit', hour12: true });

export const formatDate = (iso: string | null | undefined): string => {
  if (!iso) return '—';
  try { return DATE_FORMATTER.format(new Date(iso)); }
  catch { return '—'; }
};

export const formatTime = (iso: string | null | undefined): string => {
  if (!iso) return '—';
  try { return TIME_FORMATTER.format(new Date(iso)); }
  catch { return '—'; }
};

export const formatDateTime = (iso: string | null | undefined): string => {
  if (!iso) return '—';
  try { return DATETIME_FORMATTER.format(new Date(iso)); }
  catch { return '—'; }
};

export const formatRelative = (iso: string | null | undefined): string => {
  if (!iso) return '—';
  try {
    const now = Date.now();
    const then = new Date(iso).getTime();
    const diff = now - then;
    if (diff < 60_000) return 'just now';
    if (diff < 3_600_000) return `${Math.floor(diff / 60_000)}m ago`;
    if (diff < 86_400_000) return `${Math.floor(diff / 3_600_000)}h ago`;
    if (diff < 604_800_000) return `${Math.floor(diff / 86_400_000)}d ago`;
    return formatDate(iso);
  } catch { return '—'; }
};

export const isOverdue = (dueDateIso: string): boolean =>
  new Date(dueDateIso).getTime() < Date.now();

export const daysUntil = (iso: string): number =>
  Math.ceil((new Date(iso).getTime() - Date.now()) / 86_400_000);
