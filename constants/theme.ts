import { Platform } from "react-native";

export const colors = {
  background: "#f7f9fc",
  surface: "#ffffff",
  surfaceElevated: "#ffffff",
  surfaceMuted: "#f8f9fc",
  text: "#0b1e33",
  textMuted: "#64748b",
  border: "#e2e8f0",
  accent: "#1e293b",
  accentStrong: "#0b1e33",
  accentSoft: "#eef2ff",
  accentText: "#ffffff",
  success: "#16a34a",
  successSoft: "rgba(22,163,74,0.10)",
  warning: "#f59e0b",
  warningSoft: "rgba(245,158,11,0.12)",
  danger: "#ef4444",
  dangerSoft: "rgba(239,68,68,0.10)",
  info: "#94a3b8",
  infoSoft: "rgba(148,163,184,0.10)",
  muted: "#94a3b8",
};

export const spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
};

export const radius = {
  sm: 12,
  md: 18,
  lg: 24,
  xl: 32,
};

export const shadows = {
  soft: {
    shadowColor: "#000000",
    shadowOpacity: 0.05,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 8 },
    elevation: 2,
  },
  card: {
    shadowColor: "#000000",
    shadowOpacity: 0.08,
    shadowRadius: 24,
    shadowOffset: { width: 0, height: 12 },
    elevation: 4,
  },
};

export const fonts = {
  display: Platform.select({
    ios: "SF Pro Display",
    android: "sans-serif-medium",
    default: '"Inter", "Segoe UI", system-ui, sans-serif',
  }),
  text: Platform.select({
    ios: "SF Pro Text",
    android: "sans-serif",
    default: '"Inter", "Segoe UI", system-ui, sans-serif',
  }),
  label: Platform.select({
    ios: "SF Pro Display",
    android: "sans-serif-medium",
    default: '"Inter", "Segoe UI", system-ui, sans-serif',
  }),
};

export const typography = {
  heroSize: 24,
  heroLineHeight: 30,
  display: {
    fontFamily: fonts.display,
    fontWeight: "700" as const,
    letterSpacing: -0.02,
  },
  title: {
    fontFamily: fonts.display,
    fontWeight: "600" as const,
    letterSpacing: -0.01,
  },
  body: {
    fontFamily: fonts.text,
    fontWeight: "500" as const,
    letterSpacing: 0,
  },
  label: {
    fontFamily: fonts.label,
    fontWeight: "600" as const,
    letterSpacing: 0.3,
  },
  button: {
    fontFamily: fonts.label,
    fontWeight: "600" as const,
    letterSpacing: 0,
  },
};
