import { Ionicons } from "@expo/vector-icons";
import { Tabs } from "expo-router";
import { colors, typography } from "../../constants/theme";
import { useRentalPlatform } from "../../state/rentalPlatform";

export default function TabsLayout() {
  const { canAccessSection } = useRentalPlatform();
  const tabOptions = (section: string, title: string) => ({
    title,
    href: canAccessSection(section) ? undefined : null,
  });

  return (
    <Tabs
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarActiveTintColor: colors.accent,
        tabBarInactiveTintColor: colors.muted,
        tabBarStyle: {
          alignSelf: "center",
          backgroundColor: colors.surface,
          borderTopColor: colors.border,
          height: 62,
          maxWidth: 430,
          paddingBottom: 8,
          paddingTop: 7,
          width: "100%",
          shadowColor: "#000000",
          shadowOffset: { width: 0, height: -4 },
          shadowOpacity: 0.32,
          shadowRadius: 10,
          elevation: 8,
        },
        tabBarLabelStyle: {
          fontSize: 10,
          lineHeight: 13,
          marginTop: 1,
          ...typography.label,
        },
        tabBarItemStyle: {
          minHeight: 50,
          paddingVertical: 3,
        },
        tabBarIcon: ({ color, size }) => {
          const iconMap: Record<string, keyof typeof Ionicons.glyphMap> = {
            index: "home-outline",
            listings: "layers-outline",
            payments: "card-outline",
            maintenance: "construct-outline",
            inbox: "chatbubble-ellipses-outline",
            profile: "person-circle-outline",
          };

          return <Ionicons name={iconMap[route.name] ?? "ellipse-outline"} size={size} color={color} />;
        },
      })}
    >
      <Tabs.Screen name="index" options={{ title: "Home" }} />
      <Tabs.Screen name="listings" options={tabOptions("listings", "Listings")} />
      <Tabs.Screen name="inbox" options={tabOptions("inbox", "Inbox")} />
      <Tabs.Screen name="payments" options={tabOptions("payments", "Payments")} />
      <Tabs.Screen name="maintenance" options={tabOptions("maintenance", "Maintenance")} />
      <Tabs.Screen name="profile" options={{ title: "Profile" }} />
    </Tabs>
  );
}
