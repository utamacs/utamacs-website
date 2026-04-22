export interface Event {
  title: string;
  description: string;
  date: string;
  time: string;
  location: string;
  registrationUrl?: string;
  isPast: boolean;
}

export const events: Event[] = [
  {
    title: 'Annual General Meeting 2025',
    description: 'The Annual General Meeting where committee reports will be presented, financial statements reviewed, and elections held for the next term.',
    date: 'April 30, 2025',
    time: '6:00 PM – 8:00 PM',
    location: 'Community Hall, UTA MACS',
    isPast: false,
  },
  {
    title: 'Children\'s Summer Camp',
    description: 'A fun-filled 5-day summer camp for children aged 6-16 featuring sports, arts & crafts, coding workshops, and team-building activities.',
    date: 'May 5 – May 9, 2025',
    time: '9:00 AM – 1:00 PM',
    location: 'Clubhouse & Outdoor Courts',
    registrationUrl: '#',
    isPast: false,
  },
  {
    title: 'Community Clean-Up Drive',
    description: 'Join hands with fellow residents to keep our community clean and green. Cleaning supplies will be provided. Refreshments for all volunteers.',
    date: 'April 27, 2025',
    time: '7:00 AM – 10:00 AM',
    location: 'Meet at Main Gate',
    isPast: false,
  },
  {
    title: 'Yoga & Wellness Workshop',
    description: 'A morning wellness workshop led by certified yoga instructors. Open to all residents. Bring your own mat. Limited spots available.',
    date: 'May 11, 2025',
    time: '6:30 AM – 8:00 AM',
    location: 'Open-Air Amphitheater',
    registrationUrl: '#',
    isPast: false,
  },
  {
    title: 'Ugadi Celebrations 2025',
    description: 'Grand Ugadi celebration with cultural performances, traditional feast, games for kids, and a community bonding evening for all residents and families.',
    date: 'March 30, 2025',
    time: '5:00 PM – 9:00 PM',
    location: 'Community Amphitheater',
    isPast: true,
  },
  {
    title: 'Sports Day – Cricket & Badminton',
    description: 'Inter-block cricket and badminton tournament. Teams from all blocks competed in friendly matches with prizes for the winners.',
    date: 'March 16, 2025',
    time: '8:00 AM – 5:00 PM',
    location: 'Sports Complex',
    isPast: true,
  },
  {
    title: 'Safety & Emergency Preparedness Workshop',
    description: 'Workshop on fire safety, first aid, and emergency evacuation procedures conducted by city fire department officials.',
    date: 'February 22, 2025',
    time: '10:00 AM – 12:00 PM',
    location: 'Community Hall',
    isPast: true,
  },
];
