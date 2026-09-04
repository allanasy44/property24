import { Ionicons } from "@expo/vector-icons";
import { Link, useLocalSearchParams, useRouter, type Href } from "expo-router";
import { useMemo, useState } from "react";
import { ImageBackground, Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { Screen } from "../../components/Screen";
import { colors, radius, shadows, spacing, typography, useTheme } from "../../constants/theme";
import { AccountRole, Property, useRentalPlatform } from "../../state/rentalPlatform";

type SupplierProfile = {
  id: string;
  name: string;
  role: AccountRole;
  verified: boolean;
  profilePicture?: string;
  coverPhoto?: string;
  bio?: string;
};

export default function SupplierProfileScreen() {
  const { id, propertyId } = useLocalSearchParams<{ id?: string; propertyId?: string }>();
  const router = useRouter();
  const supplierId = normalizeParam(id);
  const selectedPropertyId = normalizeParam(propertyId);
  const { state, authToken, hasCapability, startPropertyConversation, toggleSupplierFollow } = useRentalPlatform();
  const { colors: themeColors } = useTheme();
  const [following, setFollowing] = useState(false);
  const [notice, setNotice] = useState("");
  const [chatError, setChatError] = useState("");
  const [openingChat, setOpeningChat] = useState(false);
  const styles = useMemo(
    () =>
      StyleSheet.create({
        content: { paddingBottom: spacing.xl, backgroundColor: themeColors.background },
        profileHeader: { backgroundColor: themeColors.surface },
        cover: { height: 142, justifyContent: "flex-start", padding: 12, backgroundColor: themeColors.border },
        coverShade: { ...StyleSheet.absoluteFillObject, backgroundColor: "rgba(17,19,21,0.22)" },
        backButton: { width: 38, height: 38, borderRadius: 19, alignItems: "center", justifyContent: "center", backgroundColor: "rgba(17,19,21,0.68)" },
        identityBlock: { paddingHorizontal: 14, paddingBottom: 16, borderBottomWidth: 1, borderBottomColor: themeColors.border, backgroundColor: themeColors.surface },
        avatar: { width: 76, height: 76, borderRadius: 38, overflow: "hidden", alignItems: "center", justifyContent: "center", marginTop: -38, borderWidth: 4, borderColor: themeColors.surface, backgroundColor: themeColors.text },
        avatarImage: { width: "100%", height: "100%" },
        avatarText: { color: "#FFFFFF", fontSize: 24, ...typography.display },
        nameRow: { flexDirection: "row", alignItems: "center", gap: 10, marginTop: 10 },
        nameCopy: { flex: 1, minWidth: 0 },
        verifiedNameRow: { flexDirection: "row", alignItems: "center", gap: 5 },
        name: { flexShrink: 1, color: themeColors.text, fontSize: 23, lineHeight: 29, ...typography.display },
        handle: { color: themeColors.textMuted, fontSize: 12, marginTop: 2, ...typography.label },
        followButton: { minHeight: 34, justifyContent: "center", borderRadius: 999, borderWidth: 1, borderColor: themeColors.accent, paddingHorizontal: 16, backgroundColor: themeColors.accent },
        followButtonActive: { borderColor: themeColors.accent, backgroundColor: "transparent" },
        followText: { color: "#FFFFFF", fontSize: 12, ...typography.button },
        followTextActive: { color: themeColors.accent },
        bio: { color: themeColors.text, fontSize: 13, lineHeight: 20, marginTop: 12, ...typography.body },
        notice: { color: themeColors.success, fontSize: 12, marginTop: 8, ...typography.label },
        error: { color: themeColors.warning, fontSize: 12, marginTop: 8, ...typography.label },
        actionRow: { flexDirection: "row", alignItems: "center", gap: 8, marginTop: 13 },
        primaryAction: { flex: 1, minHeight: 42, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 7, borderRadius: 8, backgroundColor: themeColors.accent },
        primaryActionDisabled: { opacity: 0.65 },
        primaryText: { color: themeColors.accentText, fontSize: 13, ...typography.button },
        iconAction: { width: 42, height: 42, borderRadius: 21, alignItems: "center", justifyContent: "center", borderWidth: 1, borderColor: themeColors.border, backgroundColor: themeColors.surface },
        statsBand: { flexDirection: "row", alignItems: "center", marginTop: 10, borderTopWidth: 1, borderBottomWidth: 1, borderColor: themeColors.border, backgroundColor: themeColors.surface },
        stat: { flex: 1, minHeight: 62, alignItems: "center", justifyContent: "center", gap: 2 },
        statValue: { color: themeColors.text, fontSize: 16, ...typography.title },
        statLabel: { color: themeColors.textMuted, fontSize: 10, textTransform: "uppercase", ...typography.label },
        detailSection: { paddingHorizontal: 14, paddingVertical: 14, gap: 10, backgroundColor: themeColors.surface, borderBottomWidth: 1, borderBottomColor: themeColors.border },
        sectionTitle: { color: themeColors.text, fontSize: 17, lineHeight: 22, ...typography.title },
        detailRow: { flexDirection: "row", alignItems: "flex-start", gap: 10 },
        detailIcon: { width: 34, height: 34, borderRadius: 8, alignItems: "center", justifyContent: "center", backgroundColor: themeColors.accentSoft },
        detailCopy: { flex: 1, minWidth: 0 },
        detailLabel: { color: themeColors.text, fontSize: 12, ...typography.label },
        detailValue: { color: themeColors.textMuted, fontSize: 12, lineHeight: 18, marginTop: 1, ...typography.body },
        listingSection: { paddingHorizontal: 14, paddingTop: 14, gap: 10 },
        sectionHeader: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
        sectionMeta: { color: themeColors.success, fontSize: 12, ...typography.button },
        listingItem: { minHeight: 86, flexDirection: "row", alignItems: "center", gap: 10, borderWidth: 1, borderColor: themeColors.border, borderRadius: radius.lg, padding: 8, backgroundColor: themeColors.surface, ...shadows.soft },
        listingImage: { width: 72, height: 66, borderRadius: 8, overflow: "hidden", justifyContent: "flex-end", alignItems: "flex-start", padding: 6, backgroundColor: themeColors.border },
        videoBadge: { width: 22, height: 22, borderRadius: 11, alignItems: "center", justifyContent: "center", backgroundColor: "rgba(17,19,21,0.78)" },
        listingCopy: { flex: 1, minWidth: 0, gap: 3 },
        listingTitle: { color: themeColors.text, fontSize: 14, ...typography.title },
        listingMeta: { color: themeColors.textMuted, fontSize: 12, ...typography.body },
        listingTrust: { color: themeColors.success, fontSize: 11, ...typography.label },
        missingCard: { flex: 1, margin: spacing.lg, alignItems: "flex-start", justifyContent: "center", borderRadius: radius.lg, padding: spacing.lg, gap: 8, backgroundColor: themeColors.surfaceElevated, ...shadows.card },
        missingTitle: { color: themeColors.text, fontSize: 20, ...typography.title },
        missingBody: { color: themeColors.textMuted, lineHeight: 20, ...typography.body },
        homeLink: { color: themeColors.accent, marginTop: 4, ...typography.button },
      }),
    [themeColors]
  );

  const supplierProperties = useMemo(
    () =>
      state.properties.filter(
        (property) =>
          property.verified &&
          property.supplierVerified !== false &&
          supplierMatches(property, supplierId)
      ),
    [state.properties, supplierId]
  );
  const selectedProperty = supplierProperties.find((property) => property.id === selectedPropertyId) || supplierProperties[0];
  const supplier = selectedProperty ? resolveSupplier(selectedProperty, supplierId) : null;
  const canMessage =
    Boolean(selectedProperty) &&
    (hasCapability("message_landlord_or_agent") || hasCapability("message_tenants") || hasCapability("message_clients"));
  const voiceHref: Href | null = selectedProperty
    ? { pathname: "/inbox", params: { propertyId: selectedProperty.id, intent: "voice" } }
    : null;
  const videoHref: Href | null = selectedProperty
    ? { pathname: "/inbox", params: { propertyId: selectedProperty.id, intent: "video" } }
    : null;

  const listingViews = supplierProperties.reduce((total, property) => total + property.listingViews, 0);
  const savedCount = supplierProperties.reduce((total, property) => total + property.savedCount, 0);
  const applicationsCount = supplierProperties.reduce((total, property) => total + property.applicationsCount, 0);

  const toggleFollow = () => {
    if (!supplier?.id) return;
    if (!authToken) {
      setNotice("Sign in is required before following suppliers.");
      return;
    }

    const nextValue = !following;
    setFollowing(nextValue);
    setNotice(nextValue ? "Following this supplier." : "Supplier removed from following.");
    void toggleSupplierFollow(supplier.id, nextValue).catch((error) => {
      setFollowing(!nextValue);
      setNotice(error instanceof Error ? error.message : "Follow action could not be saved.");
    });
  };

  const openChat = async () => {
    if (!selectedProperty || openingChat) return;
    if (!authToken) {
      setChatError("Sign in is required before starting a chat.");
      return;
    }

    setOpeningChat(true);
    setNotice("");
    setChatError("");
    try {
      await startPropertyConversation(selectedProperty.id);
      router.push({ pathname: "/inbox", params: { propertyId: selectedProperty.id } });
    } catch (error) {
      setChatError(error instanceof Error ? error.message : "Chat could not be opened. Please try again.");
    } finally {
      setOpeningChat(false);
    }
  };

  if (!supplier || !supplier.verified || !supplierProperties.length) {
    return (
      <Screen>
        <View style={styles.missingCard}>
          <Ionicons name="shield-outline" size={28} color={colors.textMuted} />
          <Text style={styles.missingTitle}>Supplier not available</Text>
          <Text style={styles.missingBody}>This profile is hidden until the landlord or agent passes the required checks.</Text>
          <Link href="/" asChild>
            <Text style={styles.homeLink}>Back to Home</Text>
          </Link>
        </View>
      </Screen>
    );
  }

  return (
    <Screen>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <View style={styles.profileHeader}>
          <ImageBackground source={{ uri: supplier.coverPhoto || imageFor(selectedProperty) }} resizeMode="cover" style={styles.cover}>
            <View style={styles.coverShade} />
            <Link href="/" asChild>
              <Pressable style={styles.backButton}>
                <Ionicons name="chevron-back" size={20} color="#FFFFFF" />
              </Pressable>
            </Link>
          </ImageBackground>

          <View style={styles.identityBlock}>
            <View style={styles.avatar}>
              {supplier.profilePicture ? (
                <ImageBackground source={{ uri: supplier.profilePicture }} resizeMode="cover" style={styles.avatarImage} />
              ) : (
                <Text style={styles.avatarText}>{initials(supplier.name)}</Text>
              )}
            </View>
            <View style={styles.nameRow}>
              <View style={styles.nameCopy}>
                <Text numberOfLines={1} style={styles.name}>{supplier.name}</Text>
                <Text style={styles.handle}>@{supplierHandle(supplier.name)} · {roleLabel(supplier.role)}</Text>
              </View>
              <Pressable onPress={toggleFollow} style={[styles.followButton, following && styles.followButtonActive]}>
                <Text style={[styles.followText, following && styles.followTextActive]}>{following ? "Following" : "Follow"}</Text>
              </Pressable>
            </View>

            <Text style={styles.bio}>
              {supplier.bio || `${roleNoun(supplier.role)} with contact details kept inside the app until the rental process is appropriate.`}
            </Text>
            {notice ? <Text style={styles.notice}>{notice}</Text> : null}
            {chatError ? <Text style={styles.error}>{chatError}</Text> : null}

            <View style={styles.actionRow}>
              {canMessage ? (
                <Pressable onPress={() => void openChat()} disabled={openingChat} style={[styles.primaryAction, openingChat && styles.primaryActionDisabled]}>
                  <Ionicons name="chatbubble-ellipses" size={17} color={colors.accentText} />
                  <Text style={styles.primaryText}>{openingChat ? "Opening chat..." : "Message"}</Text>
                </Pressable>
              ) : null}
              {canMessage && voiceHref ? (
                <Link href={voiceHref} asChild>
                  <Pressable style={styles.iconAction}>
                    <Ionicons name="call-outline" size={18} color={colors.accent} />
                  </Pressable>
                </Link>
              ) : null}
              {canMessage && videoHref ? (
                <Link href={videoHref} asChild>
                  <Pressable style={styles.iconAction}>
                    <Ionicons name="videocam-outline" size={19} color={colors.accent} />
                  </Pressable>
                </Link>
              ) : null}
            </View>
          </View>
        </View>

        <View style={styles.statsBand}>
          <Stat value={`${supplierProperties.length}`} label="Listings" styles={styles} />
          <Stat value={`${listingViews}`} label="Views" styles={styles} />
          <Stat value={`${savedCount}`} label="Saved" styles={styles} />
          <Stat value={`${applicationsCount}`} label="Applications" styles={styles} />
        </View>

        <View style={styles.detailSection}>
          <Text style={styles.sectionTitle}>Profile details</Text>
          <DetailRow icon="call-outline" label="Phone" value="Hidden until both sides move through the rental flow" styles={styles} themeColors={themeColors} />
          <DetailRow icon="business-outline" label="Account type" value={roleLabel(supplier.role)} styles={styles} themeColors={themeColors} />
          <DetailRow icon="home-outline" label="Main listing" value={selectedProperty.title} styles={styles} themeColors={themeColors} />
        </View>

        <View style={styles.listingSection}>
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Active houses</Text>
          </View>
          {supplierProperties.map((property) => (
            <Link key={property.id} href={`/property/${encodeURIComponent(property.id)}`} asChild>
              <Pressable style={styles.listingItem}>
                <ImageBackground source={{ uri: imageFor(property) }} resizeMode="cover" style={styles.listingImage}>
                  {property.videoCount ? (
                    <View style={styles.videoBadge}>
                      <Ionicons name="play" size={10} color="#FFFFFF" />
                    </View>
                  ) : null}
                </ImageBackground>
                <View style={styles.listingCopy}>
                  <Text numberOfLines={1} style={styles.listingTitle}>{property.title}</Text>
                  <Text numberOfLines={1} style={styles.listingMeta}>{property.suburb}, {property.city} · {property.price}</Text>
                  <Text numberOfLines={1} style={styles.listingTrust}>{property.bedrooms} beds · {property.water} · {property.solarPower ? "Solar" : "Grid"}</Text>
                </View>
                <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />
              </Pressable>
            </Link>
          ))}
        </View>
      </ScrollView>
    </Screen>
  );
}

function Stat({ value, label, styles }: { value: string; label: string; styles: any }) {
  return (
    <View style={styles.stat}>
      <Text style={styles.statValue}>{value}</Text>
      <Text numberOfLines={1} style={styles.statLabel}>{label}</Text>
    </View>
  );
}

function DetailRow({ icon, label, value, styles, themeColors }: { icon: keyof typeof Ionicons.glyphMap; label: string; value: string; styles: any; themeColors: any }) {
  return (
    <View style={styles.detailRow}>
      <View style={styles.detailIcon}>
        <Ionicons name={icon} size={17} color={themeColors.accent} />
      </View>
      <View style={styles.detailCopy}>
        <Text style={styles.detailLabel}>{label}</Text>
        <Text style={styles.detailValue}>{value}</Text>
      </View>
    </View>
  );
}

function normalizeParam(value?: string | string[]) {
  return Array.isArray(value) ? value[0] || "" : value || "";
}

function supplierMatches(property: Property, supplierId: string) {
  if (!supplierId) return false;
  return [property.supplierId, property.agentId, property.ownerId].some((value) => String(value) === supplierId);
}

function resolveSupplier(property: Property, supplierId: string): SupplierProfile {
  if (property.agentId && String(property.agentId) === supplierId) {
    return {
      id: property.agentId,
      name: property.agentName || property.supplierName || "Agent",
      role: "agent",
      verified: Boolean(property.agentVerified ?? property.supplierVerified),
      profilePicture: property.agentProfilePicture || property.supplierProfilePicture,
      coverPhoto: property.agentCoverPhoto || property.supplierCoverPhoto,
      bio: property.agentBio || property.supplierBio,
    };
  }

  if (property.ownerId && String(property.ownerId) === supplierId) {
    return {
      id: property.ownerId,
      name: property.ownerName || property.supplierName || "Landlord",
      role: property.ownerRole || "landlord",
      verified: Boolean(property.ownerVerified ?? property.supplierVerified),
      profilePicture: property.ownerProfilePicture || property.supplierProfilePicture,
      coverPhoto: property.ownerCoverPhoto || property.supplierCoverPhoto,
      bio: property.ownerBio || property.supplierBio,
    };
  }

  return {
    id: property.supplierId || supplierId,
    name: property.supplierName || property.agentName || property.ownerName || "Supplier",
    role: property.supplierRole || (property.agentName ? "agent" : "landlord"),
    verified: Boolean(property.supplierVerified),
    profilePicture: property.supplierProfilePicture,
    coverPhoto: property.supplierCoverPhoto,
    bio: property.supplierBio,
  };
}

function roleLabel(role: AccountRole) {
  if (role === "agent") return "Agent";
  if (role === "landlord") return "Landlord";
  if (role === "tenant") return "Tenant";
  return "Administrator";
}

function roleNoun(role: AccountRole) {
  if (role === "agent") return "agent";
  if (role === "landlord") return "landlord";
  if (role === "tenant") return "tenant";
  return "administrator";
}

function initials(name: string) {
  const value = name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("");
  return value || "S";
}

function supplierHandle(name: string) {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, "").slice(0, 18) || "supplier";
}

function imageFor(property?: Property) {
  const firstPhoto = property?.photos?.[0];
  if (firstPhoto?.startsWith("http")) return firstPhoto;
  const normalized = (property?.type || "").toLowerCase();
  if (normalized.includes("flat")) return "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=1000&q=80&auto=format&fit=crop";
  if (normalized.includes("cottage")) return "https://images.unsplash.com/photo-1518780664697-55e3ad937233?w=1000&q=80&auto=format&fit=crop";
  if (normalized.includes("student")) return "https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=1000&q=80&auto=format&fit=crop";
  return "https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=1000&q=80&auto=format&fit=crop";
}
