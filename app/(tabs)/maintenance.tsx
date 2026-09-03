import { useEffect, useMemo, useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { Screen } from "../../components/Screen";
import { colors, radius, shadows, spacing, typography, useTheme } from "../../constants/theme";
import { maintenanceCategories } from "../../constants/content";
import { type MaintenanceItem, useRentalPlatform } from "../../state/rentalPlatform";
import { AccessGuard } from "../../components/AccessGuard";

export default function MaintenanceScreen() {
  const { colors: themeColors } = useTheme();
  const styles = createStyles(themeColors);
  const { state, addMaintenance, hasCapability, account, authUser, authError } = useRentalPlatform();
  const isTenant = account.accountType === "tenant";
  const activeLease = useActiveTenantLease(state, authUser?.id, authUser?.name);
  const maintenanceUnlocked = !isTenant || Boolean(activeLease);
  const canCreateMaintenance = isTenant && hasCapability("report_maintenance") && maintenanceUnlocked;
  const visibleRequests = useMemo(
    () => isTenant ? state.maintenance.filter((item) => sameTenant(item, authUser?.id, authUser?.name)) : state.maintenance,
    [authUser?.id, authUser?.name, isTenant, state.maintenance]
  );
  const [issue, setIssue] = useState("");
  const [category, setCategory] = useState("Plumbing");
  const [property, setProperty] = useState("");
  const [tenant, setTenant] = useState("");
  const [description, setDescription] = useState("");
  const [photoCount, setPhotoCount] = useState("");

  useEffect(() => {
    if (!isTenant || !activeLease) return;
    setTenant(activeLease.tenant);
    setProperty(activeLease.property);
  }, [activeLease, isTenant]);

  const submit = () => {
    if (!canCreateMaintenance) return;
    const tenantName = activeLease?.tenant || tenant.trim();
    const propertyName = activeLease?.property || property.trim();
    if (!issue.trim() || !propertyName || !tenantName) return;
    addMaintenance({
      issue: issue.trim(),
      category,
      property: propertyName,
      tenant: tenantName,
      propertyId: activeLease?.propertyId,
      tenantId: activeLease?.tenantId,
      description: description.trim(),
      photoCount: Number(photoCount) || 0,
      priority: "High",
      status: "Open",
      updatedAt: "Just now",
    });
    setIssue("");
    setDescription("");
    setPhotoCount("");
  };

  return (
    <AccessGuard section="maintenance" roles={["tenant", "landlord"]}>
      <Screen>
        <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
          <View style={styles.topBar}>
            <View style={styles.titleBlock}>
              <Text style={styles.brandMark}>P24</Text>
              <Text style={styles.screenTitle}>Maintenance</Text>
              <Text style={styles.screenMeta}>{isTenant ? activeLease?.property || "No active lease" : `${visibleRequests.length} tickets`}</Text>
            </View>
            <StatusPill ready={maintenanceUnlocked} />
          </View>

          <View style={styles.summaryStrip}>
            <View style={styles.summaryCard}>
              <Text style={styles.summaryLabel}>Open</Text>
              <Text style={styles.summaryValue}>{visibleRequests.filter((item) => item.status.toLowerCase() !== "resolved").length}</Text>
            </View>
            <View style={styles.summaryCard}>
              <Text style={styles.summaryLabel}>Urgent</Text>
              <Text style={styles.summaryValue}>{visibleRequests.filter((item) => item.priority.toLowerCase() === "high").length}</Text>
            </View>
          </View>

          {isTenant ? <OccupancyGate ready={Boolean(activeLease)} /> : null}

          {canCreateMaintenance ? (
            <View style={styles.panel}>
              <Text style={styles.panelTitle}>New request</Text>
              <TextInput value={issue} onChangeText={setIssue} placeholder="Issue" placeholderTextColor={themeColors.textMuted} style={styles.input} />
              <View style={styles.categoryRow}>
                {maintenanceCategories.map((entry) => (
                  <Pressable key={entry} onPress={() => setCategory(entry)} style={[styles.categoryChip, category === entry && styles.categoryChipActive]}>
                    <Text style={[styles.categoryText, category === entry && styles.categoryTextActive]}>{entry}</Text>
                  </Pressable>
                ))}
              </View>
              <TextInput editable={false} value={property} placeholder="Property" placeholderTextColor={themeColors.textMuted} style={[styles.input, styles.lockedInput]} />
              <TextInput value={description} onChangeText={setDescription} placeholder="Details" placeholderTextColor={themeColors.textMuted} style={[styles.input, styles.textArea]} multiline />
              <TextInput value={photoCount} onChangeText={setPhotoCount} keyboardType="number-pad" placeholder="Photos" placeholderTextColor={themeColors.textMuted} style={styles.input} />
              <Pressable onPress={submit} style={styles.button}><Text style={styles.buttonText}>Submit</Text></Pressable>
            </View>
          ) : null}

          {authError ? <Text style={styles.errorText}>{authError}</Text> : null}

          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Tickets</Text>
            <Text style={styles.sectionCount}>{visibleRequests.length}</Text>
          </View>
          <View style={styles.stack}>
            {visibleRequests.map((item) => <RequestRow key={item.id} item={item} />)}
            {!visibleRequests.length ? <Text style={styles.empty}>No maintenance tickets.</Text> : null}
          </View>
        </ScrollView>
      </Screen>
    </AccessGuard>
  );
}

function OccupancyGate({ ready }: { ready: boolean }) {
  const { colors: themeColors } = useTheme();
  const styles = createStyles(themeColors);
  return (
    <View style={[styles.gate, ready && styles.gateReady]}>
      <View style={styles.gateTitleRow}>
        <Ionicons name={ready ? "shield-checkmark" : "lock-closed-outline"} size={17} color={ready ? themeColors.success : themeColors.warning} />
        <Text style={styles.gateTitle}>{ready ? "Active lease" : "Locked"}</Text>
      </View>
      <View style={styles.stepRow}>
        <Ionicons name={ready ? "checkmark-circle" : "ellipse-outline"} size={15} color={ready ? themeColors.success : themeColors.textMuted} />
        <Text style={[styles.stepText, ready && styles.stepTextDone]}>Occupancy confirmed</Text>
      </View>
    </View>
  );
}

function StatusPill({ ready }: { ready: boolean }) {
  const { colors: themeColors } = useTheme();
  const styles = createStyles(themeColors);
  return <Text style={[styles.statusPill, ready ? styles.statusReady : styles.statusLocked]}>{ready ? "Ready" : "Locked"}</Text>;
}

function RequestRow({ item }: { item: MaintenanceItem }) {
  const { colors: themeColors } = useTheme();
  const styles = createStyles(themeColors);
  return (
    <View style={styles.rowCard}>
      <View style={styles.rowTop}>
        <Text numberOfLines={1} style={styles.rowTitle}>{item.issue}</Text>
        <Text style={styles.priority}>{item.priority}</Text>
      </View>
      <Text style={styles.rowMeta}>{item.category} · {item.property}</Text>
      {item.description ? <Text numberOfLines={2} style={styles.rowMeta}>{item.description}</Text> : null}
      <View style={styles.rowBottom}>
        <Text style={styles.rowStatus}>{item.status}</Text>
        <Text style={styles.rowTime}>{item.updatedAt}</Text>
      </View>
    </View>
  );
}

function useActiveTenantLease(state: ReturnType<typeof useRentalPlatform>["state"], userId?: string, userName?: string) {
  return useMemo(() => state.leases.find((lease) => sameTenant(lease, userId, userName) && isStatus(lease.status, "active")), [state.leases, userId, userName]);
}

function sameTenant(item: { tenant?: string; tenantId?: string }, userId?: string, userName?: string) {
  return Boolean((userId && item.tenantId === userId) || (userName && item.tenant === userName));
}

function isStatus(value: string, expected: string) {
  return value.toLowerCase().replace(/\s+/g, "_") === expected;
}

function createStyles(themeColors: typeof colors) {
  const colors = themeColors;
  return StyleSheet.create({
  content: { padding: spacing.md, paddingBottom: spacing.xl, gap: spacing.md, backgroundColor: colors.background },
  topBar: { flexDirection: "row", alignItems: "flex-start", justifyContent: "space-between", gap: spacing.md, borderWidth: 1, borderColor: colors.border, borderRadius: radius.lg, backgroundColor: colors.surfaceElevated, padding: spacing.md, ...shadows.card },
  summaryStrip: { flexDirection: "row", gap: spacing.sm },
  summaryCard: { flex: 1, borderWidth: 1, borderColor: colors.border, borderRadius: radius.md, backgroundColor: colors.surfaceElevated, padding: spacing.sm, ...shadows.soft },
  summaryLabel: { color: colors.textMuted, fontSize: 10, ...typography.label },
  summaryValue: { color: colors.text, fontSize: 18, marginTop: 4, ...typography.display },
  titleBlock: { flex: 1, minWidth: 0, gap: 3 },
  brandMark: { alignSelf: "flex-start", overflow: "hidden", borderRadius: 4, backgroundColor: colors.accent, color: colors.accentText, paddingHorizontal: 8, paddingVertical: 4, fontSize: 11, marginBottom: 4, ...typography.button },
  screenTitle: { color: colors.text, fontSize: 25, lineHeight: 30, ...typography.display },
  screenMeta: { color: colors.textMuted, fontSize: 12, marginTop: 2, ...typography.label },
  statusPill: { overflow: "hidden", borderRadius: 999, paddingHorizontal: 10, paddingVertical: 6, fontSize: 11, ...typography.button },
  statusReady: { color: colors.accentText, backgroundColor: colors.accent },
  statusLocked: { color: colors.warning, backgroundColor: "rgba(245,197,24,0.10)", borderWidth: 1, borderColor: "rgba(245,197,24,0.24)" },
  gate: { borderWidth: 1, borderColor: colors.border, borderLeftWidth: 3, borderLeftColor: colors.accent, borderRadius: radius.lg, backgroundColor: colors.surfaceElevated, padding: spacing.md, gap: spacing.sm, ...shadows.soft },
  gateReady: { borderColor: "rgba(229,9,20,0.44)", borderLeftColor: colors.accent },
  gateTitleRow: { flexDirection: "row", alignItems: "center", gap: 8 },
  gateTitle: { color: colors.text, fontSize: 14, ...typography.title },
  stepRow: { flexDirection: "row", alignItems: "center", gap: 5 },
  stepText: { color: colors.textMuted, fontSize: 12, ...typography.label },
  stepTextDone: { color: colors.text },
  panel: { borderWidth: 1, borderColor: colors.border, backgroundColor: colors.surfaceElevated, borderRadius: radius.lg, padding: spacing.md, gap: spacing.sm, ...shadows.card },
  panelTitle: { color: colors.text, fontSize: 16, lineHeight: 21, ...typography.title },
  input: { backgroundColor: colors.background, borderRadius: radius.md, borderWidth: 1, borderColor: colors.border, color: colors.text, minHeight: 44, paddingHorizontal: 11, outlineStyle: "none" as any, ...typography.body },
  lockedInput: { color: colors.textMuted, backgroundColor: colors.surfaceMuted },
  textArea: { minHeight: 82, paddingTop: 11, textAlignVertical: "top" },
  categoryRow: { flexDirection: "row", flexWrap: "wrap", gap: 7 },
  categoryChip: { borderWidth: 1, borderColor: colors.border, borderRadius: 999, paddingHorizontal: 10, paddingVertical: 7, backgroundColor: colors.background },
  categoryChipActive: { borderColor: colors.accent, backgroundColor: colors.accentSoft },
  categoryText: { color: colors.textMuted, fontSize: 11, ...typography.button },
  categoryTextActive: { color: colors.text },
  button: { backgroundColor: colors.accent, borderRadius: radius.md, alignItems: "center", paddingVertical: 12, ...shadows.soft },
  buttonText: { color: colors.accentText, ...typography.button },
  errorText: { color: colors.warning, fontSize: 12, lineHeight: 18, ...typography.label },
  sectionHeader: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", marginTop: 2 },
  sectionTitle: { color: colors.text, fontSize: 16, ...typography.title },
  sectionCount: { overflow: "hidden", borderRadius: 999, color: colors.text, backgroundColor: colors.surfaceMuted, paddingHorizontal: 9, paddingVertical: 4, fontSize: 11, ...typography.label },
  stack: { gap: spacing.sm },
  rowCard: { borderWidth: 1, borderColor: colors.border, borderLeftWidth: 3, borderLeftColor: colors.accent, backgroundColor: colors.surfaceElevated, borderRadius: radius.lg, padding: spacing.md, gap: 6, ...shadows.soft },
  rowTop: { flexDirection: "row", justifyContent: "space-between", gap: 10 },
  rowBottom: { flexDirection: "row", justifyContent: "space-between", gap: 10, marginTop: 2 },
  rowTitle: { flex: 1, color: colors.text, ...typography.title },
  priority: { overflow: "hidden", borderRadius: 999, color: colors.warning, backgroundColor: "rgba(245,197,24,0.10)", paddingHorizontal: 8, paddingVertical: 4, fontSize: 11, ...typography.label },
  rowMeta: { color: colors.textMuted, fontSize: 12, lineHeight: 18, ...typography.body },
  rowStatus: { color: colors.accent, fontSize: 12, ...typography.label },
  rowTime: { color: colors.textMuted, fontSize: 12, ...typography.body },
  empty: { color: colors.textMuted, ...typography.body },
  });
}
