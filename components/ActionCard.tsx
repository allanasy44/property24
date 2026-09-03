import { Ionicons } from "@expo/vector-icons";
import { Href, Link } from "expo-router";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { colors, radius, shadows, spacing, typography, useTheme } from "../constants/theme";

type ActionCardProps = {
  title: string;
  subtitle: string;
  icon: keyof typeof Ionicons.glyphMap;
  href: Href;
};

export function ActionCard({ title, subtitle, icon, href }: ActionCardProps) {
  const { colors: themeColors } = useTheme();
  const styles = createStyles(themeColors);
  return (
    <Link href={href} asChild>
      <Pressable style={({ pressed }) => [styles.card, pressed && styles.cardPressed]}>
        <View style={styles.iconWrap}>
          <Ionicons name={icon} size={18} color={themeColors.accentStrong} />
        </View>
        <Text style={styles.title}>{title}</Text>
        <Text style={styles.subtitle}>{subtitle}</Text>
      </Pressable>
    </Link>
  );
}

function createStyles(themeColors: typeof colors) {
  return StyleSheet.create({
  card: {
    width: "48%",
    backgroundColor: themeColors.surfaceElevated,
    borderRadius: radius.xl,
    borderWidth: 1,
    borderColor: themeColors.border,
    padding: spacing.md,
    gap: 10,
    minHeight: 118,
    ...shadows.soft,
  },
  cardPressed: {
    transform: [{ scale: 0.99 }],
    borderColor: themeColors.border,
    shadowOpacity: 0.08,
  },
  iconWrap: {
    width: 40,
    height: 40,
    borderRadius: 14,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: themeColors.accentSoft,
    borderWidth: 1,
    borderColor: "rgba(30,41,59,0.08)",
  },
  title: {
    color: themeColors.text,
    fontSize: 15,
    lineHeight: 19,
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
