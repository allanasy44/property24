import { Ionicons } from "@expo/vector-icons";
import { StyleSheet, Text, View } from "react-native";
import { colors, radius, shadows, spacing, typography, useTheme } from "../constants/theme";

type LiveFeedProps = {
  items: Array<{
    id: string;
    title: string;
    meta: string;
    status: string;
    tone: "success" | "warning" | "info" | "danger";
  }>;
};

export function LiveFeed({ items }: LiveFeedProps) {
  const { colors: themeColors } = useTheme();
  const styles = createStyles(themeColors);
  const toneMap = {
    success: { backgroundColor: themeColors.successSoft, color: themeColors.success, icon: "checkmark-circle-outline" as const },
    warning: { backgroundColor: themeColors.warningSoft, color: themeColors.warning, icon: "time-outline" as const },
    info: { backgroundColor: themeColors.infoSoft, color: themeColors.info, icon: "radio-outline" as const },
    danger: { backgroundColor: themeColors.dangerSoft, color: themeColors.danger, icon: "alert-circle-outline" as const },
  };
  if (!items.length) {
    return null;
  }

  return (
    <View style={styles.container}>
      {items.map((item) => {
        const tone = toneMap[item.tone];

        return (
          <View key={item.id} style={styles.card}>
            <View style={[styles.iconWrap, { backgroundColor: tone.backgroundColor }]}>
              <Ionicons name={tone.icon} size={16} color={tone.color} />
            </View>
            <View style={styles.body}>
              <View style={styles.row}>
                <Text style={styles.title}>{item.title}</Text>
                <Text style={styles.status}>{item.status}</Text>
              </View>
              <Text style={styles.meta}>{item.meta}</Text>
            </View>
          </View>
        );
      })}
    </View>
  );
}

function createStyles(themeColors: typeof colors) {
  return StyleSheet.create({
  container: {
    gap: spacing.sm,
  },
  emptyCard: {
    flexDirection: "row",
    gap: 10,
    backgroundColor: themeColors.surfaceElevated,
    borderRadius: radius.xl,
    borderWidth: 1,
    borderColor: themeColors.border,
    padding: spacing.md,
    ...shadows.soft,
  },
  card: {
    flexDirection: "row",
    gap: 12,
    backgroundColor: themeColors.surfaceElevated,
    borderRadius: radius.xl,
    borderWidth: 1,
    borderColor: themeColors.border,
    padding: spacing.md,
    ...shadows.soft,
  },
  iconWrap: {
    width: 36,
    height: 36,
    borderRadius: 12,
    alignItems: "center",
    justifyContent: "center",
    marginTop: 2,
    borderWidth: 1,
    borderColor: "rgba(30,41,59,0.08)",
  },
  body: {
    flex: 1,
    gap: 4,
  },
  row: {
    flexDirection: "row",
    justifyContent: "space-between",
    gap: 10,
  },
  title: {
    flex: 1,
    color: themeColors.text,
    ...typography.title,
  },
  status: {
    color: themeColors.textMuted,
    fontSize: 12,
    ...typography.label,
  },
  meta: {
    color: themeColors.textMuted,
    lineHeight: 18,
    ...typography.body,
  },
  });
}
