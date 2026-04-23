export type BookingStatus =
  | 'pending' | 'confirmed' | 'in_use' | 'completed' | 'cancelled' | 'no_show';

export interface Facility {
  id: string;
  societyId: string;
  name: string;
  description: string | null;
  capacity: number;
  amenities: string[];
  bookingFee: number;
  depositAmount: number;
  isActive: boolean;
  advanceBookingDays: number;
  cancellationHoursFree: number;
}

export interface FacilityAvailability {
  date: string;
  slots: Array<{
    startTime: string;
    endTime: string;
    isAvailable: boolean;
  }>;
}

export interface FacilityBooking {
  id: string;
  societyId: string;
  facilityId: string;
  userId: string;
  unitId: string;
  bookingDate: string;
  startTime: string;
  endTime: string;
  attendeesCount: number;
  purpose: string;
  status: BookingStatus;
  feeCharged: number;
  depositPaid: number;
  depositRefunded: boolean;
  createdAt: string;
}

export interface CreateBookingDTO {
  facilityId: string;
  bookingDate: string;
  startTime: string;
  endTime: string;
  attendeesCount: number;
  purpose: string;
  unitId: string;
}

export interface IFacilityService {
  listFacilities(societyId: string): Promise<Facility[]>;
  getAvailability(facilityId: string, date: string): Promise<FacilityAvailability>;
  createBooking(data: CreateBookingDTO, userId: string, societyId: string): Promise<FacilityBooking>;
  cancelBooking(bookingId: string, reason: string, actorId: string, role: string): Promise<FacilityBooking>;
  listBookings(societyId: string, userId: string, role: string): Promise<FacilityBooking[]>;
}
