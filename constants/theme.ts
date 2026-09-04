import AsyncStorage from "@react-native-async-storage/async-storage";
import React, { createContext, useContext, useEffect, useMemo, useState } from "react";
import { Platform, useColorScheme } from "react-native";

export type ThemeMode = "light" | "dark";

const lightPalette = {
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

const darkPalette = {
  background: "#020b14",
  surface: "#0b1622",
  surfaceElevated: "#122334",
  surfaceMuted: "#1a2f42",
  text: "#f4f9ff",
  textMuted: "#c7d7eb",
  border: "#2a4058",
  accent: "#edf6ff",
  accentStrong: "#f8fbff",
  accentSoft: "rgba(237,246,255,0.12)",
  accentText: "#071421",
  success: "#8af0c0",
  successSoft: "rgba(138,240,192,0.14)",
  warning: "#ffd166",
  warningSoft: "rgba(255,209,102,0.14)",
  danger: "#ff7d7d",
  dangerSoft: "rgba(255,125,125,0.14)",
  info: "#cfe3ff",
  infoSoft: "rgba(207,227,255,0.12)",
  muted: "#dfe9f7",
};

export const colors = lightPalette;
export const themePalettes = {
  light: lightPalette,
  dark: darkPalette,
} as const;

export type ThemeContextValue = {
  mode: ThemeMode;
  colors: typeof colors;
  toggleTheme: () => void;
  setThemeMode: (mode: ThemeMode) => void;
};

const THEME_STORAGE_KEY = "property24-theme-mode";
const ThemeContext = createContext<ThemeContextValue | null>(null);

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const systemMode = useColorScheme() === "dark" ? "dark" : "light";
  const [mode, setMode] = useState<ThemeMode>(systemMode);
  const activePalette = useMemo(() => (mode === "dark" ? darkPalette : lightPalette), [mode]);

  useEffect(() => {
    let isMounted = true;
    AsyncStorage.getItem(THEME_STORAGE_KEY)
      .then((storedMode) => {
        if (!isMounted) return;
        if (storedMode === "dark" || storedMode === "light") {
          setMode(storedMode);
        } else {
          setMode(systemMode);
        }
      })
      .catch(() => {
        if (isMounted) setMode(systemMode);
      });

    return () => {
      isMounted = false;
    };
  }, [systemMode]);

  useEffect(() => {
    AsyncStorage.setItem(THEME_STORAGE_KEY, mode).catch(() => undefined);
  }, [activePalette, mode]);

  const value = useMemo<ThemeContextValue>(() => ({
    mode,
    colors: { ...activePalette } as typeof colors,
    toggleTheme: () => setMode((current) => (current === "dark" ? "light" : "dark")),
    setThemeMode: (nextMode) => setMode(nextMode),
  }), [activePalette, mode]);

  return React.createElement(ThemeContext.Provider, { value }, children);
}

export function useTheme() {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error("useTheme must be used inside ThemeProvider");
  }
  return context;
}

export function useAppTheme() {
  const { mode, colors: activeColors, toggleTheme, setThemeMode } = useTheme();
  return { mode, colors: activeColors, toggleTheme, setThemeMode };
}

export function getGreetingFromTime(date = new Date()) {
  const hour = date.getHours();
  if (hour < 12) return "Good morning";
  if (hour < 18) return "Good afternoon";
  return "Good evening";
}

export function formatDashboardTime(date = new Date()) {
  return date.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
}

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
    shadowOpacity: 0,
    shadowRadius: 0,
    shadowOffset: { width: 0, height: 0 },
    elevation: 0,
  },
  card: {
    shadowColor: "#000000",
    shadowOpacity: 0,
    shadowRadius: 0,
    shadowOffset: { width: 0, height: 0 },
    elevation: 0,
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
