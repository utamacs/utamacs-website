// Design tokens — mirrors tailwind.config.cjs tokens for native mobile use
// All values from the web portal's design system, adapted for React Native

export const colors = {
  primary: {
    50: '#EFF6FF',
    100: '#DBEAFE',
    200: '#BFDBFE',
    600: '#1E3A8A',
    700: '#1E40AF',
    800: '#1E3A8A',
  },
  secondary: {
    50: '#ECFDF5',
    100: '#D1FAE5',
    500: '#10B981',
    600: '#059669',
  },
  accent: {
    50: '#FFFBEB',
    100: '#FEF3C7',
    500: '#F59E0B',
    600: '#D97706',
  },
  red: {
    50: '#FEF2F2',
    100: '#FEE2E2',
    500: '#EF4444',
    600: '#DC2626',
    700: '#B91C1C',
  },
  amber: {
    50: '#FFFBEB',
    500: '#F59E0B',
    600: '#D97706',
  },
  blue: {
    50: '#EFF6FF',
    500: '#3B82F6',
  },
  text: {
    primary: '#111827',
    secondary: '#4B5563',
    muted: '#9CA3AF',
    inverse: '#FFFFFF',
  },
  background: {
    primary: '#FFFFFF',
    secondary: '#F8FAFC',
    tertiary: '#F3F4F6',
  },
  border: {
    light: '#E5E7EB',
    medium: '#D1D5DB',
  },
  dark: {
    background: {
      primary: '#111827',
      secondary: '#1F2937',
      tertiary: '#374151',
    },
    text: {
      primary: '#F9FAFB',
      secondary: '#D1D5DB',
      muted: '#9CA3AF',
    },
    border: {
      light: '#374151',
      medium: '#4B5563',
    },
  },
} as const;

export const typography = {
  fontFamily: {
    display: 'Poppins-Bold',
    displaySemiBold: 'Poppins-SemiBold',
    body: 'Inter-Regular',
    medium: 'Inter-Medium',
    semiBold: 'Inter-SemiBold',
    bold: 'Inter-Bold',
  },
  // Scale in points/dp (React Native uses pt on iOS, dp on Android — system scales with DPI)
  size: {
    xs: 11,
    sm: 13,
    base: 15,
    md: 15,
    lg: 17,
    xl: 19,
    '2xl': 22,
    '3xl': 28,
    '4xl': 34,
  },
  lineHeight: {
    xs: 16,
    sm: 18,
    base: 22,
    lg: 24,
    xl: 26,
    '2xl': 30,
    '3xl': 36,
  },
} as const;

export const spacing = {
  0: 0,
  0.5: 2,
  1: 4,
  1.5: 6,
  2: 8,
  3: 12,
  4: 16,
  5: 20,
  6: 24,
  8: 32,
  10: 40,
  12: 48,
  16: 64,
} as const;

export const radius = {
  none: 0,
  sm: 6,
  md: 8,
  lg: 12,
  xl: 16,
  '2xl': 20,
  full: 9999,
} as const;

export const shadow = {
  none: {
    shadowColor: 'transparent',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0,
    shadowRadius: 0,
    elevation: 0,
  },
  soft: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 4,
    elevation: 2,
  },
  medium: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 4,
  },
  large: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.15,
    shadowRadius: 16,
    elevation: 8,
  },
} as const;

// Minimum touch target — Apple HIG: 44pt; Material: 48dp
export const minTouchTarget = 44 as const;
