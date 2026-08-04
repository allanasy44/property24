import { Ionicons } from "@expo/vector-icons";
import { Href, Link } from "expo-router";
import { StyleSheet, Text, View } from "react-native";
import { colors, radius, shadows, spacing, typography } from "../constants/theme";

type ActionCardProps = {
  title: string;
  subtitle: string;
  icon: keyof typeof Ionicons.glyphMap;
  href: Href;
};

export function ActionCard({ title, subtitle, icon, href }: ActionCardProps) {
  return (
    <Link href={href} asChild>
      <View style={styles.card}>
        <View style={styles.iconWrap}>
          <Ionicons name={icon} size={18} color={colors.accent} />
        </View>
        <Text style={styles.title}>{title}</Text>
        <Text style={styles.subtitle}>{subtitle}</Text>
      </View>
    </Link>
  );
}

const styles = StyleSheet.create({
  card: {
    width: "48%",
    backgroundColor: colors.surfaceElevated,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    padding: spacing.md,
    gap: 8,
    ...shadows.soft,
  },
  iconWrap: {
    width: 36,
    height: 36,
    borderRadius: 8,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: colors.accentSoft,
  },
  title: {
    color: colors.text,
    fontSize: 15,
    lineHeight: 19,
    ...typography.title,
  },
  subtitle: {
    color: colors.textMuted,
    lineHeight: 18,
    fontSize: 12,
    ...typography.body,
  },
});
