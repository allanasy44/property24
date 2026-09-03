import { Ionicons } from "@expo/vector-icons";
import * as ImagePicker from "expo-image-picker";
import * as Location from "expo-location";
import { useEffect, useMemo, useState } from "react";
import { ActivityIndicator, ImageBackground, Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { AccessGuard } from "../../components/AccessGuard";
import { PropertyCard } from "../../components/PropertyCard";
import { Screen } from "../../components/Screen";
import { colors, radius, shadows, spacing, typography, useTheme } from "../../constants/theme";
import { AccountMediaFile, AuthUser, useRentalPlatform } from "../../state/rentalPlatform";

const propertyTypes = ["House", "Flat", "Cottage", "Student accommodation", "Commercial property"];
const maxPhotos = 10;

export default function ListingsScreen() {
  const { colors: themeColors } = useTheme();
  const colors = themeColors;
  const styles = createStyles(themeColors);
  const { state, addProperty, updateProperty, deleteProperty, authUser, authLoading, authError, createLandlordAgent, fetchLandlordAgents, hasCapability } = useRentalPlatform();
  const canCreateListing = hasCapability("add_properties") || hasCapability("list_properties");
  const canCreateAgents = authUser?.role === "landlord" && Boolean(authUser?.verified) && hasCapability("create_agents");
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
  const [keepAddressPrivate, setKeepAddressPrivate] = useState(true);
  const [intakeStep, setIntakeStep] = useState<1 | 2>(1);
  const [successVisible, setSuccessVisible] = useState(false);
  const [editedListingIds, setEditedListingIds] = useState<string[]>([]);
  const [deletedListings, setDeletedListings] = useState<Array<{ id: string; title: string; address: string }>>([]);
  const [listingFilter, setListingFilter] = useState<"all" | "vacant" | "occupied" | "attention">("all");

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
    setKeepAddressPrivate(true);
    setIntakeStep(1);
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
        setEditedListingIds((current) => current.includes(editingId) ? current : [editingId, ...current]);
        setListingNotice("Property updated and saved.");
      } else {
        await addProperty(payload);
        setListingNotice("Property saved with media. It will appear publicly after verification.");
        setSuccessVisible(true);
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
      const deletedProperty = state.properties.find((property) => property.id === propertyId);
      await deleteProperty(propertyId);
      if (deletedProperty) setDeletedListings((current) => [{ id: deletedProperty.id, title: deletedProperty.title, address: deletedProperty.address }, ...current].slice(0, 3));
      setListingNotice("Property deleted.");
    } catch (error) {
      setListingError(error instanceof Error ? error.message : "Property could not be deleted.");
    }
  };

  const visibleProperties = state.properties.filter((property) => {
    const status = listingStatus(property, state.leases);
    return listingFilter === "all" || (listingFilter === "vacant" && status === "vacant") || (listingFilter === "occupied" && status === "occupied") || (listingFilter === "attention" && (status === "pending" || editedListingIds.includes(property.id)));
  });

  return (
    <AccessGuard section="listings" roles={["landlord", "agent"]}>
      <Screen>
        <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
          <View style={styles.header}>
            <View style={styles.headerTopLine}><Text style={styles.title}>My properties</Text></View>
            <View style={styles.statusRail}>
              {(["all", "vacant", "occupied", "attention"] as const).map((filter) => (
                <Pressable key={filter} onPress={() => setListingFilter(filter)} style={[styles.statusFilter, listingFilter === filter && styles.statusFilterActive]}>
                  <Text style={[styles.statusFilterText, listingFilter === filter && styles.statusFilterTextActive]}>{filter === "all" ? "All listings" : filter === "attention" ? "Needs attention" : filter === "vacant" ? "Vacant" : "Occupied"}</Text>
                </Pressable>
              ))}
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
                    {editingId ? <Text style={styles.formTitle}>Edit property</Text> : null}
                  </View>
                </View>
              </View>

              {formOpen ? (
                <>
                  {intakeStep === 1 ? (
                    <>
                      <Text style={styles.referenceLabel}>Property for</Text>
                      <View style={styles.saleRentRow}>
                        <View style={[styles.saleRentOption, styles.saleRentActive]}><Text style={[styles.saleRentText, styles.saleRentTextActive]}>Rent</Text></View>
                      </View>
                      <Text style={styles.referenceLabel}>Property details</Text>
                      <Input label="Enter title" value={form.title} onChangeText={(value) => setForm((current) => ({ ...current, title: value }))} />
                      <Input label="Enter details here..." value={form.description} onChangeText={(value) => setForm((current) => ({ ...current, description: value }))} multiline />
                      <View style={styles.selectField}><Text style={styles.selectText}>{form.city || "Select locality"}</Text><Ionicons name="chevron-down" size={16} color={colors.textMuted} /></View>
                      <View style={styles.addressField}><View style={styles.addressIcon}><Ionicons name="location-sharp" size={18} color={colors.text} /></View><TextInput value={form.address} onChangeText={(value) => setForm((current) => ({ ...current, address: value }))} placeholder="Enter house address" placeholderTextColor={colors.textMuted} style={styles.addressInput} /></View>
                      <Pressable onPress={() => setKeepAddressPrivate((value) => !value)} style={styles.privateRow}><Text style={styles.privateText}>Keep this house address <Text style={styles.privateAccent}>Private</Text></Text><View style={[styles.switchTrack, keepAddressPrivate && styles.switchTrackActive]}><View style={[styles.switchThumb, keepAddressPrivate && styles.switchThumbActive]} /></View></Pressable>
                      <Pressable onPress={() => { if (!form.title.trim()) { setListingError("Enter a property title."); return; } setListingError(""); setIntakeStep(2); }} style={styles.continueButton}><Text style={styles.continueText}>Continue</Text></Pressable>
                    </>
                  ) : (
                    <>
                  <Text style={styles.inputLabel}>Property type</Text>
                  <View style={styles.optionRow}>
                    {propertyTypes.map((type) => <Pressable key={type} onPress={() => setForm((current) => ({ ...current, type }))} style={[styles.optionChip, form.type === type && styles.optionChipActive]}><Text style={[styles.optionText, form.type === type && styles.optionTextActive]}>{shortType(type)}</Text></Pressable>)}
                  </View>
                  <Text style={styles.referenceLabel}>Enter more details about property</Text>
                  <CounterRow label="BHK" value={form.bedrooms} onChange={(value) => setForm((current) => ({ ...current, bedrooms: value }))} />
                  <CounterRow label="Bathrooms" value={form.bathrooms} onChange={(value) => setForm((current) => ({ ...current, bathrooms: value }))} />
                  <Input label="Address" value={form.address} onChangeText={(value) => setForm((current) => ({ ...current, address: value }))} />
                  <Input label="Price" value={form.price} onChangeText={(value) => setForm((current) => ({ ...current, price: value }))} />
                  <Text style={styles.referenceLabel}>Upload property image <Text style={styles.referenceHint}>(Max 10 photos)</Text></Text>
                  <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.photoRail}>
                    {photoFiles.map((file) => <View key={file.uri} style={styles.photoThumb}><ImageBackground source={{ uri: file.uri }} resizeMode="cover" style={styles.photoThumbImage} /><Pressable onPress={() => setPhotoFiles((current) => current.filter((item) => item.uri !== file.uri))} style={styles.photoRemove}><Ionicons name="trash-outline" size={12} color={colors.accentText} /></Pressable></View>)}
                    <Pressable onPress={pickPhotos} disabled={photoFiles.length >= maxPhotos || authLoading} style={styles.addPhoto}><Ionicons name="add" size={24} color={colors.textMuted} /></Pressable>
                  </ScrollView>
                  <View style={styles.referenceDivider} />
                  <View style={styles.formRow}>
                    <Input label="City" value={form.city} onChangeText={(value) => setForm((current) => ({ ...current, city: value }))} />
                    <Input label="Suburb" value={form.suburb} onChangeText={(value) => setForm((current) => ({ ...current, suburb: value }))} />
                  </View>
                  <Input label="Deposit" value={form.deposit} onChangeText={(value) => setForm((current) => ({ ...current, deposit: value }))} />
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
                    <Pressable onPress={() => setIntakeStep(1)} style={styles.secondaryButton}><Text style={styles.secondaryButtonText}>Back</Text></Pressable>
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
                  )}
                </>
              ) : null}
            </View>
          ) : null}

          <View style={styles.inventoryHeader}><View><Text style={styles.inventoryTitle}>Property inventory</Text><Text style={styles.inventorySubtitle}>{visibleProperties.length} active {visibleProperties.length === 1 ? "listing" : "listings"}</Text></View><Ionicons name="options-outline" size={20} color={colors.textMuted} /></View>
          <View style={styles.listStack}>
            {visibleProperties.length ? (
              visibleProperties.map((property) => (
                <View key={property.id} style={styles.propertyCardShell}>
                  <View style={styles.propertyStatusHeader}>
                    <View style={styles.statusIdentity}><View style={[styles.statusDot, { backgroundColor: listingStatusColor(listingStatus(property, state.leases), colors) }]} /><Text style={styles.statusName}>{listingStatusLabel(listingStatus(property, state.leases))}</Text></View>
                    <View style={styles.flagRow}>
                      {editedListingIds.includes(property.id) ? <Text style={styles.editedFlag}>Edited</Text> : null}
                      {property.verified ? <Text style={styles.verifiedFlag}>Verified</Text> : <Text style={styles.reviewFlag}>Review</Text>}
                    </View>
                  </View>
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
          {deletedListings.length ? <View style={styles.deletedPanel}><View style={styles.deletedHeader}><Ionicons name="archive-outline" size={17} color={colors.textMuted} /><Text style={styles.deletedTitle}>Recently removed</Text></View>{deletedListings.map((property) => <View key={property.id} style={styles.deletedRow}><View style={{ flex: 1 }}><Text style={styles.deletedName}>{property.title}</Text><Text style={styles.deletedMeta}>{property.address}</Text></View><Text style={styles.deletedFlag}>Deleted</Text></View>)}</View> : null}
        </ScrollView>
        <Modal visible={successVisible} transparent animationType="fade" onRequestClose={() => setSuccessVisible(false)}>
          <View style={styles.successOverlay}><View style={styles.successModal}><Pressable onPress={() => setSuccessVisible(false)} style={styles.successClose}><Ionicons name="close" size={18} color={colors.text} /></Pressable><View style={styles.successIcon}><Ionicons name="checkmark" size={28} color={colors.accentText} /></View><Text style={styles.successTitle}>Congratulations!</Text><Text style={styles.successBody}>Your property listed successfully.</Text><Pressable onPress={() => setSuccessVisible(false)} style={styles.continueButton}><Text style={styles.continueText}>Continue</Text></Pressable></View></View>
        </Modal>
      </Screen>
    </AccessGuard>
  );
}

function CounterRow({ label, value, onChange }: { label: string; value: string; onChange: (value: string) => void }) {
  const { colors: themeColors } = useTheme();
  const colors = themeColors;
  const styles = createStyles(themeColors);
  const numericValue = Number(value) || 1;
  return (
    <View style={styles.counterRow}>
      <View style={styles.counterLabel}><Ionicons name={label === "BHK" ? "bed-outline" : "water-outline"} size={14} color={colors.textMuted} /><Text style={styles.counterText}>{label}</Text></View>
      <View style={styles.counterControls}><Pressable onPress={() => onChange(String(Math.max(1, numericValue - 1)))} style={styles.counterButton}><Text style={styles.counterMinus}>−</Text></Pressable><Text style={styles.counterValue}>{value || "1"}</Text><Pressable onPress={() => onChange(String(numericValue + 1))} style={styles.counterButtonLight}><Text style={styles.counterPlus}>+</Text></Pressable></View>
    </View>
  );
}

function Input({ autoCapitalize, label, multiline, keyboardType, secureTextEntry, value, onChangeText }: { autoCapitalize?: "none" | "sentences" | "words" | "characters"; label: string; multiline?: boolean; keyboardType?: "default" | "number-pad" | "email-address" | "phone-pad"; secureTextEntry?: boolean; value: string; onChangeText: (value: string) => void }) {
  const { colors: themeColors } = useTheme();
  const colors = themeColors;
  const styles = createStyles(themeColors);
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
  const styles = createStyles(useTheme().colors);
  return (
    <Pressable onPress={onPress} style={[styles.optionChip, active && styles.optionChipActive]}>
      <Text style={[styles.optionText, active && styles.optionTextActive]}>{label}</Text>
    </Pressable>
  );
}

function IntakeStep({ number, label, active = false }: { number: string; label: string; active?: boolean }) {
  const styles = createStyles(useTheme().colors);
  return (
    <View style={styles.intakeStep}>
      <View style={[styles.stepNumber, active && styles.stepNumberActive]}>
        <Text style={[styles.stepNumberText, active && styles.stepNumberTextActive]}>{number}</Text>
      </View>
      <Text style={[styles.stepLabel, active && styles.stepLabelActive]}>{label}</Text>
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

function listingStatus(property: { id: string; title: string; verified: boolean }, leases: Array<{ propertyId?: string; property?: string; status: string }>) {
  const occupied = leases.some((lease) => isActiveLease(lease) && (lease.propertyId === property.id || lease.property === property.title));
  if (occupied) return "occupied" as const;
  return property.verified ? "vacant" as const : "pending" as const;
}

function isActiveLease(lease: { status: string }) {
  return lease.status.toLowerCase().replace(/\s+/g, "_") === "active";
}

function listingStatusLabel(status: "vacant" | "occupied" | "pending") {
  return status === "occupied" ? "Occupied" : status === "pending" ? "Needs review" : "Vacant";
}

function listingStatusColor(status: "vacant" | "occupied" | "pending", themeColors: typeof colors) {
  return status === "occupied" ? themeColors.info : status === "pending" ? themeColors.warning : themeColors.success;
}

function createStyles(themeColors: typeof colors) {
  const colors = themeColors;
  return StyleSheet.create({
  content: { padding: spacing.md, paddingBottom: spacing.xl, gap: spacing.md, backgroundColor: colors.background },
  header: { gap: spacing.sm, marginBottom: spacing.sm },
  headerTopLine: { alignItems: "center", flexDirection: "row", justifyContent: "space-between" },
  title: { color: colors.text, fontSize: 26, lineHeight: 32, ...typography.display },
  statusRail: { flexDirection: "row", gap: 5, marginTop: spacing.sm },
  statusFilter: { alignItems: "center", backgroundColor: colors.background, borderColor: colors.border, borderRadius: 999, borderWidth: 1, flex: 1, justifyContent: "center", minWidth: 0, paddingHorizontal: 4, paddingVertical: 8 },
  statusFilterActive: { backgroundColor: colors.accent, borderColor: colors.accent },
  statusFilterText: { color: colors.textMuted, fontSize: 10, textAlign: "center", ...typography.button },
  statusFilterTextActive: { color: colors.accentText },
  formCard: { backgroundColor: colors.surfaceElevated, borderColor: colors.border, borderRadius: 28, borderWidth: 1, padding: spacing.md, gap: 14, ...shadows.card },
  formHeaderBar: { flexDirection: "row", alignItems: "flex-start", justifyContent: "space-between", gap: spacing.sm },
  agentCard: { backgroundColor: colors.surfaceElevated, borderRadius: radius.xl, borderWidth: 1, borderColor: "rgba(229,9,20,0.34)", padding: spacing.md, gap: spacing.sm, ...shadows.card },
  agentGrid: { flexDirection: "row", gap: 7 },
  agentNotice: { color: colors.success, fontSize: 12, lineHeight: 18, ...typography.label },
  agentError: { color: colors.warning, fontSize: 12, lineHeight: 18, ...typography.label },
  formTitleRow: { flex: 1, flexDirection: "row", alignItems: "flex-start", justifyContent: "space-between", gap: spacing.md, marginBottom: 2 },
  formTitleCopy: { flex: 1, minWidth: 0 },
  formKicker: { color: colors.accent, fontSize: 10, marginBottom: 3, ...typography.label },
  intakeStep: { alignItems: "center", gap: 4 },
  stepNumber: { alignItems: "center", backgroundColor: colors.surfaceMuted, borderRadius: 999, height: 27, justifyContent: "center", width: 27 },
  stepNumberActive: { backgroundColor: colors.accent },
  stepNumberText: { color: colors.textMuted, fontSize: 9, ...typography.label },
  stepNumberTextActive: { color: colors.accentText },
  stepLabel: { color: colors.textMuted, fontSize: 9, ...typography.label },
  stepLabelActive: { color: colors.text },
  formTitle: { color: colors.text, fontSize: 18, ...typography.title },
  saleRentRow: { backgroundColor: colors.background, borderColor: colors.border, borderRadius: 999, borderWidth: 1, flexDirection: "row", padding: 2 },
  saleRentOption: { alignItems: "center", borderRadius: 999, flex: 1, justifyContent: "center", minHeight: 34 },
  saleRentActive: { backgroundColor: colors.accent },
  saleRentText: { color: colors.textMuted, fontSize: 11, ...typography.button },
  saleRentTextActive: { color: colors.accentText },
  selectField: { alignItems: "center", backgroundColor: colors.background, borderColor: colors.border, borderRadius: radius.md, borderWidth: 1, flexDirection: "row", justifyContent: "space-between", minHeight: 42, paddingHorizontal: 11 },
  selectText: { color: colors.textMuted, fontSize: 12, ...typography.body },
  addressField: { alignItems: "center", backgroundColor: colors.background, borderColor: colors.border, borderRadius: radius.md, borderWidth: 1, flexDirection: "row", minHeight: 42, overflow: "hidden" },
  addressIcon: { alignItems: "center", backgroundColor: colors.accentSoft, borderRadius: 10, height: 34, justifyContent: "center", marginLeft: 4, width: 34 },
  addressInput: { color: colors.text, flex: 1, fontSize: 12, paddingHorizontal: 12, ...typography.body },
  privateRow: { alignItems: "center", backgroundColor: colors.background, borderColor: colors.border, borderRadius: radius.md, borderWidth: 1, flexDirection: "row", justifyContent: "space-between", minHeight: 42, paddingHorizontal: 11 },
  privateText: { color: colors.textMuted, fontSize: 11, ...typography.body },
  privateAccent: { color: colors.success, ...typography.button },
  switchTrack: { backgroundColor: colors.border, borderRadius: 999, height: 20, justifyContent: "center", paddingHorizontal: 2, width: 40 },
  switchTrackActive: { backgroundColor: colors.successSoft },
  switchThumb: { backgroundColor: colors.textMuted, borderRadius: 999, height: 16, width: 16 },
  switchThumbActive: { alignSelf: "flex-end", backgroundColor: colors.success },
  continueButton: { alignItems: "center", backgroundColor: colors.accent, borderRadius: radius.lg, justifyContent: "center", minHeight: 48, paddingVertical: 12, width: "100%" },
  continueText: { color: colors.accentText, fontSize: 12, ...typography.button },
  successOverlay: { alignItems: "center", backgroundColor: "rgba(2,11,20,0.78)", flex: 1, justifyContent: "center", padding: spacing.lg },
  successModal: { alignItems: "center", backgroundColor: colors.surfaceElevated, borderColor: colors.border, borderRadius: 24, borderWidth: 1, gap: 10, maxWidth: 360, padding: spacing.lg, position: "relative", width: "100%" },
  successClose: { alignItems: "center", backgroundColor: colors.surfaceMuted, borderRadius: 999, height: 32, justifyContent: "center", position: "absolute", right: 12, top: 12, width: 32 },
  successIcon: { alignItems: "center", backgroundColor: colors.success, borderRadius: 999, height: 52, justifyContent: "center", marginTop: 14, shadowColor: colors.success, shadowOpacity: 0.3, shadowRadius: 18, width: 52 },
  successTitle: { color: colors.text, fontSize: 17, marginTop: 6, ...typography.title },
  successBody: { color: colors.textMuted, fontSize: 11, ...typography.body },
    referenceLabel: { color: colors.text, fontSize: 12, marginTop: 2, ...typography.label },
    referenceHint: { color: colors.textMuted, fontSize: 11, ...typography.body },
    counterRow: { alignItems: "center", backgroundColor: colors.background, borderColor: colors.border, borderRadius: radius.md, borderWidth: 1, flexDirection: "row", justifyContent: "space-between", minHeight: 42, paddingLeft: 11, paddingRight: 5 },
    counterLabel: { alignItems: "center", flexDirection: "row", gap: 8 },
    counterText: { color: colors.textMuted, fontSize: 11, ...typography.body },
    counterControls: { alignItems: "center", flexDirection: "row", gap: 9 },
    counterButton: { alignItems: "center", backgroundColor: colors.surfaceMuted, borderColor: colors.border, borderRadius: 999, borderWidth: 1, height: 29, justifyContent: "center", width: 29 },
    counterButtonLight: { alignItems: "center", backgroundColor: colors.accent, borderRadius: 999, height: 29, justifyContent: "center", width: 29 },
    counterMinus: { color: colors.textMuted, fontSize: 19, lineHeight: 21 },
    counterPlus: { color: colors.accentText, fontSize: 20, lineHeight: 21 },
    counterValue: { color: colors.text, fontSize: 13, minWidth: 12, textAlign: "center", ...typography.button },
    photoRail: { gap: 8 },
    photoThumb: { borderRadius: 13, height: 56, overflow: "hidden", position: "relative", width: 84 },
    photoThumbImage: { flex: 1 },
    photoRemove: { alignItems: "center", backgroundColor: "rgba(10,10,10,0.78)", borderRadius: 999, height: 22, justifyContent: "center", position: "absolute", right: 5, top: 5, width: 22 },
    addPhoto: { alignItems: "center", backgroundColor: colors.accentSoft, borderColor: colors.border, borderRadius: 13, borderWidth: 1, height: 56, justifyContent: "center", width: 66 },
    referenceDivider: { backgroundColor: colors.border, height: 1, marginVertical: 2 },
  formSubtitle: { color: colors.textMuted, fontSize: 12, lineHeight: 18, marginTop: 2, ...typography.body },
  formIcon: { width: 34, height: 34, borderRadius: 8, alignItems: "center", justifyContent: "center", backgroundColor: colors.accentSoft },
  collapseButton: { minHeight: 36, borderRadius: 999, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.background, paddingHorizontal: 15, justifyContent: "center" },
  collapseText: { color: colors.text, fontSize: 12, ...typography.button },
  formRow: { flexDirection: "row", gap: 7 },
  optionRow: { flexDirection: "row", flexWrap: "wrap", gap: 5 },
  optionChip: { alignItems: "center", backgroundColor: colors.background, borderColor: colors.border, borderRadius: 999, borderWidth: 1, justifyContent: "center", paddingHorizontal: 8, paddingVertical: 8 },
  optionChipActive: { backgroundColor: colors.accent, borderColor: colors.accent },
  optionText: { color: colors.textMuted, fontSize: 10, textAlign: "center", ...typography.button },
  optionTextActive: { color: colors.accentText },
  inputLabel: { color: colors.textMuted, fontSize: 11, textTransform: "uppercase", ...typography.label },
  gpsPanel: { gap: 7 },
  gpsButton: { minHeight: 42, borderRadius: radius.md, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.accentSoft, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 8 },
  gpsButtonText: { color: colors.text, fontSize: 13, ...typography.button },
  mediaPanel: { gap: 8, borderWidth: 1, borderColor: colors.border, borderRadius: radius.md, backgroundColor: colors.background, padding: spacing.sm },
  mediaHeader: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  mediaCount: { color: colors.accent, fontSize: 12, ...typography.label },
  mediaButton: { minHeight: 42, borderRadius: radius.md, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.accentSoft, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 8, paddingHorizontal: 11 },
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
    minHeight: 42,
    fontSize: 14,
    outlineStyle: "none" as any,
    ...typography.body,
  },
  textArea: { minHeight: 96, textAlignVertical: "top" },
  actionRow: { flexDirection: "row", justifyContent: "space-between", gap: spacing.sm },
  button: { flex: 1, minHeight: 48, flexDirection: "row", gap: 8, backgroundColor: colors.accent, borderRadius: 999, alignItems: "center", justifyContent: "center", paddingVertical: 12 },
  buttonCompact: { flex: 1 },
  secondaryButton: { flex: 1, minHeight: 48, borderRadius: 999, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.background, alignItems: "center", justifyContent: "center", paddingVertical: 12 },
  secondaryButtonText: { color: colors.text, ...typography.button },
  buttonDisabled: { opacity: 0.55 },
  buttonText: { color: colors.accentText, ...typography.button },
  inventoryHeader: { alignItems: "center", flexDirection: "row", justifyContent: "space-between", marginTop: spacing.sm },
  inventoryTitle: { color: colors.text, fontSize: 20, ...typography.title },
  inventorySubtitle: { color: colors.textMuted, fontSize: 12, marginTop: 3, ...typography.body },
  propertyCardShell: { gap: 8 },
  propertyStatusHeader: { alignItems: "center", flexDirection: "row", justifyContent: "space-between", paddingHorizontal: 3 },
  statusIdentity: { alignItems: "center", flexDirection: "row", gap: 7 },
  statusDot: { borderRadius: 999, height: 8, width: 8 },
  statusName: { color: colors.text, fontSize: 12, ...typography.button },
  flagRow: { alignItems: "center", flexDirection: "row", gap: 6 },
  editedFlag: { backgroundColor: colors.accentSoft, borderRadius: 999, color: colors.text, fontSize: 10, overflow: "hidden", paddingHorizontal: 8, paddingVertical: 4, ...typography.label },
  verifiedFlag: { backgroundColor: colors.successSoft, borderRadius: 999, color: colors.success, fontSize: 10, overflow: "hidden", paddingHorizontal: 8, paddingVertical: 4, ...typography.label },
  reviewFlag: { backgroundColor: colors.warningSoft, borderRadius: 999, color: colors.warning, fontSize: 10, overflow: "hidden", paddingHorizontal: 8, paddingVertical: 4, ...typography.label },
  cardActionRow: { flexDirection: "row", justifyContent: "space-between", gap: spacing.sm },
  softAction: { flex: 1, minHeight: 40, borderRadius: 12, backgroundColor: colors.accentSoft, borderWidth: 1, borderColor: colors.border, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 6 },
  softActionText: { color: colors.accent, fontSize: 12, ...typography.button },
  deleteAction: { flex: 1, minHeight: 40, borderRadius: 12, backgroundColor: colors.dangerSoft, borderWidth: 1, borderColor: "rgba(239,68,68,0.18)", flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 6 },
  deleteActionText: { color: colors.danger, fontSize: 12, ...typography.button },
  listStack: { gap: spacing.md },
  emptyCard: { backgroundColor: colors.surfaceElevated, borderRadius: radius.lg, padding: spacing.lg, gap: 8, ...shadows.soft },
  emptyTitle: { color: colors.text, ...typography.title },
  emptyBody: { color: colors.textMuted, lineHeight: 20, ...typography.body },
  deletedPanel: { backgroundColor: colors.surfaceMuted, borderColor: colors.border, borderRadius: radius.lg, borderWidth: 1, gap: spacing.sm, padding: spacing.md },
  deletedHeader: { alignItems: "center", flexDirection: "row", gap: 7 },
  deletedTitle: { color: colors.text, fontSize: 14, ...typography.title },
  deletedRow: { alignItems: "center", borderTopColor: colors.border, borderTopWidth: 1, flexDirection: "row", gap: spacing.sm, paddingTop: spacing.sm },
  deletedName: { color: colors.text, fontSize: 12, ...typography.button },
  deletedMeta: { color: colors.textMuted, fontSize: 11, marginTop: 2, ...typography.body },
  deletedFlag: { color: colors.danger, fontSize: 10, ...typography.label },
  });
}
