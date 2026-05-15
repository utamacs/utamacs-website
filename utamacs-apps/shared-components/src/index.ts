// @utamacs/shared — Public API
// All consumers import from this barrel file

// Design System
export * from './design/tokens';
export * from './design/theme';

// API Client
export { apiClient, createApiClient } from './api/client';
export * from './api/endpoints';

// Repositories
export { AuthRepository } from './repositories/auth/AuthRepository';
export { ComplaintsRepository } from './repositories/complaints/ComplaintsRepository';
export { FinanceRepository } from './repositories/finance/FinanceRepository';
export { MembersRepository } from './repositories/members/MembersRepository';
export { NotificationsRepository } from './repositories/notifications/NotificationsRepository';
export { VisitorsRepository } from './repositories/visitors/VisitorsRepository';
export { FacilitiesRepository } from './repositories/facilities/FacilitiesRepository';
export { CommunityRepository } from './repositories/community/CommunityRepository';
export { PollsRepository } from './repositories/polls/PollsRepository';

// Use Cases
export { LoginUseCase } from './usecases/auth/LoginUseCase';
export { LogoutUseCase } from './usecases/auth/LogoutUseCase';
export { CheckPermissionUseCase } from './usecases/permissions/CheckPermissionUseCase';
export { QueueMutationUseCase } from './usecases/offline/QueueMutationUseCase';
export { ReplayOfflineQueueUseCase } from './usecases/offline/ReplayOfflineQueueUseCase';
export { RegisterPushTokenUseCase } from './usecases/notifications/RegisterPushTokenUseCase';

// Analytics
export { track } from './analytics/tracker';
export type { AnalyticsEvent } from './analytics/events';

// Utils
export { formatINR, formatAmount } from './utils/currency';
export { formatDate, formatDateTime, formatRelative } from './utils/date';
export { formatPhone, maskPhone, validateIndianPhone } from './utils/phone';
export { isValidUUID, isValidEmail } from './utils/validation';

// Types
export type * from './types/api.types';
export type * from './types/navigation.types';
