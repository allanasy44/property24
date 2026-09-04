import { Link, useLocalSearchParams, useRouter } from "expo-router";
import { Image, ImageBackground, Pressable, ScrollView, Share, StyleSheet, Text, View, useWindowDimensions } from "react-native";
import { useMemo, useState } from "react";
import { Ionicons } from "@expo/vector-icons";
import { colors, radius, shadows, spacing, typography, useTheme } from "../../constants/theme";
import { Screen } from "../../components/Screen";
import { useRentalPlatform } from "../../state/rentalPlatform";

export default function PropertyDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const { height: windowHeight } = useWindowDimensions();
  const { state, addApplication, addViewing, authError, authUser, hasCapability, account } = useRentalPlatform();
  const { colors: themeColors } = useTheme();
  const [notice, setNotice] = useState("");
  const property = state.properties.find((entry) => entry.id === id);
  const canApply = hasCapability("apply_for_rentals");
  const canMessage = hasCapability("message_landlord_or_agent") || hasCapability("message_tenants") || hasCapability("message_clients");
  const lifecycle = usePropertyLifecycle(state, property?.id, authUser?.id, authUser?.name);
  const isTenant = account.accountType === "tenant";
  const styles = useMemo(
    () =>
      StyleSheet.create({
        screen: { flex: 1, backgroundColor: themeColors.background },
        content: { paddingBottom: 104, backgroundColor: themeColors.background },
        hero: { height: Math.max(330, Math.min(520, windowHeight * 0.44)), overflow: "hidden", borderBottomLeftRadius: 28, borderBottomRightRadius: 28, backgroundColor: themeColors.border },
        heroImage: { flex: 1, justifyContent: "space-between", padding: 14 },
        heroShade: { ...StyleSheet.absoluteFillObject, backgroundColor: "rgba(2,11,20,0.18)" },
        glassButton: { width: 42, height: 42, alignItems: "center", justifyContent: "center", borderRadius: 21, backgroundColor: "rgba(17,19,21,0.42)" },
        heroTop: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 8 },
        heroActions: { flexDirection: "row", gap: 8 },
        heroBottom: { gap: 12 },
        galleryRow: { flexDirection: "row", alignItems: "flex-end", justifyContent: "space-between", gap: 8 },
        playButton: { width: 42, height: 42, alignItems: "center", justifyContent: "center", borderRadius: 21, backgroundColor: "rgba(17,19,21,0.62)" },
        thumbnails: { flexDirection: "row", gap: 6 },
        thumbnail: { width: 48, height: 42, overflow: "hidden", borderRadius: 9, borderWidth: 1, borderColor: "rgba(255,255,255,0.72)" },
        thumbnailImage: { width: "100%", height: "100%" },
        galleryCount: { minHeight: 34, flexDirection: "row", alignItems: "center", gap: 5, borderRadius: 17, paddingHorizontal: 10, backgroundColor: "rgba(17,19,21,0.62)" },
        galleryCountText: { color: "#FFFFFF", fontSize: 12, ...typography.button },
        details: { padding: spacing.md, gap: 14, backgroundColor: themeColors.background },
        statusRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
        status: { flexDirection: "row", alignItems: "center", gap: 6 },
        statusDot: { width: 7, height: 7, borderRadius: 4, backgroundColor: themeColors.success },
        statusText: { color: themeColors.text, fontSize: 12, ...typography.label },
        statusPrice: { color: themeColors.accent, fontSize: 14, ...typography.title },
        title: { color: themeColors.text, fontSize: 28, lineHeight: 34, ...typography.display },
        priceRow: { flexDirection: "row", alignItems: "baseline", gap: 10 },
        price: { color: themeColors.text, fontSize: 31, lineHeight: 37, ...typography.display },
        estimate: { color: themeColors.textMuted, fontSize: 13, ...typography.body },
        meta: { color: themeColors.textMuted, ...typography.body },
        addressRow: { flexDirection: "row", alignItems: "center", gap: 7 },
        address: { flex: 1, color: themeColors.text, fontSize: 13, ...typography.body },
        deposit: { color: themeColors.textMuted, ...typography.label },
        description: { color: themeColors.textMuted, lineHeight: 22, ...typography.body },
        quickStats: { flexDirection: "row", gap: 7 },
        quickStat: { flex: 1, minHeight: 40, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 5, borderWidth: 1, borderColor: themeColors.border, borderRadius: 8, paddingHorizontal: 6, backgroundColor: themeColors.surface },
        quickStatText: { color: themeColors.text, fontSize: 11, ...typography.label },
        infoGrid: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
        infoCard: { width: "48%", minHeight: 86, justifyContent: "space-between", borderWidth: 1, borderColor: themeColors.border, borderRadius: 12, padding: 12, backgroundColor: themeColors.surface },
        infoLabel: { color: themeColors.textMuted, fontSize: 11, ...typography.label },
        infoValue: { color: themeColors.text, fontSize: 15, ...typography.title },
        gpsCard: { flexDirection: "row", alignItems: "center", gap: 8, paddingVertical: 4 },
        gpsText: { flex: 1, color: themeColors.textMuted, fontSize: 12, ...typography.body },
        lifecycleCard: { backgroundColor: themeColors.surfaceElevated, borderRadius: radius.lg, borderWidth: 1, borderColor: themeColors.border, padding: spacing.md, gap: spacing.sm, marginTop: spacing.sm },
        lifecycleTitle: { color: themeColors.text, fontSize: 16, ...typography.title },
        lifecycleText: { color: themeColors.textMuted, fontSize: 12, lineHeight: 18, ...typography.body },
        stepStack: { gap: 8 },
        stepRow: { flexDirection: "row", alignItems: "center", gap: 8 },
        stepText: { flex: 1, color: themeColors.textMuted, fontSize: 12, ...typography.label },
        stepTextDone: { color: themeColors.text },
        actionStack: { gap: spacing.sm, marginTop: spacing.sm },
        finalActionRow: { flexDirection: "row", flexWrap: "wrap", gap: spacing.sm },
        bottomBar: { position: "absolute", left: 0, right: 0, bottom: 0, flexDirection: "row", gap: 8, paddingHorizontal: 12, paddingTop: 10, paddingBottom: 12, borderTopWidth: 1, borderTopColor: themeColors.border, backgroundColor: themeColors.surface },
        primaryAction: { flex: 1, overflow: "hidden", backgroundColor: themeColors.accent, color: themeColors.accentText, paddingHorizontal: 12, paddingVertical: 13, borderRadius: 8, textAlign: "center", ...typography.button },
        secondaryButton: { flex: 1, backgroundColor: themeColors.surface, paddingHorizontal: 12, paddingVertical: 13, borderRadius: 8, borderWidth: 1, borderColor: themeColors.border },
        secondaryText: { color: themeColors.text, textAlign: "center", ...typography.button },
        secondaryLink: { overflow: "hidden", backgroundColor: themeColors.surface, color: themeColors.text, paddingHorizontal: 16, paddingVertical: 12, borderRadius: 8, borderWidth: 1, borderColor: themeColors.border, textAlign: "center", ...typography.button },
        notice: { color: themeColors.success, lineHeight: 18, ...typography.label },
        errorText: { color: themeColors.warning, lineHeight: 18, ...typography.label },
        readOnlyNote: { flex: 1, color: themeColors.textMuted, lineHeight: 20, ...typography.body },
        missingCard: { flex: 1, margin: spacing.lg, backgroundColor: themeColors.surfaceElevated, borderRadius: radius.lg, padding: spacing.lg, gap: 8, ...shadows.card },
        missingTitle: { color: themeColors.text, fontSize: 20, ...typography.title },
        missingBody: { color: themeColors.textMuted, lineHeight: 20, ...typography.body },
      }),
    [themeColors, windowHeight]
  );

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
    addViewing({ propertyId: property.id, property: property.title, agent: property.supplierName || "Property contact", tenantId: authUser?.id, tenant: authUser?.name || "Tenant", date, time: "10:00", status: "Pending" });
    setNotice("Viewing requested. Wait for the landlord or agent to confirm and complete it after the physical visit.");
  };

  const submitApplication = () => {
    addApplication({ propertyId: property.id, tenantId: authUser?.id, applicant: authUser?.name || "Tenant", property: property.title, role: "Tenant application after physical viewing", status: "Under review", score: 0, time: "Now" });
    setNotice("Application submitted. Payments remain locked until approval and signed lease.");
  };

  return (
    <Screen>
      <View style={styles.screen}>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <View style={styles.hero}>
          <ImageBackground source={{ uri: property.photos?.[0] || "https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&w=1200&q=80" }} resizeMode="cover" style={styles.heroImage}>
            <View style={styles.heroShade} />
            <View style={styles.heroTop}>
              <Pressable onPress={() => router.back()} style={styles.glassButton}><Ionicons name="arrow-back" size={21} color="#FFFFFF" /></Pressable>
              <View style={styles.heroActions}>
                <Pressable style={styles.glassButton}><Ionicons name="heart-outline" size={21} color="#FFFFFF" /></Pressable>
                <Pressable onPress={() => Share.share({ title: property.title, message: `${property.title} - ${property.address}` })} style={styles.glassButton}><Ionicons name="share-outline" size={20} color="#FFFFFF" /></Pressable>
                <Pressable style={styles.glassButton}><Ionicons name="ellipsis-horizontal" size={21} color="#FFFFFF" /></Pressable>
              </View>
            </View>
            <View style={styles.heroBottom}>
              <View style={styles.galleryRow}>
                <Pressable style={styles.playButton}><Ionicons name="play" size={17} color="#FFFFFF" /></Pressable>
                <View style={styles.thumbnails}>
                  {(property.photos?.slice(0, 3) || []).map((photo, index) => <Image key={`${photo}-${index}`} source={{ uri: photo }} style={styles.thumbnail} />)}
                  <View style={styles.galleryCount}><Ionicons name="images-outline" size={15} color="#FFFFFF" /><Text style={styles.galleryCountText}>{property.photos?.length || 0}</Text></View>
                </View>
              </View>
            </View>
          </ImageBackground>
        </View>

        <View style={styles.details}>
          <View style={styles.statusRow}><View style={styles.status}><View style={styles.statusDot} /><Text style={styles.statusText}>For sale</Text></View><Text style={styles.statusPrice}>{property.price}</Text></View>
          <Text style={styles.title}>{property.title}</Text>
          <View style={styles.priceRow}><Text style={styles.price}>{property.price}</Text><Text style={styles.estimate}>Est. {estimatedMonthly(property.price)}/mo</Text></View>
          <View style={styles.addressRow}><Ionicons name="location-outline" size={17} color={themeColors.accent} /><Text style={styles.address}>{property.address}, {property.city}</Text></View>

          <View style={styles.quickStats}>
            <QuickStat icon="bed-outline" label={`${property.bedrooms} Bed`} styles={styles} />
            <QuickStat icon="water-outline" label={`${property.bathrooms} Bath`} styles={styles} />
            <QuickStat icon="resize-outline" label="2,500 Sqft" styles={styles} />
            <QuickStat icon="expand-outline" label="" styles={styles} />
          </View>

          <View style={styles.infoGrid}>
            <InfoCard icon="home-outline" label="Property type" value={property.type} styles={styles} />
            <InfoCard icon="calendar-outline" label="Year built" value="2010" styles={styles} />
            <InfoCard icon="car-outline" label="Parking" value={property.parking} styles={styles} />
            <InfoCard icon="flash-outline" label="Power" value={property.solarPower ? "Solar backup" : property.power} styles={styles} />
          </View>
          <Text style={styles.description}>{property.description}</Text>
          <View style={styles.gpsCard}><Ionicons name="navigate-outline" size={17} color={colors.accent} /><Text style={styles.gpsText}>{property.gps}</Text></View>

          {isTenant ? <LifecyclePanel lifecycle={lifecycle} styles={styles} themeColors={themeColors} /> : null}
          {notice ? <Text style={styles.notice}>{notice}</Text> : null}
          {authError ? <Text style={styles.errorText}>{authError}</Text> : null}

          <View style={styles.actionStack}>
            {isTenant && lifecycle.viewing && !lifecycle.viewed ? (
              <Text style={styles.readOnlyNote}>Viewing status: {lifecycle.viewing.status}. Application and payment stay locked until the viewing is completed after the physical visit.</Text>
            ) : null}
            {isTenant && lifecycle.application && !lifecycle.applicationApproved ? <Text style={styles.readOnlyNote}>Application status: {lifecycle.application.status}. Lease and payments unlock after approval.</Text> : null}
            {isTenant && lifecycle.applicationApproved && !lifecycle.activeLease ? <Text style={styles.readOnlyNote}>Application approved. The landlord or agent must generate and sign the lease before payment opens.</Text> : null}
            {isTenant && lifecycle.activeLease ? (
              <View style={styles.finalActionRow}>
              </View>
            ) : null}
            {!isTenant && !canApply ? <Text style={styles.readOnlyNote}>{account.accountType} workspace can manage this listing without tenant application actions.</Text> : null}
          </View>
        </View>
      </ScrollView>
      <View style={styles.bottomBar}>
        {canMessage ? <Link href={{ pathname: "/inbox", params: { propertyId: property.id } }} asChild><Text style={styles.primaryAction}>Contact an Agent</Text></Link> : null}
        {isTenant ? <Pressable onPress={requestViewing} style={styles.secondaryButton}><Text style={styles.secondaryText}>Schedule Tour</Text></Pressable> : null}
      </View>
      </View>
    </Screen>
  );
}

function QuickStat({ icon, label, styles }: { icon: keyof typeof Ionicons.glyphMap; label: string; styles: any }) {
  return <View style={styles.quickStat}><Ionicons name={icon} size={16} color={styles.quickStatText.color} /><Text style={styles.quickStatText}>{label}</Text></View>;
}

function InfoCard({ icon, label, value, styles }: { icon: keyof typeof Ionicons.glyphMap; label: string; value: string; styles: any }) {
  return <View style={styles.infoCard}><Ionicons name={icon} size={18} color={styles.quickStatText.color} /><Text style={styles.infoLabel}>{label}</Text><Text numberOfLines={1} style={styles.infoValue}>{value || "Not specified"}</Text></View>;
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

function LifecyclePanel({ lifecycle, styles, themeColors }: { lifecycle: ReturnType<typeof usePropertyLifecycle>; styles: any; themeColors: any }) {
  const steps = [
    { label: "Request and physically complete viewing", done: lifecycle.viewed, active: !lifecycle.viewing },
    { label: "Apply only after viewing", done: lifecycle.applicationApproved, active: lifecycle.viewed && !lifecycle.application },
    { label: "Landlord approves application", done: lifecycle.applicationApproved, active: Boolean(lifecycle.application && !lifecycle.applicationApproved) },
    { label: "Signed active lease unlocks payment", done: Boolean(lifecycle.activeLease), active: lifecycle.applicationApproved && !lifecycle.activeLease },
  ];
  return (
    <View style={[styles.lifecycleCard, { backgroundColor: themeColors.surfaceElevated, borderColor: themeColors.border }] }>
      <Text style={[styles.lifecycleTitle, { color: themeColors.text }]}>Safe rental flow</Text>
      <Text style={[styles.lifecycleText, { color: themeColors.textMuted }]}>No deposit or repair request should happen from an advert alone. The app needs proof of viewing, approval, and lease status.</Text>
      <View style={styles.stepStack}>
        {steps.map((step) => (
          <View key={step.label} style={styles.stepRow}>
            <Ionicons name={step.done ? "checkmark-circle" : step.active ? "radio-button-on" : "ellipse-outline"} size={16} color={step.done ? themeColors.success : step.active ? themeColors.accent : themeColors.textMuted} />
            <Text style={[styles.stepText, step.done && styles.stepTextDone, { color: step.done ? themeColors.text : themeColors.textMuted }]}>{step.label}</Text>
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

function DetailPill({ label, styles }: { label: string; styles: any }) {
  return <Text style={styles.detailPill}>{label}</Text>;
}

function estimatedMonthly(value: string) {
  const amount = Number(value.replace(/[^0-9.]/g, ""));
  if (!Number.isFinite(amount) || amount <= 0) return "—";
  const monthly = amount > 10000 ? amount * 0.0032 : amount;
  return `$${Math.round(monthly).toLocaleString()}`;
}

