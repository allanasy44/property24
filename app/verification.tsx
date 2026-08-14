import { Ionicons } from "@expo/vector-icons";
import * as ImagePicker from "expo-image-picker";
import { useState } from "react";
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { AccessGuard } from "../components/AccessGuard";
import { Screen } from "../components/Screen";
import { SectionHeader } from "../components/SectionHeader";
import { verificationChecks } from "../constants/content";
import { colors, radius, shadows, spacing, typography } from "../constants/theme";
import { AccountMediaFile, AccountRole, useRentalPlatform } from "../state/rentalPlatform";

export default function VerificationScreen() {
  const { state, account, authUser, authError, authLoading, reviewVerification, hasCapability, submitVerification, extractVerificationId } = useRentalPlatform();
  const isAdmin = hasCapability("verify_users");
  const [notice, setNotice] = useState("");
  const [documentNumber, setDocumentNumber] = useState("");
  const [idFrontFile, setIdFrontFile] = useState<AccountMediaFile | undefined>();
  const [idBackFile, setIdBackFile] = useState<AccountMediaFile | undefined>();
  const [ownershipFile, setOwnershipFile] = useState<AccountMediaFile | undefined>();
  const [agencyName, setAgencyName] = useState("");
  const [contactDetails, setContactDetails] = useState("");

  const review = async (id: string, status: "approved" | "rejected") => {
    setNotice("");
    try {
      await reviewVerification(id, status);
      setNotice(`Verification ${status}.`);
    } catch {
      // The provider exposes authError from the account service.
    }
  };

  const captureIdentityImage = async (side: "front" | "back") => {
    setNotice("");
    const permission = await ImagePicker.requestCameraPermissionsAsync();
    if (!permission.granted) {
      setNotice("Camera permission is required.");
      return;
    }
    const result = await ImagePicker.launchCameraAsync({ mediaTypes: ["images"], quality: 0.9, allowsEditing: false });
    const asset = result.assets?.[0];
    if (result.canceled || !asset) return;
    const file = imageAssetToUpload(asset, `id-${side}`);
    if (side === "front") setIdFrontFile(file);
    else setIdBackFile(file);
  };

  const chooseOwnershipEvidence = async () => {
    setNotice("");
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) {
      setNotice("Photo library permission is required.");
      return;
    }
    const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ["images"], quality: 0.9, allowsEditing: false });
    const asset = result.assets?.[0];
    if (result.canceled || !asset) return;
    setOwnershipFile(imageAssetToUpload(asset, "ownership-authority"));
  };

  const submitFullVerification = async () => {
    setNotice("");
    if (!authUser) return;
    if (!idFrontFile || !idBackFile) {
      setNotice("Capture the front and back of your ID first.");
      return;
    }
    if (!documentNumber.trim()) {
      setNotice("Enter your document number.");
      return;
    }
    if (authUser.role === "landlord" && !ownershipFile) {
      setNotice("Upload property ownership or authority evidence.");
      return;
    }
    if (authUser.role === "landlord" && !agencyName.trim()) {
      setNotice("Enter the estate or company name.");
      return;
    }
    try {
      const extraction = await extractVerificationId({ idFrontFile, idBackFile });
      await submitVerification({
        role: authUser.role,
        name: authUser.name,
        phone: authUser.phone,
        privacy_notice_accepted: true,
        document_type: "identity_document",
        declaration_accepted: true,
        national_id_number: documentNumber.trim(),
        extracted_national_id_number: extraction.extractedNationalIdNumber,
        phone_verified: authUser.phoneVerified,
        email_verified: authUser.emailVerified,
        selfie_uploaded: false,
        identity_confirmed: true,
        idFrontFile,
        idBackFile,
        ownershipOrAuthorizationFile: ownershipFile,
        agency_name: agencyName.trim(),
        contact_details: contactDetails.trim(),
      });
      setNotice("Verification submitted for review.");
      setDocumentNumber("");
      setIdFrontFile(undefined);
      setIdBackFile(undefined);
      setOwnershipFile(undefined);
    } catch {
      // authError is shown below.
    }
  };

  return (
    <AccessGuard section="verification" roles={["tenant", "landlord", "agent", "admin"]}>
      <Screen>
        <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
          <View style={styles.hero}>
            <Text style={styles.kicker}>Verification</Text>
            <Text style={styles.title}>{isAdmin ? "Review account evidence from the verification queue." : "Submit your identity evidence for review."}</Text>
          </View>

          {!isAdmin ? (
            <View style={styles.formCard}>
              <SectionHeader title={account.accountType === "landlord" ? "Become a Verified Landlord" : `${roleLabel(account.accountType)} verification`} subtitle="Submit identity evidence for review. Basic account access stays available while this is reviewed." />
              <View style={styles.actionGrid}>
                <EvidenceButton label="ID front" done={Boolean(idFrontFile)} icon="card-outline" onPress={() => captureIdentityImage("front")} />
                <EvidenceButton label="ID back" done={Boolean(idBackFile)} icon="albums-outline" onPress={() => captureIdentityImage("back")} />
                {account.accountType === "landlord" ? <EvidenceButton label="Ownership/authority" done={Boolean(ownershipFile)} icon="document-attach-outline" onPress={chooseOwnershipEvidence} /> : null}
              </View>
              <TextInput placeholder="Document number" placeholderTextColor={colors.textMuted} value={documentNumber} onChangeText={setDocumentNumber} style={styles.input} />
              {account.accountType === "landlord" ? <TextInput placeholder="Estate or company name" placeholderTextColor={colors.textMuted} value={agencyName} onChangeText={setAgencyName} style={styles.input} /> : null}
              {account.accountType === "landlord" ? <TextInput placeholder="Public contact or branch details" placeholderTextColor={colors.textMuted} value={contactDetails} onChangeText={setContactDetails} style={styles.input} /> : null}
              <Pressable onPress={submitFullVerification} disabled={authLoading || authUser?.verified} style={[styles.button, (authLoading || authUser?.verified) && styles.buttonDisabled]}>
                {authLoading ? <ActivityIndicator color={colors.accentText} /> : <Text style={styles.buttonText}>{authUser?.verified ? "Already verified" : "Submit for review"}</Text>}
              </Pressable>
            </View>
          ) : null}

          {notice ? <Text style={styles.notice}>{notice}</Text> : null}
          {authError ? <Text style={styles.error}>{authError}</Text> : null}

          <SectionHeader title={isAdmin ? "Verification queue" : "My verification requests"} subtitle="Fetched with the signed-in account token." />
          <View style={styles.queueStack}>
            {state.verifications.map((item) => (
              <View key={item.id} style={styles.queueCard}>
                <View style={styles.row}>
                  <Text style={styles.name}>{item.name}</Text>
                  <Text style={styles.status}>{item.status}</Text>
                </View>
                <Text style={styles.meta}>{item.role}</Text>
                <View style={styles.checkRow}>
                  {item.checks.map((check) => (
                    <View key={check} style={styles.checkPill}>
                      <Ionicons name="checkmark-circle-outline" size={14} color={colors.success} />
                      <Text style={styles.checkText}>{check}</Text>
                    </View>
                  ))}
                </View>
                <Text style={styles.reviewedBy}>Reviewed by {item.reviewedBy || "Pending"}</Text>
                {isAdmin && item.status !== "Approved" ? (
                  <View style={styles.reviewRow}>
                    <Pressable onPress={() => review(item.id, "approved")} disabled={authLoading} style={styles.approveButton}>
                      <Text style={styles.approveText}>Approve</Text>
                    </Pressable>
                    <Pressable onPress={() => review(item.id, "rejected")} disabled={authLoading} style={styles.rejectButton}>
                      <Text style={styles.rejectText}>Reject</Text>
                    </Pressable>
                  </View>
                ) : null}
              </View>
            ))}
            {!state.verifications.length ? <Text style={styles.empty}>No verification requests yet.</Text> : null}
          </View>

          <SectionHeader title="Required checks" subtitle="The account verification flow enforces these before approval." />
          <View style={styles.requirementCard}>
            {verificationChecks.map((item) => (
              <View key={item} style={styles.requirementRow}>
                <Ionicons name="shield-checkmark-outline" size={18} color={colors.accent} />
                <Text style={styles.requirementText}>{item}</Text>
              </View>
            ))}
          </View>
        </ScrollView>
      </Screen>
    </AccessGuard>
  );
}

function EvidenceButton({ done, icon, label, onPress }: { done: boolean; icon: keyof typeof Ionicons.glyphMap; label: string; onPress: () => void }) {
  return (
    <Pressable onPress={onPress} style={[styles.evidenceButton, done && styles.evidenceButtonDone]}>
      <Ionicons name={done ? "checkmark-circle" : icon} size={18} color={done ? colors.success : colors.accent} />
      <Text style={styles.evidenceText}>{label}</Text>
    </Pressable>
  );
}

function imageAssetToUpload(asset: ImagePicker.ImagePickerAsset, label: string): AccountMediaFile {
  const cleanUri = asset.uri.split("?")[0] || "";
  const extension = cleanUri.split(".").pop()?.toLowerCase() || "jpg";
  const safeExtension = extension.length > 5 ? "jpg" : extension;
  return {
    uri: asset.uri,
    name: asset.fileName || `${label}-${Date.now()}.${safeExtension}`,
    type: asset.mimeType || `image/${safeExtension === "jpg" ? "jpeg" : safeExtension}`,
  };
}

function Toggle({ label, value, onPress }: { label: string; value: boolean; onPress: () => void }) {
  return (
    <Pressable onPress={onPress} style={[styles.toggle, value && styles.toggleActive]}>
      <Ionicons name={value ? "checkmark-circle" : "ellipse-outline"} size={18} color={value ? colors.accent : colors.textMuted} />
      <Text style={styles.toggleText}>{label}</Text>
    </Pressable>
  );
}

function roleLabel(role: AccountRole) {
  if (role === "admin") return "Administrator";
  return role.charAt(0).toUpperCase() + role.slice(1);
}

const styles = StyleSheet.create({
  content: { padding: spacing.lg, gap: spacing.lg },
  hero: { backgroundColor: colors.surfaceElevated, borderRadius: radius.xl, padding: spacing.lg, gap: spacing.sm, ...shadows.card },
  kicker: { color: colors.accent, ...typography.label },
  title: { color: colors.text, fontSize: 26, lineHeight: 32, ...typography.display },
  formCard: { backgroundColor: colors.surfaceElevated, borderRadius: radius.lg, padding: spacing.md, gap: spacing.sm, ...shadows.soft },
  actionGrid: { gap: spacing.sm },
  evidenceButton: { minHeight: 44, flexDirection: "row", alignItems: "center", gap: spacing.sm, borderRadius: radius.md, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.background, paddingHorizontal: 12 },
  evidenceButtonDone: { borderColor: colors.success, backgroundColor: colors.successSoft },
  evidenceText: { color: colors.text, ...typography.label },
  input: { backgroundColor: colors.background, borderRadius: radius.md, borderWidth: 1, borderColor: colors.border, color: colors.text, paddingHorizontal: 12, paddingVertical: 12, ...typography.body },
  textArea: { minHeight: 84, textAlignVertical: "top" },
  toggle: { minHeight: 44, flexDirection: "row", alignItems: "center", gap: spacing.sm, backgroundColor: colors.background, borderRadius: radius.md, borderWidth: 1, borderColor: colors.border, paddingHorizontal: 12 },
  toggleActive: { borderColor: colors.accent, backgroundColor: colors.accentSoft },
  toggleText: { color: colors.text, ...typography.label },
  button: { backgroundColor: colors.accent, borderRadius: radius.lg, alignItems: "center", justifyContent: "center", minHeight: 48 },
  buttonDisabled: { opacity: 0.5 },
  buttonText: { color: colors.accentText, ...typography.button },
  notice: { color: colors.success, ...typography.label },
  error: { color: colors.danger, lineHeight: 20, ...typography.label },
  queueStack: { gap: spacing.sm },
  queueCard: { backgroundColor: colors.surfaceElevated, borderRadius: radius.lg, padding: spacing.md, gap: 8, ...shadows.soft },
  row: { flexDirection: "row", justifyContent: "space-between", gap: 10 },
  name: { flex: 1, color: colors.text, ...typography.title },
  status: { color: colors.success, ...typography.label },
  meta: { color: colors.textMuted, lineHeight: 18, ...typography.body },
  checkRow: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  checkPill: { flexDirection: "row", alignItems: "center", gap: 6, backgroundColor: colors.background, borderRadius: 999, paddingHorizontal: 10, paddingVertical: 8 },
  checkText: { color: colors.text, fontSize: 12, ...typography.label },
  reviewedBy: { color: colors.textMuted, fontSize: 12, fontStyle: "italic", ...typography.body },
  reviewRow: { flexDirection: "row", gap: spacing.sm },
  approveButton: { flex: 1, alignItems: "center", borderRadius: radius.md, backgroundColor: colors.successSoft, paddingVertical: 10 },
  approveText: { color: colors.success, ...typography.button },
  rejectButton: { flex: 1, alignItems: "center", borderRadius: radius.md, backgroundColor: colors.dangerSoft, paddingVertical: 10 },
  rejectText: { color: colors.danger, ...typography.button },
  requirementCard: { backgroundColor: colors.surfaceElevated, borderRadius: radius.lg, padding: spacing.md, gap: 10, ...shadows.soft },
  requirementRow: { flexDirection: "row", alignItems: "center", gap: 10 },
  requirementText: { color: colors.text, flex: 1, ...typography.body },
  empty: { color: colors.textMuted, ...typography.body },
});
