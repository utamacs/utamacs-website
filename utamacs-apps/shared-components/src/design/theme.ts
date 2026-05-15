import { colors, typography, spacing, radius, shadow } from './tokens';

export type ThemeMode = 'light' | 'dark';

export const lightTheme = {
  mode: 'light' as ThemeMode,
  colors: {
    primary: colors.primary[600],
    primaryLight: colors.primary[50],
    secondary: colors.secondary[500],
    secondaryLight: colors.secondary[50],
    accent: colors.accent[500],
    accentLight: colors.accent[50],
    danger: colors.red[600],
    dangerLight: colors.red[50],
    warning: colors.amber[500],
    warningLight: colors.amber[50],
    background: colors.background.primary,
    backgroundSecondary: colors.background.secondary,
    backgroundTertiary: colors.background.tertiary,
    surface: colors.background.primary,
    text: colors.text.primary,
    textSecondary: colors.text.secondary,
    textMuted: colors.text.muted,
    textInverse: colors.text.inverse,
    border: colors.border.light,
    borderMedium: colors.border.medium,
  },
  typography,
  spacing,
  radius,
  shadow,
};

export const darkTheme: typeof lightTheme = {
  mode: 'dark',
  colors: {
    primary: colors.primary[200],
    primaryLight: colors.primary[800],
    secondary: colors.secondary[500],
    secondaryLight: colors.secondary[100],
    accent: colors.accent[500],
    accentLight: colors.accent[100],
    danger: colors.red[500],
    dangerLight: colors.red[100],
    warning: colors.amber[500],
    warningLight: colors.amber[50],
    background: colors.dark.background.primary,
    backgroundSecondary: colors.dark.background.secondary,
    backgroundTertiary: colors.dark.background.tertiary,
    surface: colors.dark.background.secondary,
    text: colors.dark.text.primary,
    textSecondary: colors.dark.text.secondary,
    textMuted: colors.dark.text.muted,
    textInverse: colors.text.primary,
    border: colors.dark.border.light,
    borderMedium: colors.dark.border.medium,
  },
  typography,
  spacing,
  radius,
  shadow,
};

export type Theme = typeof lightTheme;
