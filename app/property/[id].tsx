import { Link, useLocalSearchParams } from "expo-router";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { useMemo, useState } from "react";
import { Ionicons } from "@expo/vector-icons";
import { colors, radius, shadows, spacing, typography } from "../../constants/theme";
import { Screen } from "../../components/Screen";
import { useRentalPlatform } from "../../state/rentalPlatform";

export default function PropertyDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { state, addApplication, addViewing, authError, authUser, hasCapability, account } = useRentalPlatform();
  const [notice, setNotice] = useState("");
  const property = state.properties.find((entry) => entry.id === id);
  const canApply = hasCapability("apply_for_rentals");
  const canMessage = hasCapability("message_landlord_or_agent") || hasCapability("message_tenants") || hasCapability("message_clients");
  const lifecycle = usePropertyLifecycle(state, property?.id, authUser?.id, authUser?.name);
  const isTenant = account.accountType === "tenant";

  if (!property) {
    return (
      <Screen>
        <View style={styles.missingCard}>
          <Text style={styles.missingTitle}>Property not found</Text>
          <Text style={styles.missingBody}>Return to listings and select an available property.</Text>
          <Link href="/listings" asChild>
            <Text style={styles.primaryAction}>Back to listings</Text>
          </Link>
        </View>
      </Screen>
    );
  }

  const requestViewing = () => {
    const date = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
    addViewing({ propertyId: property.id, property: property.title, agent: property.supplierName || "Verified supplier", tenantId: authUser?.id, tenant: authUser?.name || "Tenant", date, time: "10:00", status: "Pending" });
    setNotice("Viewing requested. Wait for the landlord or agent to confirm and complete it after the physical visit.");
  };

  const submitApplication = () => {
    addApplication({ propertyId: property.id, tenantId: authUser?.id, applicant: authUser?.name || "Tenant", property: property.title, role: "Tenant application after physical viewing", status: "Under review", score: 0, time: "Now" });
    setNotice("Application submitted. Payments remain locked until approval and signed lease.");
  };

  return (
    <Screen>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <View style={styles.hero}>
          <Text style={styles.badge}>{property.verified ? "Verified listing" : "Pending verification"}</Text>
          <Text style={styles.title}>{property.title}</Text>
          <Text style={styles.meta}>{property.city}, {property.suburb}</Text>
          <Text style={styles.address}>{property.address}</Text>
          <Text style={styles.price}>{property.price}</Text>
          <Text style={styles.deposit}>Deposit {property.deposit ?? "Required"}</Text>
          <Text style={styles.description}>{property.description}</Text>

          <View style={styles.mediaRow}>
            <DetailPill label={`${property.bedrooms} bedrooms`} />
            <DetailPill label={`${property.bathrooms} bathrooms`} />
            <DetailPill label={property.furnished} />
            <DetailPill label={`${property.videoCount} videos`} />
            <DetailPill label={property.tourAvailable ? "360 tour ready" : "360 tour future"} />
            <DetailPill label={property.type} />
            <DetailPill label={property.water} />
            <DetailPill label={property.solarPower ? "Solar power" : "No solar"} />
            <DetailPill label={property.borehole ? "Borehole" : "No borehole"} />
            <DetailPill label={property.petFriendly ? "Pet friendly" : "No pets"} />
            <DetailPill label={`${property.applicationsCount ?? 0} applications`} />
          </View>

          <View style={styles.gpsCard}>
            <Ionicons name="location-outline" size={18} color={colors.accent} />
            <Text style={styles.gpsText}>{property.gps}</Text>
          </View>

          {isTenant ? <LifecyclePanel lifecycle={lifecycle} /> : null}
          {notice ? <Text style={styles.notice}>{notice}</Text> : null}
          {authError ? <Text style={styles.errorText}>{authError}</Text> : null}

          <View style={styles.actionStack}>
            {canMessage ? (
              <Link href={{ pathname: "/inbox", params: { propertyId: property.id } }} asChild>
                <Text style={styles.primaryAction}>Message verified supplier</Text>
              </Link>
            ) : null}
            {isTenant && !lifecycle.viewing ? (
              <Pressable onPress={requestViewing} style={styles.secondaryButton}>
                <Text style={styles.secondaryText}>Request physical viewing</Text>
              </Pressable>
            ) : null}
            {isTenant && lifecycle.viewing && !lifecycle.viewed ? (
              <Text style={styles.readOnlyNote}>Viewing status: {lifecycle.viewing.status}. Application and payment stay locked until the viewing is completed after the physical visit.</Text>
            ) : null}
            {isTenant && lifecycle.viewed && !lifecycle.application && canApply ? (
              <Pressable onPress={submitApplication} style={styles.secondaryButton}>
                <Text style={styles.secondaryText}>Apply after viewing</Text>
              </Pressable>
            ) : null}
            {isTenant && lifecycle.application && !lifecycle.applicationApproved ? <Text style={styles.readOnlyNote}>Application status: {lifecycle.application.status}. Lease and payments unlock after approval.</Text> : null}
            {isTenant && lifecycle.applicationApproved && !lifecycle.activeLease ? <Text style={styles.readOnlyNote}>Application approved. The landlord or agent must generate and sign the lease before payment opens.</Text> : null}
            {isTenant && lifecycle.activeLease ? (
              <View style={styles.finalActionRow}>
                <Link href="/maintenance" asChild><Text style={styles.secondaryLink}>Maintenance</Text></Link>
              </View>
            ) : null}
            {!isTenant && !canApply ? <Text style={styles.readOnlyNote}>{account.accountType} workspace can manage this listing without tenant application actions.</Text> : null}
          </View>
        </View>
      </ScrollView>
    </Screen>
  );
}

function usePropertyLifecycle(state: ReturnType<typeof useRentalPlatform>["state"], propertyId?: string, userId?: string, userName?: string) {
  return useMemo(() => {
    const viewing = state.viewings.find((item) => sameTenant(item, userId, userName) && samePropertyId(item, propertyId));
    const application = state.applications.find((item) => sameTenant(item, userId, userName) && samePropertyId(item, propertyId));
    const activeLease = state.leases.find((item) => sameTenant(item, userId, userName) && samePropertyId(item, propertyId) && isStatus(item.status, "active"));
    const viewed = Boolean(viewing && isStatus(viewing.status, "completed"));
    const applicationApproved = Boolean(application && isStatus(application.status, "approved"));
    return { viewing, viewed, application, applicationApproved, activeLease };
  }, [propertyId, state.applications, state.leases, state.viewings, userId, userName]);
}

function LifecyclePanel({ lifecycle }: { lifecycle: ReturnType<typeof usePropertyLifecycle> }) {
  const steps = [
    { label: "Request and physically complete viewing", done: lifecycle.viewed, active: !lifecycle.viewing },
    { label: "Apply only after viewing", done: lifecycle.applicationApproved, active: lifecycle.viewed && !lifecycle.application },
    { label: "Landlord approves application", done: lifecycle.applicationApproved, active: Boolean(lifecycle.application && !lifecycle.applicationApproved) },
    { label: "Signed active lease unlocks payment", done: Boolean(lifecycle.activeLease), active: lifecycle.applicationApproved && !lifecycle.activeLease },
  ];
  return (
    <View style={styles.lifecycleCard}>
      <Text style={styles.lifecycleTitle}>Safe rental flow</Text>
      <Text style={styles.lifecycleText}>No deposit or repair request should happen from an advert alone. The app needs proof of viewing, approval, and lease status.</Text>
      <View style={styles.stepStack}>
        {steps.map((step) => (
          <View key={step.label} style={styles.stepRow}>
            <Ionicons name={step.done ? "checkmark-circle" : step.active ? "radio-button-on" : "ellipse-outline"} size={16} color={step.done ? colors.success : step.active ? colors.accent : colors.textMuted} />
            <Text style={[styles.stepText, step.done && styles.stepTextDone]}>{step.label}</Text>
          </View>
        ))}
      </View>
    </View>
  );
}

function sameTenant(item: { tenant?: string; tenantId?: string }, userId?: string, userName?: string) {
  return Boolean((userId && item.tenantId === userId) || (userName && item.tenant === userName));
}

function samePropertyId(item: { propertyId?: string }, propertyId?: string) {
  return Boolean(propertyId && item.propertyId === propertyId);
}

function isStatus(value: string, expected: string) {
  return value.toLowerCase().replace(/\s+/g, "_") === expected;
}

function DetailPill({ label }: { label: string }) {
  return <Text style={styles.detailPill}>{label}</Text>;
}

const styles = StyleSheet.create({
  content: { padding: spacing.lg, gap: spacing.md },
  hero: { backgroundColor: colors.surfaceElevated, borderRadius: radius.xl, padding: spacing.lg, gap: spacing.sm, ...shadows.card },
  badge: { color: colors.success, backgroundColor: colors.successSoft, alignSelf: "flex-start", paddingHorizontal: 12, paddingVertical: 8, borderRadius: 999, ...typography.button },
  title: { color: colors.text, fontSize: 28, lineHeight: 34, ...typography.display },
  meta: { color: colors.textMuted, ...typography.body },
  address: { color: colors.text, ...typography.label },
  price: { color: colors.accent, fontSize: 26, lineHeight: 31, marginTop: 6, ...typography.display },
  deposit: { color: colors.textMuted, ...typography.label },
  description: { color: colors.textMuted, lineHeight: 22, ...typography.body },
  mediaRow: { flexDirection: "row", flexWrap: "wrap", gap: 8, marginTop: 4 },
  detailPill: { backgroundColor: colors.background, color: colors.text, borderWidth: 1, borderColor: colors.border, borderRadius: 999, paddingHorizontal: 10, paddingVertical: 6, fontSize: 12, ...typography.label },
  gpsCard: { flexDirection: "row", alignItems: "center", gap: 8, backgroundColor: colors.background, borderRadius: radius.lg, paddingHorizontal: 12, paddingVertical: 10 },
  gpsText: { color: colors.textMuted, ...typography.body },
  lifecycleCard: { backgroundColor: "#0B0B0B", borderRadius: radius.lg, borderWidth: 1, borderColor: colors.border, padding: spacing.md, gap: spacing.sm, marginTop: spacing.sm },
  lifecycleTitle: { color: colors.text, fontSize: 16, ...typography.title },
  lifecycleText: { color: colors.textMuted, fontSize: 12, lineHeight: 18, ...typography.body },
  stepStack: { gap: 8 },
  stepRow: { flexDirection: "row", alignItems: "center", gap: 8 },
  stepText: { flex: 1, color: colors.textMuted, fontSize: 12, ...typography.label },
  stepTextDone: { color: colors.text },
  actionStack: { gap: spacing.sm, marginTop: spacing.sm },
  finalActionRow: { flexDirection: "row", flexWrap: "wrap", gap: spacing.sm },
  primaryAction: { overflow: "hidden", backgroundColor: colors.accent, color: colors.accentText, paddingHorizontal: 16, paddingVertical: 12, borderRadius: 8, textAlign: "center", ...typography.button },
  secondaryButton: { backgroundColor: colors.surface, paddingHorizontal: 16, paddingVertical: 12, borderRadius: 8, borderWidth: 1, borderColor: colors.border },
  secondaryText: { color: colors.text, textAlign: "center", ...typography.button },
  secondaryLink: { overflow: "hidden", backgroundColor: colors.surface, color: colors.text, paddingHorizontal: 16, paddingVertical: 12, borderRadius: 8, borderWidth: 1, borderColor: colors.border, textAlign: "center", ...typography.button },
  notice: { color: colors.success, lineHeight: 18, ...typography.label },
  errorText: { color: colors.warning, lineHeight: 18, ...typography.label },
  readOnlyNote: { flex: 1, color: colors.textMuted, lineHeight: 20, ...typography.body },
  missingCard: { flex: 1, margin: spacing.lg, backgroundColor: colors.surfaceElevated, borderRadius: radius.lg, padding: spacing.lg, gap: 8, ...shadows.card },
  missingTitle: { color: colors.text, fontSize: 20, ...typography.title },
  missingBody: { color: colors.textMuted, lineHeight: 20, ...typography.body },
});
