import { Ionicons } from "@expo/vector-icons";
import { StyleSheet, Text, View } from "react-native";
import { colors, radius, shadows, spacing, typography } from "../constants/theme";

type LiveFeedProps = {
  items: Array<{
    id: string;
    title: string;
    meta: string;
    status: string;
    tone: "success" | "warning" | "info" | "danger";
  }>;
};

const toneMap = {
  success: { backgroundColor: colors.successSoft, color: colors.success, icon: "checkmark-circle-outline" as const },
  warning: { backgroundColor: colors.warningSoft, color: colors.warning, icon: "time-outline" as const },
  info: { backgroundColor: colors.infoSoft, color: colors.info, icon: "radio-outline" as const },
  danger: { backgroundColor: colors.dangerSoft, color: colors.danger, icon: "alert-circle-outline" as const },
};

export function LiveFeed({ items }: LiveFeedProps) {
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

const styles = StyleSheet.create({
  container: {
    gap: spacing.sm,
  },
  card: {
    flexDirection: "row",
    gap: 10,
    backgroundColor: colors.surfaceElevated,
    borderRadius: radius.lg,
    padding: spacing.md,
    ...shadows.soft,
  },
  iconWrap: {
    width: 34,
    height: 34,
    borderRadius: 12,
    alignItems: "center",
    justifyContent: "center",
    marginTop: 2,
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
    color: colors.text,
    ...typography.title,
  },
  status: {
    color: colors.textMuted,
    fontSize: 12,
    ...typography.label,
  },
  meta: {
    color: colors.textMuted,
    lineHeight: 18,
    ...typography.body,
  },
});
