import { Link } from "expo-router";
import { ReactNode } from "react";
import { StyleSheet, Text, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { colors, radius, shadows, spacing, typography } from "../constants/theme";
import { AccountRole, useRentalPlatform } from "../state/rentalPlatform";
import { Screen } from "./Screen";

type AccessGuardProps = {
  section: string;
  roles?: AccountRole[];
  children: ReactNode;
};

export function AccessGuard({ section, roles, children }: AccessGuardProps) {
  const { account, canAccessSection } = useRentalPlatform();
  const allowedByRole = !roles || roles.includes(account.accountType);

  if (allowedByRole && canAccessSection(section)) {
    return <>{children}</>;
  }

  return (
    <Screen>
      <View style={styles.wrap}>
        <View style={styles.card}>
          <View style={styles.iconWrap}>
            <Ionicons name="lock-closed-outline" size={24} color={colors.accent} />
          </View>
          <Text style={styles.title}>Access limited</Text>
          <Text style={styles.body}>
            This area is hidden for the current {account.accountType} account. Sign in with an account that has the right permissions to continue.
          </Text>
          <Link href="/profile" asChild>
            <Text style={styles.action}>Review account access</Text>
          </Link>
        </View>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  wrap: { flex: 1, padding: spacing.lg, justifyContent: "center" },
  card: { backgroundColor: colors.surfaceElevated, borderRadius: radius.xl, padding: spacing.lg, gap: spacing.md, alignItems: "flex-start", ...shadows.card },
  iconWrap: { width: 48, height: 48, borderRadius: 16, backgroundColor: colors.accentSoft, alignItems: "center", justifyContent: "center" },
  title: { color: colors.text, fontSize: 22, lineHeight: 28, ...typography.display },
  body: { color: colors.textMuted, lineHeight: 22, ...typography.body },
  action: { color: colors.accent, ...typography.button },
});
