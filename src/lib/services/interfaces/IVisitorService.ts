export type PreApprovalStatus = 'pending' | 'approved' | 'used' | 'expired' | 'cancelled';
export type EntryType = 'pre_approved' | 'walk_in' | 'delivery' | 'service' | 'vendor';

export interface VisitorPreApproval {
  id: string;
  societyId: string;
  hostUnitId: string;
  hostUserId: string;
  visitorName: string;
  purpose: string;
  expectedDate: string;
  expectedTimeFrom: string;
  expectedTimeTo: string;
  qrToken: string;
  status: PreApprovalStatus;
  createdAt: string;
  expiresAt: string;
}

export interface CreatePreApprovalDTO {
  visitorName: string;
  visitorPhone: string;
  purpose: string;
  expectedDate: string;
  expectedTimeFrom: string;
  expectedTimeTo: string;
  unitId: string;
}

export interface VisitorLog {
  id: string;
  societyId: string;
  preApprovalId: string | null;
  visitorName: string;
  hostUnitId: string;
  entryType: EntryType;
  entryTime: string;
  exitTime: string | null;
  vehicleNumber: string | null;
  loggedBy: string;
  createdAt: string;
}

export interface IVisitorService {
  createPreApproval(data: CreatePreApprovalDTO, hostUserId: string, societyId: string): Promise<VisitorPreApproval>;
  cancelPreApproval(id: string, userId: string): Promise<void>;
  logEntry(preApprovalId: string | null, visitorName: string, hostUnitId: string, entryType: EntryType, vehicleNumber: string | null, loggedBy: string, societyId: string): Promise<VisitorLog>;
  logExit(logId: string, actorId: string): Promise<VisitorLog>;
  listPreApprovals(userId: string, societyId: string, role: string): Promise<VisitorPreApproval[]>;
  listLogs(societyId: string, userId: string, role: string, unitId?: string): Promise<VisitorLog[]>;
  validateQRToken(token: string): Promise<VisitorPreApproval>;
}
