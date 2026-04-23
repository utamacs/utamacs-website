export type ComplaintStatus =
  | 'Open' | 'Assigned' | 'In_Progress' | 'Waiting_for_User'
  | 'Resolved' | 'Closed' | 'Reopened';

export type ComplaintPriority = 'Low' | 'Medium' | 'High' | 'Critical';

export interface Complaint {
  id: string;
  societyId: string;
  ticketNumber: string;
  title: string;
  description: string;
  category: string;
  priority: ComplaintPriority;
  status: ComplaintStatus;
  raisedBy: string;
  assignedTo: string | null;
  unitId: string;
  slaHours: number;
  slaDeadline: string;
  resolvedAt: string | null;
  closedAt: string | null;
  reopenCount: number;
  createdAt: string;
  updatedAt: string;
}

export interface CreateComplaintDTO {
  title: string;
  description: string;
  category: string;
  priority?: ComplaintPriority;
  unitId: string;
}

export interface ComplaintFilters {
  societyId: string;
  status?: ComplaintStatus | ComplaintStatus[];
  category?: string;
  priority?: ComplaintPriority;
  assignedTo?: string;
  page?: number;
  limit?: number;
}

export interface Paginated<T> {
  data: T[];
  total: number;
  page: number;
  limit: number;
}

export interface ComplaintComment {
  id: string;
  complaintId: string;
  userId: string;
  comment: string;
  isInternal: boolean;
  createdAt: string;
}

export interface IComplaintService {
  create(data: CreateComplaintDTO, actorId: string, societyId: string): Promise<Complaint>;
  getById(id: string, requesterId: string, role: string): Promise<Complaint>;
  list(filters: ComplaintFilters, requesterId: string, role: string): Promise<Paginated<Complaint>>;
  updateStatus(id: string, status: ComplaintStatus, note: string, actorId: string): Promise<Complaint>;
  assign(id: string, assigneeId: string, actorId: string): Promise<Complaint>;
  addComment(id: string, body: string, isInternal: boolean, actorId: string): Promise<ComplaintComment>;
  addAttachment(id: string, storageKey: string, fileName: string, mimeType: string, fileSize: number, uploaderId: string): Promise<void>;
}
