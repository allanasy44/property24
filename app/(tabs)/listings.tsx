import { Ionicons } from "@expo/vector-icons";
import * as ImagePicker from "expo-image-picker";
import * as Location from "expo-location";
import { useEffect, useMemo, useState } from "react";
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { AccessGuard } from "../../components/AccessGuard";
import { PropertyCard } from "../../components/PropertyCard";
import { Screen } from "../../components/Screen";
import { SectionHeader } from "../../components/SectionHeader";
import { colors, radius, shadows, spacing, typography } from "../../constants/theme";
import { AccountMediaFile, AuthUser, useRentalPlatform } from "../../state/rentalPlatform";

const propertyTypes = ["House", "Flat", "Cottage", "Student accommodation", "Commercial property"];
const maxPhotos = 10;

export default function ListingsScreen() {
  const { state, addProperty, updateProperty, deleteProperty, authUser, authLoading, authError, createLandlordAgent, fetchLandlordAgents, hasCapability } = useRentalPlatform();
  const canCreateListing = hasCapability("add_properties") || hasCapability("list_properties");
  const canCreateAgents = authUser?.role === "landlord" && Boolean(authUser?.verified) && hasCapability("create_agents");
  const workspaceLabel = authUser?.role === "agent" ? "Agent listing workspace" : "Landlord workspace";
  const workspaceSubtitle = authUser?.role === "agent"
    ? "Manage assigned listings with the access your landlord has given you."
    : "Manage rentals, listing media, map pins, and assigned agents from one landlord account.";
  const [agentForm, setAgentForm] = useState({ name: "", email: "", phone: "", password: "" });
  const [agents, setAgents] = useState<AuthUser[]>([]);
  const [selectedAgentId, setSelectedAgentId] = useState("");
  const [agentNotice, setAgentNotice] = useState("");
  const [agentError, setAgentError] = useState("");
  const [listingNotice, setListingNotice] = useState("");
  const [listingError, setListingError] = useState("");
  const [photoFiles, setPhotoFiles] = useState<AccountMediaFile[]>([]);
  const [videoFiles, setVideoFiles] = useState<AccountMediaFile[]>([]);
  const [formOpen, setFormOpen] = useState(true);
  const [editingId, setEditingId] = useState<string | null>(null);

  const [form, setForm] = useState({
    title: "",
    address: "",
    city: "",
    suburb: "",
    price: "",
    deposit: "",
    type: "House",
    bedrooms: "",
    bathrooms: "",
    furnished: "Unfurnished",
    parking: "",
    power: "",
    solarPower: false,
    water: "",
    borehole: false,
    gps: "",
    tourAvailable: false,
    petFriendly: false,
    description: "",
  });

  const assignableAgents = useMemo(() => {
    const fromProperties = state.properties
      .filter((property) => property.agentId && property.agentName)
      .map((property) => ({
        id: String(property.agentId),
        name: property.agentName || "Agent",
        email: "",
        phone: "",
        role: "agent" as const,
        verified: Boolean(property.agentVerified),
        emailVerified: false,
        phoneVerified: false,
        accountOnboardingComplete: false,
        profileStatus: property.agentVerified ? "verified" : "onboarding_required",
        authProvider: "password",
        googleEmailVerified: false,
        profilePicture: property.agentProfilePicture,
        coverPhoto: property.agentCoverPhoto,
        bio: property.agentBio || "",
        lastSeenAt: property.agentLastSeenAt,
      }));
    const merged = [...agents, ...fromProperties];
    return merged.filter((agent, index, all) => all.findIndex((item) => item.id === agent.id) === index);
  }, [agents, state.properties]);

  useEffect(() => {
    if (!canCreateAgents) return;
    fetchLandlordAgents()
      .then(setAgents)
      .catch(() => undefined);
  }, [canCreateAgents, fetchLandlordAgents]);

  const submitAgent = async () => {
    setAgentNotice("");
    setAgentError("");
    if (!canCreateAgents) return;
    if (!agentForm.name.trim() || !agentForm.email.trim() || !agentForm.phone.trim() || !agentForm.password.trim()) {
      setAgentError("Enter the agent name, email, phone, and password.");
      return;
    }
    if (agentForm.password.length < 15) {
      setAgentError("Agent password must be at least 15 characters.");
      return;
    }

    try {
      const agent = await createLandlordAgent({
        name: agentForm.name,
        email: agentForm.email,
        phone: agentForm.phone,
        password: agentForm.password,
      });
      setAgentForm({ name: "", email: "", phone: "", password: "" });
      setAgents((current) => [agent, ...current.filter((item) => item.id !== agent.id)]);
      setSelectedAgentId(agent.id);
      setAgentNotice(`${agent.name} was created as an agent and selected for assignment.`);
    } catch (error) {
      setAgentError(error instanceof Error ? error.message : "Agent account could not be created.");
    }
  };

  const pickPhotos = async () => {
    setListingError("");
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) {
      setListingError("Photo library permission is required to upload house pictures.");
      return;
    }
    const remaining = Math.max(0, maxPhotos - photoFiles.length);
    if (!remaining) {
      setListingError(`A listing can have a maximum of ${maxPhotos} photos.`);
      return;
    }
    const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ["images"], allowsMultipleSelection: true, selectionLimit: remaining, quality: 0.86 });
    if (result.canceled) return;
    setPhotoFiles((current) => [...current, ...result.assets.slice(0, remaining).map((asset) => imageAssetToUpload(asset, "property-photo"))].slice(0, maxPhotos));
  };

  const pickVideos = async () => {
    setListingError("");
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) {
      setListingError("Photo library permission is required to upload house videos.");
      return;
    }
    const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ["videos"], allowsMultipleSelection: true, quality: 0.8, videoMaxDuration: 90 });
    if (result.canceled) return;
    setVideoFiles((current) => [...current, ...result.assets.map((asset) => imageAssetToUpload(asset, "property-video"))]);
  };

  const captureGps = async () => {
    setListingNotice("");
    setListingError("");
    const permission = await Location.requestForegroundPermissionsAsync();
    if (!permission.granted) {
      setListingError("Location permission is required to save the house map pin.");
      return;
    }
    try {
      const position = await Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Balanced });
      const gps = `${position.coords.latitude.toFixed(6)}, ${position.coords.longitude.toFixed(6)}`;
      setForm((current) => ({ ...current, gps }));
      setListingNotice("GPS map pin added to this listing.");
    } catch {
      setListingError("GPS could not be captured. Make sure location is enabled on the phone.");
    }
  };

  const resetForm = () => {
    setForm({
      title: "",
      address: "",
      city: "",
      suburb: "",
      price: "",
      deposit: "",
      type: "House",
      bedrooms: "",
      bathrooms: "",
      furnished: "Unfurnished",
      parking: "",
      power: "",
      solarPower: false,
      water: "",
      borehole: false,
      gps: "",
      tourAvailable: false,
      petFriendly: false,
      description: "",
    });
    setPhotoFiles([]);
    setVideoFiles([]);
    setSelectedAgentId("");
    setEditingId(null);
  };

  const openEditForm = (property: (typeof state.properties)[number]) => {
    setEditingId(property.id);
    setForm({
      title: property.title,
      address: property.address,
      city: property.city,
      suburb: property.suburb,
      price: property.price.replace(/\s*\/\s*month/i, "").trim(),
      deposit: property.deposit,
      type: property.type,
      bedrooms: String(property.bedrooms),
      bathrooms: String(property.bathrooms),
      furnished: property.furnished,
      parking: property.parking,
      power: property.power,
      solarPower: property.solarPower,
      water: property.water,
      borehole: property.borehole,
      gps: property.gps,
      tourAvailable: property.tourAvailable,
      petFriendly: property.petFriendly,
      description: property.description,
    });
    setPhotoFiles([]);
    setVideoFiles([]);
    setSelectedAgentId(property.agentId || "");
    setFormOpen(true);
  };

  const submit = async () => {
    setListingNotice("");
    setListingError("");
    if (!canCreateListing || !form.title.trim() || !form.address.trim()) {
      setListingError("Enter at least the title and address.");
      return;
    }
    if (photoFiles.length > maxPhotos) {
      setListingError(`A listing can have a maximum of ${maxPhotos} photos.`);
      return;
    }

    try {
      const payload = {
        title: form.title.trim(),
        address: form.address.trim(),
        city: form.city.trim() || "Harare",
        suburb: form.suburb.trim() || "Central",
        price: formatRent(form.price),
        deposit: formatMoney(form.deposit) || "Deposit required",
        type: form.type.trim() || "House",
        bedrooms: Number(form.bedrooms) || 0,
        bathrooms: Number(form.bathrooms) || 0,
        furnished: form.furnished.trim() || "Unfurnished",
        parking: form.parking.trim() || "Parking available",
        power: form.power.trim() || "Grid",
        solarPower: form.solarPower,
        water: form.water.trim() || "Available",
        borehole: form.borehole,
        gps: form.gps.trim() || "Unknown",
        videoCount: videoFiles.length,
        tourAvailable: form.tourAvailable,
        petFriendly: form.petFriendly,
        description: form.description.trim() || "Newly added property",
        photos: photoFiles.map((file) => file.uri),
        photoFiles,
        videoFiles,
        agentId: selectedAgentId || undefined,
        verified: false,
      };

      if (editingId) {
        await updateProperty(editingId, payload);
        setListingNotice("Property updated and saved.");
      } else {
        await addProperty(payload);
        setListingNotice("Property saved with media. It will appear publicly after verification.");
      }

      resetForm();
      setFormOpen(false);
    } catch (error) {
      setListingError(error instanceof Error ? error.message : editingId ? "Property could not be updated." : "Property could not be saved.");
    }
  };

  const handleDelete = async (propertyId: string) => {
    setListingNotice("");
    setListingError("");
    try {
      await deleteProperty(propertyId);
      setListingNotice("Property deleted.");
    } catch (error) {
      setListingError(error instanceof Error ? error.message : "Property could not be deleted.");
    }
  };

  return (
    <AccessGuard section="listings" roles={["landlord", "agent"]}>
      <Screen>
        <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
          <View style={styles.header}>
            <Text style={styles.eyebrow}>{workspaceLabel}</Text>
            <Text style={styles.title}>Listings</Text>
            <Text style={styles.subtitle}>{workspaceSubtitle}</Text>
            <View style={styles.summaryRow}>
              <SummaryTile icon="home-outline" value={`${state.properties.length}`} label="Properties" />
              <SummaryTile icon="shield-checkmark-outline" value={`${state.properties.filter((item) => item.verified).length}`} label="Verified" />
              <SummaryTile icon="image-outline" value="10" label="Max photos" />
            </View>
          </View>

          {canCreateAgents ? (
            <View style={styles.agentCard}>
              <View style={styles.formTitleRow}>
                <View style={styles.formTitleCopy}>
                  <Text style={styles.formTitle}>Create agent</Text>
                  <Text style={styles.formSubtitle}>Agents are created by the landlord and can be assigned to manage selected houses.</Text>
                </View>
                <View style={styles.formIcon}>
                  <Ionicons name="person-add-outline" size={18} color={colors.accent} />
                </View>
              </View>
              <View style={styles.agentGrid}>
                <Input label="Full name" value={agentForm.name} onChangeText={(value) => setAgentForm((current) => ({ ...current, name: value }))} />
                <Input label="Email" value={agentForm.email} onChangeText={(value) => setAgentForm((current) => ({ ...current, email: value }))} keyboardType="email-address" autoCapitalize="none" />
              </View>
              <View style={styles.agentGrid}>
                <Input label="Phone" value={agentForm.phone} onChangeText={(value) => setAgentForm((current) => ({ ...current, phone: value }))} keyboardType="phone-pad" />
                <Input label="Temporary password" value={agentForm.password} onChangeText={(value) => setAgentForm((current) => ({ ...current, password: value }))} secureTextEntry autoCapitalize="none" />
              </View>
              {agentNotice ? <Text style={styles.agentNotice}>{agentNotice}</Text> : null}
              {agentError || authError ? <Text style={styles.agentError}>{agentError || authError}</Text> : null}
              <Pressable onPress={submitAgent} disabled={authLoading} style={[styles.button, authLoading && styles.buttonDisabled]}>
                {authLoading ? <ActivityIndicator color={colors.accentText} /> : <Ionicons name="person-add-outline" size={18} color={colors.accentText} />}
                <Text style={styles.buttonText}>{authLoading ? "Creating..." : "Create agent"}</Text>
              </Pressable>
            </View>
          ) : null}

          {canCreateListing ? (
            <View style={styles.formCard}>
              <View style={styles.formHeaderBar}>
                <View style={styles.formTitleRow}>
                  <View>
                    <Text style={styles.formTitle}>{editingId ? "Edit listing" : "New listing intake"}</Text>
                    <Text style={styles.formSubtitle}>{editingId ? "Update the listing details and media." : "Photos, videos, GPS, rent, deposit, utilities, and assigned agent."}</Text>
                  </View>
                  <View style={styles.formIcon}>
                    <Ionicons name={editingId ? "create-outline" : "add"} size={18} color={colors.accent} />
                  </View>
                </View>
                <Pressable onPress={() => { setFormOpen((current) => !current); if (!formOpen) resetForm(); }} style={styles.collapseButton}>
                  <Text style={styles.collapseText}>{formOpen ? "Hide" : "Show"}</Text>
                </Pressable>
              </View>

              {formOpen ? (
                <>
                  <Input label="Title" value={form.title} onChangeText={(value) => setForm((current) => ({ ...current, title: value }))} />
                  <Input label="Address" value={form.address} onChangeText={(value) => setForm((current) => ({ ...current, address: value }))} />
                  <View style={styles.formRow}>
                    <Input label="City" value={form.city} onChangeText={(value) => setForm((current) => ({ ...current, city: value }))} />
                    <Input label="Suburb" value={form.suburb} onChangeText={(value) => setForm((current) => ({ ...current, suburb: value }))} />
                  </View>
                  <View style={styles.formRow}>
                    <Input label="Price" value={form.price} onChangeText={(value) => setForm((current) => ({ ...current, price: value }))} />
                    <Input label="Deposit" value={form.deposit} onChangeText={(value) => setForm((current) => ({ ...current, deposit: value }))} />
                  </View>
                  <View style={styles.optionRow}>
                    {propertyTypes.map((type) => (
                      <Pressable key={type} onPress={() => setForm((current) => ({ ...current, type }))} style={[styles.optionChip, form.type === type && styles.optionChipActive]}>
                        <Text style={[styles.optionText, form.type === type && styles.optionTextActive]}>{shortType(type)}</Text>
                      </Pressable>
                    ))}
                  </View>
                  <View style={styles.formRow}>
                    <Input label="Bedrooms" keyboardType="number-pad" value={form.bedrooms} onChangeText={(value) => setForm((current) => ({ ...current, bedrooms: value }))} />
                    <Input label="Bathrooms" keyboardType="number-pad" value={form.bathrooms} onChangeText={(value) => setForm((current) => ({ ...current, bathrooms: value }))} />
                  </View>
                  <Input label="Furnished" value={form.furnished} onChangeText={(value) => setForm((current) => ({ ...current, furnished: value }))} />
                  <Input label="Parking" value={form.parking} onChangeText={(value) => setForm((current) => ({ ...current, parking: value }))} />
                  <Input label="Power" value={form.power} onChangeText={(value) => setForm((current) => ({ ...current, power: value }))} />
                  <Input label="Water" value={form.water} onChangeText={(value) => setForm((current) => ({ ...current, water: value }))} />
                  <View style={styles.gpsPanel}>
                    <Input label="GPS" value={form.gps} onChangeText={(value) => setForm((current) => ({ ...current, gps: value }))} />
                    <Pressable onPress={captureGps} disabled={authLoading} style={[styles.gpsButton, authLoading && styles.buttonDisabled]}>
                      <Ionicons name="locate-outline" size={17} color={colors.accent} />
                      <Text style={styles.gpsButtonText}>Use current pin</Text>
                    </Pressable>
                  </View>

                  {authUser?.role === "landlord" && assignableAgents.length ? (
                    <View style={styles.mediaPanel}>
                      <Text style={styles.inputLabel}>Assign agent</Text>
                      <View style={styles.optionRow}>
                        <ToggleChip label="Owner handles" active={!selectedAgentId} onPress={() => setSelectedAgentId("")} />
                        {assignableAgents.map((agent) => (
                          <ToggleChip key={agent.id} label={agent.name} active={selectedAgentId === agent.id} onPress={() => setSelectedAgentId(agent.id)} />
                        ))}
                      </View>
                    </View>
                  ) : null}

                  <View style={styles.mediaPanel}>
                    <View style={styles.mediaHeader}>
                      <Text style={styles.inputLabel}>Pictures</Text>
                      <Text style={styles.mediaCount}>{photoFiles.length}/{maxPhotos}</Text>
                    </View>
                    <Pressable onPress={pickPhotos} disabled={photoFiles.length >= maxPhotos || authLoading} style={[styles.mediaButton, (photoFiles.length >= maxPhotos || authLoading) && styles.buttonDisabled]}>
                      <Ionicons name="images-outline" size={17} color={colors.accent} />
                      <Text style={styles.mediaButtonText}>{photoFiles.length ? "Add more photos" : "Upload photos"}</Text>
                    </Pressable>
                    {photoFiles.length ? <Text style={styles.mediaMeta}>{photoFiles.map((file) => file.name).join(" · ")}</Text> : null}
                  </View>

                  <View style={styles.mediaPanel}>
                    <View style={styles.mediaHeader}>
                      <Text style={styles.inputLabel}>Videos</Text>
                      <Text style={styles.mediaCount}>{videoFiles.length}</Text>
                    </View>
                    <Pressable onPress={pickVideos} disabled={authLoading} style={styles.mediaButton}>
                      <Ionicons name="videocam-outline" size={17} color={colors.accent} />
                      <Text style={styles.mediaButtonText}>{videoFiles.length ? "Add more videos" : "Upload videos"}</Text>
                    </Pressable>
                    {videoFiles.length ? <Text style={styles.mediaMeta}>{videoFiles.map((file) => file.name).join(" · ")}</Text> : null}
                  </View>

                  <View style={styles.optionRow}>
                    <ToggleChip label="Solar power" active={form.solarPower} onPress={() => setForm((current) => ({ ...current, solarPower: !current.solarPower }))} />
                    <ToggleChip label="Borehole" active={form.borehole} onPress={() => setForm((current) => ({ ...current, borehole: !current.borehole }))} />
                    <ToggleChip label="Pet friendly" active={form.petFriendly} onPress={() => setForm((current) => ({ ...current, petFriendly: !current.petFriendly }))} />
                    <ToggleChip label="360 tour future" active={form.tourAvailable} onPress={() => setForm((current) => ({ ...current, tourAvailable: !current.tourAvailable }))} />
                  </View>
                  <Input label="Description" value={form.description} onChangeText={(value) => setForm((current) => ({ ...current, description: value }))} multiline />
                  {listingNotice ? <Text style={styles.agentNotice}>{listingNotice}</Text> : null}
                  {listingError || authError ? <Text style={styles.agentError}>{listingError || authError}</Text> : null}
                  <View style={styles.actionRow}>
                    {editingId ? (
                      <Pressable onPress={() => { resetForm(); setFormOpen(false); }} style={[styles.secondaryButton, authLoading && styles.buttonDisabled]}>
                        <Text style={styles.secondaryButtonText}>Cancel</Text>
                      </Pressable>
                    ) : null}
                    <Pressable onPress={submit} disabled={authLoading} style={[styles.button, authLoading && styles.buttonDisabled, editingId && styles.buttonCompact]}>
                      {authLoading ? <ActivityIndicator color={colors.accentText} /> : <Ionicons name="cloud-upload-outline" size={18} color={colors.accentText} />}
                      <Text style={styles.buttonText}>{authLoading ? (editingId ? "Updating..." : "Saving...") : editingId ? "Update property" : "Save property"}</Text>
                    </Pressable>
                  </View>
                </>
              ) : null}
            </View>
          ) : null}

          <SectionHeader title="Current properties" subtitle="Rendered from live account data and used by Home, Inbox, and supplier profiles." />
          <View style={styles.listStack}>
            {state.properties.length ? (
              state.properties.map((property) => (
                <View key={property.id} style={styles.propertyCardShell}>
                  <PropertyCard property={property} />
                  <View style={styles.cardActionRow}>
                    <Pressable onPress={() => openEditForm(property)} style={styles.softAction}>
                      <Ionicons name="create-outline" size={16} color={colors.accent} />
                      <Text style={styles.softActionText}>Edit</Text>
                    </Pressable>
                    <Pressable onPress={() => handleDelete(property.id)} style={styles.deleteAction}>
                      <Ionicons name="trash-outline" size={16} color={colors.danger} />
                      <Text style={styles.deleteActionText}>Delete</Text>
                    </Pressable>
                  </View>
                </View>
              ))
            ) : (
              <View style={styles.emptyCard}>
                <Text style={styles.emptyTitle}>No properties saved yet</Text>
                <Text style={styles.emptyBody}>Use the form above to add your first listing and populate the app dynamically.</Text>
              </View>
            )}
          </View>
        </ScrollView>
      </Screen>
    </AccessGuard>
  );
}

function Input({ autoCapitalize, label, multiline, keyboardType, secureTextEntry, value, onChangeText }: { autoCapitalize?: "none" | "sentences" | "words" | "characters"; label: string; multiline?: boolean; keyboardType?: "default" | "number-pad" | "email-address" | "phone-pad"; secureTextEntry?: boolean; value: string; onChangeText: (value: string) => void }) {
  return (
    <View style={{ flex: 1, gap: 6 }}>
      <Text style={styles.inputLabel}>{label}</Text>
      <TextInput
        value={value}
        onChangeText={onChangeText}
        multiline={multiline}
        autoCapitalize={autoCapitalize}
        keyboardType={keyboardType}
        secureTextEntry={secureTextEntry}
        style={[styles.input, multiline && styles.textArea]}
        placeholderTextColor={colors.textMuted}
      />
    </View>
  );
}

function ToggleChip({ label, active, onPress }: { label: string; active: boolean; onPress: () => void }) {
  return (
    <Pressable onPress={onPress} style={[styles.optionChip, active && styles.optionChipActive]}>
      <Text style={[styles.optionText, active && styles.optionTextActive]}>{label}</Text>
    </Pressable>
  );
}

function SummaryTile({ icon, value, label }: { icon: keyof typeof Ionicons.glyphMap; value: string; label: string }) {
  return (
    <View style={styles.summaryTile}>
      <Ionicons name={icon} size={15} color={colors.accent} />
      <Text style={styles.summaryValue}>{value}</Text>
      <Text style={styles.summaryLabel}>{label}</Text>
    </View>
  );
}

function shortType(value: string) {
  if (value === "Student accommodation") return "Student";
  if (value === "Commercial property") return "Commercial";
  return value;
}

function formatRent(value: string) {
  const cleaned = value.trim();
  if (!cleaned) return "$0 / month";
  if (cleaned.includes("/")) return cleaned;
  return `${formatMoney(cleaned)} / month`;
}

function formatMoney(value: string) {
  const cleaned = value.trim();
  if (!cleaned) return "";
  return cleaned.startsWith("$") ? cleaned : `$${cleaned}`;
}

function imageAssetToUpload(asset: ImagePicker.ImagePickerAsset, label: string): AccountMediaFile {
  const cleanUri = asset.uri.split("?")[0] || "";
  const extension = cleanUri.split(".").pop()?.toLowerCase() || (asset.type === "video" ? "mp4" : "jpg");
  const safeExtension = extension.length > 5 ? (asset.type === "video" ? "mp4" : "jpg") : extension;
  return {
    uri: asset.uri,
    name: asset.fileName || `${label}-${Date.now()}.${safeExtension}`,
    type: asset.mimeType || (asset.type === "video" ? "video/mp4" : `image/${safeExtension === "jpg" ? "jpeg" : safeExtension}`),
  };
}

const styles = StyleSheet.create({
  content: { padding: spacing.md, paddingBottom: spacing.xl, gap: spacing.md, backgroundColor: colors.background },
  header: { gap: spacing.sm, marginBottom: spacing.sm },
  eyebrow: { color: colors.accent, fontSize: 12, textTransform: "uppercase", ...typography.label },
  title: { color: colors.text, fontSize: 26, lineHeight: 32, ...typography.display },
  subtitle: { color: colors.textMuted, lineHeight: 22, ...typography.body },
  summaryRow: { flexDirection: "row", gap: spacing.sm },
  summaryTile: { flex: 1, minHeight: 76, borderWidth: 1, borderColor: colors.border, borderRadius: radius.lg, padding: spacing.sm, gap: 3, backgroundColor: colors.surface, ...shadows.soft },
  summaryValue: { color: colors.text, fontSize: 17, ...typography.title },
  summaryLabel: { color: colors.textMuted, fontSize: 10, textTransform: "uppercase", ...typography.label },
  formCard: { backgroundColor: colors.surfaceElevated, borderRadius: radius.xl, borderWidth: 1, borderColor: colors.border, padding: spacing.md, gap: spacing.sm, ...shadows.card },
  formHeaderBar: { flexDirection: "row", alignItems: "flex-start", justifyContent: "space-between", gap: spacing.sm },
  agentCard: { backgroundColor: colors.surfaceElevated, borderRadius: radius.xl, borderWidth: 1, borderColor: "rgba(229,9,20,0.34)", padding: spacing.md, gap: spacing.sm, ...shadows.card },
  agentGrid: { flexDirection: "row", gap: spacing.sm },
  agentNotice: { color: colors.success, fontSize: 12, lineHeight: 18, ...typography.label },
  agentError: { color: colors.warning, fontSize: 12, lineHeight: 18, ...typography.label },
  formTitleRow: { flex: 1, flexDirection: "row", alignItems: "flex-start", justifyContent: "space-between", gap: spacing.md, marginBottom: 2 },
  formTitleCopy: { flex: 1, minWidth: 0 },
  formTitle: { color: colors.text, fontSize: 17, ...typography.title },
  formSubtitle: { color: colors.textMuted, fontSize: 12, lineHeight: 18, marginTop: 2, ...typography.body },
  formIcon: { width: 34, height: 34, borderRadius: 8, alignItems: "center", justifyContent: "center", backgroundColor: colors.accentSoft },
  collapseButton: { minHeight: 32, borderRadius: 999, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.background, paddingHorizontal: 12, justifyContent: "center" },
  collapseText: { color: colors.text, fontSize: 12, ...typography.button },
  formRow: { flexDirection: "row", gap: spacing.sm },
  optionRow: { flexDirection: "row", flexWrap: "wrap", gap: spacing.sm },
  optionChip: { backgroundColor: colors.background, borderRadius: 8, borderWidth: 1, borderColor: colors.border, paddingHorizontal: 10, paddingVertical: 8 },
  optionChipActive: { backgroundColor: colors.accentSoft, borderColor: colors.accent },
  optionText: { color: colors.text, fontSize: 12, ...typography.button },
  optionTextActive: { color: colors.accent },
  inputLabel: { color: colors.textMuted, fontSize: 12, textTransform: "uppercase", ...typography.label },
  gpsPanel: { gap: 8 },
  gpsButton: { minHeight: 42, borderRadius: radius.md, borderWidth: 1, borderColor: "rgba(229,9,20,0.36)", backgroundColor: colors.accentSoft, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 8 },
  gpsButtonText: { color: colors.text, fontSize: 13, ...typography.button },
  mediaPanel: { gap: 8, borderWidth: 1, borderColor: colors.border, borderRadius: radius.md, backgroundColor: colors.background, padding: spacing.sm },
  mediaHeader: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  mediaCount: { color: colors.accent, fontSize: 12, ...typography.label },
  mediaButton: { minHeight: 42, borderRadius: radius.md, borderWidth: 1, borderColor: "rgba(229,9,20,0.36)", backgroundColor: colors.accentSoft, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 8 },
  mediaButtonText: { color: colors.text, fontSize: 13, ...typography.button },
  mediaMeta: { color: colors.textMuted, fontSize: 11, lineHeight: 16, ...typography.body },
  input: {
    backgroundColor: colors.background,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: colors.border,
    color: colors.text,
    paddingHorizontal: 12,
    paddingVertical: 12,
    fontSize: 14,
    outlineStyle: "none" as any,
    ...typography.body,
  },
  textArea: { minHeight: 96, textAlignVertical: "top" },
  actionRow: { flexDirection: "row", justifyContent: "space-between", gap: spacing.sm },
  button: { flex: 1, minHeight: 44, flexDirection: "row", gap: 8, backgroundColor: colors.accent, borderRadius: radius.lg, alignItems: "center", justifyContent: "center", paddingVertical: 12 },
  buttonCompact: { flex: 1 },
  secondaryButton: { flex: 1, minHeight: 44, borderRadius: radius.lg, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.background, alignItems: "center", justifyContent: "center", paddingVertical: 12 },
  secondaryButtonText: { color: colors.text, ...typography.button },
  buttonDisabled: { opacity: 0.55 },
  buttonText: { color: colors.accentText, ...typography.button },
  propertyCardShell: { gap: 8 },
  cardActionRow: { flexDirection: "row", justifyContent: "space-between", gap: spacing.sm },
  softAction: { flex: 1, minHeight: 40, borderRadius: 12, backgroundColor: colors.accentSoft, borderWidth: 1, borderColor: colors.border, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 6 },
  softActionText: { color: colors.accent, fontSize: 12, ...typography.button },
  deleteAction: { flex: 1, minHeight: 40, borderRadius: 12, backgroundColor: colors.dangerSoft, borderWidth: 1, borderColor: "rgba(239,68,68,0.18)", flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 6 },
  deleteActionText: { color: colors.danger, fontSize: 12, ...typography.button },
  listStack: { gap: spacing.md },
  emptyCard: { backgroundColor: colors.surfaceElevated, borderRadius: radius.lg, padding: spacing.lg, gap: 8, ...shadows.soft },
  emptyTitle: { color: colors.text, ...typography.title },
  emptyBody: { color: colors.textMuted, lineHeight: 20, ...typography.body },
});
