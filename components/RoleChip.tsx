import { StyleSheet, Text, View } from "react-native";
import { colors, radius, typography } from "../constants/theme";

type RoleChipProps = {
  title: string;
  subtitle: string;
  active?: boolean;
  accent: string;
};

export function RoleChip({ title, subtitle, active, accent }: RoleChipProps) {
  return (
    <View style={[styles.chip, active && { borderColor: accent, backgroundColor: "rgba(15, 118, 110, 0.08)" }]}>
      <Text style={[styles.title, active && { color: accent }]}>{title}</Text>
      <Text style={styles.subtitle}>{subtitle}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  chip: {
    flex: 1,
    minWidth: 140,
    backgroundColor: colors.surfaceElevated,
    borderRadius: radius.lg,
    paddingHorizontal: 14,
    paddingVertical: 12,
    borderWidth: 1,
    borderColor: colors.border,
    gap: 4,
  },
  title: {
    color: colors.text,
    ...typography.title,
  },
  subtitle: {
    color: colors.textMuted,
    lineHeight: 18,
    fontSize: 12,
    ...typography.body,
  },
});
