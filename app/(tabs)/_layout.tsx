import { Ionicons } from "@expo/vector-icons";
import { BlurView } from "expo-blur";
import { Tabs } from "expo-router";
import { Pressable, ScrollView, StyleSheet, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import type { BottomTabBarProps } from "@react-navigation/bottom-tabs";
import { colors, radius, shadows, useTheme } from "../../constants/theme";
import { useRentalPlatform } from "../../state/rentalPlatform";

export default function TabsLayout() {
  const { canAccessSection } = useRentalPlatform();
  const tabOptions = (section: string, title: string) => ({
    title,
    href: canAccessSection(section) ? undefined : null,
  });

  return (
    <Tabs
      tabBar={(props) => <FloatingTabBar {...props} />}
      screenOptions={{
        headerShown: false,
      }}
    >
      <Tabs.Screen name="index" options={{ title: "Home" }} />
      <Tabs.Screen name="listings" options={tabOptions("listings", "Listings")} />
      <Tabs.Screen name="inbox" options={tabOptions("inbox", "Inbox")} />
      <Tabs.Screen name="calls" options={tabOptions("calls", "Calls")} />
      <Tabs.Screen name="profile" options={{ title: "Settings" }} />
    </Tabs>
  );
}

function FloatingTabBar({ state, descriptors, navigation }: BottomTabBarProps) {
  const insets = useSafeAreaInsets();
  const { mode, colors: themeColors } = useTheme();
  const { canAccessSection } = useRentalPlatform();
  const iconMap: Record<string, keyof typeof Ionicons.glyphMap> = {
    index: "compass-outline",
    listings: "business-outline",
    inbox: "chatbubbles-outline",
    calls: "call-outline",
    profile: "settings-outline",
  };

  return (
    <View pointerEvents="box-none" style={[styles.host, { bottom: Math.max(insets.bottom, 10) }]}>
      <BlurView intensity={58} tint={mode === "dark" ? "dark" : "light"} style={[styles.dock, { backgroundColor: mode === "dark" ? "rgba(11,22,34,0.82)" : "rgba(238,242,255,0.30)" }]}>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.items}>
          {state.routes.filter((route) => canAccessSection(route.name)).map((route) => {
            const descriptor = descriptors[route.key];
            const label = descriptor.options.tabBarLabel ?? descriptor.options.title ?? route.name;
            const focused = state.routes[state.index]?.key === route.key;
            const onPress = () => {
              const event = navigation.emit({ type: "tabPress", target: route.key, canPreventDefault: true });
              if (!focused && !event.defaultPrevented) navigation.navigate(route.name, route.params);
            };
            return (
              <Pressable key={route.key} accessibilityLabel={String(label)} accessibilityRole="tab" accessibilityState={{ selected: focused }} onPress={onPress} style={styles.item}>
                <View style={[styles.iconCircle, focused && styles.iconCircleActive, { backgroundColor: focused ? (mode === "dark" ? "rgba(148,163,184,0.18)" : "rgba(238,242,255,0.42)") : (mode === "dark" ? "rgba(148,163,184,0.10)" : "rgba(238,242,255,0.16)") }]}><Ionicons name={iconMap[route.name] ?? "ellipse-outline"} size={24} color={themeColors.text} /></View>
              </Pressable>
            );
          })}
        </ScrollView>
      </BlurView>
    </View>
  );
}

const styles = StyleSheet.create({
  host: { left: 0, paddingHorizontal: 12, position: "absolute", right: 0 },
  dock: { alignSelf: "center", backgroundColor: "rgba(238,242,255,0.30)", borderColor: "transparent", borderRadius: radius.xl, borderWidth: 0, maxWidth: 430, overflow: "hidden", ...shadows.card, width: "100%" },
  items: { alignItems: "center", flexGrow: 1, justifyContent: "space-around", minHeight: 76, paddingHorizontal: 8 },
  item: { alignItems: "center", borderRadius: radius.lg, minWidth: 68, paddingHorizontal: 6, paddingVertical: 8 },
  iconCircle: { alignItems: "center", backgroundColor: "rgba(238,242,255,0.16)", borderColor: "transparent", borderRadius: 999, borderWidth: 0, height: 48, justifyContent: "center", width: 48 },
  iconCircleActive: { backgroundColor: "rgba(238,242,255,0.42)", borderColor: "transparent", ...shadows.soft },
});
