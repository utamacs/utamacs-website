// Typed analytics event registry — exhaustive catalog of all trackable events
// All analytics calls must use events from this file; no bare event name strings

export type AnalyticsEvent =
  // Auth
  | { name: 'login_attempted'; properties: { method: 'password' | 'otp' | 'biometric' } }
  | { name: 'login_succeeded'; properties: { method: 'password' | 'otp' | 'biometric' } }
  | { name: 'login_failed'; properties: { method: 'password' | 'otp'; reason: string } }
  | { name: 'logout'; properties: Record<string, never> }
  | { name: 'biometric_enrolled'; properties: Record<string, never> }
  // Complaints
  | { name: 'complaint_list_viewed'; properties: { filter: string } }
  | { name: 'complaint_detail_viewed'; properties: { complaint_id: string; status: string } }
  | { name: 'complaint_create_started'; properties: Record<string, never> }
  | { name: 'complaint_created'; properties: { category: string; has_attachment: boolean } }
  | { name: 'complaint_attachment_added'; properties: { source: 'camera' | 'gallery' } }
  | { name: 'complaint_rated'; properties: { rating: number } }
  // Finance
  | { name: 'finance_viewed'; properties: { tab: 'dues' | 'ledger' | 'expenses' } }
  | { name: 'payment_recorded'; properties: { amount_bucket: string; mode: string } }
  | { name: 'receipt_downloaded'; properties: Record<string, never> }
  // Visitors
  | { name: 'visitor_pass_create_started'; properties: Record<string, never> }
  | { name: 'visitor_pass_created'; properties: { duration_hours: number; type: string } }
  | { name: 'visitor_pass_shared'; properties: { method: 'image' | 'code' | 'link' } }
  | { name: 'gate_request_received'; properties: Record<string, never> }
  | { name: 'gate_request_approved'; properties: { response_time_seconds: number } }
  | { name: 'gate_request_rejected'; properties: { response_time_seconds: number } }
  | { name: 'gate_request_expired'; properties: Record<string, never> }
  | { name: 'qr_scan_started'; properties: Record<string, never> }
  | { name: 'qr_scanned'; properties: { result: 'valid' | 'expired' | 'invalid' | 'error' } }
  // Notifications
  | { name: 'notification_received'; properties: { type: string } }
  | { name: 'notification_opened'; properties: { type: string; latency_seconds: number } }
  | { name: 'notification_dismissed'; properties: { type: string } }
  // Community
  | { name: 'community_post_viewed'; properties: { post_id: string } }
  | { name: 'community_post_created'; properties: { has_images: boolean; image_count: number } }
  | { name: 'community_post_reacted'; properties: { reaction: string } }
  // Facilities
  | { name: 'facility_list_viewed'; properties: Record<string, never> }
  | { name: 'facility_booking_started'; properties: { facility_id: string } }
  | { name: 'facility_booked'; properties: { facility_id: string; duration_hours: number } }
  | { name: 'facility_booking_cancelled'; properties: Record<string, never> }
  // Polls
  | { name: 'poll_viewed'; properties: { poll_id: string } }
  | { name: 'poll_voted'; properties: { poll_id: string } }
  // Navigation
  | { name: 'screen_viewed'; properties: { screen_name: string; role: string } }
  | { name: 'tab_switched'; properties: { tab: string } }
  | { name: 'module_accessed'; properties: { module: string } }
  // Offline
  | { name: 'offline_queue_added'; properties: { endpoint: string } }
  | { name: 'offline_queue_replayed'; properties: { count: number; failed: number } }
  // Errors
  | { name: 'api_error'; properties: { endpoint: string; status: number; code: string } }
  | { name: 'crash_recovered'; properties: { screen: string } };

export type EventName = AnalyticsEvent['name'];
export type EventProperties<T extends EventName> = Extract<AnalyticsEvent, { name: T }>['properties'];
