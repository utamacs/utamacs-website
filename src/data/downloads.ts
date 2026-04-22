export type DocumentCategory = 'Bylaws' | 'Financial' | 'Maintenance' | 'Forms' | 'Minutes';

export interface Document {
  title: string;
  subtitle: string;
  description: string;
  icon: string;
  updatedDate: string;
  downloadUrl: string;
  category: DocumentCategory;
}

export const documents: Document[] = [
  {
    title: 'Association Bylaws',
    subtitle: 'Version 3.2 – 2024 Edition',
    description: 'The complete governing document of UTA MACS outlining membership rules, committee powers, meeting procedures, and resident rights.',
    icon: 'fa-file-alt',
    updatedDate: 'January 2024',
    downloadUrl: '#',
    category: 'Bylaws',
  },
  {
    title: 'Annual Financial Report 2024',
    subtitle: 'Audited Statement of Accounts',
    description: 'Detailed income and expenditure statement, balance sheet, and auditor\'s report for the financial year 2023-24.',
    icon: 'fa-file-invoice-dollar',
    updatedDate: 'March 2025',
    downloadUrl: '#',
    category: 'Financial',
  },
  {
    title: 'Maintenance Schedule 2025',
    subtitle: 'Annual Planned Maintenance Calendar',
    description: 'Year-round schedule for preventive maintenance of elevators, generators, water tanks, pumps, and common area equipment.',
    icon: 'fa-tools',
    updatedDate: 'January 2025',
    downloadUrl: '#',
    category: 'Maintenance',
  },
  {
    title: 'Resident Registration Form',
    subtitle: 'New Resident Onboarding Package',
    description: 'Required forms for new residents including vehicle registration, visitor pass application, and emergency contact details.',
    icon: 'fa-file-signature',
    updatedDate: 'February 2025',
    downloadUrl: '#',
    category: 'Forms',
  },
  {
    title: 'AGM Minutes – October 2024',
    subtitle: 'Annual General Meeting Proceedings',
    description: 'Official minutes of the Annual General Meeting held on October 20, 2024, including resolutions passed and action items.',
    icon: 'fa-clipboard-list',
    updatedDate: 'November 2024',
    downloadUrl: '#',
    category: 'Minutes',
  },
];
