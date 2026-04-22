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
    name: 'Sri K. Bal Reddy',
    role: 'President',
    description: 'Leading the association with a focus on community welfare, infrastructure, and transparent governance for all residents.',
    email: 'president@utamacs.org',
    initials: 'KR',
    colorVariant: 'primary',
  },
  {
    name: 'Smt. Rama Ananth',
    role: 'Working President',
    description: 'Overseeing day-to-day operations of the association and coordinating between all committee members and residents.',
    email: 'workingpresident@utamacs.org',
    initials: 'RA',
    colorVariant: 'secondary',
  },
  {
    name: 'Sri T V Subramanyam',
    role: 'Vice President',
    description: 'Supporting the President in all administrative matters and representing the association in official capacities.',
    initials: 'TS',
    colorVariant: 'accent',
  },
  {
    name: 'Sri Prashanth',
    role: 'General Secretary',
    description: 'Managing all administrative functions, correspondence, meeting minutes, and ensuring smooth operations of the association.',
    email: 'secretary@utamacs.org',
    initials: 'PR',
    colorVariant: 'primary',
  },
  {
    name: 'Sri Suresh Kumar',
    role: 'Treasurer',
    description: 'Overseeing financial management, maintenance fund collection, and annual budget planning for community projects.',
    email: 'treasurer@utamacs.org',
    initials: 'SK',
    colorVariant: 'secondary',
  },
  {
    name: 'Sri Eaga Rajesh Reddy',
    role: 'Joint Secretary',
    description: 'Assisting the General Secretary in administrative duties and managing communications with residents.',
    initials: 'ER',
    colorVariant: 'accent',
  },
  {
    name: 'Sri Dande Nitin',
    role: 'Organising Secretary',
    description: 'Planning and coordinating community events, meetings, and organizational activities across the society.',
    initials: 'DN',
    colorVariant: 'primary',
  },
  {
    name: 'Smt. Geetha Nambiar',
    role: 'Cultural Secretary',
    description: 'Organizing cultural programs, festivals, and social activities that celebrate diversity and build community bonds.',
    initials: 'GN',
    colorVariant: 'secondary',
  },
];

export const executiveMembers: CommitteeMember[] = [
  {
    name: 'Sri Geerish Kumar',
    role: 'Maintenance & Club House',
    description: 'Responsible for maintenance of common areas and club house facilities across the community.',
    initials: 'GK',
    colorVariant: 'primary',
  },
  {
    name: 'Sri Praseed K. V.',
    role: 'WTP & STP',
    description: 'Overseeing the water treatment plant (WTP) and sewage treatment plant (STP) operations.',
    initials: 'PK',
    colorVariant: 'secondary',
  },
  {
    name: 'Smt. Jhansi',
    role: 'Temple & Play Area',
    description: 'Managing the temple facilities and play area maintenance for children and residents.',
    initials: 'JH',
    colorVariant: 'accent',
  },
  {
    name: 'Smt. G. Sindhu',
    role: 'Games',
    description: 'Coordinating sports and games activities, tournaments, and recreational programs for residents.',
    initials: 'GS',
    colorVariant: 'primary',
  },
  {
    name: 'Sri Sharath Chandra',
    role: 'Security',
    description: 'Overseeing security arrangements, CCTV operations, and safety protocols across the community.',
    initials: 'SC',
    colorVariant: 'secondary',
  },
  {
    name: 'Sri D. Harsha',
    role: 'Executive Member',
    description: 'Supporting the committee in community development initiatives and resident welfare programs.',
    initials: 'DH',
    colorVariant: 'accent',
  },
];
