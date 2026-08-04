import { Ionicons } from "@expo/vector-icons";
import { ComponentProps, ReactNode, useEffect, useMemo, useRef, useState } from "react";
import { ActivityIndicator, Animated, Easing, KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, useWindowDimensions, View } from "react-native";
import { colors, spacing, typography } from "../constants/theme";
import { PublicAccountRole, useRentalPlatform } from "../state/rentalPlatform";

type AuthGateProps = {
  children: ReactNode;
};

type AuthMode = "signin" | "register";

const publicRoles: PublicAccountRole[] = ["tenant", "landlord", "agent"];

const introLetters = "PROPERTY24".split("");

const verificationByRole: Record<PublicAccountRole, string[]> = {
  tenant: ["Email OTP", "National ID", "Selfie match"],
  landlord: ["Email OTP", "National ID", "Selfie match", "Ownership proof"],
  agent: ["Email OTP", "National ID", "Agency registration", "Agency contacts"],
};

export function AuthGate({ children }: AuthGateProps) {
  const { ready, authUser, authToken, authError, authLoading, signIn, registerAccount, verifyRegistrationOtp } = useRentalPlatform();
  const { width } = useWindowDimensions();
  const compact = width < 680;
  const [mode, setMode] = useState<AuthMode>("signin");
  const [accountType, setAccountType] = useState<PublicAccountRole>("tenant");
  const [name, setName] = useState("");
  const [identifier, setIdentifier] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [otp, setOtp] = useState("");
  const [otpChallengeId, setOtpChallengeId] = useState("");
  const [otpDestination, setOtpDestination] = useState("");
  const [otpHint, setOtpHint] = useState("");
  const [submitted, setSubmitted] = useState(false);
  const [localError, setLocalError] = useState("");
  const [introVisible, setIntroVisible] = useState(false);
  const lastIntroUserRef = useRef<string | null>(null);

  useEffect(() => {
    const authKey = authUser && authToken ? `${authUser.id}:${authToken.slice(0, 10)}` : null;
    if (!authKey) {
      lastIntroUserRef.current = null;
      setIntroVisible(false);
      return;
    }
    if (lastIntroUserRef.current === authKey) return;
    lastIntroUserRef.current = authKey;
    setIntroVisible(true);
  }, [authToken, authUser]);

  const canSubmit = useMemo(() => {
    if (authLoading) return false;
    if (otpChallengeId) return otp.trim().length >= 4;
    if (!password.trim()) return false;
    if (mode === "signin") return Boolean(identifier.trim());
    return Boolean(name.trim() && identifier.trim() && phone.trim());
  }, [authLoading, identifier, mode, name, otp, otpChallengeId, password, phone]);

  if (!ready) {
    return (
      <View style={styles.loadingWrap}>
        <ActivityIndicator color={colors.accent} />
      </View>
    );
  }

  if (authUser && authToken) {
    return (
      <>
        {children}
        {introVisible ? <PostLoginIntro onDone={() => setIntroVisible(false)} /> : null}
      </>
    );
  }

  const submit = async () => {
    setSubmitted(true);
    setLocalError("");
    if (!canSubmit) return;

    try {
      if (otpChallengeId) {
        await verifyRegistrationOtp(otpChallengeId, otp);
        return;
      }
      if (mode === "signin") {
        await signIn({ username: identifier, password });
        return;
      }
      const challenge = await registerAccount({ accountType, name, email: identifier, phone, password });
      setOtpChallengeId(challenge.challengeId);
      setOtpDestination(challenge.destination || challenge.email);
      setOtpHint(challenge.message || "OTP sent to your account email address.");
      setOtp("");
      setSubmitted(false);
    } catch {
      // The provider exposes the displayable authError.
    }
  };


  return (
    <KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : undefined} style={styles.wrap}>
      <ScrollView contentContainerStyle={[styles.content, compact && styles.contentCompact]} keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>
        <View style={[styles.shell, compact && styles.shellCompact]}>
          <View style={[styles.formPanel, compact && styles.formPanelCompact]}>
            <View style={styles.authHeader}>
              <Text style={[styles.brand, compact && styles.brandCompact]}>PROPERTY24</Text>
              <Text style={[styles.headline, compact && styles.headlineCompact]}>{otpChallengeId ? "Verify OTP" : mode === "signin" ? "Sign In" : "Create Account"}</Text>
              <Text style={[styles.subhead, compact && styles.subheadCompact]}>
                {otpChallengeId ? `Enter the OTP sent to ${otpDestination || "your email"}.` : mode === "signin" ? "Continue with your role-based rental account." : `${roleLabel(accountType)} access starts with account verification.`}
              </Text>
            </View>
            {!otpChallengeId && mode === "register" ? (
              <View style={[styles.roleGrid, compact && styles.roleGridCompact]}>
                {publicRoles.map((role) => (
                  <Pressable key={role} onPress={() => setAccountType(role)} style={[styles.roleCard, compact && styles.roleCardCompact, accountType === role && styles.roleCardActive]}>
                    <Ionicons name={roleIcon(role)} size={compact ? 14 : 16} color={accountType === role ? "#E50914" : "#A3A3A3"} />
                    <Text style={[styles.roleTitle, compact && styles.roleTitleCompact]}>{roleLabel(role)}</Text>
                  </Pressable>
                ))}
              </View>
            ) : null}

            <View style={styles.form}>
              {otpChallengeId ? (
                <>
                  <Field compact={compact} icon="keypad-outline" placeholder="Enter OTP" value={otp} onChangeText={setOtp} keyboardType="number-pad" />
                  {otpHint ? <Text style={styles.otpHint}>{otpHint}</Text> : null}
                </>
              ) : (
                <>
                  {mode === "register" ? (
                    <Field compact={compact} icon="person-outline" placeholder="Full name" value={name} onChangeText={setName} autoCapitalize="words" />
                  ) : null}
                  <Field
                    compact={compact}
                    icon="mail-outline"
                    placeholder={mode === "signin" ? "Email, username, or phone" : "Email address for OTP"}
                    value={identifier}
                    onChangeText={setIdentifier}
                    autoCapitalize="none"
                    keyboardType="email-address"
                  />
                  {mode === "register" ? <Field compact={compact} icon="call-outline" placeholder="Phone number" value={phone} onChangeText={setPhone} keyboardType="phone-pad" /> : null}
                  <Field compact={compact} icon="lock-closed-outline" placeholder="Password" value={password} onChangeText={setPassword} secureTextEntry />
                </>
              )}
            </View>

            {authError || localError ? <Text style={styles.error}>{authError || localError}</Text> : null}
            {submitted && !canSubmit ? <Text style={styles.error}>Complete the required fields to continue.</Text> : null}

            <Pressable onPress={submit} disabled={!canSubmit} style={[styles.submitButton, !canSubmit && styles.submitButtonDisabled]}>
              {authLoading ? (
                <ActivityIndicator color={colors.accentText} />
              ) : (
                <Text style={styles.submitText}>{otpChallengeId ? "Verify Account" : mode === "signin" ? "Sign In" : `Create ${roleLabel(accountType)} Account`}</Text>
              )}
            </Pressable>

            <Pressable
              onPress={() => {
                setOtpChallengeId("");
                setOtp("");
                setOtpDestination("");
                setOtpHint("");
                setSubmitted(false);
                setLocalError("");
                if (!otpChallengeId) setMode(mode === "signin" ? "register" : "signin");
              }}
              style={styles.switchPrompt}
            >
              <Text style={styles.switchMuted}>{otpChallengeId ? "Wrong details?" : mode === "signin" ? "New to Property24?" : "Already have an account?"}</Text>
              <Text style={styles.switchAction}>{otpChallengeId ? " Start again." : mode === "signin" ? " Create an account." : " Sign in."}</Text>
            </Pressable>

          </View>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
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

function Field(props: ComponentProps<typeof TextInput> & { compact?: boolean; icon: keyof typeof Ionicons.glyphMap }) {
  const { compact, style, ...rest } = props;
  return (
    <View style={[styles.field, compact && styles.fieldCompact]}>
      <TextInput
        autoCorrect={false}
        cursorColor="#E50914"
        placeholderTextColor="#8C8C8C"
        selectionColor="#E50914"
        style={[styles.input, webInputChrome, compact && styles.inputCompact, style]}
        {...rest}
      />
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

function roleLabel(role: PublicAccountRole) {
  return role.charAt(0).toUpperCase() + role.slice(1);
}

function roleIcon(role: PublicAccountRole) {
  if (role === "landlord") return "business-outline";
  if (role === "agent") return "briefcase-outline";
  return "key-outline";
}

const styles = StyleSheet.create({
  loadingWrap: { flex: 1, alignItems: "center", justifyContent: "center", backgroundColor: "#000000" },
  wrap: { flex: 1, backgroundColor: "#000000" },
  content: { flexGrow: 1, minHeight: "100%", alignItems: "center", justifyContent: "center", paddingHorizontal: 14, paddingVertical: 22, backgroundColor: "#000000" },
  contentCompact: { justifyContent: "center", paddingHorizontal: 14, paddingTop: 22, paddingBottom: 22 },
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
  form: { gap: 10 },
  field: { minHeight: 50, flexDirection: "row", alignItems: "center", borderWidth: 1, borderColor: "#242424", borderRadius: 4, paddingHorizontal: 13, backgroundColor: "#171717" },
  fieldCompact: { minHeight: 50, borderRadius: 4, paddingHorizontal: 13 },
  input: { flex: 1, minWidth: 0, color: "#FFFFFF", fontSize: 14, backgroundColor: "transparent", outlineStyle: "none" as any, ...typography.body },
  inputCompact: { fontSize: 14 },
  error: { color: "#FFA00A", lineHeight: 20, fontSize: 12, ...typography.label },
  otpHint: { color: "#B3B3B3", fontSize: 12, lineHeight: 17, textAlign: "center", ...typography.body },
  switchPrompt: { minHeight: 32, flexDirection: "row", alignItems: "center", justifyContent: "center", flexWrap: "wrap" },
  switchMuted: { color: "#737373", fontSize: 14, lineHeight: 19, ...typography.body },
  switchAction: { color: "#FFFFFF", fontSize: 14, lineHeight: 19, ...typography.button },
  submitButton: { minHeight: 50, flexDirection: "row", alignItems: "center", justifyContent: "center", borderRadius: 4, backgroundColor: "#E50914" },
  submitButtonDisabled: { opacity: 0.45 },
  submitText: { color: "#FFFFFF", fontSize: 16, ...typography.button },
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
