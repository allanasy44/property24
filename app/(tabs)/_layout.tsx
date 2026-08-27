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
        tabBarActiveTintColor: colors.accentStrong,
        tabBarInactiveTintColor: colors.muted,
        tabBarActiveBackgroundColor: "rgba(15, 23, 42, 0.06)",
        tabBarStyle: {
          alignSelf: "center",
          backgroundColor: "rgba(255,255,255,0.97)",
          borderTopColor: colors.border,
          borderTopWidth: 1,
          borderTopLeftRadius: 22,
          borderTopRightRadius: 22,
          height: 74,
          maxWidth: 430,
          paddingBottom: 10,
          paddingTop: 8,
          width: "100%",
          shadowColor: "#000000",
          shadowOffset: { width: 0, height: -6 },
          shadowOpacity: 0.07,
          shadowRadius: 18,
          elevation: 8,
        },
        tabBarLabelStyle: {
          fontSize: 10,
          lineHeight: 13,
          marginTop: 1,
          ...typography.label,
        },
        tabBarItemStyle: {
          minHeight: 56,
          paddingVertical: 4,
          borderRadius: 16,
          marginHorizontal: 6,
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
