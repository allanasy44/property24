import { Link } from "expo-router";
import { StyleSheet, Text, View } from "react-native";
import { Screen } from "../components/Screen";
import { colors, radius, spacing, typography, useTheme } from "../constants/theme";

export default function NotFoundScreen() {
  const { colors: themeColors } = useTheme();
  const styles = createStyles(themeColors);
  return (
    <Screen>
      <View style={styles.container}>
        <Text style={styles.title}>Page not found</Text>
        <Text style={styles.subtitle}>The route does not exist yet. Return to the rental platform.</Text>
        <Link href="/" style={styles.link}>
          Go home
        </Link>
      </View>
    </Screen>
  );
}

function createStyles(themeColors: typeof colors) {
  return StyleSheet.create({
  container: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    padding: spacing.lg,
    gap: spacing.md,
  },
  title: {
    color: themeColors.text,
    fontSize: 28,
    lineHeight: 34,
    ...typography.display,
  },
  subtitle: {
    color: themeColors.textMuted,
    textAlign: "center",
    lineHeight: 22,
    ...typography.body,
  },
  link: {
    backgroundColor: themeColors.accent,
    color: themeColors.accentText,
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: radius.md,
    ...typography.button,
  },
  });
}
