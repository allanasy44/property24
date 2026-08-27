import { useEffect, useMemo, useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { Screen } from "../../components/Screen";
import { colors, radius, shadows, spacing, typography } from "../../constants/theme";
import { type LeaseItem, type PaymentItem, useRentalPlatform } from "../../state/rentalPlatform";
import { AccessGuard } from "../../components/AccessGuard";

const methods = ["EcoCash", "ZIPIT", "Bank transfer", "Visa/Mastercard"];

export default function PaymentsScreen() {
  const { state, addPayment, hasCapability, account, authUser, authError } = useRentalPlatform();
  const isTenant = account.accountType === "tenant";
  const isAdmin = account.accountType === "admin";
  const lifecycle = usePaymentLifecycle(state, authUser?.id, authUser?.name);
  const activeLease = lifecycle.activeLease;
  const paymentUnlocked = !isTenant || lifecycle.ready;
  const canRecordPayment = (hasCapability("pay_rent") && paymentUnlocked) || hasCapability("manage_payments");
  const visiblePayments = useMemo(
    () => isTenant ? state.payments.filter((item) => sameTenant(item, authUser?.id, authUser?.name)) : state.payments,
    [authUser?.id, authUser?.name, isTenant, state.payments]
  );
  const [tenant, setTenant] = useState("");
  const [property, setProperty] = useState("");
  const [amount, setAmount] = useState("");
  const [method, setMethod] = useState("EcoCash");

  useEffect(() => {
    if (!isTenant || !activeLease) return;
    setTenant(activeLease.tenant);
    setProperty(activeLease.property);
    setAmount(activeLease.deposit || activeLease.monthlyRent || "");
  }, [activeLease, isTenant]);

  const submit = () => {
    if (!canRecordPayment) return;
    const tenantName = isTenant && activeLease ? activeLease.tenant : tenant.trim();
    const propertyName = isTenant && activeLease ? activeLease.property : property.trim();
    const amountValue = amount.trim();
    if (!tenantName || !propertyName || !amountValue) return;
    addPayment({
      tenant: tenantName,
      property: propertyName,
      tenantId: activeLease?.tenantId,
      propertyId: activeLease?.propertyId,
      amount: formatMoney(amountValue),
      method,
      status: isTenant ? "Pending" : "Received",
      time: "Just now",
      reminderStatus: isTenant ? "Awaiting landlord confirmation" : "Recorded",
    });
    if (!isTenant) {
      setTenant("");
      setProperty("");
    }
    setAmount("");
  };

  return (
    <AccessGuard section="payments" roles={["tenant", "landlord", "admin"]}>
      <Screen>
        <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
          <View style={styles.topBar}>
            <View style={styles.titleBlock}>
              <Text style={styles.brandMark}>P24</Text>
              <Text style={styles.screenTitle}>Payments</Text>
              <Text style={styles.screenMeta}>{isTenant ? activeLease?.property || "No active lease" : `${visiblePayments.length} records`}</Text>
            </View>
            <StatusPill ready={paymentUnlocked || !isTenant} />
          </View>

          <View style={styles.summaryStrip}>
            <View style={styles.summaryCard}>
              <Text style={styles.summaryLabel}>Paid</Text>
              <Text style={styles.summaryValue}>{visiblePayments.filter((item) => item.status.toLowerCase() === "received").length}</Text>
            </View>
            <View style={styles.summaryCard}>
              <Text style={styles.summaryLabel}>Pending</Text>
              <Text style={styles.summaryValue}>{visiblePayments.filter((item) => item.status.toLowerCase() === "pending").length}</Text>
            </View>
          </View>

          {isTenant ? <PaymentGate steps={lifecycle.steps} /> : null}

          {canRecordPayment ? (
            <View style={styles.panel}>
              <Text style={styles.panelTitle}>{isAdmin ? "Record payment" : "Lease payment"}</Text>
              <TextInput editable={!isTenant} value={tenant} onChangeText={setTenant} placeholder="Tenant" placeholderTextColor={colors.textMuted} style={[styles.input, isTenant && styles.lockedInput]} />
              <TextInput editable={!isTenant} value={property} onChangeText={setProperty} placeholder="Property" placeholderTextColor={colors.textMuted} style={[styles.input, isTenant && styles.lockedInput]} />
              <TextInput value={amount} onChangeText={setAmount} placeholder="Amount" placeholderTextColor={colors.textMuted} keyboardType="decimal-pad" style={styles.input} />
              <View style={styles.methodRow}>
                {methods.map((entry) => (
                  <Pressable key={entry} onPress={() => setMethod(entry)} style={[styles.methodChip, method === entry && styles.methodChipActive]}>
                    <Text style={[styles.methodText, method === entry && styles.methodTextActive]}>{entry}</Text>
                  </Pressable>
                ))}
              </View>
              <Pressable onPress={submit} style={styles.button}>
                <Text style={styles.buttonText}>{isTenant ? "Submit" : "Save"}</Text>
              </Pressable>
            </View>
          ) : null}

          {authError ? <Text style={styles.errorText}>{authError}</Text> : null}

          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>History</Text>
            <Text style={styles.sectionCount}>{visiblePayments.length}</Text>
          </View>
          <View style={styles.stack}>
            {visiblePayments.map((payment) => <PaymentRow key={payment.id} payment={payment} />)}
            {!visiblePayments.length ? <Text style={styles.empty}>No payments yet.</Text> : null}
          </View>
        </ScrollView>
      </Screen>
    </AccessGuard>
  );
}

function PaymentGate({ steps }: { steps: { label: string; done: boolean }[] }) {
  const ready = steps.every((step) => step.done);
  return (
    <View style={[styles.gate, ready && styles.gateReady]}>
      <View style={styles.gateTitleRow}>
        <Ionicons name={ready ? "shield-checkmark" : "lock-closed-outline"} size={17} color={ready ? colors.success : colors.warning} />
        <Text style={styles.gateTitle}>{ready ? "Ready" : "Locked"}</Text>
      </View>
      <View style={styles.stepStack}>
        {steps.map((step) => (
          <View key={step.label} style={styles.stepRow}>
            <Ionicons name={step.done ? "checkmark-circle" : "ellipse-outline"} size={15} color={step.done ? colors.success : colors.textMuted} />
            <Text style={[styles.stepText, step.done && styles.stepTextDone]}>{step.label}</Text>
          </View>
        ))}
      </View>
    </View>
  );
}

function StatusPill({ ready }: { ready: boolean }) {
  return <Text style={[styles.statusPill, ready ? styles.statusReady : styles.statusLocked]}>{ready ? "Ready" : "Locked"}</Text>;
}

function PaymentRow({ payment }: { payment: PaymentItem }) {
  return (
    <View style={styles.rowCard}>
      <View style={styles.rowTop}>
        <Text numberOfLines={1} style={styles.rowTitle}>{payment.property}</Text>
        <Text style={styles.amount}>{payment.amount}</Text>
      </View>
      <Text style={styles.rowMeta}>{payment.tenant} · {payment.method}</Text>
      <View style={styles.rowBottom}>
        <Text style={styles.rowStatus}>{payment.status}</Text>
        <Text style={styles.rowTime}>{payment.time}</Text>
      </View>
    </View>
  );
}

function usePaymentLifecycle(state: ReturnType<typeof useRentalPlatform>["state"], userId?: string, userName?: string) {
  return useMemo(() => {
    const tenantLease = state.leases.find((lease) => sameTenant(lease, userId, userName) && isStatus(lease.status, "active"));
    const viewingDone = Boolean(tenantLease && state.viewings.some((viewing) => sameTenant(viewing, userId, userName) && sameProperty(viewing, tenantLease) && isStatus(viewing.status, "completed")));
    const applicationApproved = Boolean(tenantLease && state.applications.some((application) => sameTenant(application, userId, userName) && sameProperty(application, tenantLease) && isStatus(application.status, "approved")));
    const steps = [
      { label: "Viewing", done: viewingDone },
      { label: "Application", done: applicationApproved },
      { label: "Lease", done: Boolean(tenantLease) },
    ];
    return { activeLease: tenantLease, ready: steps.every((step) => step.done), steps };
  }, [state.applications, state.leases, state.viewings, userId, userName]);
}

function sameTenant(item: { tenant?: string; tenantId?: string }, userId?: string, userName?: string) {
  return Boolean((userId && item.tenantId === userId) || (userName && item.tenant === userName));
}

function sameProperty(item: { property?: string; propertyId?: string }, lease: LeaseItem) {
  return Boolean((item.propertyId && lease.propertyId && item.propertyId === lease.propertyId) || (item.property && item.property === lease.property));
}

function isStatus(value: string, expected: string) {
  return value.toLowerCase().replace(/\s+/g, "_") === expected;
}

function formatMoney(value: string) {
  const cleaned = value.trim();
  return cleaned.startsWith("$") ? cleaned : `$${cleaned}`;
}

const styles = StyleSheet.create({
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
  stepStack: { flexDirection: "row", flexWrap: "wrap", gap: spacing.sm },
  stepRow: { flexDirection: "row", alignItems: "center", gap: 5 },
  stepText: { color: colors.textMuted, fontSize: 12, ...typography.label },
  stepTextDone: { color: colors.text },
  panel: { borderWidth: 1, borderColor: colors.border, backgroundColor: colors.surfaceElevated, borderRadius: radius.lg, padding: spacing.md, gap: spacing.sm, ...shadows.card },
  panelTitle: { color: colors.text, fontSize: 16, lineHeight: 21, ...typography.title },
  input: { backgroundColor: colors.background, borderRadius: radius.md, borderWidth: 1, borderColor: colors.border, color: colors.text, minHeight: 44, paddingHorizontal: 11, outlineStyle: "none" as any, ...typography.body },
  lockedInput: { color: colors.textMuted, backgroundColor: "#101010" },
  methodRow: { flexDirection: "row", flexWrap: "wrap", gap: 7 },
  methodChip: { borderWidth: 1, borderColor: colors.border, borderRadius: 999, paddingHorizontal: 10, paddingVertical: 7, backgroundColor: colors.background },
  methodChipActive: { borderColor: colors.accent, backgroundColor: colors.accentSoft },
  methodText: { color: colors.textMuted, fontSize: 11, ...typography.button },
  methodTextActive: { color: colors.text },
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
  amount: { color: colors.accent, fontSize: 16, ...typography.display },
  rowMeta: { color: colors.textMuted, fontSize: 12, ...typography.body },
  rowStatus: { color: colors.accent, fontSize: 12, ...typography.label },
  rowTime: { color: colors.textMuted, fontSize: 12, ...typography.body },
  empty: { color: colors.textMuted, ...typography.body },
});
