import { Platform } from "react-native";

export const colors = {
  background: "#000000",
  surface: "#050505",
  surfaceElevated: "#0B0B0B",
  surfaceMuted: "#141414",
  text: "#FFFFFF",
  textMuted: "#B3B3B3",
  border: "#1F1F1F",
  accent: "#E50914",
  accentDark: "#B20710",
  accentSoft: "rgba(229,9,20,0.12)",
  accentText: "#FFFFFF",
  success: "#46D369",
  successSoft: "rgba(70,211,105,0.11)",
  warning: "#F5C518",
  warningSoft: "rgba(245,197,24,0.12)",
  danger: "#E50914",
  dangerSoft: "rgba(229,9,20,0.12)",
  info: "#B3B3B3",
  infoSoft: "#101010",
  muted: "#6E6E6E",
};

export const spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
};

export const radius = {
  md: 8,
  lg: 8,
  xl: 8,
};

export const shadows = {
  soft: {
    shadowColor: "#000000",
    shadowOpacity: 0.34,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 3 },
    elevation: 1,
  },
  card: {
    shadowColor: "#000000",
    shadowOpacity: 0.38,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 6 },
    elevation: 2,
  },
};

export const fonts = {
  display: Platform.select({
    ios: "Avenir Next",
    android: "sans-serif-medium",
    default: '"Inter", "SF Pro Display", "Segoe UI", system-ui, sans-serif',
  }),
  text: Platform.select({
    ios: "Avenir Next",
    android: "sans-serif",
    default: '"Inter", "Segoe UI", system-ui, sans-serif',
  }),
  label: Platform.select({
    ios: "Avenir Next",
    android: "sans-serif-medium",
    default: '"Inter", "Segoe UI", system-ui, sans-serif',
  }),
};

export const typography = {
  heroSize: 24,
  heroLineHeight: 30,
  display: {
    fontFamily: fonts.display,
    fontWeight: "800" as const,
    letterSpacing: 0,
  },
  title: {
    fontFamily: fonts.display,
    fontWeight: "800" as const,
    letterSpacing: 0,
  },
  body: {
    fontFamily: fonts.text,
    fontWeight: "500" as const,
    letterSpacing: 0,
  },
  label: {
    fontFamily: fonts.label,
    fontWeight: "700" as const,
    letterSpacing: 0,
  },
  button: {
    fontFamily: fonts.label,
    fontWeight: "800" as const,
    letterSpacing: 0,
  },
};
