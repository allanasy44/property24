import { Ionicons } from "@expo/vector-icons";
import * as Google from "expo-auth-session/providers/google";
import * as ImagePicker from "expo-image-picker";
import * as WebBrowser from "expo-web-browser";
import { ComponentProps, ReactNode, useEffect, useMemo, useRef, useState } from "react";
import { ActivityIndicator, Animated, BackHandler, Easing, KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, useWindowDimensions, View } from "react-native";
import { colors, spacing, typography } from "../constants/theme";
import { AccountMediaFile, AccountRole, PublicAccountRole, useRentalPlatform } from "../state/rentalPlatform";

WebBrowser.maybeCompleteAuthSession();

type AuthGateProps = {
  children: ReactNode;
};

type AuthMode = "signin" | "register";

const publicRoles: PublicAccountRole[] = ["tenant", "landlord"];

const introLetters = "PROPERTY24".split("");

type IdDocumentType = "national_id" | "foreign_id" | "passport" | "drivers_license";

const verificationCountries = ["Zimbabwe", "South Africa", "Botswana", "Zambia", "Mozambique", "Other"];
const idDocumentTypes: { value: IdDocumentType; label: string; icon: keyof typeof Ionicons.glyphMap }[] = [
  { value: "national_id", label: "Zimbabwe National ID", icon: "card-outline" },
  { value: "foreign_id", label: "Foreign national ID", icon: "id-card-outline" },
  { value: "passport", label: "Passport", icon: "book-outline" },
  { value: "drivers_license", label: "Driver's licence", icon: "car-outline" },
];

const googleWebClientId = process.env.EXPO_PUBLIC_GOOGLE_CLIENT_ID?.trim();
const googleIosClientId = process.env.EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID?.trim();
const googleAndroidClientId = process.env.EXPO_PUBLIC_GOOGLE_ANDROID_CLIENT_ID?.trim();
const googleFallbackClientId = googleWebClientId || googleIosClientId || googleAndroidClientId || "missing-google-client-id";
const googleConfigured = Boolean(googleWebClientId || googleIosClientId || googleAndroidClientId);
const passwordMinLength = 15;
const passwordMaxLength = 128;
const passwordControlCharPattern = /[\x00-\x1F\x7F]/;

export function AuthGate({ children }: AuthGateProps) {
  const { ready, authUser, authToken, authError, authLoading, account, signIn, registerAccount, googleSignIn, submitVerification, sendVerificationPhoneOtp, verifyVerificationPhoneOtp, extractVerificationId } = useRentalPlatform();
  const { width } = useWindowDimensions();
  const compact = width < 680;
  const [mode, setMode] = useState<AuthMode>("signin");
  const [accountType, setAccountType] = useState<PublicAccountRole>("tenant");
  const [name, setName] = useState("");
  const [identifier, setIdentifier] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [formNonce, setFormNonce] = useState(0);
  const [submitted, setSubmitted] = useState(false);
  const [localError, setLocalError] = useState("");
  const [introVisible, setIntroVisible] = useState(false);
  const lastIntroUserRef = useRef<string | null>(null);
  const [googleRequest, googleResponse, promptGoogle] = Google.useIdTokenAuthRequest(
    {
      clientId: googleFallbackClientId,
      webClientId: googleWebClientId || googleFallbackClientId,
      iosClientId: googleIosClientId || googleFallbackClientId,
      androidClientId: googleAndroidClientId || googleFallbackClientId,
      scopes: ["openid", "profile", "email"],
      selectAccount: true,
    },
    { scheme: "property24zimbabwe", path: "auth/google" }
  );

  const clearAuthForm = () => {
    setName("");
    setIdentifier("");
    setPhone("");
    setPassword("");
    setConfirmPassword("");
    setShowPassword(false);
    setShowConfirmPassword(false);
    setLocalError("");
    setSubmitted(false);
    setFormNonce((value) => value + 1);
  };

  useEffect(() => {
    const authKey = authUser && authToken ? `${authUser.id}:${authToken.slice(0, 10)}` : null;
    if (!authKey) {
      lastIntroUserRef.current = null;
      clearAuthForm();
      setIntroVisible(false);
      return;
    }
    if (lastIntroUserRef.current === authKey) return;
    lastIntroUserRef.current = authKey;
    clearAuthForm();
    setIntroVisible(true);
  }, [authToken, authUser]);

  useEffect(() => {
    if (!googleResponse) return;
    if (googleResponse.type === "success") {
      const idToken = googleResponse.params.id_token || googleResponse.authentication?.idToken;
      if (!idToken) {
        setLocalError("Google did not return a verified ID token. Check your Google OAuth client setup.");
        return;
      }
      googleSignIn(idToken, mode === "register" ? accountType : undefined).catch(() => undefined);
      return;
    }
    if (googleResponse.type === "error") {
      setLocalError(googleResponse.error?.message || "Google sign-in failed. Try again.");
    }
  }, [accountType, googleResponse, googleSignIn, mode]);

  const passwordPolicyError = useMemo(() => {
    if (mode !== "register" || !password) return "";
    if (password.length < passwordMinLength) return `Password must be at least ${passwordMinLength} characters.`;
    if (password.length > passwordMaxLength) return `Password must be ${passwordMaxLength} characters or fewer.`;
    if (!password.trim()) return "Password must include at least one non-space character.";
    if (passwordControlCharPattern.test(password)) return "Password cannot contain control characters.";
    return "";
  }, [mode, password]);

  const hasRequiredFields = useMemo(() => {
    if (mode === "signin") return Boolean(identifier.trim() && password.length > 0);
    return Boolean(identifier.trim() && password.length > 0 && confirmPassword.length > 0);
  }, [confirmPassword, identifier, mode, name, password, phone]);

  const canSubmit = useMemo(() => {
    if (authLoading) return false;
    if (mode === "signin") return hasRequiredFields;
    return Boolean(hasRequiredFields && !passwordPolicyError && password === confirmPassword);
  }, [authLoading, confirmPassword, hasRequiredFields, mode, password, passwordPolicyError]);

  if (!ready) {
    return (
      <View style={styles.loadingWrap}>
        <ActivityIndicator color={colors.accent} />
      </View>
    );
  }

  if (authUser && authToken) {
    const verificationLocked = ["tenant", "landlord", "agent"].includes(authUser.role) && !authUser.verified;
    return (
      <>
        {verificationLocked ? (
          <VerificationGate role={authUser.role} accountName={authUser.name} accountEmail={authUser.email} authError={authError} authLoading={authLoading} submitVerification={submitVerification} sendPhoneOtp={sendVerificationPhoneOtp} verifyPhoneOtp={verifyVerificationPhoneOtp} extractId={extractVerificationId} />
        ) : children}
        {introVisible ? <PostLoginIntro onDone={() => setIntroVisible(false)} /> : null}
      </>
    );
  }

  const submit = async () => {
    setSubmitted(true);
    setLocalError("");
    if (!hasRequiredFields) {
      setLocalError("Complete the required fields to continue.");
      return;
    }
    if (mode === "register" && passwordPolicyError) {
      setLocalError(passwordPolicyError);
      return;
    }
    if (mode === "register" && password !== confirmPassword) {
      setLocalError("Passwords do not match.");
      return;
    }
    if (!canSubmit) return;

    try {
      if (mode === "signin") {
        await signIn({ username: identifier, password });
        clearAuthForm();
        return;
      }
      await registerAccount({ accountType, name: "", email: identifier, phone: "", password });
      clearAuthForm();
      setMode("signin");
      setLocalError("Account created. Sign in to continue.");
    } catch {
      // The provider exposes the displayable authError.
    }
  };

  const submitGoogle = async () => {
    setSubmitted(false);
    setLocalError("");
    if (!googleConfigured) {
      setLocalError("Google sign-in needs EXPO_PUBLIC_GOOGLE_CLIENT_ID or a native Google client ID.");
      return;
    }
    try {
      await promptGoogle();
    } catch (error) {
      setLocalError(error instanceof Error ? error.message : "Google sign-in failed. Try again.");
    }
  };


  return (
    <KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : undefined} style={styles.wrap}>
      <ScrollView contentContainerStyle={[styles.content, compact && styles.contentCompact]} keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>
        <View key={`auth-form-${formNonce}`} style={[styles.shell, compact && styles.shellCompact]}>
          <View style={[styles.formPanel, compact && styles.formPanelCompact]}>
            <View style={styles.authHeader}>
              <Text style={[styles.brand, compact && styles.brandCompact]}>PROPERTY24</Text>
              <Text style={[styles.headline, compact && styles.headlineCompact]}>{mode === "signin" ? "Sign In" : "Create Account"}</Text>
            </View>
            {mode === "register" ? (
              <View style={styles.googleRoleWrap}>
                <Text style={styles.googleRoleLabel}>Account role</Text>
                <View style={[styles.roleGrid, compact && styles.roleGridCompact]}>
                  {publicRoles.map((role) => (
                    <Pressable key={role} onPress={() => setAccountType(role)} style={[styles.roleCard, compact && styles.roleCardCompact, accountType === role && styles.roleCardActive]}>
                      <Ionicons name={roleIcon(role)} size={compact ? 14 : 16} color={accountType === role ? "#E50914" : "#A3A3A3"} />
                      <Text style={[styles.roleTitle, compact && styles.roleTitleCompact]}>{roleLabel(role)}</Text>
                    </Pressable>
                  ))}
                </View>
              </View>
            ) : null}

            <View style={styles.form}>
              <Field
                compact={compact}
                icon="mail-outline"
                placeholder={mode === "signin" ? "Email, username, or phone" : "Email address"}
                value={identifier}
                onChangeText={setIdentifier}
                autoCapitalize="none"
                keyboardType="email-address"
                autoComplete={mode === "signin" ? "username" : "email"}
                textContentType={mode === "signin" ? "username" : "emailAddress"}
                maxLength={254}
              />
              <Field
                compact={compact}
                icon="lock-closed-outline"
                placeholder="Password"
                value={password}
                onChangeText={setPassword}
                secureTextEntry={!showPassword}
                autoCapitalize="none"
                autoComplete={mode === "signin" ? "current-password" : "new-password"}
                textContentType={mode === "signin" ? "password" : "newPassword"}
                maxLength={passwordMaxLength}
                rightAccessory={
                  <Pressable onPress={() => setShowPassword((value) => !value)} hitSlop={10} style={styles.eyeButton}>
                    <Ionicons name={showPassword ? "eye-off-outline" : "eye-outline"} size={20} color="#B3B3B3" />
                  </Pressable>
                }
              />
              {mode === "register" ? (
                <Field
                  compact={compact}
                  icon="lock-closed-outline"
                  placeholder="Confirm password"
                  value={confirmPassword}
                  onChangeText={setConfirmPassword}
                  secureTextEntry={!showConfirmPassword}
                  autoCapitalize="none"
                  autoComplete="new-password"
                  textContentType="newPassword"
                  maxLength={passwordMaxLength}
                  rightAccessory={
                    <Pressable onPress={() => setShowConfirmPassword((value) => !value)} hitSlop={10} style={styles.eyeButton}>
                      <Ionicons name={showConfirmPassword ? "eye-off-outline" : "eye-outline"} size={20} color="#B3B3B3" />
                    </Pressable>
                  }
                />
              ) : null}
            </View>

            {authError || localError ? <Text style={styles.error}>{authError || localError}</Text> : null}
            {submitted && mode === "register" && passwordPolicyError ? <Text style={styles.error}>{passwordPolicyError}</Text> : null}
            {submitted && mode === "register" && !passwordPolicyError && password !== confirmPassword ? <Text style={styles.error}>Passwords do not match.</Text> : null}
            {submitted && !hasRequiredFields ? <Text style={styles.error}>Complete the required fields to continue.</Text> : null}

            <Pressable onPress={submit} disabled={authLoading} style={[styles.submitButton, authLoading && styles.submitButtonDisabled]}>
              {authLoading ? (
                <ActivityIndicator color={colors.accentText} />
              ) : (
                <Text style={styles.submitText}>{mode === "signin" ? "Sign In" : `Create ${roleLabel(accountType)} Account`}</Text>
              )}
            </Pressable>

            <View style={styles.dividerRow}>
              <View style={styles.dividerLine} />
              <Text style={styles.dividerText}>or</Text>
              <View style={styles.dividerLine} />
            </View>

            <Pressable onPress={submitGoogle} disabled={authLoading || !googleRequest || !googleConfigured} style={[styles.googleButton, (authLoading || !googleRequest || !googleConfigured) && styles.googleButtonDisabled]}>
              <View style={styles.googleMark}>
                <Text style={styles.googleMarkText}>G</Text>
              </View>
              <Text style={styles.googleButtonText}>{mode === "signin" ? "Sign in with Google" : "Continue with Google"}</Text>
            </Pressable>

            <Pressable
              onPress={() => {
                clearAuthForm();
                setMode(mode === "signin" ? "register" : "signin");
              }}
              style={styles.switchPrompt}
            >
              <Text style={styles.switchMuted}>{mode === "signin" ? "New to Property24?" : "Already have an account?"}</Text>
              <Text style={styles.switchAction}>{mode === "signin" ? " Create an account." : " Sign in."}</Text>
            </Pressable>

          </View>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}


function VerificationGate({
  role,
  accountName,
  accountEmail,
  authError,
  authLoading,
  submitVerification,
  sendPhoneOtp,
  verifyPhoneOtp,
  extractId,
}: {
  role: AccountRole;
  accountName: string;
  accountEmail: string;
  authError: string;
  authLoading: boolean;
  submitVerification: ReturnType<typeof useRentalPlatform>["submitVerification"];
  sendPhoneOtp: ReturnType<typeof useRentalPlatform>["sendVerificationPhoneOtp"];
  verifyPhoneOtp: ReturnType<typeof useRentalPlatform>["verifyVerificationPhoneOtp"];
  extractId: ReturnType<typeof useRentalPlatform>["extractVerificationId"];
}) {
  const [phone, setPhone] = useState("");
  const [otpChallengeId, setOtpChallengeId] = useState("");
  const [otpCode, setOtpCode] = useState("");
  const [otpSecondsLeft, setOtpSecondsLeft] = useState(0);
  const [phoneVerified, setPhoneVerified] = useState(false);
  const [countryOfResidence, setCountryOfResidence] = useState("Zimbabwe");
  const [otherResidenceCountry, setOtherResidenceCountry] = useState("");
  const [documentIssueCountry, setDocumentIssueCountry] = useState("Zimbabwe");
  const [otherDocumentCountry, setOtherDocumentCountry] = useState("");
  const [documentType, setDocumentType] = useState<IdDocumentType>("national_id");
  const [idFrontFile, setIdFrontFile] = useState<AccountMediaFile | undefined>();
  const [idBackFile, setIdBackFile] = useState<AccountMediaFile | undefined>();
  const [extractedNationalId, setExtractedNationalId] = useState("");
  const [confirmedNationalId, setConfirmedNationalId] = useState("");
  const [identityConfirmed, setIdentityConfirmed] = useState(false);
  const [agencyName, setAgencyName] = useState("");
  const [agencyRegistration, setAgencyRegistration] = useState("");
  const [contactDetails, setContactDetails] = useState("");
  const [notice, setNotice] = useState("");
  const [localError, setLocalError] = useState("");
  const [currentStage, setCurrentStage] = useState(0);

  const otpCountdown = `${Math.floor(otpSecondsLeft / 60)}:${String(otpSecondsLeft % 60).padStart(2, "0")}`;
  const accountDisplayName = displayAccountName(accountName, accountEmail);
  const setupRequired = role === "landlord" || role === "agent";
  const residenceCountryValue = countryOfResidence === "Other" ? otherResidenceCountry.trim() : countryOfResidence;
  const documentCountryValue = documentIssueCountry === "Other" ? otherDocumentCountry.trim() : documentIssueCountry;
  const selectedDocument = idDocumentTypes.find((item) => item.value === documentType) || idDocumentTypes[0];
  const isZimbabweNationalId = isZimbabweCountry(documentCountryValue) && documentType === "national_id";
  const requiresBack = isZimbabweNationalId;
  const reviewStage = setupRequired ? 8 : 7;

  useEffect(() => {
    if (!otpSecondsLeft) return undefined;
    const timer = setInterval(() => setOtpSecondsLeft((value) => Math.max(0, value - 1)), 1000);
    return () => clearInterval(timer);
  }, [otpSecondsLeft]);

  useEffect(() => {
    if (Platform.OS !== "android") return undefined;
    const subscription = BackHandler.addEventListener("hardwareBackPress", () => {
      if (phoneVerified) {
        setNotice("");
        setLocalError("");
        setCurrentStage((stage) => {
          if (stage <= 2) return 2;
          return Math.max(2, stage - 1);
        });
        return true;
      }
      if (currentStage > 0) {
        setNotice("");
        setLocalError("");
        setCurrentStage((stage) => Math.max(0, stage - 1));
        return true;
      }
      return false;
    });
    return () => subscription.remove();
  }, [currentStage, phoneVerified]);

  const goBack = () => {
    setNotice("");
    setLocalError("");
    setCurrentStage((stage) => Math.max(phoneVerified ? 2 : 0, stage - 1));
  };

  const requestOtp = async () => {
    setNotice("");
    setLocalError("");
    if (!phone.trim()) {
      setLocalError("Enter your phone number.");
      return;
    }
    try {
      const challenge = await sendPhoneOtp(phone);
      setOtpChallengeId(challenge.challengeId);
      setOtpSecondsLeft(challenge.expiresInSeconds || 30);
      setNotice(challenge.message?.trim() ? challenge.message.trim() : "");
      setCurrentStage(1);
    } catch {
      // authError is shown below.
    }
  };

  const confirmOtp = async () => {
    setNotice("");
    setLocalError("");
    if (!otpChallengeId) {
      setLocalError("Request an OTP first.");
      return;
    }
    if (!otpCode.trim()) {
      setLocalError("Enter the OTP.");
      return;
    }
    try {
      const result = await verifyPhoneOtp(otpChallengeId, otpCode);
      setPhoneVerified(result.phoneVerified);
      if (result.phone) setPhone(result.phone);
      setOtpChallengeId("");
      setOtpCode("");
      setOtpSecondsLeft(0);
      setNotice("");
      setCurrentStage(2);
    } catch {
      // authError is shown below.
    }
  };

  const continueDocumentSetup = () => {
    setNotice("");
    setLocalError("");
    if (!residenceCountryValue) {
      setLocalError("Enter your country of residence.");
      return;
    }
    if (!documentCountryValue) {
      setLocalError("Enter the country that issued your document.");
      return;
    }
    if (!isZimbabweCountry(documentCountryValue) && documentType === "national_id") {
      setDocumentType("foreign_id");
    }
    setIdFrontFile(undefined);
    setIdBackFile(undefined);
    setExtractedNationalId("");
    setConfirmedNationalId("");
    setIdentityConfirmed(false);
    setCurrentStage(3);
  };

  const captureId = async (side: "front" | "back") => {
    setNotice("");
    setLocalError("");
    const permission = await ImagePicker.requestCameraPermissionsAsync();
    if (!permission.granted) {
      setLocalError("Camera permission is required.");
      return;
    }
    const result = await ImagePicker.launchCameraAsync({ mediaTypes: ["images"], quality: 0.9, allowsEditing: false });
    const asset = result.assets?.[0];
    if (result.canceled || !asset) return;
    const file = imageAssetToVerificationUpload(asset, `id-${side}`);
    if (side === "front") {
      setIdFrontFile(file);
      setCurrentStage(requiresBack ? 4 : 5);
    } else {
      setIdBackFile(file);
      setCurrentStage(5);
    }
    setIdentityConfirmed(false);
    setExtractedNationalId("");
  };

  const runExtraction = async () => {
    setNotice("");
    setLocalError("");
    if (!idFrontFile || (requiresBack && !idBackFile)) {
      setLocalError("Capture the required document sides.");
      return;
    }
    if (!requiresBack) {
      setCurrentStage(6);
      return;
    }
    try {
      const result = await extractId({ idFrontFile, idBackFile: idBackFile as AccountMediaFile, nationalIdHint: confirmedNationalId });
      setExtractedNationalId(result.extractedNationalIdNumber);
      setConfirmedNationalId(result.extractedNationalIdNumber || confirmedNationalId);
      setIdentityConfirmed(false);
      setCurrentStage(6);
    } catch {
      // authError is shown below.
    }
  };

  const confirmIdentity = () => {
    setNotice("");
    setLocalError("");
    const documentNumber = confirmedNationalId.trim();
    if (!documentNumber) {
      setLocalError(documentType === "passport" ? "Enter your passport number." : "Enter your ID number.");
      return;
    }
    if (isZimbabweNationalId && !isValidZimbabweNationalId(documentNumber)) {
      setLocalError("Zimbabwe national ID must match the local format and check letter. Example: 63123456C12.");
      return;
    }
    if (!isZimbabweNationalId && !isValidForeignDocumentNumber(documentNumber)) {
      setLocalError("Enter a valid document number using letters, numbers, spaces, hyphens, or slashes.");
      return;
    }
    setIdentityConfirmed(true);
    if (setupRequired) {
      setCurrentStage(7);
    } else {
      submit(true);
    }
  };

  const submit = async (identityAlreadyConfirmed = identityConfirmed) => {
    setNotice("");
    setLocalError("");
    if (!phone.trim() || !phoneVerified) {
      setLocalError("Complete OTP verification before continuing.");
      return;
    }
    if (!residenceCountryValue || !documentCountryValue || !documentType) {
      setCurrentStage(2);
      setLocalError("Complete country and document selection.");
      return;
    }
    if (!idFrontFile) {
      setCurrentStage(3);
      setLocalError("Capture the identity document.");
      return;
    }
    if (requiresBack && !idBackFile) {
      setCurrentStage(4);
      setLocalError("Capture the back of the Zimbabwe national ID.");
      return;
    }
    if (!confirmedNationalId.trim() || !identityAlreadyConfirmed) {
      setCurrentStage(6);
      setLocalError("Confirm your document number.");
      return;
    }
    if (role === "landlord" && !agencyName.trim()) {
      setCurrentStage(7);
      setLocalError("Enter the estate or company name.");
      return;
    }
    if (role === "agent" && (!agencyName.trim() || !agencyRegistration.trim() || !contactDetails.trim())) {
      setCurrentStage(7);
      setLocalError("Complete agency details.");
      return;
    }
    try {
      await submitVerification({
        role,
        name: accountDisplayName,
        phone: phone.trim(),
        country_of_residence: residenceCountryValue,
        privacy_notice_accepted: true,
        document_issue_country: documentCountryValue,
        document_type: isZimbabweCountry(documentCountryValue) ? documentType : documentType === "national_id" ? "foreign_id" : documentType,
        residential_address: "",
        address_gps_confirmed: false,
        proof_of_address_confirmed: false,
        politically_exposed_person: false,
        declaration_accepted: true,
        national_id_number: confirmedNationalId.trim(),
        extracted_national_id_number: extractedNationalId.trim(),
        phone_verified: phoneVerified,
        selfie_uploaded: false,
        identity_confirmed: identityAlreadyConfirmed,
        idFrontFile,
        idBackFile,
        agency_name: agencyName.trim(),
        estate_agency_registration: agencyRegistration.trim(),
        contact_details: contactDetails.trim(),
      });
      setNotice("");
      setCurrentStage(reviewStage);
    } catch {
      // authError is shown below.
    }
  };

  const renderStage = () => {
    if (currentStage === 0) {
      return (
        <VerificationScreenCard title="OTP verification" icon="phone-portrait-outline">
          <Field compact icon="call-outline" placeholder="Phone number" value={phone} onChangeText={(value) => { setPhone(value); setPhoneVerified(false); setOtpChallengeId(""); setOtpSecondsLeft(0); }} keyboardType="phone-pad" autoComplete="tel" textContentType="telephoneNumber" maxLength={32} />
          <Pressable onPress={requestOtp} disabled={authLoading || Boolean(otpSecondsLeft)} style={[styles.submitButton, (authLoading || Boolean(otpSecondsLeft)) && styles.submitButtonDisabled]}>
            {authLoading ? <ActivityIndicator color={colors.accentText} /> : <Text style={styles.submitText}>Send OTP</Text>}
          </Pressable>
        </VerificationScreenCard>
      );
    }

    if (currentStage === 1) {
      return (
        <VerificationScreenCard title="Enter OTP" icon="keypad-outline">
          <Text numberOfLines={1} style={styles.otpSentTo}>{phone}</Text>
          <View style={styles.otpCountdownBox}><Text style={styles.otpCountdownText}>{otpCountdown}</Text></View>
          <Field compact icon="keypad-outline" placeholder="Enter OTP" value={otpCode} onChangeText={setOtpCode} keyboardType="number-pad" maxLength={6} />
          <Pressable onPress={confirmOtp} disabled={authLoading || phoneVerified} style={[styles.submitButton, (authLoading || phoneVerified) && styles.submitButtonDisabled]}>
            {authLoading ? <ActivityIndicator color={colors.accentText} /> : <Text style={styles.submitText}>Verify</Text>}
          </Pressable>
          <Pressable onPress={requestOtp} disabled={authLoading || Boolean(otpSecondsLeft)} style={[styles.stagePrimaryButton, (authLoading || Boolean(otpSecondsLeft)) && styles.stageButtonMuted]}>
            <Text style={styles.stagePrimaryText}>{otpSecondsLeft ? "Resend after countdown" : "Resend OTP"}</Text>
          </Pressable>
        </VerificationScreenCard>
      );
    }

    if (currentStage === 2) {
      return (
        <VerificationScreenCard title="Document" icon="id-card-outline">
          <Text style={styles.stageSubtitle}>Choose where you live and the identity document you will place in the camera.</Text>
          <View style={styles.choiceStack}>
            {verificationCountries.map((country) => <ChoiceRow key={country} label={country} icon="location-outline" active={countryOfResidence === country} onPress={() => setCountryOfResidence(country)} />)}
          </View>
          {countryOfResidence === "Other" ? <Field compact icon="earth-outline" placeholder="Country of residence" value={otherResidenceCountry} onChangeText={setOtherResidenceCountry} maxLength={80} /> : null}
          <View style={styles.choiceStack}>
            {verificationCountries.map((country) => <ChoiceRow key={country} label={country} icon="flag-outline" active={documentIssueCountry === country} onPress={() => { setDocumentIssueCountry(country); if (country !== "Zimbabwe" && documentType === "national_id") setDocumentType("foreign_id"); }} />)}
          </View>
          {documentIssueCountry === "Other" ? <Field compact icon="earth-outline" placeholder="Document issuing country" value={otherDocumentCountry} onChangeText={setOtherDocumentCountry} maxLength={80} /> : null}
          <View style={styles.choiceStack}>
            {idDocumentTypes.map((item) => <ChoiceRow key={item.value} label={item.label} icon={item.icon} active={documentType === item.value} onPress={() => setDocumentType(item.value)} />)}
          </View>
          <Pressable onPress={continueDocumentSetup} style={styles.submitButton}><Text style={styles.submitText}>Continue</Text></Pressable>
        </VerificationScreenCard>
      );
    }

    if (currentStage === 3) {
      return <CaptureScreen title={requiresBack ? "ID front" : selectedDocument.label} icon={selectedDocument.icon} done={Boolean(idFrontFile)} button="Take photo" onPress={() => captureId("front")} />;
    }

    if (currentStage === 4) {
      return <CaptureScreen title="ID back" icon="albums-outline" done={Boolean(idBackFile)} button="Take photo" onPress={() => captureId("back")} />;
    }

    if (currentStage === 5) {
      return (
        <VerificationScreenCard title="Document check" icon="scan-outline">
          <View style={styles.captureStatusRow}>
            <StatusPill label="Front" done={Boolean(idFrontFile)} />
            {requiresBack ? <StatusPill label="Back" done={Boolean(idBackFile)} /> : null}
          </View>
          <Pressable onPress={runExtraction} disabled={authLoading} style={[styles.submitButton, authLoading && styles.submitButtonDisabled]}>
            {authLoading ? <ActivityIndicator color={colors.accentText} /> : <Text style={styles.submitText}>Check document</Text>}
          </Pressable>
        </VerificationScreenCard>
      );
    }

    if (currentStage === 6) {
      return (
        <VerificationScreenCard title="Confirm ID" icon="checkmark-done-outline">
          <View style={styles.extractedBox}>
            <Text style={styles.extractedLabel}>{isZimbabweNationalId ? "Zimbabwe ID" : selectedDocument.label}</Text>
            <Text style={styles.extractedValue}>{extractedNationalId || "Enter manually"}</Text>
          </View>
          <Field compact icon="card-outline" placeholder={documentType === "passport" ? "Passport number" : "Document number"} value={confirmedNationalId} onChangeText={(value) => { setConfirmedNationalId(value); setIdentityConfirmed(false); }} maxLength={64} />
          <ComplianceCheck checked={identityConfirmed} onPress={() => setIdentityConfirmed((value) => !value)} label="This document number is correct and belongs to me." />
          <Pressable onPress={confirmIdentity} style={styles.submitButton}><Text style={styles.submitText}>{setupRequired ? "Confirm" : "Submit"}</Text></Pressable>
        </VerificationScreenCard>
      );
    }

    if (currentStage === 7 && setupRequired) {
      return (
        <VerificationScreenCard title={role === "agent" ? "Agency details" : "Estate setup"} icon="business-outline">
          <Field compact icon="business-outline" placeholder={role === "agent" ? "Agency name" : "Estate or company name"} value={agencyName} onChangeText={setAgencyName} maxLength={160} />
          {role === "agent" ? <Field compact icon="document-text-outline" placeholder="Agency registration" value={agencyRegistration} onChangeText={setAgencyRegistration} maxLength={120} /> : null}
          <Field compact icon="call-outline" placeholder={role === "agent" ? "Agency contact details" : "Public contact or branch details"} value={contactDetails} onChangeText={setContactDetails} maxLength={220} />
          <Pressable onPress={() => submit(true)} disabled={authLoading} style={[styles.submitButton, authLoading && styles.submitButtonDisabled]}>
            {authLoading ? <ActivityIndicator color={colors.accentText} /> : <Text style={styles.submitText}>Submit</Text>}
          </Pressable>
        </VerificationScreenCard>
      );
    }

    return (
      <VerificationScreenCard title="In review" icon="shield-checkmark-outline">
        <View style={[styles.captureFrame, styles.captureFrameDone]}>
          <Ionicons name="time-outline" size={48} color={colors.success} />
          <Text style={styles.captureFrameText}>Your identity document has been submitted for review.</Text>
        </View>
        <Text style={styles.stageSubtitle}>Verified access opens after the administrator approves the ID checks.</Text>
      </VerificationScreenCard>
    );
  };

  return (
    <KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : undefined} style={styles.wrap}>
      <ScrollView contentContainerStyle={styles.verificationContent} keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>
        <View style={styles.verificationPanel}>
          <Text style={[styles.brand, styles.verificationBrandCenter]}>PROPERTY24</Text>
          {currentStage > (phoneVerified ? 2 : 0) && currentStage < reviewStage ? (
            <Pressable onPress={goBack} disabled={authLoading} style={styles.stageBackButton}>
              <Ionicons name="chevron-back" size={18} color="#FFFFFF" />
            </Pressable>
          ) : null}
          {renderStage()}
          {notice ? <Text style={styles.noticeText}>{notice}</Text> : null}
          {localError || authError ? <Text style={styles.error}>{localError || authError}</Text> : null}
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

function ChoiceRow({ active, icon, label, onPress }: { active: boolean; icon: keyof typeof Ionicons.glyphMap; label: string; onPress: () => void }) {
  return (
    <Pressable onPress={onPress} style={[styles.optionRow, active && styles.optionRowActive]}>
      <Ionicons name={icon} size={18} color={active ? "#E50914" : "#A3A3A3"} />
      <Text numberOfLines={1} style={styles.optionRowText}>{label}</Text>
      <Ionicons name={active ? "radio-button-on" : "radio-button-off"} size={18} color={active ? "#E50914" : "#5F5F5F"} />
    </Pressable>
  );
}

function ComplianceCheck({ checked, label, onPress }: { checked: boolean; label: string; onPress: () => void }) {
  return (
    <Pressable onPress={onPress} style={[styles.complianceRow, checked && styles.complianceRowActive]}>
      <Ionicons name={checked ? "checkbox" : "square-outline"} size={20} color={checked ? "#E50914" : "#A3A3A3"} />
      <Text style={styles.complianceText}>{label}</Text>
    </Pressable>
  );
}

function VerificationScreenCard({ children, icon, title }: { children: ReactNode; icon: keyof typeof Ionicons.glyphMap; title: string }) {
  return (
    <View style={styles.verificationScreenCard}>
      <View style={styles.verificationIconCircle}>
        <Ionicons name={icon} size={30} color="#E50914" />
      </View>
      <Text style={styles.verificationScreenTitle}>{title}</Text>
      <View style={styles.verificationScreenBody}>{children}</View>
    </View>
  );
}

function CaptureScreen({ button, done, icon, onPress, title }: { button: string; done: boolean; icon: keyof typeof Ionicons.glyphMap; onPress: () => void; title: string }) {
  return (
    <VerificationScreenCard title={title} icon={done ? "checkmark-circle" : icon}>
      <View style={[styles.captureFrame, done && styles.captureFrameDone]}>
        <Ionicons name={done ? "checkmark-circle" : icon} size={46} color={done ? colors.success : colors.accent} />
      </View>
      <Pressable onPress={onPress} style={[styles.submitButton, done && styles.stepButtonDone]}>
        <Text style={styles.submitText}>{done ? "Retake" : button}</Text>
      </Pressable>
    </VerificationScreenCard>
  );
}

function StatusPill({ done, label }: { done: boolean; label: string }) {
  return (
    <View style={[styles.statusPill, done && styles.statusPillDone]}>
      <Ionicons name={done ? "checkmark-circle" : "ellipse-outline"} size={16} color={done ? colors.success : colors.textMuted} />
      <Text style={styles.statusPillText}>{label}</Text>
    </View>
  );
}


function displayAccountName(name: string, email: string) {
  const cleanName = String(name || "").trim();
  const cleanEmail = String(email || "").trim();
  if (cleanName && cleanName !== "Property24 user" && cleanName !== cleanEmail) return cleanName;
  const localPart = cleanEmail.split("@")[0]?.replace(/[._-]+/g, " ").trim();
  return localPart || cleanEmail || "Property24 account";
}


function imageAssetToVerificationUpload(asset: ImagePicker.ImagePickerAsset, label = "verification"): AccountMediaFile {
  const cleanUri = asset.uri.split("?")[0] || "";
  const extension = cleanUri.split(".").pop()?.toLowerCase() || "jpg";
  const safeExtension = extension.length > 5 ? "jpg" : extension;
  return {
    uri: asset.uri,
    name: asset.fileName || `${label}-${Date.now()}.${safeExtension}`,
    type: asset.mimeType || `image/${safeExtension === "jpg" ? "jpeg" : safeExtension}`,
  };
}

function PostLoginIntro({ onDone }: { onDone: () => void }) {
  const opacity = useRef(new Animated.Value(1)).current;
  const wordScale = useRef(new Animated.Value(1.08)).current;
  const barScale = useRef(new Animated.Value(0)).current;
  const letterAnimations = useRef(introLetters.map(() => new Animated.Value(0))).current;

  useEffect(() => {
    const letterReveal = Animated.stagger(58, letterAnimations.map((value) =>
      Animated.timing(value, { toValue: 1, duration: 360, easing: Easing.out(Easing.back(1.35)), useNativeDriver: true })
    ));
    const sequence = Animated.sequence([
      Animated.parallel([
        Animated.timing(wordScale, { toValue: 1, duration: 520, easing: Easing.out(Easing.cubic), useNativeDriver: true }),
        letterReveal,
      ]),
      Animated.timing(barScale, { toValue: 1, duration: 340, easing: Easing.inOut(Easing.cubic), useNativeDriver: true }),
      Animated.delay(120),
      Animated.parallel([
        Animated.timing(opacity, { toValue: 0, duration: 320, easing: Easing.inOut(Easing.cubic), useNativeDriver: true }),
        Animated.timing(wordScale, { toValue: 1.08, duration: 320, easing: Easing.inOut(Easing.cubic), useNativeDriver: true }),
      ]),
    ]);
    sequence.start(({ finished }) => {
      if (finished) onDone();
    });
    return () => sequence.stop();
  }, [barScale, letterAnimations, onDone, opacity, wordScale]);

  return (
    <Animated.View pointerEvents="none" style={[styles.introOverlay, { opacity }]}>
      <Animated.View style={[styles.introLogoWrap, { transform: [{ scale: wordScale }] }]}>
        <View style={styles.introWord}>
          {introLetters.map((letter, index) => {
            const progress = letterAnimations[index];
            const translateY = progress.interpolate({ inputRange: [0, 1], outputRange: [22, 0] });
            const translateX = progress.interpolate({ inputRange: [0, 1], outputRange: [index < introLetters.length / 2 ? -10 : 10, 0] });
            const scale = progress.interpolate({ inputRange: [0, 0.72, 1], outputRange: [0.82, 1.08, 1] });
            return (
              <Animated.Text
                key={`${letter}-${index}`}
                style={[styles.introLetter, letter === "2" || letter === "4" ? styles.introNumber : null, { opacity: progress, transform: [{ translateX }, { translateY }, { scale }] }]}
              >
                {letter}
              </Animated.Text>
            );
          })}
        </View>
        <View style={styles.introUnderlineTrack}>
          <Animated.View style={[styles.introUnderline, { transform: [{ scaleX: barScale }] }]} />
        </View>
      </Animated.View>
    </Animated.View>
  );
}

function Field(props: ComponentProps<typeof TextInput> & { compact?: boolean; icon: keyof typeof Ionicons.glyphMap; rightAccessory?: ReactNode }) {
  const { compact, icon, rightAccessory, style, ...rest } = props;
  return (
    <View style={[styles.field, compact && styles.fieldCompact]}>
      <TextInput
        autoCorrect={false}
        spellCheck={false}
        importantForAutofill="yes"
        cursorColor="#E50914"
        placeholderTextColor="#8C8C8C"
        selectionColor="#E50914"
        style={[styles.input, webInputChrome, compact && styles.inputCompact, style]}
        {...rest}
      />
      {rightAccessory}
    </View>
  );
}

const webInputChrome = Platform.OS === "web" ? ({
  backgroundColor: "transparent",
  boxShadow: "none",
  caretColor: "#E50914",
  outlineColor: "transparent",
  outlineStyle: "none",
  WebkitAppearance: "none",
  WebkitBoxShadow: "0 0 0 1000px #171717 inset",
  WebkitTextFillColor: "#FFFFFF",
} as any) : null;

function roleLabel(role: AccountRole) {
  return role.charAt(0).toUpperCase() + role.slice(1);
}

function roleIcon(role: PublicAccountRole) {
  if (role === "landlord") return "business-outline";
  return "key-outline";
}

function normalizeDocumentNumber(value: string) {
  return value.replace(/[^A-Za-z0-9]/g, "").toUpperCase();
}

function isZimbabweCountry(value: string) {
  return ["zimbabwe", "zw", "zwe"].includes(value.trim().toLowerCase());
}

function isValidZimbabweNationalId(value: string) {
  const normalized = normalizeDocumentNumber(value);
  if (!/^\d{8,9}[A-Z]\d{2}$/.test(normalized)) return false;
  const checkLetters = "ABCDEFGHJKLMNPQRSTVWXYZ";
  const expected = checkLetters[Number(normalized.slice(0, -3)) % checkLetters.length];
  return normalized.slice(-3, -2) === expected;
}

function isValidForeignDocumentNumber(value: string) {
  return /^[A-Za-z0-9][A-Za-z0-9\-/ ]{4,31}$/.test(value.trim());
}

const styles = StyleSheet.create({
  loadingWrap: { flex: 1, alignItems: "center", justifyContent: "center", backgroundColor: "#000000" },
  wrap: { flex: 1, backgroundColor: "#000000" },
  content: { flexGrow: 1, minHeight: "100%", alignItems: "center", justifyContent: "center", paddingHorizontal: 14, paddingVertical: 22, backgroundColor: "#000000" },
  contentCompact: { justifyContent: "center", paddingHorizontal: 14, paddingTop: 22, paddingBottom: 22 },
  verificationContent: { flexGrow: 1, minHeight: "100%", alignItems: "center", justifyContent: "center", paddingHorizontal: 14, paddingVertical: 22, backgroundColor: "#000000" },
  verificationPanel: { width: "100%", maxWidth: 430, borderRadius: 2, paddingHorizontal: 22, paddingVertical: 28, gap: 12, backgroundColor: "rgba(0,0,0,0.82)" },
  verificationCopy: { color: "#B3B3B3", fontSize: 13, lineHeight: 18, ...typography.body },
  verificationBrandCenter: { width: "100%", textAlign: "center", alignSelf: "center", marginBottom: 2 },
  verificationScreenCard: { minHeight: 430, justifyContent: "center", gap: 14 },
  verificationIconCircle: { alignSelf: "center", width: 74, height: 74, borderRadius: 37, alignItems: "center", justifyContent: "center", borderWidth: 1, borderColor: "rgba(229,9,20,0.34)", backgroundColor: "rgba(229,9,20,0.10)" },
  verificationScreenTitle: { color: "#FFFFFF", fontSize: 24, lineHeight: 30, textAlign: "center", ...typography.display },
  verificationScreenBody: { gap: 10 },
  stageBackButton: { position: "absolute", top: 26, left: 16, zIndex: 5, width: 38, height: 38, borderRadius: 19, alignItems: "center", justifyContent: "center", backgroundColor: "#171717", borderWidth: 1, borderColor: "#292929" },
  otpSentTo: { color: "#B3B3B3", fontSize: 13, textAlign: "center", ...typography.label },
  otpCountdownBox: { alignSelf: "center", minWidth: 92, minHeight: 46, alignItems: "center", justifyContent: "center", borderRadius: 23, borderWidth: 1, borderColor: "rgba(229,9,20,0.38)", backgroundColor: "rgba(229,9,20,0.10)" },
  otpCountdownText: { color: "#FFFFFF", fontSize: 19, ...typography.title },
  stageButtonMuted: { opacity: 0.55 },
  captureStatusRow: { flexDirection: "row", gap: 8 },
  statusPill: { flex: 1, minHeight: 42, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 6, borderRadius: 4, borderWidth: 1, borderColor: "#242424", backgroundColor: "#171717" },
  statusPillDone: { borderColor: "rgba(70,211,105,0.48)", backgroundColor: "rgba(70,211,105,0.08)" },
  statusPillText: { color: "#FFFFFF", fontSize: 13, ...typography.label },
  choiceStack: { gap: 7 },
  optionRow: { minHeight: 44, flexDirection: "row", alignItems: "center", gap: 9, borderWidth: 1, borderColor: "#242424", borderRadius: 4, paddingHorizontal: 12, backgroundColor: "#111111" },
  optionRowActive: { borderColor: "rgba(229,9,20,0.62)", backgroundColor: "rgba(229,9,20,0.12)" },
  optionRowText: { flex: 1, minWidth: 0, color: "#FFFFFF", fontSize: 13, ...typography.label },
  complianceRow: { minHeight: 44, flexDirection: "row", alignItems: "center", gap: 9, borderWidth: 1, borderColor: "#242424", borderRadius: 4, paddingHorizontal: 12, backgroundColor: "#111111" },
  complianceRowActive: { borderColor: "rgba(229,9,20,0.55)", backgroundColor: "rgba(229,9,20,0.10)" },
  complianceText: { flex: 1, minWidth: 0, color: "#FFFFFF", fontSize: 12, lineHeight: 17, ...typography.body },

  shell: { width: "100%", maxWidth: 430, flexDirection: "column", borderRadius: 2, overflow: "hidden", paddingHorizontal: 22, paddingVertical: 28, backgroundColor: "rgba(0,0,0,0.76)" },
  shellCompact: { maxWidth: 430, flexDirection: "column", borderRadius: 2, paddingHorizontal: 22, paddingVertical: 28 },
  identityPanel: { flex: 0, minWidth: 0, flexDirection: "column", alignItems: "flex-start", justifyContent: "flex-start", paddingHorizontal: 0, paddingTop: 0, paddingBottom: 22, gap: 6, backgroundColor: "transparent" },
  identityPanelCompact: { flex: 0, minWidth: 0, flexDirection: "column", alignItems: "flex-start", justifyContent: "flex-start", paddingHorizontal: 0, paddingVertical: 0, gap: 6 },
  brandMark: { display: "none" },
  brandMarkCompact: { display: "none" },
  identityCopy: { flex: 1, minWidth: 0, gap: 4 },
  identityCopyCompact: { gap: 2 },
  brand: { color: "#E50914", fontSize: 24, lineHeight: 29, textTransform: "uppercase", ...typography.display },
  brandCompact: { fontSize: 24, lineHeight: 29 },
  headline: { color: "#FFFFFF", fontSize: 28, lineHeight: 34, maxWidth: 330, marginTop: 10, ...typography.display },
  headlineCompact: { fontSize: 28, lineHeight: 34, maxWidth: 330, marginTop: 10 },
  subhead: { color: "#B3B3B3", fontSize: 13, lineHeight: 18, maxWidth: 300, ...typography.body },
  subheadCompact: { fontSize: 13, lineHeight: 18, maxWidth: 300 },
  rail: { display: "none" },
  railItem: { flexDirection: "row", alignItems: "center", gap: spacing.sm, minHeight: 24 },
  railText: { color: "#B3B3B3", fontSize: 12, ...typography.label },
  formPanel: { flex: 0, minWidth: 0, paddingHorizontal: 0, paddingTop: 0, paddingBottom: 0, gap: 12, backgroundColor: "transparent" },
  authHeader: { width: "100%", gap: 4, marginBottom: 10, alignItems: "flex-start" },
  formPanelCompact: { flex: 0, minWidth: 0, paddingHorizontal: 0, paddingTop: 0, paddingBottom: 0, gap: 10 },
  roleGrid: { flexDirection: "row", flexWrap: "nowrap", gap: 6 },
  roleGridCompact: { flexWrap: "nowrap", gap: 6 },
  roleCard: { flex: 1, minHeight: 38, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 4, borderWidth: 1, borderColor: "#333333", borderRadius: 4, paddingHorizontal: 6, paddingVertical: 7, backgroundColor: "#191919" },
  roleCardCompact: { flex: 1, minHeight: 38, paddingHorizontal: 6, paddingVertical: 7, gap: 4 },
  roleCardActive: { borderColor: "#E50914", backgroundColor: "rgba(229,9,20,0.16)" },
  roleTitle: { color: "#FFFFFF", fontSize: 11, ...typography.button },
  roleTitleCompact: { fontSize: 11 },
  googleRoleWrap: { gap: 7 },
  googleRoleLabel: { color: "#A3A3A3", fontSize: 11, lineHeight: 14, textTransform: "uppercase", ...typography.label },
  form: { gap: 10 },
  field: { minHeight: 50, flexDirection: "row", alignItems: "center", borderWidth: 1, borderColor: "#242424", borderRadius: 4, paddingHorizontal: 13, backgroundColor: "#171717" },
  fieldCompact: { minHeight: 50, borderRadius: 4, paddingHorizontal: 13 },
  input: { flex: 1, minWidth: 0, color: "#FFFFFF", fontSize: 14, backgroundColor: "transparent", outlineStyle: "none" as any, ...typography.body },
  eyeButton: { width: 34, height: 34, alignItems: "center", justifyContent: "center" },
  inputCompact: { fontSize: 14 },
  error: { color: "#FFA00A", lineHeight: 20, fontSize: 12, ...typography.label },
  noticeText: { color: "#46D369", lineHeight: 20, fontSize: 12, ...typography.label },
  verifyToggle: { minHeight: 46, flexDirection: "row", alignItems: "center", gap: 9, borderRadius: 4, borderWidth: 1, borderColor: "#242424", paddingHorizontal: 13, backgroundColor: "#171717" },
  verifyToggleActive: { borderColor: "#E50914", backgroundColor: "rgba(229,9,20,0.14)" },
  verifyToggleText: { flex: 1, minWidth: 0, color: "#FFFFFF", fontSize: 13, ...typography.label },
  verificationStep: { gap: 8 },
  stepTitle: { color: "#A3A3A3", fontSize: 11, textTransform: "uppercase", ...typography.label },
  stepActions: { gap: 8 },
  stepButton: { minHeight: 42, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 8, borderRadius: 4, borderWidth: 1, borderColor: "#333333", backgroundColor: "#171717" },
  stepButtonDone: { borderColor: "#E50914", backgroundColor: "rgba(229,9,20,0.14)" },
  stepButtonText: { color: "#FFFFFF", fontSize: 13, ...typography.button },
  stepBadge: { width: 24, height: 24, borderRadius: 12, alignItems: "center", justifyContent: "center", backgroundColor: "rgba(229,9,20,0.18)" },
  stepBadgeText: { color: "#E50914", fontSize: 12, ...typography.button },
  stageCard: { borderWidth: 1, borderColor: "#242424", borderRadius: 6, backgroundColor: "#0F0F0F", padding: 12, gap: 10 },
  stageHeader: { gap: 3, marginBottom: 2 },
  stageEyebrow: { color: "#E50914", fontSize: 11, textTransform: "uppercase", ...typography.label },
  stageTitle: { color: "#FFFFFF", fontSize: 18, lineHeight: 23, ...typography.title },
  stageSubtitle: { color: "#B3B3B3", fontSize: 12, lineHeight: 17, ...typography.body },
  stagePrimaryButton: { minHeight: 46, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 8, borderRadius: 4, borderWidth: 1, borderColor: "#333333", backgroundColor: "#171717" },
  stagePrimaryText: { color: "#FFFFFF", fontSize: 14, ...typography.button },
  progressRail: { flexDirection: "row", flexWrap: "wrap", gap: 6, marginVertical: 2 },
  progressItem: { minHeight: 34, maxWidth: "48%", flexGrow: 1, flexBasis: "30%", flexDirection: "row", alignItems: "center", gap: 6, borderWidth: 1, borderColor: "#242424", borderRadius: 4, paddingHorizontal: 7, backgroundColor: "#111111" },
  progressItemActive: { borderColor: "#E50914", backgroundColor: "rgba(229,9,20,0.12)" },
  progressItemDone: { borderColor: "rgba(70,211,105,0.42)" },
  progressItemLocked: { opacity: 0.42 },
  progressDot: { width: 20, height: 20, borderRadius: 10, alignItems: "center", justifyContent: "center", backgroundColor: "#242424" },
  progressDotActive: { backgroundColor: "#E50914" },
  progressDotDone: { backgroundColor: "#46D369" },
  progressDotText: { color: "#FFFFFF", fontSize: 10, ...typography.button },
  progressText: { flex: 1, minWidth: 0, color: "#A3A3A3", fontSize: 11, ...typography.label },
  progressTextActive: { color: "#FFFFFF" },
  stageNavRow: { flexDirection: "row", gap: 8 },
  stageNavButton: { flex: 1, minHeight: 42, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 5, borderRadius: 4, borderWidth: 1, borderColor: "#333333", backgroundColor: "#171717" },
  stageNavButtonDisabled: { opacity: 0.35 },
  stageNavText: { color: "#FFFFFF", fontSize: 13, ...typography.button },
  captureFrame: { minHeight: 138, alignItems: "center", justifyContent: "center", gap: 8, borderWidth: 1, borderColor: "#242424", borderRadius: 6, backgroundColor: "#070707" },
  captureFrameDone: { borderColor: "rgba(70,211,105,0.5)", backgroundColor: "rgba(70,211,105,0.08)" },
  captureFrameText: { color: "#FFFFFF", fontSize: 13, ...typography.label },
  extractedBox: { borderWidth: 1, borderColor: "#242424", borderRadius: 4, backgroundColor: "#171717", padding: 12, gap: 4 },
  extractedLabel: { color: "#A3A3A3", fontSize: 11, textTransform: "uppercase", ...typography.label },
  extractedValue: { color: "#FFFFFF", fontSize: 16, ...typography.title },
  reviewStack: { borderWidth: 1, borderColor: "#242424", borderRadius: 6, overflow: "hidden" },
  reviewRowItem: { minHeight: 42, flexDirection: "row", alignItems: "center", gap: 8, borderBottomWidth: 1, borderBottomColor: "#242424", paddingHorizontal: 10, backgroundColor: "#111111" },
  reviewRowText: { color: "#FFFFFF", fontSize: 13, ...typography.label },
    otpHint: { color: "#B3B3B3", fontSize: 12, lineHeight: 17, textAlign: "center", ...typography.body },
  switchPrompt: { minHeight: 32, flexDirection: "row", alignItems: "center", justifyContent: "center", flexWrap: "wrap" },
  switchMuted: { color: "#737373", fontSize: 14, lineHeight: 19, ...typography.body },
  switchAction: { color: "#FFFFFF", fontSize: 14, lineHeight: 19, ...typography.button },
  submitButton: { minHeight: 50, flexDirection: "row", alignItems: "center", justifyContent: "center", borderRadius: 4, backgroundColor: "#E50914" },
  submitButtonDisabled: { opacity: 0.45 },
  submitText: { color: "#FFFFFF", fontSize: 16, ...typography.button },
  dividerRow: { minHeight: 20, flexDirection: "row", alignItems: "center", gap: 10 },
  dividerLine: { flex: 1, height: 1, backgroundColor: "#272727" },
  dividerText: { color: "#777777", fontSize: 12, ...typography.label },
  googleButton: { minHeight: 50, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 10, borderRadius: 4, borderWidth: 1, borderColor: "#333333", backgroundColor: "#171717" },
  googleButtonDisabled: { opacity: 0.5 },
  googleMark: { width: 23, height: 23, alignItems: "center", justifyContent: "center", borderRadius: 12, borderWidth: 1, borderColor: "rgba(229,9,20,0.45)", backgroundColor: "rgba(229,9,20,0.12)" },
  googleMarkText: { color: "#E50914", fontSize: 16, lineHeight: 20, fontWeight: "900" },
  googleButtonText: { color: "#FFFFFF", fontSize: 15, ...typography.button },
  introOverlay: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 1000,
    elevation: 1000,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#000000",
  },
  introLogoWrap: { alignItems: "center", justifyContent: "center", paddingHorizontal: 18 },
  introWord: {
    minWidth: 284,
    height: 56,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    overflow: "hidden",
  },
  introLetter: { color: "#E50914", fontSize: 34, lineHeight: 42, textAlign: "center", textTransform: "uppercase", ...typography.display },
  introNumber: { color: "#E50914" },
  introUnderlineTrack: { width: 184, height: 2, marginTop: 14, overflow: "hidden", backgroundColor: "rgba(229,9,20,0.18)" },
  introUnderline: { width: "100%", height: "100%", backgroundColor: "#E50914" },
});
