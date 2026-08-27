import { Ionicons } from "@expo/vector-icons";
import { Href, Link } from "expo-router";
import { Pressable, StyleSheet, Text, View } from "react-native";
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
      <Pressable style={({ pressed }) => [styles.card, pressed && styles.cardPressed]}>
        <View style={styles.iconWrap}>
          <Ionicons name={icon} size={18} color={colors.accentStrong} />
        </View>
        <Text style={styles.title}>{title}</Text>
        <Text style={styles.subtitle}>{subtitle}</Text>
      </Pressable>
    </Link>
  );
}

const styles = StyleSheet.create({
  card: {
    width: "48%",
    backgroundColor: colors.surfaceElevated,
    borderRadius: radius.xl,
    borderWidth: 1,
    borderColor: colors.border,
    padding: spacing.md,
    gap: 10,
    minHeight: 118,
    ...shadows.soft,
  },
  cardPressed: {
    transform: [{ scale: 0.99 }],
    borderColor: colors.border,
    shadowOpacity: 0.08,
  },
  iconWrap: {
    width: 40,
    height: 40,
    borderRadius: 14,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: colors.accentSoft,
    borderWidth: 1,
    borderColor: "rgba(30,41,59,0.08)",
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
