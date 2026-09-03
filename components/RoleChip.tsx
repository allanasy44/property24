import { StyleSheet, Text, View } from "react-native";
import { colors, radius, typography, useTheme } from "../constants/theme";

type RoleChipProps = {
  title: string;
  subtitle: string;
  active?: boolean;
  accent: string;
};

export function RoleChip({ title, subtitle, active, accent }: RoleChipProps) {
  const { colors: themeColors } = useTheme();
  const styles = createStyles(themeColors);
  return (
    <View
      style={[styles.chip, active && { borderColor: accent, backgroundColor: themeColors.accentSoft }]}
    >
      <Text style={[styles.title, active && { color: accent }]}>{title}</Text>
      <Text style={styles.subtitle}>{subtitle}</Text>
    </View>
  );
}

function createStyles(themeColors: typeof colors) {
  return StyleSheet.create({
  chip: {
    flex: 1,
    minWidth: 140,
    backgroundColor: themeColors.surfaceElevated,
    borderRadius: radius.lg,
    paddingHorizontal: 14,
    paddingVertical: 12,
    borderWidth: 1,
    borderColor: themeColors.border,
    gap: 4,
  },
  title: {
    color: themeColors.text,
    ...typography.title,
  },
  subtitle: {
    color: themeColors.textMuted,
    lineHeight: 18,
    fontSize: 12,
    ...typography.body,
  },
  });
}
