import { Ionicons } from "@expo/vector-icons";
import { ScrollView, StyleSheet, Text, View } from "react-native";
import { useEffect, useState } from "react";
import { Screen } from "../components/Screen";
import { SectionHeader } from "../components/SectionHeader";
import { LiveFeed } from "../components/LiveFeed";
import { RoleChip } from "../components/RoleChip";
import { colors, radius, shadows, spacing, typography, useTheme } from "../constants/theme";
import { journeyPoints, roleCards } from "../constants/content";
import { useRentalPlatform, useRentalPlatformStats } from "../state/rentalPlatform";
import { AccessGuard } from "../components/AccessGuard";

export default function OperationsScreen() {
  const { colors: themeColors } = useTheme();
  const styles = createStyles(themeColors);
  const [clock, setClock] = useState(new Date());
  const { state } = useRentalPlatform();
  const stats = useRentalPlatformStats();

  useEffect(() => {
    const timer = setInterval(() => setClock(new Date()), 5000);
    return () => clearInterval(timer);
  }, []);

  const metrics = [
    { label: "Listings", value: `${stats.listings}`, change: "active portfolio", tone: "info" as const },
    { label: "Payments", value: `${state.payments.length}`, change: `${stats.receivedPayments} received`, tone: "success" as const },
    { label: "Maintenance", value: `${state.maintenance.length}`, change: `${stats.maintenanceOpen} open`, tone: "warning" as const },
    { label: "Leases", value: `${state.leases.length}`, change: `${stats.occupiedRate}% active`, tone: "info" as const },
  ];

  return (
    <AccessGuard section="operations" roles={["agent", "admin"]}>
      <Screen>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <View style={styles.hero}>
          <View style={styles.heroTop}>
            <View>
              <Text style={styles.kicker}>Live operations</Text>
              <Text style={styles.title}>Everything in one mobile control center.</Text>
            </View>
            <View style={styles.clockBadge}>
              <Ionicons name="pulse" size={16} color={themeColors.success} />
              <Text style={styles.clockText}>{clock.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}</Text>
            </View>
          </View>
          <Text style={styles.subtitle}>Track payments, leases, maintenance, chats, and analytics as one workflow.</Text>
        </View>

        <SectionHeader title="Who is using the app" subtitle="Role-specific entry points for the rental platform." />
        <View style={styles.roleGrid}>
          {roleCards.map((role, index) => (
            <RoleChip key={role.title} title={role.title} subtitle={journeyPoints[role.title as keyof typeof journeyPoints][0]} active={index === 0} accent={role.accent} />
          ))}
        </View>

        <SectionHeader title="Live feed" subtitle="A queue of events created by in-app actions." />
        <LiveFeed items={state.liveEvents} />

        <SectionHeader title="KPIs" subtitle="Quick portfolio health for landlords, agents, and admins." />
        <View style={styles.metricGrid}>
          {metrics.map((metric) => (
            <View key={metric.label} style={styles.metricCard}>
              <Text style={styles.metricLabel}>{metric.label}</Text>
              <Text style={styles.metricValue}>{metric.value}</Text>
              <Text style={[styles.metricChange, metric.tone === "warning" ? styles.warning : metric.tone === "success" ? styles.success : styles.info]}>
                {metric.change}
              </Text>
            </View>
          ))}
        </View>
        </ScrollView>
      </Screen>
    </AccessGuard>
  );
}

function createStyles(themeColors: typeof colors) {
  return StyleSheet.create({
  content: { padding: spacing.lg, gap: spacing.lg },
  hero: { backgroundColor: themeColors.surfaceElevated, borderRadius: radius.xl, padding: spacing.lg, gap: spacing.md, ...shadows.card },
  heroTop: { flexDirection: "row", justifyContent: "space-between", gap: spacing.md },
  kicker: { color: themeColors.accent, marginBottom: 6, ...typography.label },
  title: { color: themeColors.text, fontSize: 30, lineHeight: 36, maxWidth: 270, ...typography.display },
  subtitle: { color: themeColors.textMuted, lineHeight: 22, ...typography.body },
  clockBadge: { flexDirection: "row", alignItems: "center", gap: 6, alignSelf: "flex-start", backgroundColor: themeColors.successSoft, paddingHorizontal: 10, paddingVertical: 8, borderRadius: 999 },
  clockText: { color: themeColors.success, ...typography.label },
  roleGrid: { flexDirection: "row", flexWrap: "wrap", gap: spacing.sm },
  metricGrid: { flexDirection: "row", flexWrap: "wrap", gap: spacing.sm },
  metricCard: { width: "48%", backgroundColor: themeColors.surfaceElevated, borderRadius: radius.lg, padding: spacing.md, gap: 4, ...shadows.soft },
  metricLabel: { color: themeColors.textMuted, ...typography.label },
  metricValue: { color: themeColors.text, fontSize: 24, lineHeight: 29, ...typography.display },
  metricChange: { ...typography.label },
  warning: { color: themeColors.warning },
  success: { color: themeColors.success },
  info: { color: themeColors.info },
  });
}
