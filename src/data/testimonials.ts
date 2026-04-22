export interface Testimonial {
  name: string;
  initials: string;
  residentSince: string;
  quote: string;
  colorVariant: 'primary' | 'secondary' | 'accent';
}

export const testimonials: Testimonial[] = [
  {
    name: 'Ananya Krishnan',
    initials: 'AK',
    residentSince: 'Resident since 2019',
    quote: 'The association has truly transformed our community. From prompt maintenance responses to beautifully organized festivals, living here feels like being part of one big family. The new online portal makes everything so convenient.',
    colorVariant: 'primary',
  },
  {
    name: 'Ravi Teja Namburu',
    initials: 'RT',
    residentSince: 'Resident since 2021',
    quote: 'I was worried about community engagement when I moved in, but the committee\'s dedication blew me away. Regular events, transparent finances, and quick resolution of issues — this is how all apartment associations should operate.',
    colorVariant: 'secondary',
  },
  {
    name: 'Lakshmi Devi',
    initials: 'LD',
    residentSince: 'Resident since 2018',
    quote: 'As a senior resident, I appreciate how the committee considers everyone\'s needs. The 24/7 security, well-maintained common areas, and regular health camps make this a truly safe and caring place to call home.',
    colorVariant: 'accent',
  },
];
