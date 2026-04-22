export interface CommitteeMember {
  name: string;
  role: string;
  description: string;
  phone?: string;
  email?: string;
  initials: string;
  colorVariant: 'primary' | 'secondary' | 'accent';
}

export const committeeMembers: CommitteeMember[] = [
  {
    name: 'Rajesh Kumar',
    role: 'President',
    description: 'Leading the association with 8+ years of community service experience. Focused on improving infrastructure and resident welfare.',
    phone: '+91 98765 43210',
    email: 'president@utamacs.org',
    initials: 'RK',
    colorVariant: 'primary',
  },
  {
    name: 'Priya Sharma',
    role: 'Secretary',
    description: 'Managing all administrative functions, correspondence, and meeting minutes. Ensuring smooth operations of the association.',
    phone: '+91 98765 43211',
    email: 'secretary@utamacs.org',
    initials: 'PS',
    colorVariant: 'secondary',
  },
  {
    name: 'Amit Patel',
    role: 'Treasurer',
    description: 'Overseeing financial management, maintenance fund collection, and annual budget planning for community projects.',
    phone: '+91 98765 43212',
    email: 'treasurer@utamacs.org',
    initials: 'AP',
    colorVariant: 'accent',
  },
  {
    name: 'Suresh Reddy',
    role: 'Maintenance Convenor',
    description: 'Coordinating all maintenance activities, vendor management, and infrastructure upkeep across the community.',
    phone: '+91 98765 43213',
    email: 'maintenance@utamacs.org',
    initials: 'SR',
    colorVariant: 'primary',
  },
  {
    name: 'Meera Singh',
    role: 'Events Coordinator',
    description: 'Planning and organizing community events, festivals, and social gatherings that bring residents together.',
    phone: '+91 98765 43214',
    email: 'events@utamacs.org',
    initials: 'MS',
    colorVariant: 'secondary',
  },
  {
    name: 'Vijay Kumar',
    role: 'Member Representative',
    description: 'Acting as the voice of residents, gathering feedback and ensuring member concerns are addressed by the committee.',
    phone: '+91 98765 43215',
    email: 'representative@utamacs.org',
    initials: 'VK',
    colorVariant: 'accent',
  },
];
