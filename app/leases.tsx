import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { useState } from "react";
import { Screen } from "../components/Screen";
import { SectionHeader } from "../components/SectionHeader";
import { colors, radius, shadows, spacing, typography, useTheme } from "../constants/theme";
import { useRentalPlatform } from "../state/rentalPlatform";
import { AccessGuard } from "../components/AccessGuard";

export default function LeasesScreen() {
  const { colors: themeColors } = useTheme();
  const styles = createStyles(themeColors);
  const { state, addLease, hasCapability } = useRentalPlatform();
  const canCreateLease = hasCapability("add_properties") || hasCapability("approve_tenants");
  const [property, setProperty] = useState("");
  const [tenant, setTenant] = useState("");
  const [landlord, setLandlord] = useState("");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [monthlyRent, setMonthlyRent] = useState("");
  const [deposit, setDeposit] = useState("");
  const [term, setTerm] = useState("12 Months");

  const submit = () => {
    if (!canCreateLease || !property.trim() || !tenant.trim() || !landlord.trim()) return;
    addLease({
      property: property.trim(),
      tenant: tenant.trim(),
      landlord: landlord.trim(),
      startDate: startDate.trim(),
      endDate: endDate.trim(),
      monthlyRent: formatMoney(monthlyRent),
      deposit: formatMoney(deposit),
      term: term.trim() || "12 Months",
      pdf: "Residential Lease Agreement",
      status: "Draft",
      signedByTenant: false,
      signedByLandlord: false,
    });
    setProperty("");
    setTenant("");
    setLandlord("");
    setStartDate("");
    setEndDate("");
    setMonthlyRent("");
    setDeposit("");
    setTerm("12 Months");
  };

  return (
    <AccessGuard section="leases" roles={["tenant", "landlord"]}>
      <Screen>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <View style={styles.hero}>
          <Text style={styles.kicker}>Digital lease agreements</Text>
          <Text style={styles.title}>Generate, review, and e-sign rental contracts on mobile.</Text>
        </View>

        {canCreateLease ? (
          <View style={styles.formCard}>
          <SectionHeader title="Create lease" subtitle="Adds contract to live lease records." />
          <TextInput value={landlord} onChangeText={setLandlord} placeholder="Landlord" placeholderTextColor={themeColors.textMuted} style={[styles.input, { color: themeColors.text }]} />
          <TextInput value={tenant} onChangeText={setTenant} placeholder="Tenant" placeholderTextColor={themeColors.textMuted} style={[styles.input, { color: themeColors.text }]} />
          <TextInput value={property} onChangeText={setProperty} placeholder="Property" placeholderTextColor={themeColors.textMuted} style={[styles.input, { color: themeColors.text }]} />
          <View style={styles.formRow}>
            <TextInput value={startDate} onChangeText={setStartDate} placeholder="Start date" placeholderTextColor={themeColors.textMuted} style={[styles.input, { flex: 1, color: themeColors.text }]} />
            <TextInput value={endDate} onChangeText={setEndDate} placeholder="End date" placeholderTextColor={themeColors.textMuted} style={[styles.input, { flex: 1, color: themeColors.text }]} />
          </View>
          <View style={styles.formRow}>
            <TextInput value={monthlyRent} onChangeText={setMonthlyRent} placeholder="Monthly rent" placeholderTextColor={themeColors.textMuted} style={[styles.input, { flex: 1, color: themeColors.text }]} />
            <TextInput value={deposit} onChangeText={setDeposit} placeholder="Deposit" placeholderTextColor={themeColors.textMuted} style={[styles.input, { flex: 1, color: themeColors.text }]} />
          </View>
          <TextInput value={term} onChangeText={setTerm} placeholder="Lease term, e.g. 12 Months" placeholderTextColor={themeColors.textMuted} style={[styles.input, { color: themeColors.text }]} />
          <Pressable onPress={submit} style={styles.button}><Text style={styles.buttonText}>Save lease</Text></Pressable>
          </View>
        ) : null}

        <SectionHeader title="Lease records" subtitle="Organized and ready for digital signatures." />
        <View style={styles.leaseStack}>
          {state.leases.map((lease) => (
            <View key={lease.id} style={styles.leaseCard}>
              <View style={styles.row}><Text style={styles.property}>{lease.property}</Text><Text style={styles.status}>{lease.status}</Text></View>
              <Text style={styles.meta}>Landlord: {lease.landlord}</Text>
              <Text style={styles.meta}>Tenant: {lease.tenant}</Text>
              <Text style={styles.meta}>{lease.startDate} to {lease.endDate}</Text>
              <Text style={styles.meta}>Rent {lease.monthlyRent || "Not set"} · Deposit {lease.deposit || "Not set"} · {lease.term || "Not set"}</Text>
              <Text style={styles.meta}>PDF: {lease.pdf ?? "Residential Lease Agreement"}</Text>
              <View style={styles.signatureRow}>
                <SignatureBubble label="Tenant signed" signed={lease.signedByTenant} />
                <SignatureBubble label="Landlord signed" signed={lease.signedByLandlord} />
              </View>
            </View>
          ))}
          {!state.leases.length ? <Text style={styles.empty}>No lease records yet.</Text> : null}
        </View>

        <SectionHeader title="Template preview" subtitle="Auto-generated from form fields." />
        <View style={styles.templateCard}>
          <Text style={styles.templateLine}>Residential Lease Agreement</Text>
          <Text style={styles.templateLine}>Landlord: {landlord || "Not selected"}</Text>
          <Text style={styles.templateLine}>Tenant: {tenant || "Not selected"}</Text>
          <Text style={styles.templateLine}>Property: {property || "Not selected"}</Text>
          <Text style={styles.templateLine}>Monthly Rent: {formatMoney(monthlyRent) || "Not set"}</Text>
          <Text style={styles.templateLine}>Deposit: {formatMoney(deposit) || "Not set"}</Text>
          <Text style={styles.templateLine}>Lease: {term || "12 Months"}</Text>
          <Text style={styles.templateLine}>Electronic signatures: Tenant and landlord</Text>
        </View>
        </ScrollView>
      </Screen>
    </AccessGuard>
  );
}

function SignatureBubble({ label, signed }: { label: string; signed: boolean }) {
  const { colors: themeColors } = useTheme();
  const styles = createStyles(themeColors);
  return (
    <View style={[styles.signatureBubble, signed ? styles.signed : styles.pending]}>
      <Ionicons name={signed ? "checkmark-circle-outline" : "time-outline"} size={16} color={signed ? themeColors.success : themeColors.warning} />
      <Text style={signed ? styles.signedText : styles.pendingText}>{label}</Text>
    </View>
  );
}

function formatMoney(value: string) {
  const cleaned = value.trim();
  if (!cleaned) return "";
  return cleaned.startsWith("$") ? cleaned : `$${cleaned}`;
}

function createStyles(themeColors: typeof colors) {
  return StyleSheet.create({
  content: { padding: spacing.lg, gap: spacing.lg },
  hero: { backgroundColor: themeColors.surfaceElevated, borderRadius: radius.xl, padding: spacing.lg, gap: spacing.sm, ...shadows.card },
  kicker: { color: themeColors.accent, textTransform: "uppercase", fontSize: 12, ...typography.label },
  title: { color: themeColors.text, fontSize: 28, lineHeight: 34, ...typography.display },
  formCard: { backgroundColor: themeColors.surfaceElevated, borderRadius: radius.lg, padding: spacing.md, gap: spacing.sm, ...shadows.soft },
  formRow: { flexDirection: "row", gap: spacing.sm },
  input: { backgroundColor: themeColors.background, borderRadius: radius.md, borderWidth: 1, borderColor: themeColors.border, color: themeColors.text, paddingHorizontal: 12, paddingVertical: 12, ...typography.body },
  button: { backgroundColor: themeColors.accent, borderRadius: radius.lg, alignItems: "center", paddingVertical: 14 },
  buttonText: { color: themeColors.accentText, ...typography.button },
  leaseStack: { gap: spacing.sm },
  leaseCard: { backgroundColor: themeColors.surfaceElevated, borderRadius: radius.lg, padding: spacing.md, gap: 6, ...shadows.soft },
  row: { flexDirection: "row", justifyContent: "space-between", gap: 10 },
  property: { flex: 1, color: themeColors.text, ...typography.title },
  status: { color: themeColors.accent, ...typography.label },
  meta: { color: themeColors.textMuted, lineHeight: 18, ...typography.body },
  signatureRow: { flexDirection: "row", flexWrap: "wrap", gap: spacing.sm, marginTop: 4 },
  signatureBubble: { flexDirection: "row", alignItems: "center", gap: 6, borderRadius: 999, paddingHorizontal: 10, paddingVertical: 8 },
  signed: { backgroundColor: themeColors.successSoft },
  pending: { backgroundColor: themeColors.warningSoft },
  signedText: { color: themeColors.success, ...typography.label },
  pendingText: { color: themeColors.warning, ...typography.label },
  templateCard: { backgroundColor: themeColors.surfaceElevated, borderRadius: radius.lg, padding: spacing.md, gap: 8, ...shadows.soft },
  templateLine: { color: themeColors.text, lineHeight: 20, ...typography.body },
  empty: { color: themeColors.textMuted, ...typography.body },
  });
}
