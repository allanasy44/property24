import { Ionicons } from "@expo/vector-icons";
import * as ImagePicker from "expo-image-picker";
import { useRouter, type Href } from "expo-router";
import type React from "react";
import { useEffect, useState } from "react";
import { ImageBackground, Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { Screen } from "../../components/Screen";
import { colors, radius, shadows, spacing, typography, useTheme } from "../../constants/theme";
import { AccountMediaFile, AccountRole, useRentalPlatform } from "../../state/rentalPlatform";

type SettingsRowProps = {
  icon: keyof typeof Ionicons.glyphMap;
  title: string;
  meta?: string;
  href?: Href;
  tone?: "default" | "danger";
  onPress?: () => void;
  disabled?: boolean;
};

type PhotoTarget = "profile" | "cover";
type ProfileTextTarget = "name" | "about";

export default function ProfileScreen() {
  const { colors: themeColors } = useTheme();
  const colors = themeColors;
  const styles = createStyles(themeColors);
  const { account, authUser, authLoading, authError, signOut, updateAccountProfile } = useRentalPlatform();
  const [nameDraft, setNameDraft] = useState(authUser?.name || "");
  const [bioDraft, setBioDraft] = useState(authUser?.bio || "");
  const [profilePictureDraft, setProfilePictureDraft] = useState(authUser?.profilePicture || "");
  const [coverPhotoDraft, setCoverPhotoDraft] = useState(authUser?.coverPhoto || "");
  const [notice, setNotice] = useState("");
  const [editingProfile, setEditingProfile] = useState(false);
  const [editingField, setEditingField] = useState<ProfileTextTarget | null>(null);
  const [mediaSheetTarget, setMediaSheetTarget] = useState<PhotoTarget | null>(null);

  useEffect(() => {
    setNameDraft(authUser?.name || "");
    setBioDraft(authUser?.bio || "");
    setProfilePictureDraft(authUser?.profilePicture || "");
    setCoverPhotoDraft(authUser?.coverPhoto || "");
  }, [authUser?.bio, authUser?.coverPhoto, authUser?.name, authUser?.profilePicture]);

  const selectedProfilePicture = profilePictureDraft.trim();
  const selectedCoverPhoto = coverPhotoDraft.trim();
  const hiddenCount = account.hiddenSections.length;
  const verificationLabel = authUser?.verified ? "Verified" : authUser?.accountOnboardingComplete ? "Basic account" : account.onboardingRequirements.length ? `${account.onboardingRequirements.length} pending` : "Ready";

  const saveProfileMedia = async () => {
    setNotice("");
    try {
      await updateAccountProfile({
        name: nameDraft.trim(),
        bio: bioDraft.trim(),
        profilePicture: selectedProfilePicture,
        coverPhoto: coverPhotoDraft.trim(),
      });
      setNotice("Profile saved.");
      setEditingField(null);
      setEditingProfile(false);
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "Profile could not be saved.");
    }
  };

  const pickImage = async (target: PhotoTarget) => {
    setNotice("");
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) {
      setNotice("Photo library permission is required to update profile images.");
      return;
    }

    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ["images"],
      allowsEditing: true,
      aspect: target === "cover" ? [16, 9] : [1, 1],
      quality: 0.86,
    });
    if (result.canceled || !result.assets[0]) return;

    const asset = result.assets[0];
    const file = imageAssetToUpload(asset, target);

    if (target === "profile") setProfilePictureDraft(asset.uri);
    if (target === "cover") setCoverPhotoDraft(asset.uri);

    try {
      await updateAccountProfile({
        name: nameDraft.trim(),
        bio: bioDraft.trim(),
        profilePicture: target === "profile" ? "" : selectedProfilePicture,
        coverPhoto: target === "cover" ? "" : selectedCoverPhoto,
        profilePictureFile: target === "profile" ? file : undefined,
        coverPhotoFile: target === "cover" ? file : undefined,
      });
      setNotice(`${target === "cover" ? "Cover photo" : "Profile photo"} updated.`);
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "Image could not be uploaded.");
    }
  };

  const removeImage = async (target: PhotoTarget) => {
    setNotice("");
    if (target === "profile") setProfilePictureDraft("");
    if (target === "cover") setCoverPhotoDraft("");

    try {
      await updateAccountProfile({
        name: nameDraft.trim(),
        bio: bioDraft.trim(),
        profilePicture: target === "profile" ? "" : selectedProfilePicture,
        coverPhoto: target === "cover" ? "" : selectedCoverPhoto,
        removeProfilePicture: target === "profile",
        removeCoverPhoto: target === "cover",
      });
      setNotice(`${target === "cover" ? "Cover photo" : "Profile photo"} removed.`);
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "Image could not be removed.");
    }
  };

  if (editingProfile) {
    return (
      <Screen>
        <ScrollView contentContainerStyle={styles.editContent} showsVerticalScrollIndicator={false}>
          <View style={styles.editHeader}>
            <Pressable onPress={() => { setMediaSheetTarget(null); setEditingField(null); setEditingProfile(false); }} style={styles.backButton}>
              <Ionicons name="chevron-back" size={25} color={colors.text} />
            </Pressable>
            <Text style={styles.editTitle}>Profile</Text>
          </View>

          {editingField ? (
            <FocusedTextEditor
              target={editingField}
              value={editingField === "name" ? nameDraft : bioDraft}
              onChangeText={editingField === "name" ? setNameDraft : setBioDraft}
              onDone={() => setEditingField(null)}
            />
          ) : null}

          <View style={styles.coverTopSection}>
            <View style={styles.coverEditTitleRow}>
              <View style={styles.coverEditCopy}>
                <Text style={styles.coverEditTitle}>Cover photo</Text>
                <Text style={styles.coverEditMeta}>Public profile header</Text>
              </View>
              <Pressable onPress={() => setMediaSheetTarget("cover")} style={styles.coverEditAction}>
                <Ionicons name="camera-outline" size={18} color={colors.accent} />
              </Pressable>
            </View>
            <Pressable onPress={() => setMediaSheetTarget("cover")} style={styles.editCoverPreview}>
              {selectedCoverPhoto ? (
                <ImageBackground source={{ uri: selectedCoverPhoto }} resizeMode="cover" style={styles.editCoverImage}>
                  <View style={styles.coverShade} />
                  <View style={styles.coverChangePill}>
                    <Ionicons name="camera" size={14} color={colors.accentText} />
                    <Text style={styles.coverChangeText}>Change</Text>
                  </View>
                </ImageBackground>
              ) : (
                <View style={styles.editCoverEmpty}>
                  <Ionicons name="image-outline" size={24} color={colors.textMuted} />
                  <Text style={styles.editCoverEmptyText}>Add cover photo</Text>
                </View>
              )}
            </Pressable>
          </View>

          <View style={styles.editPhotoStage}>
            <Pressable onPress={() => setMediaSheetTarget("profile")} style={styles.editAvatar}>
              {selectedProfilePicture ? (
                <ImageBackground source={{ uri: selectedProfilePicture }} resizeMode="cover" style={styles.avatarImage} />
              ) : (
                <Text style={styles.editAvatarText}>{avatarText(nameDraft || authUser?.name)}</Text>
              )}
              <View style={styles.editAvatarCamera}>
                <Ionicons name="camera" size={22} color={colors.accentText} />
              </View>
            </Pressable>
          </View>

          <View style={styles.editSection}>
            <EditField icon="person-outline" label="Name">
              <EditableTextRow active={editingField === "name"} emptyText="Add name" value={nameDraft} onEdit={() => setEditingField("name")} />
            </EditField>
            <EditField icon="information-circle-outline" label="About">
              <EditableTextRow active={editingField === "about"} emptyText="Add about" value={bioDraft} onEdit={() => setEditingField("about")} />
            </EditField>
          </View>

          {notice ? <Text style={[styles.notice, isErrorNotice(notice) ? styles.errorText : null]}>{notice}</Text> : null}
          {authError ? <Text style={styles.errorText}>{authError}</Text> : null}
          <Pressable onPress={saveProfileMedia} disabled={authLoading} style={[styles.editSaveButton, authLoading && styles.buttonDisabled]}>
            <Text style={styles.editSaveText}>{authLoading ? "Saving..." : "Save"}</Text>
          </Pressable>
        </ScrollView>
        <PhotoActionSheet
          hasPhoto={mediaSheetTarget === "cover" ? Boolean(selectedCoverPhoto) : Boolean(selectedProfilePicture)}
          target={mediaSheetTarget}
          visible={Boolean(mediaSheetTarget)}
          onClose={() => setMediaSheetTarget(null)}
          onPick={(target) => { setMediaSheetTarget(null); void pickImage(target); }}
          onRemove={(target) => { setMediaSheetTarget(null); void removeImage(target); }}
        />
      </Screen>
    );
  }

  return (
    <Screen>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <View style={styles.settingsHeader}>
          <Text style={styles.screenTitle}>Profile</Text>
          <Text style={styles.brandMark}>P24</Text>
        </View>

        <Pressable onPress={() => setEditingProfile(true)} style={({ pressed }) => [styles.profileHero, pressed && styles.profileHeroPressed]}>
          {selectedCoverPhoto ? (
            <ImageBackground source={{ uri: selectedCoverPhoto }} resizeMode="cover" style={styles.profileHeroImage}>
              <ProfileHeroContent accountType={account.accountType} bio={authUser?.bio} email={authUser?.email} name={authUser?.name} phone={authUser?.phone} profilePicture={selectedProfilePicture} verified={Boolean(authUser?.verified)} />
            </ImageBackground>
          ) : (
            <View style={[styles.profileHeroImage, styles.profileHeroEmpty]}>
              <ProfileHeroContent accountType={account.accountType} bio={authUser?.bio} email={authUser?.email} name={authUser?.name} phone={authUser?.phone} profilePicture={selectedProfilePicture} verified={Boolean(authUser?.verified)} />
            </View>
          )}
        </Pressable>

        <SettingsGroup title="Account">
          <SettingsRow
            icon="shield-checkmark-outline"
            title="Verification"
            meta={verificationLabel}
            href={account.visibleSections.includes("verification") || account.onboardingRequirements.length ? "/verification" : undefined}
          />
          <SettingsRow
            icon="lock-closed-outline"
            title="Privacy"
            meta={`${hiddenCount} hidden`}
          />
        </SettingsGroup>

        <SettingsGroup title="Settings">
          <SettingsRow icon="notifications-outline" title="Notifications" />
          <SettingsRow icon="globe-outline" title="Language" meta="English" />
        </SettingsGroup>

        <SettingsGroup>
          <SettingsRow icon="help-circle-outline" title="Help" />
          <SettingsRow icon="document-text-outline" title="Terms" />
          <SettingsRow icon="log-out-outline" title={authLoading ? "Signing out..." : "Sign out"} tone="danger" onPress={signOut} disabled={authLoading} />
        </SettingsGroup>
      </ScrollView>
    </Screen>
  );
}

function EditField({ children, icon, label }: { children: React.ReactNode; icon: keyof typeof Ionicons.glyphMap; label: string }) {
  const { colors: themeColors } = useTheme();
  const colors = themeColors;
  const styles = createStyles(themeColors);
  return (
    <View style={styles.editField}>
      <Ionicons name={icon} size={21} color={colors.textMuted} />
      <View style={styles.editFieldCopy}>
        <Text style={styles.editFieldLabel}>{label}</Text>
        {children}
      </View>
    </View>
  );
}

function SettingsGroup({ children, title }: { children: React.ReactNode; title?: string }) {
  const styles = createStyles(useTheme().colors);
  return (
    <View style={styles.groupWrap}>
      {title ? <Text style={styles.groupLabel}>{title}</Text> : null}
      <View style={styles.settingsGroup}>{children}</View>
    </View>
  );
}

function FocusedTextEditor({ onChangeText, onDone, target, value }: { onChangeText: (value: string) => void; onDone: () => void; target: ProfileTextTarget; value: string }) {
  const styles = createStyles(useTheme().colors);
  const isAbout = target === "about";
  return (
    <View style={styles.focusEditor}>
      <View style={styles.focusEditorHeader}>
        <View>
          <Text style={styles.focusLabel}>{isAbout ? "About" : "Name"}</Text>
          <Text style={styles.focusMeta}>{isAbout ? "Visible on your rental profile" : "Visible to verified rental users"}</Text>
        </View>
        <Pressable onPress={onDone} style={styles.focusDoneButton}>
          <Text style={styles.focusDoneText}>Done</Text>
        </Pressable>
      </View>
      <TextInput
        key={target}
        value={value}
        onChangeText={onChangeText}
        placeholder={isAbout ? "About" : "Name"}
        placeholderTextColor={colors.textMuted}
        style={[styles.focusInput, isAbout && styles.focusInputMultiline]}
        multiline={isAbout}
        autoFocus
      />
    </View>
  );
}

function EditableTextRow({ active, emptyText, onEdit, value }: { active: boolean; emptyText: string; onEdit: () => void; value: string }) {
  const styles = createStyles(useTheme().colors);
  const textValue = value.trim();
  return (
    <View style={[styles.aboutDisplayRow, active && styles.editableRowActive]}>
      <Text numberOfLines={2} style={[styles.aboutDisplayText, !textValue && styles.aboutPlaceholder]}>{textValue || emptyText}</Text>
      <Pressable onPress={onEdit} style={[styles.aboutEditButton, active && styles.aboutEditButtonActive]}>
        <Ionicons name="pencil" size={16} color={active ? colors.text : colors.accent} />
      </Pressable>
    </View>
  );
}

function PhotoActionSheet({ hasPhoto, onClose, onPick, onRemove, target, visible }: { hasPhoto: boolean; onClose: () => void; onPick: (target: PhotoTarget) => void; onRemove: (target: PhotoTarget) => void; target: PhotoTarget | null; visible: boolean }) {
  const { colors: themeColors } = useTheme();
  const colors = themeColors;
  const styles = createStyles(themeColors);
  if (!target) return null;
  const title = target === "cover" ? "Cover photo" : "Profile photo";

  return (
    <Modal animationType="slide" transparent visible={visible} onRequestClose={onClose}>
      <Pressable style={styles.sheetBackdrop} onPress={onClose} />
      <View style={styles.sheetWrap}>
        <View style={styles.sheetHandle} />
        <Text style={styles.sheetTitle}>{title}</Text>
        <Text style={styles.sheetMeta}>{hasPhoto ? "Update or remove this photo" : "Add a photo from your gallery"}</Text>
        <Pressable onPress={() => onPick(target)} style={styles.sheetAction}>
          <View style={styles.sheetActionIcon}><Ionicons name="image-outline" size={20} color={colors.text} /></View>
          <Text style={styles.sheetActionText}>{hasPhoto ? "Change photo" : "Add photo"}</Text>
        </Pressable>
        {hasPhoto ? (
          <Pressable onPress={() => onRemove(target)} style={styles.sheetAction}>
            <View style={[styles.sheetActionIcon, styles.sheetDangerIcon]}><Ionicons name="trash-outline" size={20} color={colors.danger} /></View>
            <Text style={[styles.sheetActionText, styles.sheetDangerText]}>Remove photo</Text>
          </Pressable>
        ) : null}
        <Pressable onPress={onClose} style={styles.sheetCancel}>
          <Text style={styles.sheetCancelText}>Cancel</Text>
        </Pressable>
      </View>
    </Modal>
  );
}

function ProfileHeroContent({ accountType, bio, email, name, phone, profilePicture, verified }: { accountType: AccountRole; bio?: string; email?: string; name?: string; phone?: string; profilePicture: string; verified: boolean }) {
  const { colors: themeColors } = useTheme();
  const colors = themeColors;
  const styles = createStyles(themeColors);
  return (
    <View style={styles.profileHeroShade}>
      <View style={styles.avatarLarge}>
        {profilePicture ? (
          <ImageBackground source={{ uri: profilePicture }} resizeMode="cover" style={styles.avatarImage} />
        ) : (
          <Text style={styles.avatarLargeText}>{avatarText(name)}</Text>
        )}
      </View>
      <View style={styles.profileHeroBody}>
        <View style={styles.nameRow}>
          <Text numberOfLines={1} style={styles.name}>{name || `${roleLabel(accountType)} workspace`}</Text>
          {verified ? <Ionicons name="checkmark-circle" size={16} color={colors.success} /> : null}
        </View>
        <Text numberOfLines={1} style={styles.subtitle}>{bio || email || phone || "Tap to update profile"}</Text>
        <View style={styles.profileMetaRow}>
          <Text style={styles.rolePill}>{roleLabel(accountType)}</Text>
          <View style={styles.editPill}>
            <Ionicons name="pencil" size={12} color={colors.text} />
            <Text style={styles.editPillText}>Edit</Text>
          </View>
        </View>
      </View>
      <Ionicons name="chevron-forward" size={19} color={colors.text} />
    </View>
  );
}

function SettingsRow({ disabled, href, icon, meta, onPress, title, tone = "default" }: SettingsRowProps) {
  const { colors: themeColors } = useTheme();
  const colors = themeColors;
  const styles = createStyles(themeColors);
  const router = useRouter();
  const handlePress = () => {
    if (onPress) {
      onPress();
      return;
    }
    if (href) router.push(href);
  };

  return (
    <Pressable disabled={disabled || (!href && !onPress)} onPress={handlePress} style={({ pressed }) => [styles.settingsRow, pressed && styles.settingsRowPressed]}>
      <View style={[styles.rowIcon, tone === "danger" && styles.rowIconDanger]}>
        <Ionicons name={icon} size={22} color={tone === "danger" ? colors.danger : colors.textMuted} />
      </View>
      <View style={styles.rowBody}>
        <View style={styles.rowCopy}>
          <Text numberOfLines={1} style={[styles.rowTitle, tone === "danger" && styles.rowTitleDanger]}>{title}</Text>
          {meta ? <Text numberOfLines={2} style={styles.rowMeta}>{meta}</Text> : null}
        </View>
        {href ? <Ionicons name="chevron-forward" size={18} color={colors.textMuted} /> : null}
      </View>
    </Pressable>
  );
}

function roleLabel(role: AccountRole) {
  if (role === "admin") return "Administrator";
  return role.charAt(0).toUpperCase() + role.slice(1);
}

function avatarText(name?: string) {
  if (!name) return "P24";
  return name
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("");
}

function imageAssetToUpload(asset: ImagePicker.ImagePickerAsset, target: PhotoTarget): AccountMediaFile {
  const extension = fileExtension(asset.uri);
  const type = asset.mimeType || `image/${extension === "jpg" ? "jpeg" : extension}`;
  return {
    uri: asset.uri,
    name: asset.fileName || `${target}-photo-${Date.now()}.${extension}`,
    type,
  };
}

function fileExtension(uri: string) {
  const cleanUri = uri.split("?")[0] || "";
  const extension = cleanUri.split(".").pop()?.toLowerCase();
  if (!extension || extension.length > 5) return "jpg";
  if (extension === "jpeg") return "jpg";
  return extension;
}

function isErrorNotice(value: string) {
  const normalized = value.toLowerCase();
  return normalized.includes("could not") || normalized.includes("failed") || normalized.includes("required");
}

function createStyles(themeColors: typeof colors) {
  const colors = themeColors;
  return StyleSheet.create({
  content: { padding: spacing.md, paddingBottom: spacing.xl, gap: spacing.md, backgroundColor: colors.background },
  settingsHeader: { minHeight: 42, flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  screenTitle: { color: colors.text, fontSize: 24, lineHeight: 29, ...typography.display },
  brandMark: { overflow: "hidden", borderRadius: 4, backgroundColor: colors.accent, color: colors.accentText, paddingHorizontal: 8, paddingVertical: 4, fontSize: 12, ...typography.button },
  profileHero: { overflow: "hidden", borderWidth: 1, borderColor: colors.border, borderRadius: radius.lg, backgroundColor: colors.surfaceElevated, ...shadows.card },
  profileHeroPressed: { borderColor: "rgba(229,9,20,0.46)", backgroundColor: colors.surfaceMuted },
  profileHeroImage: { minHeight: 154, justifyContent: "flex-end" },
  profileHeroEmpty: { backgroundColor: colors.surfaceElevated },
  profileHeroShade: { flex: 1, flexDirection: "row", alignItems: "flex-end", gap: 12, padding: spacing.md, backgroundColor: "rgba(2,11,20,0.62)" },
  avatarLarge: { width: 66, height: 66, borderRadius: 33, overflow: "hidden", alignItems: "center", justifyContent: "center", borderWidth: 2, borderColor: colors.accent, backgroundColor: colors.background },
  avatarImage: { width: "100%", height: "100%" },
  avatarLargeText: { color: colors.accent, fontSize: 16, ...typography.button },
  profileHeroBody: { flex: 1, minWidth: 0, gap: 6 },
  nameRow: { flexDirection: "row", alignItems: "center", gap: 6 },
  name: { flex: 1, color: colors.text, fontSize: 19, lineHeight: 24, ...typography.title },
  subtitle: { color: colors.textMuted, fontSize: 13, lineHeight: 18, ...typography.body },
  profileMetaRow: { flexDirection: "row", alignItems: "center", gap: 7, flexWrap: "wrap" },
  rolePill: { overflow: "hidden", borderRadius: 999, borderWidth: 1, borderColor: colors.border, color: colors.text, backgroundColor: colors.surfaceMuted, paddingHorizontal: 9, paddingVertical: 5, fontSize: 11, ...typography.button },
  editPill: { minHeight: 27, flexDirection: "row", alignItems: "center", gap: 5, borderRadius: 999, paddingHorizontal: 9, backgroundColor: colors.accent },
  editPillText: { color: colors.accentText, fontSize: 11, ...typography.button },
  coverShade: { ...StyleSheet.absoluteFillObject, backgroundColor: "rgba(2,11,20,0.12)" },
  groupWrap: { gap: spacing.xs },
  groupLabel: { color: colors.accent, fontSize: 12, lineHeight: 16, paddingHorizontal: 2, paddingTop: 2, ...typography.label },
  settingsGroup: { overflow: "hidden", borderWidth: 1, borderColor: colors.border, borderRadius: radius.lg, backgroundColor: colors.surfaceElevated, ...shadows.soft },
  settingsRow: { minHeight: 64, flexDirection: "row", alignItems: "center", backgroundColor: colors.surfaceElevated },
  settingsRowPressed: { backgroundColor: colors.surfaceMuted },
  rowIcon: { width: 52, minHeight: 64, alignItems: "center", justifyContent: "center", backgroundColor: "transparent" },
  rowIconDanger: { backgroundColor: "transparent" },
  rowBody: { flex: 1, minWidth: 0, minHeight: 64, flexDirection: "row", alignItems: "center", gap: 8, borderBottomWidth: 1, borderBottomColor: colors.border, paddingRight: 14, paddingVertical: 8 },
  rowCopy: { flex: 1, minWidth: 0, justifyContent: "center", gap: 3 },
  rowTitle: { color: colors.text, fontSize: 16, lineHeight: 21, ...typography.title },
  rowTitleDanger: { color: colors.danger },
  rowMeta: { color: colors.textMuted, fontSize: 13, lineHeight: 18, ...typography.body },
  notice: { color: colors.success, fontSize: 12, ...typography.label },
  errorText: { color: colors.danger, fontSize: 12, lineHeight: 17, ...typography.label },
  buttonDisabled: { opacity: 0.62 },
  editContent: { paddingBottom: spacing.xl, backgroundColor: colors.background },
  editHeader: { minHeight: 52, flexDirection: "row", alignItems: "center", gap: 8, borderBottomWidth: 1, borderBottomColor: colors.border, paddingHorizontal: 6, backgroundColor: colors.background },
  backButton: { width: 38, height: 40, alignItems: "center", justifyContent: "center" },
  editTitle: { color: colors.text, fontSize: 21, lineHeight: 26, ...typography.title },
  focusEditor: { borderTopWidth: 8, borderTopColor: colors.background, backgroundColor: colors.surfaceElevated, paddingHorizontal: 20, paddingVertical: 14, gap: 12 },
  focusEditorHeader: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 12 },
  focusLabel: { color: colors.accent, fontSize: 13, lineHeight: 17, ...typography.label },
  focusMeta: { color: colors.textMuted, fontSize: 12, lineHeight: 16, marginTop: 2, ...typography.body },
  focusDoneButton: { minHeight: 34, justifyContent: "center", borderRadius: 999, paddingHorizontal: 12, backgroundColor: colors.accent },
  focusDoneText: { color: colors.accentText, fontSize: 12, ...typography.button },
  focusInput: { minHeight: 44, borderBottomWidth: 1, borderBottomColor: colors.accent, color: colors.text, fontSize: 18, lineHeight: 24, paddingHorizontal: 0, paddingVertical: 7, outlineStyle: "none" as any, ...typography.body },
  focusInputMultiline: { minHeight: 84, textAlignVertical: "top" },
  coverTopSection: { borderTopWidth: 8, borderTopColor: colors.background, backgroundColor: colors.surface, paddingBottom: 14 },
  editPhotoStage: { alignItems: "center", gap: 11, paddingTop: 22, paddingBottom: 22, backgroundColor: colors.surface },
  editAvatar: { width: 154, height: 154, borderRadius: 77, overflow: "hidden", alignItems: "center", justifyContent: "center", backgroundColor: colors.surfaceMuted },
  editAvatarText: { color: colors.accent, fontSize: 30, ...typography.display },
  editAvatarCamera: { position: "absolute", right: 11, bottom: 11, width: 44, height: 44, borderRadius: 22, alignItems: "center", justifyContent: "center", backgroundColor: colors.accent },
  editSection: { borderTopWidth: 8, borderTopColor: colors.background, backgroundColor: colors.surfaceElevated },
  editField: { minHeight: 68, flexDirection: "row", alignItems: "center", gap: 18, paddingHorizontal: 20, borderBottomWidth: 1, borderBottomColor: colors.border, backgroundColor: colors.surfaceElevated },
  editFieldCopy: { flex: 1, minWidth: 0, gap: 2 },
  editFieldLabel: { color: colors.accent, fontSize: 13, lineHeight: 17, ...typography.label },
  editInput: { minHeight: 36, color: colors.text, fontSize: 16, lineHeight: 21, paddingVertical: 0, outlineStyle: "none" as any, ...typography.body },
  aboutDisplayRow: { minHeight: 36, flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 10 },
  aboutDisplayText: { flex: 1, color: colors.text, fontSize: 16, lineHeight: 21, ...typography.body },
  aboutPlaceholder: { color: colors.textMuted },
  aboutEditButton: { width: 34, height: 34, borderRadius: 17, alignItems: "center", justifyContent: "center", backgroundColor: colors.accentSoft },
  editableRowActive: { borderLeftWidth: 2, borderLeftColor: colors.accent, paddingLeft: 8 },
  aboutEditButtonActive: { backgroundColor: colors.accent },
  coverEditTitleRow: { minHeight: 62, flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: 20 },
  coverEditCopy: { flex: 1, minWidth: 0 },
  coverEditTitle: { color: colors.text, fontSize: 16, lineHeight: 21, ...typography.title },
  coverEditMeta: { color: colors.textMuted, fontSize: 12, lineHeight: 16, marginTop: 2, ...typography.body },
  coverEditAction: { width: 36, height: 36, borderRadius: 18, alignItems: "center", justifyContent: "center", backgroundColor: colors.accentSoft },
  editCoverPreview: { height: 132, marginHorizontal: 20, borderRadius: 8, overflow: "hidden", backgroundColor: colors.background },
  editCoverImage: { flex: 1, justifyContent: "flex-end", padding: 10 },
  editCoverEmpty: { flex: 1, alignItems: "center", justifyContent: "center", gap: 5 },
  editCoverEmptyText: { color: colors.textMuted, fontSize: 12, ...typography.label },
  coverChangePill: { alignSelf: "flex-end", minHeight: 30, flexDirection: "row", alignItems: "center", gap: 5, borderRadius: 999, paddingHorizontal: 10, backgroundColor: "rgba(2,11,20,0.72)" },
  coverChangeText: { color: colors.accentText, fontSize: 12, ...typography.button },
  editSaveButton: { minHeight: 46, alignItems: "center", justifyContent: "center", marginHorizontal: 20, marginTop: 14, borderRadius: 8, backgroundColor: colors.accent },
  editSaveText: { color: colors.accentText, fontSize: 15, ...typography.button },
  sheetBackdrop: { ...StyleSheet.absoluteFillObject, backgroundColor: "rgba(2,11,20,0.72)" },
  sheetWrap: { position: "absolute", left: 0, right: 0, bottom: 0, borderTopLeftRadius: 18, borderTopRightRadius: 18, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.surfaceElevated, paddingHorizontal: spacing.md, paddingTop: 10, paddingBottom: 22, gap: 8, ...shadows.card },
  sheetHandle: { alignSelf: "center", width: 38, height: 4, borderRadius: 999, backgroundColor: colors.muted, marginBottom: 8 },
  sheetTitle: { color: colors.text, fontSize: 17, lineHeight: 22, ...typography.title },
  sheetMeta: { color: colors.textMuted, fontSize: 12, lineHeight: 17, marginBottom: 4, ...typography.body },
  sheetAction: { minHeight: 50, flexDirection: "row", alignItems: "center", gap: 12, borderRadius: radius.md, paddingHorizontal: 8, backgroundColor: colors.surfaceElevated },
  sheetActionIcon: { width: 36, height: 36, borderRadius: 18, alignItems: "center", justifyContent: "center", backgroundColor: colors.surfaceMuted },
  sheetDangerIcon: { backgroundColor: colors.dangerSoft },
  sheetActionText: { color: colors.text, fontSize: 15, ...typography.title },
  sheetDangerText: { color: colors.danger },
  sheetCancel: { minHeight: 46, alignItems: "center", justifyContent: "center", borderRadius: radius.md, marginTop: 4, backgroundColor: colors.background },
  sheetCancelText: { color: colors.text, fontSize: 14, ...typography.button },
  });
}
