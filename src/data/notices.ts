export type NoticeCategory = 'Important' | 'General' | 'Maintenance' | 'Events' | 'Financial';

export interface Notice {
  title: string;
  excerpt: string;
  date: string;
  category: NoticeCategory;
  downloadUrl?: string;
}

export const notices: Notice[] = [
  {
    title: 'Annual General Meeting – April 2025',
    excerpt: 'The Annual General Meeting of UTA MACS is scheduled for April 30, 2025 at 6:00 PM in the Community Hall. Attendance is mandatory for all flat owners.',
    date: 'April 10, 2025',
    category: 'Important',
    downloadUrl: '#',
  },
  {
    title: 'Maintenance Fund Collection – Q2 2025',
    excerpt: 'Quarterly maintenance dues of ₹5,000 per flat are due by April 15, 2025. Payments can be made via bank transfer or at the association office.',
    date: 'April 1, 2025',
    category: 'Financial',
    downloadUrl: '#',
  },
  {
    title: 'Elevator Maintenance – Blocks A & B',
    excerpt: 'Scheduled elevator maintenance for Blocks A and B will take place on April 20, 2025 from 9:00 AM to 1:00 PM. Please plan accordingly.',
    date: 'March 28, 2025',
    category: 'Maintenance',
  },
  {
    title: 'Ugadi Celebrations – Community Event',
    excerpt: 'Join us for a grand Ugadi celebration on March 30, 2025 at the community amphitheater. Cultural programs, traditional feast, and fun activities for all ages.',
    date: 'March 20, 2025',
    category: 'Events',
  },
  {
    title: 'Updated Parking Policy',
    excerpt: 'New parking regulations are in effect from April 1, 2025. All residents must register their vehicles with the association office by March 31, 2025.',
    date: 'March 15, 2025',
    category: 'General',
    downloadUrl: '#',
  },
  {
    title: 'Water Supply Disruption – March 25',
    excerpt: 'Water supply will be interrupted on March 25, 2025 from 8:00 AM to 4:00 PM due to pipeline maintenance work. Please store adequate water in advance.',
    date: 'March 22, 2025',
    category: 'Maintenance',
  },
  {
    title: 'Security Camera Installation Complete',
    excerpt: 'The installation of 32 new CCTV cameras across all entry/exit points and common areas has been completed. The community is now under 24/7 surveillance.',
    date: 'March 10, 2025',
    category: 'General',
  },
];
