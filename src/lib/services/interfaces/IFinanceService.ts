export type DueStatus = 'pending' | 'partially_paid' | 'paid' | 'overdue' | 'waived';
export type PaymentMode = 'cash' | 'cheque' | 'upi' | 'neft' | 'rtgs' | 'online';

export interface MaintenanceDue {
  id: string;
  societyId: string;
  unitId: string;
  userId: string;
  billingPeriodId: string;
  baseAmount: number;
  penaltyAmount: number;
  gstAmount: number;
  totalAmount: number;
  status: DueStatus;
  dueDate: string;
  paidAt: string | null;
}

export interface Payment {
  id: string;
  societyId: string;
  duesId: string;
  userId: string;
  amount: number;
  paymentMode: PaymentMode;
  transactionRef: string | null;
  receiptNumber: string;
  gstInvoiceNo: string | null;
  tdsDeducted: number;
  recordedBy: string;
  paidAt: string;
  createdAt: string;
}

export interface RecordPaymentDTO {
  duesId: string;
  amount: number;
  paymentMode: PaymentMode;
  transactionRef?: string;
  paidAt: string;
  tdsDeducted?: number;
}

export interface FinanceSummary {
  totalDues: number;
  collectedAmount: number;
  pendingAmount: number;
  collectionRate: number;
  overdueCount: number;
  totalExpenses: number;
}

export interface IFinanceService {
  getDues(societyId: string, userId: string, role: string): Promise<MaintenanceDue[]>;
  getDueById(id: string, requesterId: string, role: string): Promise<MaintenanceDue>;
  recordPayment(data: RecordPaymentDTO, recordedBy: string, societyId: string): Promise<Payment>;
  getPaymentReceipt(paymentId: string, requesterId: string, role: string): Promise<string>;
  getSummary(societyId: string): Promise<FinanceSummary>;
  generateGSTInvoice(paymentId: string, actorId: string): Promise<string>;
}
