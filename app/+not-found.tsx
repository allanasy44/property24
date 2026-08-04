import { Link } from "expo-router";
import { StyleSheet, Text, View } from "react-native";
import { Screen } from "../components/Screen";
import { colors, radius, spacing, typography } from "../constants/theme";

export default function NotFoundScreen() {
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

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    padding: spacing.lg,
    gap: spacing.md,
  },
  title: {
    color: colors.text,
    fontSize: 28,
    lineHeight: 34,
    ...typography.display,
  },
  subtitle: {
    color: colors.textMuted,
    textAlign: "center",
    lineHeight: 22,
    ...typography.body,
  },
  link: {
    backgroundColor: colors.accent,
    color: colors.accentText,
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: radius.md,
    ...typography.button,
  },
});
