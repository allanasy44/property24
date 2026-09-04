import { Ionicons } from "@expo/vector-icons";
import { useEffect, useState } from "react";
import { ActivityIndicator, RefreshControl, ScrollView, StyleSheet, Text, View } from "react-native";
import { Screen } from "../../components/Screen";
import { colors, spacing, typography, useTheme } from "../../constants/theme";
import { CallHistoryItem, useRentalPlatform } from "../../state/rentalPlatform";

export default function CallsScreen() {
  const { colors: themeColors } = useTheme();
  const styles = createStyles(themeColors);
  const { authUser, fetchCallHistory } = useRentalPlatform();
  const [calls, setCalls] = useState<CallHistoryItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState("");

  const loadCalls = async (isRefresh = false) => {
    if (isRefresh) setRefreshing(true);
    else setLoading(true);
    setError("");
    try {
      setCalls(await fetchCallHistory());
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : "Calls could not be loaded.");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    void loadCalls();
  }, []);

  return (
    <Screen>
      <ScrollView
        contentContainerStyle={styles.content}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={() => void loadCalls(true)} tintColor={themeColors.accent} />}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.header}>
          <Text style={styles.title}>Calls</Text>
          <Ionicons name="call-outline" size={23} color={themeColors.accent} />
        </View>

        {loading ? <ActivityIndicator color={themeColors.accent} style={styles.loader} /> : null}
        {error ? <Text style={styles.error}>{error}</Text> : null}
        {!loading && !calls.length && !error ? (
          <View style={styles.empty}>
            <View style={styles.emptyIcon}><Ionicons name="call-outline" size={30} color={themeColors.accent} /></View>
            <Text style={styles.emptyTitle}>No calls yet</Text>
            <Text style={styles.emptyBody}>Your voice and video calls will appear here.</Text>
          </View>
        ) : null}

        {!loading && calls.length ? (
          <View style={styles.list}>
            <Text style={styles.sectionLabel}>Recent</Text>
            {calls.map((call) => {
              const missed = call.status.toLowerCase() === "missed";
              const outgoing = String(call.initiatorId) === String(authUser?.id || "");
              return (
                <View key={call.id} style={styles.callRow}>
                  <View style={[styles.callIcon, missed && styles.callIconMissed]}>
                    <Ionicons name={call.mode === "video" ? "videocam-outline" : "call-outline"} size={21} color={missed ? themeColors.danger : themeColors.accent} />
                  </View>
                  <View style={styles.callCopy}>
                    <Text numberOfLines={1} style={[styles.contactName, missed && styles.missedText]}>{call.contactName}</Text>
                    <View style={styles.callMeta}>
                      <Ionicons name={outgoing ? "arrow-up-outline" : "arrow-down-outline"} size={14} color={missed ? themeColors.danger : themeColors.textMuted} />
                      <Text style={[styles.metaText, missed && styles.missedText]}>{call.mode === "video" ? "Video call" : "Voice call"} · {call.propertyTitle}</Text>
                    </View>
                  </View>
                  <Text style={[styles.time, missed && styles.missedText]}>{formatCallTime(call.createdAt)}</Text>
                </View>
              );
            })}
          </View>
        ) : null}
      </ScrollView>
    </Screen>
  );
}

function formatCallTime(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return date.toLocaleDateString([], { month: "short", day: "numeric" });
}

function createStyles(themeColors: typeof colors) {
  return StyleSheet.create({
    content: { flexGrow: 1, padding: spacing.md, paddingBottom: spacing.xl, backgroundColor: themeColors.background },
    header: { minHeight: 54, flexDirection: "row", alignItems: "center", justifyContent: "space-between", borderBottomWidth: 1, borderBottomColor: themeColors.border },
    title: { color: themeColors.text, fontSize: 25, lineHeight: 31, ...typography.display },
    loader: { marginTop: spacing.xl },
    error: { color: themeColors.danger, marginTop: spacing.md, ...typography.body },
    list: { marginTop: spacing.lg },
    sectionLabel: { color: themeColors.textMuted, fontSize: 11, textTransform: "uppercase", ...typography.label },
    callRow: { minHeight: 76, flexDirection: "row", alignItems: "center", gap: 12, borderBottomWidth: 1, borderBottomColor: themeColors.border },
    callIcon: { width: 42, height: 42, alignItems: "center", justifyContent: "center", borderRadius: 21, backgroundColor: themeColors.accentSoft },
    callIconMissed: { backgroundColor: themeColors.dangerSoft },
    callCopy: { flex: 1, minWidth: 0, gap: 4 },
    contactName: { color: themeColors.text, fontSize: 16, ...typography.title },
    missedText: { color: themeColors.danger },
    callMeta: { flexDirection: "row", alignItems: "center", gap: 4 },
    metaText: { flex: 1, color: themeColors.textMuted, fontSize: 12, ...typography.body },
    time: { color: themeColors.textMuted, fontSize: 11, ...typography.label },
    empty: { flex: 1, alignItems: "center", justifyContent: "center", paddingHorizontal: spacing.lg },
    emptyIcon: { width: 64, height: 64, alignItems: "center", justifyContent: "center", borderRadius: 32, backgroundColor: themeColors.accentSoft },
    emptyTitle: { color: themeColors.text, fontSize: 18, marginTop: spacing.md, ...typography.title },
    emptyBody: { color: themeColors.textMuted, fontSize: 13, marginTop: spacing.xs, textAlign: "center", ...typography.body },
  });
}
