import { Ionicons } from "@expo/vector-icons";
import { BlurView } from "expo-blur";
import { Tabs } from "expo-router";
import { Pressable, ScrollView, StyleSheet, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import type { BottomTabBarProps } from "@react-navigation/bottom-tabs";
import { colors, radius, shadows } from "../../constants/theme";
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
      <Tabs.Screen name="maintenance" options={tabOptions("maintenance", "Maintenance")} />
      <Tabs.Screen name="profile" options={{ title: "Profile" }} />
    </Tabs>
  );
}

function FloatingTabBar({ state, descriptors, navigation }: BottomTabBarProps) {
  const insets = useSafeAreaInsets();
  const iconMap: Record<string, keyof typeof Ionicons.glyphMap> = {
    index: "compass-outline",
    listings: "business-outline",
    maintenance: "build-outline",
    inbox: "chatbubbles-outline",
    profile: "person-outline",
  };

  return (
    <View pointerEvents="box-none" style={[styles.host, { bottom: Math.max(insets.bottom, 10) }]}>
      <BlurView intensity={58} tint="light" style={styles.dock}>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.items}>
          {state.routes.map((route, index) => {
            const descriptor = descriptors[route.key];
            const label = descriptor.options.tabBarLabel ?? descriptor.options.title ?? route.name;
            const focused = state.index === index;
            const onPress = () => {
              const event = navigation.emit({ type: "tabPress", target: route.key, canPreventDefault: true });
              if (!focused && !event.defaultPrevented) navigation.navigate(route.name, route.params);
            };
            return (
              <Pressable key={route.key} accessibilityLabel={String(label)} accessibilityRole="tab" accessibilityState={{ selected: focused }} onPress={onPress} style={styles.item}>
                <View style={[styles.iconCircle, focused && styles.iconCircleActive]}><Ionicons name={iconMap[route.name] ?? "ellipse-outline"} size={24} color={colors.text} /></View>
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
