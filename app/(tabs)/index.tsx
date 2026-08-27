import { Link } from "expo-router";
import { useMemo, useState } from "react";
import { FlatList, ImageBackground, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { AccountRole, RentalPlatformState, useRentalPlatform, useRentalPlatformStats } from "../../state/rentalPlatform";
import { colors, spacing, radius, shadows, typography } from "../../constants/theme";
import { quickActions } from "../../constants/content";
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


  if (account.accountType === "tenant") {
    return <TenantHome state={state} visibleActions={visibleActions} userName={authUser?.name} verified={Boolean(authUser?.verified)} />;
  }

  return <RoleDashboard role={account.accountType} state={state} stats={stats} visibleActions={visibleActions} userName={authUser?.name} profileStatus={authUser?.profileStatus} verified={Boolean(authUser?.verified)} />;
}

type DashboardMetric = {
  label: string;
  value: string;
  detail: string;
  icon: keyof typeof Ionicons.glyphMap;
};

type DashboardPanel = {
  title: string;
  subtitle: string;
  rows: Array<{ id: string; title: string; meta: string; status?: string }>;
  empty: string;
};

function RoleDashboard({ role, state, stats, visibleActions, userName, profileStatus, verified }: { role: Exclude<AccountRole, "tenant">; state: RentalPlatformState; stats: ReturnType<typeof useRentalPlatformStats>; visibleActions: typeof quickActions; userName?: string; profileStatus?: string; verified: boolean }) {
  const dashboard = getRoleDashboard(role, state, stats);
  const statusText = verified ? "Verified account" : profileStatus === "account_ready" ? "Basic account" : "Verification pending";
  const featured = state.properties[0] ?? {
    id: "featured",
    title: "Marbisa Residence",
    suburb: "Austin",
    city: "Austin, TX",
    price: "$475,000",
    bedrooms: 3,
    bathrooms: 2.5,
    type: "Single family",
    verified: true,
  };
  const featuredArea = "2,250 Sqft";
  const featuredYear = "2010";

  const filterPills = ["All", "Price", "Property", "Bed / Bath"];
  const pricePills = ["$20K", "$30K", "$50K", "$60K"];

  const featuredImage = featured.photos?.[0] || "https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&w=1200&q=80";

  return (
    <Screen>
      <ScrollView contentContainerStyle={styles.landlordContent} showsVerticalScrollIndicator={false}>
        <View style={styles.landlordTopRow}>
          <View>
            <Text style={styles.timeStamp}>9:30 PM</Text>
            <Text style={styles.greetingTitle}>Good morning, {userName ? firstName(userName) : roleLabel(role)}</Text>
          </View>
          <View style={styles.avatarBadge}>
            <Ionicons name="sunny-outline" size={16} color={colors.text} />
          </View>
        </View>

        <View style={styles.filterRail}>
          {['Overview', 'Properties', 'Finance', 'Insights'].map((item, index) => (
            <View key={item} style={[styles.filterChip, index === 0 && styles.filterChipActive]}>
              <Text style={[styles.filterChipText, index === 0 && styles.filterChipTextActive]}>{item}</Text>
            </View>
          ))}
        </View>

        <View style={styles.searchCard}>
          <Ionicons name="search-outline" size={16} color={colors.textMuted} />
          <Text style={styles.searchPlaceholder}>Search listings, tenants, or locations</Text>
        </View>

        <View style={styles.featureCard}>
          <ImageBackground source={{ uri: featuredImage }} resizeMode="cover" style={styles.featureImage}>
            <View style={styles.featureGradient} />
            <View style={styles.featureHeaderRow}>
              <View style={styles.featureBadge}><Text style={styles.featureBadgeText}>Featured</Text></View>
              <View style={styles.featureMetaBadge}>
                <Ionicons name="shield-checkmark" size={13} color={colors.success} />
                <Text style={styles.featureMetaText}>{featured.verified ? "Verified" : "Review"}</Text>
              </View>
            </View>
            <View style={styles.featureBodyRow}>
              <View style={styles.featureTextBlock}>
                <Text style={styles.featureLabel}>Featured property</Text>
                <Text style={styles.featureTitle}>{featured.title}</Text>
                <Text style={styles.featureLocation}>{featured.city || "Harare, Zimbabwe"}</Text>
              </View>
              <View style={styles.priceBubble}>
                <Text style={styles.priceBubbleText}>{featured.price || "$450,000"}</Text>
              </View>
            </View>
          </ImageBackground>
        </View>

        <View style={styles.portfolioSummary}>
          <View style={styles.portfolioHeaderRow}>
            <Text style={styles.portfolioTitle}>Portfolio summary</Text>
            <Text style={styles.sectionAction}>This month</Text>
          </View>
          <View style={styles.quickStatRow}>
            <View style={styles.quickStat}>
              <Text style={styles.quickStatValue}>{dashboard.metrics[0]?.value ?? '0'}</Text>
              <Text style={styles.quickStatLabel}>Listings</Text>
            </View>
            <View style={styles.quickStat}>
              <Text style={styles.quickStatValue}>{dashboard.metrics[1]?.value ?? '0'}</Text>
              <Text style={styles.quickStatLabel}>Revenue</Text>
            </View>
            <View style={styles.quickStat}>
              <Text style={styles.quickStatValue}>{dashboard.metrics[2]?.value ?? '0'}</Text>
              <Text style={styles.quickStatLabel}>Alerts</Text>
            </View>
          </View>
        </View>

        <View style={styles.featureDetailRow}>
          <View style={styles.featureDetailPill}>
            <Ionicons name="bed-outline" size={14} color={colors.textMuted} />
            <Text style={styles.featureDetailText}>{featured.bedrooms || 3} beds</Text>
          </View>
          <View style={styles.featureDetailPill}>
            <Ionicons name="water-outline" size={14} color={colors.textMuted} />
            <Text style={styles.featureDetailText}>{featured.borehole ? "Borehole" : featured.water || "Mains water"}</Text>
          </View>
          <View style={styles.featureDetailPill}>
            <Ionicons name="flash-outline" size={14} color={colors.textMuted} />
            <Text style={styles.featureDetailText}>{featured.solarPower ? "Solar" : featured.power || "Grid"}</Text>
          </View>
        </View>

        <View style={styles.metricGrid}>
          {dashboard.metrics.map((metric) => (
            <View key={metric.label} style={styles.metricCard}>
              <View style={styles.metricCardTop}>
                <Ionicons name={metric.icon} size={18} color={colors.accentStrong} />
                <Text style={styles.metricCardValue}>{metric.value}</Text>
              </View>
              <Text style={styles.metricLabel}>{metric.label}</Text>
              <Text style={styles.metricDetail}>{metric.detail}</Text>
            </View>
          ))}
        </View>

        <View style={styles.insightStrip}>
          <View style={styles.insightCard}>
            <Text style={styles.insightBadge}>Occupancy</Text>
            <Text style={styles.insightValue}>{dashboard.metrics[3]?.value ?? '0%'}</Text>
          </View>
          <View style={styles.insightCard}>
            <Text style={styles.insightBadge}>Verified</Text>
            <Text style={styles.insightValue}>{state.properties.filter((item) => item.verified).length}</Text>
          </View>
          <View style={styles.insightCard}>
            <Text style={styles.insightBadge}>Open tasks</Text>
            <Text style={styles.insightValue}>{state.maintenance.filter((item) => item.status.toLowerCase() !== "resolved").length}</Text>
          </View>
        </View>

        {state.liveEvents.length ? (
          <View style={styles.sectionHeaderRow}>
            <Text style={styles.sectionTitle}>Live activity</Text>
            <Text style={styles.sectionAction}>See all</Text>
          </View>
        ) : null}

        <LiveFeed items={state.liveEvents} />
      </ScrollView>
    </Screen>
  );
}

function getRoleDashboard(role: Exclude<AccountRole, "tenant">, state: RentalPlatformState, stats: ReturnType<typeof useRentalPlatformStats>): { metrics: DashboardMetric[]; panels: DashboardPanel[] } {
  const openMaintenance = state.maintenance.filter((item) => item.status.toLowerCase() !== "resolved");
  const listings = state.properties.slice(0, 4).map((item) => ({ id: item.id, title: item.title, meta: [item.suburb, item.price].filter(Boolean).join(" · "), status: item.verified ? "Verified" : "Review" }));
  const payments = state.payments.slice(0, 4).map((item) => ({ id: item.id, title: item.tenant || "Tenant", meta: [item.property, item.method].filter(Boolean).join(" · "), status: item.amount }));
  const maintenance = openMaintenance.slice(0, 4).map((item) => ({ id: item.id, title: item.issue, meta: [item.property, item.category].filter(Boolean).join(" · "), status: item.status }));
  const applications = state.applications.slice(0, 4).map((item) => ({ id: item.id, title: item.applicant, meta: item.property, status: item.status }));
  const viewings = state.viewings.slice(0, 4).map((item) => ({ id: item.id, title: item.property, meta: [item.tenant, item.date, item.time].filter(Boolean).join(" · "), status: item.status }));
  const verifications = state.verifications.slice(0, 4).map((item) => ({ id: item.id, title: item.name, meta: item.role, status: item.status }));
  const conversations = state.conversations.slice(0, 4).map((item) => ({ id: item.id, title: item.name, meta: item.preview, status: item.time }));

  if (role === "landlord") {
    return {
      metrics: [
        { label: "Listings", value: String(stats.listings), detail: `${stats.verifiedProperties} verified`, icon: "home-outline" },
        { label: "Rent", value: String(stats.receivedPayments), detail: "payments received", icon: "card-outline" },
        { label: "Maintenance", value: String(openMaintenance.length), detail: "open requests", icon: "construct-outline" },
        { label: "Occupancy", value: `${stats.occupiedRate}%`, detail: "active leases", icon: "stats-chart-outline" },
      ],
      panels: [
        { title: "Listings", subtitle: "Your properties", rows: listings, empty: "No properties have been listed yet." },
        { title: "Applications", subtitle: "Tenant requests", rows: applications, empty: "No applications yet." },
        { title: "Maintenance", subtitle: "Active work", rows: maintenance, empty: "No maintenance requests yet." },
      ],
    };
  }

  if (role === "agent") {
    return {
      metrics: [
        { label: "Listings", value: String(stats.listings), detail: "assigned properties", icon: "business-outline" },
        { label: "Viewings", value: String(stats.viewings), detail: "scheduled visits", icon: "calendar-outline" },
        { label: "Applications", value: String(stats.applications), detail: "tracked tenants", icon: "document-text-outline" },
        { label: "Chats", value: String(state.conversations.length), detail: "listing contacts", icon: "chatbubbles-outline" },
      ],
      panels: [
        { title: "Viewings", subtitle: "Physical house visits", rows: viewings, empty: "No viewings scheduled yet." },
        { title: "Applications", subtitle: "Pipeline", rows: applications, empty: "No applications yet." },
        { title: "Conversations", subtitle: "Listing chats", rows: conversations, empty: "No listing conversations yet." },
      ],
    };
  }

  return {
    metrics: [
      { label: "Verifications", value: String(stats.verifications), detail: "user checks", icon: "shield-checkmark-outline" },
      { label: "Listings", value: String(stats.listings), detail: `${stats.verifiedProperties} verified`, icon: "home-outline" },
      { label: "Payments", value: String(state.payments.length), detail: "records", icon: "wallet-outline" },
      { label: "Reports", value: String(openMaintenance.length), detail: "open issues", icon: "alert-circle-outline" },
    ],
    panels: [
      { title: "Verification queue", subtitle: "Trust checks", rows: verifications, empty: "No verification requests yet." },
      { title: "Listings", subtitle: "Marketplace", rows: listings, empty: "No properties have been listed yet." },
      { title: "Maintenance", subtitle: "Dispute signals", rows: maintenance, empty: "No open maintenance reports." },
    ],
  };
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
                {storyImage(item.photos?.[0]) ? (
                <ImageBackground source={{ uri: storyImage(item.photos?.[0]) }} resizeMode="cover" style={styles.storyImage}>
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
                ) : (
                  <View style={[styles.storyImage, styles.storyImageEmpty]}>
                    <Ionicons name="image-outline" size={14} color={colors.textMuted} />
                  </View>
                )}
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

function storyImage(photo?: string) {
  return photo?.startsWith("http") ? photo : "";
}

const styles = StyleSheet.create({
  landlordContent: { paddingHorizontal: 10, paddingTop: 8, paddingBottom: spacing.xl, gap: 12, backgroundColor: colors.background },
  landlordTopRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "flex-start", gap: 10 },
  timeStamp: { color: colors.muted, fontSize: 12, ...typography.label },
  greetingTitle: { color: colors.text, fontSize: 23, lineHeight: 28, marginTop: 3, ...typography.display },
  avatarBadge: { width: 38, height: 38, borderRadius: 14, backgroundColor: "#eef2ff", alignItems: "center", justifyContent: "center", borderWidth: 1, borderColor: "rgba(30,41,59,0.08)" },
  filterRail: { flexDirection: "row", gap: 8, marginTop: 2 },
  filterChip: { paddingHorizontal: 14, paddingVertical: 8, borderRadius: 999, backgroundColor: colors.surfaceElevated, borderWidth: 1, borderColor: colors.border },
  filterChipActive: { backgroundColor: colors.accent, borderColor: colors.accent },
  filterChipText: { color: colors.textMuted, fontSize: 11, ...typography.label },
  filterChipTextActive: { color: colors.accentText },
  searchCard: { flexDirection: "row", alignItems: "center", gap: 8, paddingHorizontal: 12, paddingVertical: 10, borderRadius: 16, backgroundColor: colors.surfaceElevated, borderWidth: 1, borderColor: colors.border, ...shadows.soft },
  searchPlaceholder: { color: colors.textMuted, fontSize: 12, ...typography.body },
  featureCard: { borderRadius: 28, overflow: "hidden", borderWidth: 1, borderColor: colors.border, ...shadows.card },
  featureImage: { width: "100%", minHeight: 230, padding: 16, justifyContent: "space-between" },
  featureGradient: { position: "absolute", inset: 0, backgroundColor: "rgba(10,17,25,0.20)" },
  featureHeaderRow: { position: "relative", zIndex: 1, flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  featureBadge: { backgroundColor: "rgba(255,255,255,0.18)", borderWidth: 1, borderColor: "rgba(255,255,255,0.35)", borderRadius: 999, paddingHorizontal: 12, paddingVertical: 7 },
  featureBadgeText: { color: "#ffffff", fontSize: 11, ...typography.label },
  featureMetaBadge: { flexDirection: "row", alignItems: "center", gap: 4, backgroundColor: "rgba(255,255,255,0.18)", borderWidth: 1, borderColor: "rgba(255,255,255,0.35)", borderRadius: 999, paddingHorizontal: 10, paddingVertical: 7 },
  featureMetaText: { color: "#ffffff", fontSize: 11, ...typography.label },
  featureBodyRow: { position: "relative", zIndex: 1, flexDirection: "row", alignItems: "flex-end", justifyContent: "space-between", gap: 10 },
  featureTextBlock: { flex: 1, minWidth: 0 },
  featureLabel: { color: "rgba(255,255,255,0.8)", fontSize: 11, ...typography.label },
  featureTitle: { color: "#ffffff", fontSize: 22, lineHeight: 26, marginTop: 2, ...typography.display },
  featureLocation: { color: "rgba(255,255,255,0.82)", fontSize: 12, marginTop: 4, ...typography.body },
  priceBubble: { backgroundColor: "rgba(255,255,255,0.18)", borderWidth: 1, borderColor: "rgba(255,255,255,0.32)", borderRadius: 18, paddingHorizontal: 12, paddingVertical: 10, maxWidth: 112 },
  priceBubbleText: { color: "#ffffff", fontSize: 14, textAlign: "center", ...typography.label },
  portfolioSummary: { backgroundColor: colors.surfaceElevated, borderRadius: 24, borderWidth: 1, borderColor: colors.border, padding: 12, gap: 10, ...shadows.soft },
  portfolioHeaderRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 8 },
  portfolioTitle: { color: colors.text, fontSize: 14, ...typography.title },
  quickStatRow: { flexDirection: "row", gap: 10 },
  quickStat: { flex: 1, paddingVertical: 12, paddingHorizontal: 12, borderRadius: 18, backgroundColor: colors.surfaceMuted, borderWidth: 1, borderColor: "rgba(148,163,184,0.15)" },
  quickStatValue: { color: colors.text, fontSize: 20, ...typography.display },
  quickStatLabel: { color: colors.textMuted, fontSize: 11, marginTop: 2, ...typography.label },
  featureDetailRow: { flexDirection: "row", gap: 8, flexWrap: "wrap" },
  featureDetailPill: { flexDirection: "row", alignItems: "center", gap: 6, paddingHorizontal: 10, paddingVertical: 8, borderRadius: 999, backgroundColor: colors.surfaceElevated, borderWidth: 1, borderColor: colors.border },
  featureDetailText: { color: colors.textMuted, fontSize: 11, ...typography.label },
  insightStrip: { flexDirection: "row", gap: 8 },
  insightCard: { flex: 1, backgroundColor: colors.surfaceElevated, borderWidth: 1, borderColor: colors.border, borderRadius: 18, paddingHorizontal: 12, paddingVertical: 10, ...shadows.soft },
  insightBadge: { color: colors.textMuted, fontSize: 10, ...typography.label },
  insightValue: { color: colors.text, fontSize: 18, marginTop: 4, ...typography.display },
  landlordHeaderRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 8 },
  locationTitle: { color: colors.text, fontSize: 24, lineHeight: 30, ...typography.title },
  filterRow: { flexDirection: "row", alignItems: "center", flexWrap: "wrap", gap: 6, justifyContent: "flex-end" },
  filterPill: { backgroundColor: "#f8f9fc", paddingHorizontal: 12, paddingVertical: 8, borderRadius: 999, borderWidth: 1, borderColor: "transparent" },
  filterPillActive: { backgroundColor: colors.accent, borderColor: colors.accent },
  filterPillText: { color: colors.text, fontSize: 12, ...typography.body },
  filterPillTextActive: { color: "#ffffff" },
  featuredCard: { backgroundColor: colors.surfaceElevated, borderRadius: 32, borderWidth: 1, borderColor: colors.border, padding: 22, gap: 14, ...shadows.card },
  featuredTopRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 10 },
  badgeForSale: { backgroundColor: "#eef2ff", borderRadius: 40, paddingHorizontal: 14, paddingVertical: 5 },
  badgeText: { color: "#1e293b", fontSize: 12, fontWeight: "500" },
  featuredPriceText: { color: colors.textMuted, fontSize: 14, ...typography.body },
  priceRow: { flexDirection: "row", alignItems: "flex-end", gap: 8 },
  priceLarge: { color: colors.text, fontSize: 30, lineHeight: 35, ...typography.display },
  estimateText: { color: "#475569", fontSize: 14, ...typography.body },
  propertyAddress: { color: colors.text, fontSize: 16, ...typography.body },
  detailRow: { flexDirection: "row", alignItems: "center", gap: 8, flexWrap: "wrap" },
  detailText: { color: colors.text, fontSize: 13, ...typography.body },
  divider: { color: "#cbd5e1" },
  detailGrid: { flexDirection: "row", gap: 12 },
  detailCell: { flex: 1, minWidth: 0, backgroundColor: colors.surfaceMuted, borderRadius: 16, paddingHorizontal: 14, paddingVertical: 10 },
  detailLabel: { color: colors.textMuted, fontSize: 11, ...typography.label },
  detailValue: { color: colors.text, fontSize: 14, marginTop: 4, ...typography.body },
  primaryActionsRow: { flexDirection: "row", gap: 12 },
  primaryButton: { flex: 1, minHeight: 46, borderRadius: 999, backgroundColor: "#1e293b", alignItems: "center", justifyContent: "center", paddingHorizontal: 22 },
  primaryButtonText: { color: "#ffffff", fontSize: 14, fontWeight: "500" },
  secondaryButton: { flex: 1, minHeight: 46, borderRadius: 999, backgroundColor: "#ffffff", borderWidth: 1, borderColor: "#e2e8f0", alignItems: "center", justifyContent: "center", paddingHorizontal: 22 },
  secondaryButtonText: { color: "#1e293b", fontSize: 14, fontWeight: "500" },
  sectionHeaderRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 8, marginTop: 4 },
  sectionTitle: { color: colors.text, fontSize: 17, ...typography.title },
  sectionAction: { color: colors.accent, fontSize: 12, ...typography.label },
  metricGrid: { flexDirection: "row", flexWrap: "wrap", gap: 10 },
  metricCard: { flexGrow: 1, flexBasis: "47%", minHeight: 96, backgroundColor: colors.surfaceElevated, borderRadius: 24, borderWidth: 1, borderColor: colors.border, paddingHorizontal: 14, paddingVertical: 12, gap: 6, ...shadows.soft },
  metricCardTop: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 8 },
  metricCardValue: { color: colors.text, fontSize: 22, ...typography.display },
  metricLabel: { color: colors.text, fontSize: 13, ...typography.title },
  metricDetail: { color: colors.textMuted, fontSize: 11, ...typography.body },
  activityCard: { backgroundColor: colors.surfaceElevated, borderRadius: 28, borderWidth: 1, borderColor: colors.border, padding: 18, gap: 10, ...shadows.soft },
  activityHeaderRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 10 },
  activityPrice: { color: colors.text, fontSize: 18, ...typography.title },
  activityAddress: { color: colors.text, fontSize: 15, ...typography.body },
  activityMeta: { color: colors.textMuted, fontSize: 12, borderTopWidth: 1, borderTopColor: "#f1f5f9", paddingTop: 10, ...typography.body },
  inlinePriceGrid: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  priceGridItem: { minWidth: 80, backgroundColor: "#f8f9fc", borderRadius: 16, paddingHorizontal: 14, paddingVertical: 10, alignItems: "center", justifyContent: "center" },
  priceGridItemActive: { backgroundColor: "#ffffff", borderWidth: 1, borderColor: "#2563eb" },
  priceGridText: { color: colors.text, fontSize: 13, fontWeight: "500" },
  priceGridTextActive: { color: colors.text },
  dashboardContent: { paddingHorizontal: 10, paddingTop: 8, paddingBottom: spacing.xl, gap: 10, backgroundColor: colors.background },
  dashboardHero: { backgroundColor: colors.surfaceElevated, borderRadius: radius.lg, borderWidth: 1, borderColor: colors.border, padding: spacing.md, gap: 4, ...shadows.card },
  dashboardTitle: { color: colors.text, fontSize: 25, lineHeight: 30, ...typography.display },
  dashboardSubcopy: { color: colors.textMuted, fontSize: 13, ...typography.body },
  dashboardGrid: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  dashboardMetricCard: { flexGrow: 1, flexBasis: "47%", minHeight: 94, backgroundColor: colors.surfaceElevated, borderRadius: radius.lg, borderWidth: 1, borderColor: colors.border, padding: 12, gap: 6, ...shadows.soft },
  dashboardMetricTop: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 8 },
  dashboardMetricValue: { color: colors.text, fontSize: 22, ...typography.display },
  dashboardMetricLabel: { color: colors.text, fontSize: 13, ...typography.title },
  dashboardMetricDetail: { color: colors.textMuted, fontSize: 11, ...typography.body },
  dashboardSectionHeader: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: spacing.sm, marginTop: 2 },
  dashboardPanelStack: { gap: 8 },
  dashboardPanel: { backgroundColor: colors.surfaceElevated, borderRadius: radius.lg, borderWidth: 1, borderColor: colors.border, overflow: "hidden", ...shadows.soft },
  dashboardPanelHeader: { paddingHorizontal: 12, paddingTop: 12, paddingBottom: 8, borderBottomWidth: 1, borderColor: colors.border },
  dashboardPanelTitle: { color: colors.text, fontSize: 15, ...typography.title },
  dashboardPanelSubtitle: { color: colors.textMuted, fontSize: 11, marginTop: 2, ...typography.body },
  dashboardRow: { minHeight: 58, flexDirection: "row", alignItems: "center", gap: 10, paddingHorizontal: 12, borderBottomWidth: 1, borderColor: colors.border },
  dashboardRowAvatar: { width: 34, height: 34, borderRadius: 17, alignItems: "center", justifyContent: "center", backgroundColor: colors.surfaceMuted },
  dashboardRowInitial: { color: colors.text, fontSize: 13, ...typography.title },
  dashboardRowBody: { flex: 1, minWidth: 0 },
  dashboardRowTitle: { color: colors.text, fontSize: 13, ...typography.title },
  dashboardRowMeta: { color: colors.textMuted, fontSize: 11, marginTop: 2, ...typography.body },
  dashboardRowStatus: { color: colors.accent, fontSize: 11, ...typography.label },
  dashboardEmpty: { color: colors.textMuted, padding: 12, lineHeight: 18, ...typography.body },
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
  storyImageEmpty: { alignItems: "center", justifyContent: "center", backgroundColor: colors.surfaceMuted },
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
