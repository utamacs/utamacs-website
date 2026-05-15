// Centralized API endpoint definitions — single source of truth
// All API calls must reference these constants; no bare strings in repositories

const BASE = '/api/v1';

export const endpoints = {
  auth: {
    login: `${BASE}/auth/login`,
    signout: `${BASE}/auth/signout`,
    refresh: `${BASE}/auth/refresh`,
    forgotPassword: `${BASE}/auth/forgot-password`,
    resetPassword: `${BASE}/auth/reset-password`,
  },
  mobile: {
    home: `${BASE}/mobile/home`,
  },
  members: {
    me: `${BASE}/members/me`,
    permissions: `${BASE}/members/me/permissions`,
    list: `${BASE}/members`,
    avatar: `${BASE}/members/avatar`,
    consent: `${BASE}/members/consent`,
    byId: (id: string) => `${BASE}/members/${id}`,
    resetPassword: (id: string) => `${BASE}/members/${id}/reset-password`,
    role: (id: string) => `${BASE}/members/${id}/role`,
  },
  complaints: {
    list: `${BASE}/complaints`,
    create: `${BASE}/complaints`,
    byId: (id: string) => `${BASE}/complaints/${id}`,
    status: (id: string) => `${BASE}/complaints/${id}/status`,
    comments: (id: string) => `${BASE}/complaints/${id}/comments`,
    attachments: (id: string) => `${BASE}/complaints/${id}/attachments`,
    rating: (id: string) => `${BASE}/complaints/${id}/rating`,
    subCategories: `${BASE}/complaints/sub-categories`,
  },
  finance: {
    dues: `${BASE}/finance/dues`,
    ledger: `${BASE}/finance/ledger`,
    payments: `${BASE}/finance/payments`,
    receipt: (id: string) => `${BASE}/finance/payments/${id}/receipt`,
    expenses: `${BASE}/finance/expenses`,
  },
  visitors: {
    passes: `${BASE}/visitors/passes`,
    preApprovals: `${BASE}/visitors/pre-approvals`,
    logs: `${BASE}/visitors/logs`,
    logExit: (id: string) => `${BASE}/visitors/logs/${id}/exit`,
    deliveries: `${BASE}/visitors/deliveries`,
    collectDelivery: (id: string) => `${BASE}/visitors/deliveries/${id}/collect`,
    gateRequests: `${BASE}/visitors/gate-requests`,
    gateRequestById: (id: string) => `${BASE}/visitors/gate-requests/${id}`,
    verify: `${BASE}/visitors/verify`,
    gates: `${BASE}/visitors/gates`,
  },
  facilities: {
    list: `${BASE}/facilities`,
    bookings: `${BASE}/facilities/bookings`,
    availability: (id: string) => `${BASE}/facilities/${id}/availability`,
    cancelBooking: (id: string) => `${BASE}/facilities/bookings/${id}/cancel`,
  },
  notifications: {
    list: `${BASE}/notifications`,
    markRead: `${BASE}/notifications/mark-read`,
    preferences: `${BASE}/notifications/preferences`,
    pushRegister: `${BASE}/notifications/push/register`,
    pushDeregister: `${BASE}/notifications/push/deregister`,
  },
  community: {
    posts: `${BASE}/community/posts`,
    postById: (id: string) => `${BASE}/community/posts/${id}`,
    comments: (id: string) => `${BASE}/community/posts/${id}/comments`,
    react: (id: string) => `${BASE}/community/posts/${id}/react`,
    images: (id: string) => `${BASE}/community/posts/${id}/images`,
    marketplace: `${BASE}/community/marketplace`,
    marketplaceById: (id: string) => `${BASE}/community/marketplace/${id}`,
    reports: `${BASE}/community/reports`,
  },
  polls: {
    list: `${BASE}/polls`,
    byId: (id: string) => `${BASE}/polls/${id}`,
    vote: (id: string) => `${BASE}/polls/${id}/vote`,
    results: (id: string) => `${BASE}/polls/${id}/results`,
  },
  events: {
    list: `${BASE}/events`,
    byId: (id: string) => `${BASE}/events/${id}`,
    register: (id: string) => `${BASE}/events/${id}/register`,
  },
  parking: {
    slots: `${BASE}/parking/slots`,
    allocations: `${BASE}/parking/allocations`,
    releaseAllocation: (id: string) => `${BASE}/parking/allocations/${id}/release`,
    transfers: `${BASE}/parking/transfers`,
    waitlist: `${BASE}/parking/waitlist`,
  },
  gallery: {
    albums: `${BASE}/gallery/albums`,
  },
  documents: {
    list: `${BASE}/documents`,
    byId: (id: string) => `${BASE}/documents/${id}`,
    history: (id: string) => `${BASE}/documents/${id}/history`,
  },
  notices: {
    list: `${BASE}/notices`,
    byId: (id: string) => `${BASE}/notices/${id}`,
  },
  maids: {
    list: `${BASE}/maids`,
    byId: (id: string) => `${BASE}/maids/${id}`,
    attendance: `${BASE}/maids/attendance`,
    approvals: `${BASE}/maids/approvals`,
  },
  vendors: {
    list: `${BASE}/vendors`,
    workOrders: `${BASE}/vendors/work-orders`,
    workOrderById: (id: string) => `${BASE}/vendors/work-orders/${id}`,
  },
  hoto: {
    items: `${BASE}/hoto/items`,
    itemById: (id: string) => `${BASE}/hoto/items/${id}`,
    snags: `${BASE}/hoto/snags`,
    snagById: (id: string) => `${BASE}/hoto/snags/${id}`,
  },
  waterTankers: {
    list: `${BASE}/water-tankers`,
  },
  securityPatrol: {
    list: `${BASE}/security-patrol`,
  },
  health: `${BASE}/health`,
} as const;
