import { ScrollView, StyleSheet, Text, View } from "react-native";
import { Screen } from "../components/Screen";
import { SectionHeader } from "../components/SectionHeader";
import { MetricCard } from "../components/MetricCard";
import { colors, radius, shadows, spacing, typography, useTheme } from "../constants/theme";
import { useRentalPlatform, useRentalPlatformStats } from "../state/rentalPlatform";
import { AccessGuard } from "../components/AccessGuard";

export default function AnalyticsScreen() {
  const { colors: themeColors } = useTheme();
  const styles = createStyles(themeColors);
  const { state } = useRentalPlatform();
  const stats = useRentalPlatformStats();
  const rentalIncome = state.payments.reduce((total, payment) => total + parseMoney(payment.amount), 0);
  const listingViews = state.properties.reduce((total, property) => total + (property.listingViews ?? 0), 0);
  const savedProperties = state.properties.reduce((total, property) => total + (property.savedCount ?? 0), 0);
  const applications = state.applications.length + state.properties.reduce((total, property) => total + (property.applicationsCount ?? 0), 0);

  const metrics = [
    { label: "Listing views", value: `${listingViews}`, change: "live", tone: "info" as const },
    { label: "Saved properties", value: `${savedProperties}`, change: "live", tone: "info" as const },
    { label: "Applications", value: `${applications}`, change: "live", tone: "success" as const },
    { label: "Occupancy rate", value: `${stats.occupiedRate}%`, change: "calculated", tone: "success" as const },
    { label: "Rental income", value: `$${rentalIncome}`, change: "received", tone: "success" as const },
    { label: "Disputes", value: `${Math.max(0, state.maintenance.length - state.payments.length)}`, change: "estimated", tone: "warning" as const },
  ];

  return (
    <AccessGuard section="analytics" roles={["landlord", "admin"]}>
      <Screen>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <View style={styles.hero}>
          <Text style={styles.kicker}>Property analytics</Text>
          <Text style={styles.title}>Portfolio performance at a glance.</Text>
          <Text style={styles.subtitle}>Metrics are computed from live frontend data and refreshed as the app evolves.</Text>
        </View>

        <View style={styles.summaryRow}>
          <View style={styles.summaryCard}>
            <Text style={styles.summaryLabel}>Rental income</Text>
            <Text style={styles.summaryValue}>${rentalIncome}</Text>
          </View>
          <View style={styles.summaryCard}>
            <Text style={styles.summaryLabel}>Views</Text>
            <Text style={styles.summaryValue}>{listingViews}</Text>
          </View>
        </View>

        <SectionHeader title="Performance metrics" subtitle="Portfolio view for management and reporting." />
        <View style={styles.metricGrid}>
          {metrics.map((metric) => (
            <MetricCard key={metric.label} label={metric.label} value={metric.value} change={metric.change} tone={metric.tone} />
          ))}
        </View>

        <SectionHeader title="Reports" subtitle="Useful dashboard sections for landlords and administrators." />
        <View style={styles.reportCard}>
          {[
            "Occupancy rate by property",
            "Saved properties and shortlists",
            "Applications and approval status",
            "Monthly rental income",
            "Dispute trends and moderation",
            "Commission tracking for agents",
          ].map((item) => (
            <Text key={item} style={styles.reportItem}>• {item}</Text>
          ))}
        </View>
        </ScrollView>
      </Screen>
    </AccessGuard>
  );
}

function parseMoney(value: string) {
  const amount = Number(value.replace(/[^0-9.]/g, ""));
  return Number.isFinite(amount) ? amount : 0;
}

function createStyles(themeColors: typeof colors) {
  return StyleSheet.create({
  content: { padding: spacing.lg, gap: spacing.lg },
  hero: { backgroundColor: themeColors.surfaceElevated, borderRadius: radius.xl, padding: spacing.lg, gap: spacing.sm, ...shadows.card },
  kicker: { color: themeColors.accent, ...typography.label },
  title: { color: themeColors.text, fontSize: 28, lineHeight: 34, ...typography.display },
  subtitle: { color: themeColors.textMuted, lineHeight: 22, ...typography.body },
  summaryRow: { flexDirection: "row", gap: spacing.sm },
  summaryCard: { flex: 1, backgroundColor: themeColors.surfaceElevated, borderRadius: radius.md, borderWidth: 1, borderColor: themeColors.border, padding: spacing.md, ...shadows.soft },
  summaryLabel: { color: themeColors.textMuted, fontSize: 10, ...typography.label },
  summaryValue: { color: themeColors.text, fontSize: 20, marginTop: 6, ...typography.display },
  metricGrid: { flexDirection: "row", flexWrap: "wrap", gap: spacing.sm },
  reportCard: { backgroundColor: themeColors.surfaceElevated, borderRadius: radius.lg, padding: spacing.md, gap: 8, ...shadows.soft },
  reportItem: { color: themeColors.text, lineHeight: 20, ...typography.body },
  });
}
