import { Ionicons } from "@expo/vector-icons";
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { useState } from "react";
import { useRentalPlatform } from "../../state/rentalPlatform";
import { colors, radius, shadows, spacing, typography } from "../../constants/theme";
import { PropertyCard } from "../../components/PropertyCard";
import { SectionHeader } from "../../components/SectionHeader";
import { Screen } from "../../components/Screen";
import { AccessGuard } from "../../components/AccessGuard";

const propertyTypes = ["House", "Flat", "Cottage", "Student accommodation", "Commercial property"];

export default function ListingsScreen() {
  const { state, addProperty, authUser, authLoading, authError, createLandlordAgent, hasCapability } = useRentalPlatform();
  const canCreateListing = hasCapability("add_properties") || hasCapability("list_properties");
  const canCreateAgents = authUser?.role === "landlord" && Boolean(authUser?.verified) && hasCapability("create_agents");
  const workspaceLabel = authUser?.role === "agent" ? "Agent listing workspace" : "Landlord workspace";
  const workspaceSubtitle = authUser?.role === "agent"
    ? "Manage assigned listings with the access your landlord has given you."
    : "Manage verified rentals, listing media, and agents from one landlord account.";
  const [agentForm, setAgentForm] = useState({ name: "", email: "", phone: "", password: "" });
  const [agentNotice, setAgentNotice] = useState("");
  const [agentError, setAgentError] = useState("");

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
    videoCount: "",
    tourAvailable: false,
    petFriendly: false,
    photoLabel: "",
    description: "",
  });

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
      setAgentNotice(`${agent.name} was created as an agent. They must verify before appearing on listings.`);
    } catch (error) {
      setAgentError(error instanceof Error ? error.message : "Agent account could not be created.");
    }
  };

  const submit = () => {
    if (!canCreateListing || !form.title.trim() || !form.address.trim()) return;

    addProperty({
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
      videoCount: Number(form.videoCount) || 0,
      tourAvailable: form.tourAvailable,
      petFriendly: form.petFriendly,
      description: form.description.trim() || "Newly added property",
      photos: [form.photoLabel.trim() || `${form.type} photo`],
      verified: false,
    });

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
      videoCount: "",
      tourAvailable: false,
      petFriendly: false,
      photoLabel: "",
      description: "",
    });
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
            <SummaryTile icon="image-outline" value="MinIO" label="Media store" />
          </View>
        </View>

        {canCreateAgents ? (
          <View style={styles.agentCard}>
            <View style={styles.formTitleRow}>
              <View style={styles.formTitleCopy}>
                <Text style={styles.formTitle}>Create agent</Text>
                <Text style={styles.formSubtitle}>Agents are invited from this landlord account and cannot self-register.</Text>
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
            <View style={styles.formTitleRow}>
              <View>
                <Text style={styles.formTitle}>New listing intake</Text>
                <Text style={styles.formSubtitle}>Photos, GPS, rent, deposit, utilities, and verification details.</Text>
              </View>
              <View style={styles.formIcon}>
                <Ionicons name="add" size={18} color={colors.accent} />
              </View>
            </View>
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
          <Input label="GPS" value={form.gps} onChangeText={(value) => setForm((current) => ({ ...current, gps: value }))} />
          <View style={styles.formRow}>
            <Input label="Photo label" value={form.photoLabel} onChangeText={(value) => setForm((current) => ({ ...current, photoLabel: value }))} />
            <Input label="Videos" keyboardType="number-pad" value={form.videoCount} onChangeText={(value) => setForm((current) => ({ ...current, videoCount: value }))} />
          </View>
          <View style={styles.optionRow}>
            <ToggleChip label="Solar power" active={form.solarPower} onPress={() => setForm((current) => ({ ...current, solarPower: !current.solarPower }))} />
            <ToggleChip label="Borehole" active={form.borehole} onPress={() => setForm((current) => ({ ...current, borehole: !current.borehole }))} />
            <ToggleChip label="Pet friendly" active={form.petFriendly} onPress={() => setForm((current) => ({ ...current, petFriendly: !current.petFriendly }))} />
            <ToggleChip label="360 tour future" active={form.tourAvailable} onPress={() => setForm((current) => ({ ...current, tourAvailable: !current.tourAvailable }))} />
          </View>
          <Input label="Description" value={form.description} onChangeText={(value) => setForm((current) => ({ ...current, description: value }))} multiline />
            <Pressable onPress={submit} style={styles.button}>
              <Ionicons name="cloud-upload-outline" size={18} color={colors.accentText} />
              <Text style={styles.buttonText}>Save property</Text>
            </Pressable>
          </View>
        ) : null}

        <SectionHeader title="Current properties" subtitle="Rendered from state and used by all other screens." />
        <View style={styles.listStack}>
          {state.properties.length ? (
            state.properties.map((property) => <PropertyCard key={property.id} property={property} />)
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
  agentCard: { backgroundColor: colors.surfaceElevated, borderRadius: radius.xl, borderWidth: 1, borderColor: "rgba(229,9,20,0.34)", padding: spacing.md, gap: spacing.sm, ...shadows.card },
  agentGrid: { flexDirection: "row", gap: spacing.sm },
  agentNotice: { color: colors.success, fontSize: 12, lineHeight: 18, ...typography.label },
  agentError: { color: colors.warning, fontSize: 12, lineHeight: 18, ...typography.label },
  formTitleRow: { flexDirection: "row", alignItems: "flex-start", justifyContent: "space-between", gap: spacing.md, marginBottom: 2 },
  formTitleCopy: { flex: 1, minWidth: 0 },
  formTitle: { color: colors.text, fontSize: 17, ...typography.title },
  formSubtitle: { color: colors.textMuted, fontSize: 12, lineHeight: 18, marginTop: 2, ...typography.body },
  formIcon: { width: 34, height: 34, borderRadius: 8, alignItems: "center", justifyContent: "center", backgroundColor: colors.accentSoft },
  formRow: { flexDirection: "row", gap: spacing.sm },
  optionRow: { flexDirection: "row", flexWrap: "wrap", gap: spacing.sm },
  optionChip: { backgroundColor: colors.background, borderRadius: 8, borderWidth: 1, borderColor: colors.border, paddingHorizontal: 10, paddingVertical: 8 },
  optionChipActive: { backgroundColor: colors.accentSoft, borderColor: colors.accent },
  optionText: { color: colors.text, fontSize: 12, ...typography.button },
  optionTextActive: { color: colors.accent },
  inputLabel: { color: colors.textMuted, fontSize: 12, textTransform: "uppercase", ...typography.label },
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
  button: { minHeight: 44, flexDirection: "row", gap: 8, backgroundColor: colors.accent, borderRadius: radius.lg, alignItems: "center", justifyContent: "center", paddingVertical: 12 },
  buttonDisabled: { opacity: 0.55 },
  buttonText: { color: colors.accentText, ...typography.button },
  listStack: { gap: spacing.md },
  emptyCard: { backgroundColor: colors.surfaceElevated, borderRadius: radius.lg, padding: spacing.lg, gap: 8, ...shadows.soft },
  emptyTitle: { color: colors.text, ...typography.title },
  emptyBody: { color: colors.textMuted, lineHeight: 20, ...typography.body },
});
