import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { SafeAreaProvider } from "react-native-safe-area-context";
import { AuthGate } from "../components/AuthGate";
import { ThemeProvider, useTheme } from "../constants/theme";
import { RentalPlatformProvider } from "../state/rentalPlatform";

function AppShell() {
  const { mode } = useTheme();

  return (
    <>
      <StatusBar style={mode === "dark" ? "light" : "dark"} backgroundColor={mode === "dark" ? "#071421" : "#f7f9fc"} />
      <AuthGate>
        <Stack screenOptions={{ headerShown: false }}>
          <Stack.Screen name="(tabs)" />
          <Stack.Screen name="property/[id]" />
          <Stack.Screen name="supplier/[id]" />
          <Stack.Screen name="operations" />
          <Stack.Screen name="leases" />
          <Stack.Screen name="verification" />
          <Stack.Screen name="analytics" />
        </Stack>
      </AuthGate>
    </>
  );
}

export default function RootLayout() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <ThemeProvider>
          <RentalPlatformProvider>
            <AppShell />
          </RentalPlatformProvider>
        </ThemeProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
