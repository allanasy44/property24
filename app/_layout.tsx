import { Stack } from "expo-router";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { SafeAreaProvider } from "react-native-safe-area-context";
import { AuthGate } from "../components/AuthGate";
import { RentalPlatformProvider } from "../state/rentalPlatform";

export default function RootLayout() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <RentalPlatformProvider>
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
        </RentalPlatformProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
