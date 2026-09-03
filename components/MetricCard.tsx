import { StyleSheet, Text, View } from "react-native";
import { radius, shadows, spacing, typography, useTheme } from "../constants/theme";

type MetricCardProps = {
  label: string;
  value: string;
  change: string;
  tone: "success" | "warning" | "info";
};

export function MetricCard({ label, value, change, tone }: MetricCardProps) {
  const { colors } = useTheme();
  const styles = StyleSheet.create({
    card: { width: "48%", backgroundColor: colors.surfaceElevated, borderRadius: radius.lg, padding: spacing.md, gap: 4, ...shadows.soft },
    label: { color: colors.textMuted, ...typography.label },
    value: { color: colors.text, fontSize: 24, lineHeight: 29, ...typography.display },
    change: { color: colors.success, ...typography.label },
    success: { color: colors.success },
    warning: { color: colors.warning },
    info: { color: colors.info },
  });

  return (
    <View style={styles.card}>
      <Text style={styles.label}>{label}</Text>
      <Text style={styles.value}>{value}</Text>
      <Text style={[styles.change, tone === "warning" && styles.warning, tone === "info" && styles.info, tone === "success" && styles.success]}>
        {change}
      </Text>
    </View>
  );
}
