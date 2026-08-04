import { Link } from "expo-router";
import { useMemo, useState } from "react";
import { FlatList, ImageBackground, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { AccountRole, useRentalPlatform, useRentalPlatformStats } from "../../state/rentalPlatform";
import { colors, spacing, radius, shadows, typography } from "../../constants/theme";
import { quickActions, roleCards, trustSignals, journeyPoints } from "../../constants/content";
import { ActionCard } from "../../components/ActionCard";
import { LiveFeed } from "../../components/LiveFeed";
import { PropertyCard } from "../../components/PropertyCard";
import { SectionHeader } from "../../components/SectionHeader";
import { StatCard } from "../../components/StatCard";
import { Screen } from "../../components/Screen";

const typeFilters = ["All", "House", "Flat", "Cottage", "Student accommodation", "Commercial property"];
const bedroomFilters = ["Any", "1+", "2+", "3+", "4+"];

export default function HomeScreen() {
  const { state, account, authUser } = useRentalPlatform();
  const stats = useRentalPlatformStats();
  const visibleActions = quickActions.filter((action) => action.roles.includes(account.accountType));
  const currentRoleCards = roleCards.filter((item) => toAccountRole(item.title) === account.accountType);

  if (account.accountType === "tenant") {
    return <TenantHome state={state} visibleActions={visibleActions} userName={authUser?.name} verified={Boolean(authUser?.verified)} />;
  }

  const statCards = [
    { label: "Listings", value: `${stats.listings}`, detail: `${stats.verifiedProperties} verified in app` },
    { label: "Payments", value: `${stats.receivedPayments}`, detail: "Rent transactions recorded" },
    { label: "Open issues", value: `${stats.maintenanceOpen}`, detail: "Active maintenance requests" },
  ];

  return (
    <Screen>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <View style={styles.hero}>
          <View style={styles.heroTopRow}>
            <View>
              <Text style={styles.kicker}>Property24 Zimbabwe</Text>
              <Text style={styles.title}>Find, verify, rent, and manage homes with confidence.</Text>
            </View>
            <View style={styles.verifiedBadge}>
              <Ionicons name="shield-checkmark" size={18} color={colors.success} />
              <Text style={styles.verifiedText}>Verified</Text>
            </View>
          </View>

          <Text style={styles.heroBody}>
            Mobile-first rental operations for tenants, landlords, agents, and administrators.
          </Text>

          <View style={styles.heroStatsRow}>
            {statCards.map((item) => (
              <StatCard key={item.label} label={item.label} value={item.value} detail={item.detail} />
            ))}
          </View>

          <View style={styles.heroActions}>
            <Link href="/listings" asChild>
              <Text style={styles.primaryAction}>View listings</Text>
            </Link>
            <Link href="/operations" asChild>
              <Text style={styles.secondaryAction}>Open live ops</Text>
            </Link>
          </View>
        </View>

        <SectionHeader title="Current workspace" subtitle={`${roleLabel(account.accountType)} tools only.`} />
        <FlatList
          data={currentRoleCards}
          keyExtractor={(item) => item.title}
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.roleList}
          renderItem={({ item }) => (
            <View style={[styles.roleCard, { borderColor: item.accent }]}>
              <View style={[styles.roleIcon, { backgroundColor: item.accentSoft }]}>
                <Ionicons name={item.icon as keyof typeof Ionicons.glyphMap} size={20} color={item.accent} />
              </View>
              <Text style={styles.roleTitle}>{item.title}</Text>
              <Text style={styles.roleDescription}>{item.description}</Text>
            </View>
          )}
        />

        <SectionHeader title="Featured listings" subtitle="Driven by the live local store." />
        <View style={styles.propertyStack}>
          {state.properties.length ? (
            state.properties.map((property) => <PropertyCard key={property.id} property={property} />)
          ) : (
            <View style={styles.emptyCard}>
              <Text style={styles.emptyTitle}>No properties yet</Text>
              <Text style={styles.emptyBody}>Create your first listing in the Listings tab.</Text>
              <Link href="/listings" asChild>
                <Text style={styles.emptyAction}>Add first property</Text>
              </Link>
            </View>
          )}
        </View>

        <SectionHeader title="Core workflows" subtitle="Everything needed in one phone interface." />
        <View style={styles.actionsGrid}>
          {visibleActions.map((action) => (
            <ActionCard key={action.title} title={action.title} subtitle={action.subtitle} icon={action.icon as keyof typeof Ionicons.glyphMap} href={action.href} />
          ))}
        </View>

        <SectionHeader title="What users get" subtitle="Clear value per role." />
        <View style={styles.journeyGrid}>
          <JourneyCard title="Tenant" points={journeyPoints.Tenant} accent={colors.accent} />
          <JourneyCard title="Landlord" points={journeyPoints.Landlord} accent={colors.accent} />
          <JourneyCard title="Agent" points={journeyPoints.Agent} accent={colors.accent} />
          <JourneyCard title="Administrator" points={journeyPoints.Administrator} accent={colors.accent} />
        </View>

        <SectionHeader title="Live activity" subtitle="Updates when users perform actions in-app." />
        <LiveFeed items={state.liveEvents} />

        <SectionHeader title="Trust signals" subtitle="Verification and fraud-reduction controls." />
        <View style={styles.trustGrid}>
          {trustSignals.map((signal) => (
            <View key={signal.title} style={styles.trustCard}>
              <Ionicons name={signal.icon as keyof typeof Ionicons.glyphMap} size={18} color={colors.accent} />
              <Text style={styles.trustTitle}>{signal.title}</Text>
              <Text style={styles.trustDescription}>{signal.description}</Text>
            </View>
          ))}
        </View>
      </ScrollView>
    </Screen>
  );
}

function TenantHome({ state, visibleActions, userName, verified }: { state: ReturnType<typeof useRentalPlatform>["state"]; visibleActions: typeof quickActions; userName?: string; verified: boolean }) {
  const tenantVisibleProperties = useMemo(() => state.properties.filter(isVerifiedSupplierListing), [state.properties]);
  const verifiedCount = tenantVisibleProperties.length;
  const openMaintenance = state.maintenance.filter((item) => item.status.toLowerCase() !== "resolved").length;
  const [query, setQuery] = useState("");
  const [selectedType, setSelectedType] = useState("All");
  const [maxRent, setMaxRent] = useState("");
  const [bedrooms, setBedrooms] = useState("Any");

  const filteredProperties = useMemo(
    () =>
      tenantVisibleProperties.filter((property) => {
        const text = [property.title, property.address, property.city, property.suburb, property.type, property.description].join(" ").toLowerCase();
        const rent = parseMoney(property.price);
        const minimumBedrooms = bedrooms === "Any" ? 0 : Number(bedrooms.replace("+", ""));
        const matchesQuery = text.includes(query.trim().toLowerCase());
        const matchesType = selectedType === "All" || property.type.toLowerCase() === selectedType.toLowerCase();
        const matchesMaxRent = !maxRent.trim() || rent <= Number(maxRent);
        const matchesBedrooms = property.bedrooms >= minimumBedrooms;
        return matchesQuery && matchesType && matchesMaxRent && matchesBedrooms;
      }),
    [bedrooms, maxRent, query, selectedType, tenantVisibleProperties]
  );
  const featured = filteredProperties.slice(0, 6);
  const tenantActions = visibleActions.filter((action) => action.href !== "/");

  return (
    <Screen>
      <ScrollView contentContainerStyle={styles.tenantContent} showsVerticalScrollIndicator={false}>
        <View style={styles.tenantTopBar}>
          <View>
            <Text style={styles.tenantKicker}>Tenant workspace</Text>
            <Text style={styles.tenantTitle}>{userName ? `Hi, ${firstName(userName)}` : "Find verified rentals"}</Text>
          </View>
        </View>

        <View style={styles.tenantSearchPanel}>
          <View style={styles.tenantSearch}>
            <Ionicons name="search" size={19} color={colors.textMuted} />
            <TextInput
              value={query}
              onChangeText={setQuery}
              placeholder="Search city, suburb, or address"
              placeholderTextColor={colors.textMuted}
              autoCapitalize="none"
              style={styles.tenantSearchInput}
            />
            {query ? (
              <Pressable onPress={() => setQuery("")} hitSlop={10}>
                <Ionicons name="close-circle" size={18} color={colors.muted} />
              </Pressable>
            ) : (
              <Ionicons name="options-outline" size={18} color={colors.text} />
            )}
          </View>

          <View style={styles.tenantFilterRow}>
            <View style={[styles.tenantFilterChip, styles.tenantFilterChipActive]}>
              <Ionicons name="shield-checkmark-outline" size={15} color={colors.accent} />
              <Text style={[styles.tenantFilterText, styles.tenantFilterTextActive]}>Verified suppliers</Text>
            </View>
            <View style={styles.tenantRentInputWrap}>
              <Text style={styles.tenantCurrency}>$</Text>
              <TextInput value={maxRent} onChangeText={setMaxRent} keyboardType="number-pad" placeholder="Max rent" placeholderTextColor={colors.textMuted} style={styles.tenantRentInput} />
            </View>
          </View>

          <FlatList
            horizontal
            data={typeFilters}
            keyExtractor={(item) => item}
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.tenantHorizontalFilters}
            renderItem={({ item }) => (
              <Pressable onPress={() => setSelectedType(item)} style={[styles.tenantTypeChip, selectedType === item && styles.tenantTypeChipActive]}>
                <Text style={[styles.tenantTypeText, selectedType === item && styles.tenantTypeTextActive]}>{shortType(item)}</Text>
              </Pressable>
            )}
          />

          <View style={styles.tenantBedroomBlock}>
            <Text style={styles.tenantFilterLabel}>Bedrooms</Text>
            <View style={styles.tenantBedroomChips}>
              {bedroomFilters.map((item) => (
                <Pressable key={item} onPress={() => setBedrooms(item)} style={[styles.tenantBedroomChip, bedrooms === item && styles.tenantBedroomChipActive]}>
                  <Text style={[styles.tenantBedroomText, bedrooms === item && styles.tenantBedroomTextActive]}>{item}</Text>
                </Pressable>
              ))}
            </View>
          </View>
        </View>

        <FlatList
          data={filteredProperties.slice(0, 8)}
          keyExtractor={(item) => item.id}
          horizontal
          showsHorizontalScrollIndicator={false}
          style={styles.storyRailWrap}
          contentContainerStyle={styles.storyRail}
          renderItem={({ item }) => (
            <Link href={`/property/${item.id}`} asChild>
              <Pressable style={styles.storyItem}>
                <ImageBackground source={{ uri: storyImage(item.type, item.photos?.[0]) }} resizeMode="cover" style={styles.storyImage}>
                  <View style={styles.storyShade} />
                  <View style={styles.storyBadge}>
                    <Ionicons name={item.verified ? "shield-checkmark" : "time-outline"} size={12} color="#FFFFFF" />
                  </View>
                  {item.videoCount ? (
                    <View style={styles.storyVideoBadge}>
                      <Ionicons name="play" size={10} color="#FFFFFF" />
                    </View>
                  ) : null}
                </ImageBackground>
                <View style={styles.storyCopy}>
                  <Text style={styles.storyLabel} numberOfLines={1}>{item.suburb}</Text>
                  <Text style={styles.storyMeta} numberOfLines={1}>{item.price}</Text>
                </View>
              </Pressable>
            </Link>
          )}
        />

        <View style={styles.tenantTrustStrip}>
          <TrustPill icon="shield-checkmark" label={`${verifiedCount} verified homes`} />
          <TrustPill icon="lock-closed" label="Private chat" />
          <TrustPill icon="receipt" label="Rent history" />
        </View>

        <View style={styles.tenantStatusPanel}>
          <View style={styles.statusMetric}>
            <Text style={styles.statusValue}>{verified ? "Verified" : "Pending"}</Text>
            <Text style={styles.statusLabel}>Profile checks</Text>
          </View>
          <View style={styles.statusDivider} />
          <View style={styles.statusMetric}>
            <Text style={styles.statusValue}>{state.applications.length}</Text>
            <Text style={styles.statusLabel}>Applications</Text>
          </View>
          <View style={styles.statusDivider} />
          <View style={styles.statusMetric}>
            <Text style={styles.statusValue}>{openMaintenance}</Text>
            <Text style={styles.statusLabel}>Maintenance</Text>
          </View>
        </View>

        <View style={styles.tenantSectionRow}>
          <Text style={styles.tenantSectionTitle}>Available house posts</Text>
          <Text style={styles.tenantSeeAll}>{filteredProperties.length} homes</Text>
        </View>
        <View style={styles.propertyStack}>
          {featured.length ? (
            featured.map((property) => <PropertyCard key={property.id} property={property} variant="feed" />)
          ) : (
            <View style={styles.emptyCard}>
              <Text style={styles.emptyTitle}>No homes match that search</Text>
              <Text style={styles.emptyBody}>Try another suburb, rent range, property type, or bedroom filter.</Text>
            </View>
          )}
        </View>

        <View style={styles.tenantSectionRow}>
          <Text style={styles.tenantSectionTitle}>For you</Text>
        </View>
        <View style={styles.tenantActionList}>
          {tenantActions.slice(0, 4).map((action) => (
            <Link key={action.title} href={action.href} asChild>
              <Pressable style={styles.tenantActionItem}>
                <View style={styles.tenantActionIcon}>
                  <Ionicons name={action.icon as keyof typeof Ionicons.glyphMap} size={18} color={colors.text} />
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={styles.tenantActionTitle}>{action.title}</Text>
                  <Text style={styles.tenantActionSubtitle} numberOfLines={1}>{action.subtitle}</Text>
                </View>
                <Ionicons name="chevron-forward" size={17} color={colors.muted} />
              </Pressable>
            </Link>
          ))}
        </View>
      </ScrollView>
    </Screen>
  );
}

function TrustPill({ icon, label }: { icon: keyof typeof Ionicons.glyphMap; label: string }) {
  return (
    <View style={styles.trustPill}>
      <Ionicons name={icon} size={14} color={colors.success} />
      <Text style={styles.trustPillText}>{label}</Text>
    </View>
  );
}

function toAccountRole(value: string): AccountRole {
  if (value === "Landlord") return "landlord";
  if (value === "Agent") return "agent";
  if (value === "Administrator") return "admin";
  return "tenant";
}

function roleLabel(role: AccountRole) {
  return role === "admin" ? "Administrator" : role.charAt(0).toUpperCase() + role.slice(1);
}

function firstName(name: string) {
  return name.trim().split(/\s+/)[0];
}

function parseMoney(value: string) {
  const amount = Number(value.replace(/[^0-9.]/g, ""));
  return Number.isFinite(amount) ? amount : 0;
}

function shortType(value: string) {
  if (value === "Student accommodation") return "Student";
  if (value === "Commercial property") return "Commercial";
  return value;
}

function isVerifiedSupplierListing(property: ReturnType<typeof useRentalPlatform>["state"]["properties"][number]) {
  return property.verified && property.supplierVerified !== false;
}

function storyImage(type: string, photo?: string) {
  if (photo?.startsWith("http")) return photo;
  const normalized = type.toLowerCase();
  if (normalized.includes("flat")) return "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=400&q=80&auto=format&fit=crop";
  if (normalized.includes("cottage")) return "https://images.unsplash.com/photo-1518780664697-55e3ad937233?w=400&q=80&auto=format&fit=crop";
  if (normalized.includes("student")) return "https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=400&q=80&auto=format&fit=crop";
  if (normalized.includes("commercial")) return "https://images.unsplash.com/photo-1497366754035-f200968a6e72?w=400&q=80&auto=format&fit=crop";
  return "https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=400&q=80&auto=format&fit=crop";
}

function JourneyCard({ title, points, accent }: { title: string; points: string[]; accent: string }) {
  return (
    <View style={styles.journeyCard}>
      <Text style={[styles.journeyTitle, { color: accent }]}>{title}</Text>
      {points.slice(0, 3).map((point) => (
        <View key={point} style={styles.journeyPointRow}>
          <View style={[styles.journeyDot, { backgroundColor: accent }]} />
          <Text style={styles.journeyPoint}>{point}</Text>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  tenantContent: { paddingHorizontal: 10, paddingTop: 8, paddingBottom: spacing.xl, gap: 6, backgroundColor: colors.background },
  tenantTopBar: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", gap: spacing.sm },
  tenantKicker: { color: colors.textMuted, fontSize: 10, textTransform: "uppercase", ...typography.label },
  tenantTitle: { color: colors.text, fontSize: 22, lineHeight: 27, marginTop: 0, ...typography.display },
  tenantSearchPanel: { gap: 6 },
  tenantSearch: { minHeight: 42, flexDirection: "row", alignItems: "center", gap: 7, backgroundColor: colors.surfaceElevated, borderRadius: 8, borderWidth: 1, borderColor: colors.border, paddingHorizontal: 11 },
  tenantSearchInput: { flex: 1, minWidth: 0, color: colors.text, fontSize: 13, outlineStyle: "none" as any, ...typography.body },
  tenantFilterRow: { flexDirection: "row", gap: 6 },
  tenantFilterChip: { minHeight: 32, flexDirection: "row", alignItems: "center", gap: 5, borderRadius: 8, borderWidth: 1, borderColor: colors.border, paddingHorizontal: 9, backgroundColor: colors.surfaceElevated },
  tenantFilterChipActive: { borderColor: colors.accent, backgroundColor: colors.accentSoft },
  tenantFilterText: { color: colors.textMuted, fontSize: 11, ...typography.button },
  tenantFilterTextActive: { color: colors.accent },
  tenantRentInputWrap: { flex: 1, minHeight: 32, flexDirection: "row", alignItems: "center", gap: 3, borderRadius: 8, borderWidth: 1, borderColor: colors.border, paddingHorizontal: 10, backgroundColor: colors.surfaceElevated },
  tenantCurrency: { color: colors.text, ...typography.button },
  tenantRentInput: { flex: 1, minWidth: 0, color: colors.text, fontSize: 12, outlineStyle: "none" as any, ...typography.body },
  tenantHorizontalFilters: { gap: 6, paddingRight: 12 },
  tenantTypeChip: { minHeight: 30, justifyContent: "center", borderRadius: 8, borderWidth: 1, borderColor: colors.border, paddingHorizontal: 10, backgroundColor: colors.surfaceElevated },
  tenantTypeChipActive: { borderColor: colors.accent, backgroundColor: colors.accent },
  tenantTypeText: { color: colors.textMuted, fontSize: 11, ...typography.button },
  tenantTypeTextActive: { color: "#FFFFFF" },
  tenantBedroomBlock: { gap: 5 },
  tenantFilterLabel: { color: colors.textMuted, fontSize: 10, textTransform: "uppercase", ...typography.label },
  tenantBedroomChips: { flexDirection: "row", gap: 6 },
  tenantBedroomChip: { flex: 1, minHeight: 30, alignItems: "center", justifyContent: "center", borderRadius: 8, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.surfaceElevated },
  tenantBedroomChipActive: { borderColor: colors.accent, backgroundColor: colors.accentSoft },
  tenantBedroomText: { color: colors.textMuted, fontSize: 11, ...typography.button },
  tenantBedroomTextActive: { color: colors.accent },
  tenantTrustStrip: { flexDirection: "row", flexWrap: "wrap", gap: 6 },
  trustPill: { minHeight: 26, flexDirection: "row", alignItems: "center", gap: 4, borderRadius: 999, paddingHorizontal: 8, backgroundColor: colors.successSoft },
  trustPillText: { color: colors.success, fontSize: 10, ...typography.button },
  tenantStatusPanel: { flexDirection: "row", alignItems: "center", borderWidth: 1, borderColor: colors.border, borderRadius: radius.lg, backgroundColor: colors.surfaceElevated, paddingVertical: 8 },
  statusMetric: { flex: 1, alignItems: "center", gap: 1, paddingHorizontal: 4 },
  statusValue: { color: colors.text, fontSize: 13, ...typography.title },
  statusLabel: { color: colors.textMuted, fontSize: 8, textTransform: "uppercase", ...typography.label },
  statusDivider: { width: 1, height: 22, backgroundColor: colors.border },
  storyRailWrap: { height: 48, flexGrow: 0 },
  storyRail: { gap: 3, alignItems: "flex-start", paddingRight: 6, paddingTop: 0, paddingBottom: 0 },
  storyItem: { width: 40, height: 48, alignItems: "center", gap: 0 },
  storyImage: { width: 34, height: 34, borderRadius: 17, overflow: "hidden", justifyContent: "flex-start", alignItems: "flex-end", padding: 2, borderWidth: 1.5, borderColor: colors.accent, backgroundColor: colors.border },
  storyShade: { position: "absolute", top: 0, right: 0, bottom: 0, left: 0, backgroundColor: "rgba(0,0,0,0.08)" },
  storyBadge: { width: 14, height: 14, borderRadius: 7, alignItems: "center", justifyContent: "center", backgroundColor: "rgba(17,19,21,0.72)" },
  storyVideoBadge: { position: "absolute", left: 2, bottom: 2, width: 13, height: 13, borderRadius: 7, alignItems: "center", justifyContent: "center", backgroundColor: colors.danger },
  storyCopy: { width: "100%", alignItems: "center", gap: 0 },
  storyLabel: { width: "100%", color: colors.text, fontSize: 7, lineHeight: 8, textAlign: "center", ...typography.label },
  storyMeta: { width: "100%", color: colors.textMuted, fontSize: 6, lineHeight: 7, textAlign: "center", ...typography.body },
  tenantSectionRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: spacing.sm, marginTop: 0 },
  tenantSectionTitle: { color: colors.text, fontSize: 16, lineHeight: 20, ...typography.title },
  tenantSeeAll: { color: colors.accent, fontSize: 13, ...typography.button },
  tenantActionList: { borderTopWidth: 1, borderColor: colors.border },
  tenantActionItem: { minHeight: 58, flexDirection: "row", alignItems: "center", gap: spacing.sm, borderBottomWidth: 1, borderColor: colors.border },
  tenantActionIcon: { width: 34, height: 34, borderRadius: 8, alignItems: "center", justifyContent: "center", backgroundColor: colors.surfaceMuted },
  tenantActionTitle: { color: colors.text, fontSize: 14, ...typography.title },
  tenantActionSubtitle: { color: colors.textMuted, fontSize: 12, marginTop: 2, ...typography.body },
  content: { padding: spacing.lg, gap: spacing.lg },
  hero: { backgroundColor: colors.surfaceElevated, borderRadius: radius.xl, padding: spacing.lg, gap: spacing.md, ...shadows.card },
  heroTopRow: { flexDirection: "row", justifyContent: "space-between", gap: spacing.md },
  kicker: { color: colors.accent, fontSize: 12, textTransform: "uppercase", marginBottom: 6, ...typography.label },
  title: { color: colors.text, fontSize: typography.heroSize, lineHeight: typography.heroLineHeight, maxWidth: 280, ...typography.display },
  verifiedBadge: { flexDirection: "row", alignItems: "center", alignSelf: "flex-start", gap: 6, backgroundColor: colors.successSoft, paddingHorizontal: 10, paddingVertical: 8, borderRadius: 999 },
  verifiedText: { color: colors.success, fontSize: 13, ...typography.label },
  heroBody: { color: colors.textMuted, fontSize: 15, lineHeight: 22, ...typography.body },
  heroStatsRow: { flexDirection: "row", flexWrap: "wrap", gap: spacing.sm },
  heroActions: { flexDirection: "row", gap: spacing.sm },
  primaryAction: { backgroundColor: colors.accent, color: colors.accentText, paddingHorizontal: 16, paddingVertical: 12, borderRadius: 8, overflow: "hidden", ...typography.button },
  secondaryAction: { backgroundColor: colors.surface, color: colors.text, paddingHorizontal: 16, paddingVertical: 12, borderRadius: 8, borderWidth: 1, borderColor: colors.border, overflow: "hidden", ...typography.button },
  roleList: { gap: spacing.md, paddingRight: spacing.lg },
  roleCard: { width: 178, backgroundColor: colors.surfaceElevated, borderRadius: radius.lg, padding: spacing.md, gap: 10, borderWidth: 1, borderColor: colors.border, ...shadows.soft },
  roleIcon: { width: 40, height: 40, borderRadius: 8, alignItems: "center", justifyContent: "center" },
  roleTitle: { color: colors.text, fontSize: 16, ...typography.title },
  roleDescription: { color: colors.textMuted, lineHeight: 20, fontSize: 13, ...typography.body },
  propertyStack: { gap: spacing.md },
  emptyCard: { backgroundColor: colors.surfaceElevated, borderRadius: radius.lg, padding: spacing.lg, gap: 8, ...shadows.soft },
  emptyTitle: { color: colors.text, fontSize: 16, ...typography.title },
  emptyBody: { color: colors.textMuted, lineHeight: 20, ...typography.body },
  emptyAction: { color: colors.accent, ...typography.button },
  actionsGrid: { flexDirection: "row", flexWrap: "wrap", gap: spacing.sm },
  journeyGrid: { flexDirection: "row", flexWrap: "wrap", gap: spacing.sm },
  journeyCard: { width: "48%", backgroundColor: colors.surfaceElevated, borderRadius: radius.lg, padding: spacing.md, gap: 8, ...shadows.soft },
  journeyTitle: { fontSize: 15, ...typography.title },
  journeyPointRow: { flexDirection: "row", alignItems: "flex-start", gap: 8 },
  journeyDot: { width: 8, height: 8, borderRadius: 99, marginTop: 6 },
  journeyPoint: { flex: 1, color: colors.textMuted, lineHeight: 18, fontSize: 12, ...typography.body },
  trustGrid: { flexDirection: "row", flexWrap: "wrap", gap: spacing.md },
  trustCard: { flexGrow: 1, minWidth: "46%", backgroundColor: colors.surfaceElevated, borderRadius: radius.lg, padding: spacing.md, gap: 8, ...shadows.soft },
  trustTitle: { color: colors.text, fontSize: 15, ...typography.title },
  trustDescription: { color: colors.textMuted, lineHeight: 20, fontSize: 13, ...typography.body },
});
