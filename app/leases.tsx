import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { useState } from "react";
import { Screen } from "../components/Screen";
import { SectionHeader } from "../components/SectionHeader";
import { colors, radius, shadows, spacing, typography } from "../constants/theme";
import { useRentalPlatform } from "../state/rentalPlatform";
import { AccessGuard } from "../components/AccessGuard";

export default function LeasesScreen() {
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
      startDate: startDate.trim() || "2026-07-01",
      endDate: endDate.trim() || "2027-06-30",
      monthlyRent: formatMoney(monthlyRent) || "$450",
      deposit: formatMoney(deposit) || "$450",
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
          <TextInput value={landlord} onChangeText={setLandlord} placeholder="Landlord" placeholderTextColor={colors.textMuted} style={styles.input} />
          <TextInput value={tenant} onChangeText={setTenant} placeholder="Tenant" placeholderTextColor={colors.textMuted} style={styles.input} />
          <TextInput value={property} onChangeText={setProperty} placeholder="Property" placeholderTextColor={colors.textMuted} style={styles.input} />
          <View style={styles.formRow}>
            <TextInput value={startDate} onChangeText={setStartDate} placeholder="Start date" placeholderTextColor={colors.textMuted} style={[styles.input, { flex: 1 }]} />
            <TextInput value={endDate} onChangeText={setEndDate} placeholder="End date" placeholderTextColor={colors.textMuted} style={[styles.input, { flex: 1 }]} />
          </View>
          <View style={styles.formRow}>
            <TextInput value={monthlyRent} onChangeText={setMonthlyRent} placeholder="Monthly rent" placeholderTextColor={colors.textMuted} style={[styles.input, { flex: 1 }]} />
            <TextInput value={deposit} onChangeText={setDeposit} placeholder="Deposit" placeholderTextColor={colors.textMuted} style={[styles.input, { flex: 1 }]} />
          </View>
          <TextInput value={term} onChangeText={setTerm} placeholder="Lease term, e.g. 12 Months" placeholderTextColor={colors.textMuted} style={styles.input} />
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
              <Text style={styles.meta}>Rent {lease.monthlyRent ?? "$450"} · Deposit {lease.deposit ?? "$450"} · {lease.term ?? "12 Months"}</Text>
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
          <Text style={styles.templateLine}>Landlord: {landlord || "John Doe"}</Text>
          <Text style={styles.templateLine}>Tenant: {tenant || "Jane Smith"}</Text>
          <Text style={styles.templateLine}>Property: {property || "123 Borrowdale Road"}</Text>
          <Text style={styles.templateLine}>Monthly Rent: {formatMoney(monthlyRent) || "$450"}</Text>
          <Text style={styles.templateLine}>Deposit: {formatMoney(deposit) || "$450"}</Text>
          <Text style={styles.templateLine}>Lease: {term || "12 Months"}</Text>
          <Text style={styles.templateLine}>Electronic signatures: Tenant and landlord</Text>
        </View>
        </ScrollView>
      </Screen>
    </AccessGuard>
  );
}

function SignatureBubble({ label, signed }: { label: string; signed: boolean }) {
  return (
    <View style={[styles.signatureBubble, signed ? styles.signed : styles.pending]}>
      <Ionicons name={signed ? "checkmark-circle-outline" : "time-outline"} size={16} color={signed ? colors.success : colors.warning} />
      <Text style={signed ? styles.signedText : styles.pendingText}>{label}</Text>
    </View>
  );
}

function formatMoney(value: string) {
  const cleaned = value.trim();
  if (!cleaned) return "";
  return cleaned.startsWith("$") ? cleaned : `$${cleaned}`;
}

const styles = StyleSheet.create({
  content: { padding: spacing.lg, gap: spacing.lg },
  hero: { backgroundColor: colors.surfaceElevated, borderRadius: radius.xl, padding: spacing.lg, gap: spacing.sm, ...shadows.card },
  kicker: { color: colors.accent, textTransform: "uppercase", fontSize: 12, ...typography.label },
  title: { color: colors.text, fontSize: 28, lineHeight: 34, ...typography.display },
  formCard: { backgroundColor: colors.surfaceElevated, borderRadius: radius.lg, padding: spacing.md, gap: spacing.sm, ...shadows.soft },
  formRow: { flexDirection: "row", gap: spacing.sm },
  input: { backgroundColor: colors.background, borderRadius: radius.md, borderWidth: 1, borderColor: colors.border, color: colors.text, paddingHorizontal: 12, paddingVertical: 12, ...typography.body },
  button: { backgroundColor: colors.accent, borderRadius: radius.lg, alignItems: "center", paddingVertical: 14 },
  buttonText: { color: colors.accentText, ...typography.button },
  leaseStack: { gap: spacing.sm },
  leaseCard: { backgroundColor: colors.surfaceElevated, borderRadius: radius.lg, padding: spacing.md, gap: 6, ...shadows.soft },
  row: { flexDirection: "row", justifyContent: "space-between", gap: 10 },
  property: { flex: 1, color: colors.text, ...typography.title },
  status: { color: colors.accent, ...typography.label },
  meta: { color: colors.textMuted, lineHeight: 18, ...typography.body },
  signatureRow: { flexDirection: "row", flexWrap: "wrap", gap: spacing.sm, marginTop: 4 },
  signatureBubble: { flexDirection: "row", alignItems: "center", gap: 6, borderRadius: 999, paddingHorizontal: 10, paddingVertical: 8 },
  signed: { backgroundColor: colors.successSoft },
  pending: { backgroundColor: colors.warningSoft },
  signedText: { color: colors.success, ...typography.label },
  pendingText: { color: colors.warning, ...typography.label },
  templateCard: { backgroundColor: colors.surfaceElevated, borderRadius: radius.lg, padding: spacing.md, gap: 8, ...shadows.soft },
  templateLine: { color: colors.text, lineHeight: 20, ...typography.body },
  empty: { color: colors.textMuted, ...typography.body },
});
