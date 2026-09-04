import { Ionicons } from "@expo/vector-icons";
import { Link, type Href } from "expo-router";
import * as Linking from "expo-linking";
import { useEffect, useState } from "react";
import { FlatList, ImageBackground, KeyboardAvoidingView, Modal, Platform, Pressable, Share, StyleSheet, Text, TextInput, View } from "react-native";
import { colors, radius, shadows, spacing, typography, useTheme } from "../constants/theme";
import { useRentalPlatform, type Property, type PropertyCommentItem } from "../state/rentalPlatform";

type PropertyCardProps = {
  property: Property;
  variant?: "default" | "feed";
};

export function PropertyCard({ property, variant = "default" }: PropertyCardProps) {
  const { colors: themeColors } = useTheme();
  const colors = themeColors;
  const styles = createStyles(themeColors);
  const { addPropertyComment, authToken, authUser, fetchPropertyComments, toggleSupplierFollow } = useRentalPlatform();
  const imageUri = property.photos?.find((photo) => photo?.startsWith("http")) || "";
  const photoCount = property.photos?.filter((photo) => photo?.startsWith("http")).length ?? 0;
  const feed = variant === "feed";
  const cardStyle = StyleSheet.flatten([styles.card, feed ? styles.feedCard : null]);
  const imageStyle = StyleSheet.flatten([styles.image, feed ? styles.feedImage : null]);
  const depositStyle = StyleSheet.flatten([styles.deposit, property.verified ? styles.depositVerified : null]);
  const [liked, setLiked] = useState(false);
  const [disliked, setDisliked] = useState(false);
  const [commentOpen, setCommentOpen] = useState(false);
  const [commentDraft, setCommentDraft] = useState("");
  const [comments, setComments] = useState<CommentItem[]>([]);
  const [shareCount, setShareCount] = useState(0);
  const [followingSupplier, setFollowingSupplier] = useState(false);

  const likes = property.savedCount + (liked ? 1 : 0);
  const dislikes = disliked ? 1 : 0;
  const commentCount = comments.length || property.commentsCount || 0;
  const supplierName = property.supplierName || property.agentName || property.ownerName || `${property.suburb} supplier`;
  const supplierRole = property.supplierRole === "agent" ? "Agent" : "Landlord";
  const supplierInitials = initials(supplierName);
  const supplierProfilePicture = property.supplierProfilePicture;
  const supplierProfileHref: Href = property.supplierId
    ? { pathname: "/supplier/[id]", params: { id: property.supplierId, propertyId: property.id } }
    : { pathname: "/property/[id]", params: { id: property.id } };
  const toggleFollow = () => {
    const nextValue = !followingSupplier;
    setFollowingSupplier(nextValue);
    if (property.supplierId) {
      void toggleSupplierFollow(property.supplierId, nextValue).catch(() => setFollowingSupplier(!nextValue));
    }
  };

  const toggleLike = () => {
    setLiked((value) => !value);
    if (!liked) setDisliked(false);
  };

  const toggleDislike = () => {
    setDisliked((value) => !value);
    if (!disliked) setLiked(false);
  };

  useEffect(() => {
    if (!commentOpen || !authToken) return;
    let cancelled = false;
    fetchPropertyComments(property.id)
      .then((items) => {
        if (!cancelled) setComments(items);
      })
      .catch(() => undefined);
    return () => {
      cancelled = true;
    };
  }, [authToken, commentOpen, fetchPropertyComments, property.id]);

  const addComment = async () => {
    const nextComment = commentDraft.trim();
    if (!nextComment) return;
    const optimisticComment: CommentItem = {
      id: `local-${Date.now()}`,
      propertyId: property.id,
      authorId: authUser?.id || "me",
      author: authUser?.name || "You",
      authorRole: authUser?.role || "tenant",
      authorVerified: Boolean(authUser?.verified),
      body: nextComment,
      likes: 0,
      mediaUri: imageUri,
      createdAt: new Date().toISOString(),
      time: "Now",
    };

    setComments((current) => [optimisticComment, ...current]);
    setCommentDraft("");

    try {
      const savedComment = await addPropertyComment(property.id, { body: nextComment, mediaUri: imageUri });
      setComments((current) => current.map((comment) => (comment.id === optimisticComment.id ? savedComment : comment)));
    } catch {
      setComments((current) => current.map((comment) => (comment.id === optimisticComment.id ? { ...comment, time: "Not synced" } : comment)));
    }
  };

  const shareProperty = async () => {
    const appLink = Linking.createURL(`/property/${property.id}`);
    const message = [
      `${property.title}`,
      `${property.price} · Deposit ${property.deposit}`,
      `${property.bedrooms} bed · ${property.bathrooms} bath · ${property.suburb}, ${property.city}`,
      `${property.water} · ${property.solarPower ? "Solar backup" : property.power}`,
      `Media: ${photoCount} photo(s), ${property.videoCount} video(s)`,
      `Open in Property24: ${appLink}`,
      ...(imageUri ? [`Preview image: ${imageUri}`] : []),
    ].join("\n");

    const result = await Share.share({
      title: property.title,
      message,
    }).catch(() => undefined);
    if (result?.action !== Share.dismissedAction) {
      setShareCount((value) => value + 1);
    }
  };

  const cardContent = (
    <>
      {feed ? (
        <View style={styles.feedHeader}>
          <Link href={supplierProfileHref} asChild>
            <Pressable style={styles.feedAvatar}>
              {supplierProfilePicture ? (
                <ImageBackground source={{ uri: supplierProfilePicture }} resizeMode="cover" style={styles.feedAvatarImage} />
              ) : (
                <Text style={styles.feedAvatarText}>{supplierInitials}</Text>
              )}
            </Pressable>
          </Link>
          <View style={styles.feedHeaderCopy}>
            <View style={styles.feedNameRow}>
              <Link href={supplierProfileHref} asChild>
                <Pressable style={styles.supplierLink}>
                  <Text numberOfLines={1} style={styles.feedName}>{supplierName}</Text>
                </Pressable>
              </Link>
              <Text style={styles.feedHandle}>@{supplierHandle(supplierName)}</Text>
            </View>
            <Text numberOfLines={1} style={styles.feedMeta}>{supplierRole} · Tap name to view profile</Text>
          </View>
          <Pressable onPress={toggleFollow} style={[styles.followButton, followingSupplier && styles.followButtonActive]}>
            <Text style={[styles.followText, followingSupplier && styles.followTextActive]}>{followingSupplier ? "Following" : "Follow"}</Text>
          </Pressable>
        </View>
      ) : null}

      <Link href={`/property/${property.id}`} asChild>
        <Pressable>
          {imageUri ? (
          <ImageBackground source={{ uri: imageUri }} resizeMode="cover" style={imageStyle}>
            <View style={styles.imageShade} />
            <View style={styles.topRow}>
              <View style={styles.saleBadge}><View style={styles.saleDot} /><Text style={styles.saleText}>For sale</Text></View>
              <View style={styles.mediaStack}>
                {feed ? <Pressable onPress={(event) => { event.stopPropagation(); toggleLike(); }} style={styles.favoriteButton}><Ionicons name={liked ? "heart" : "heart-outline"} size={19} color={liked ? colors.danger : "#FFFFFF"} /></Pressable> : null}
                {!feed ? <View style={styles.mediaBadge}><Ionicons name="camera-outline" size={13} color="#FFFFFF" /><Text style={styles.mediaText}>{photoCount}</Text></View> : null}
                {!feed && property.videoCount ? <View style={styles.mediaBadge}><Ionicons name="videocam-outline" size={13} color="#FFFFFF" /><Text style={styles.mediaText}>{property.videoCount}</Text></View> : null}
              </View>
            </View>
            {feed ? <View style={styles.feedImageBottom}><View style={styles.feedImageSummary}><View><Text style={styles.feedImagePrice}>{property.price}<Text style={styles.feedImagePriceUnit}> /mo</Text></Text><Text numberOfLines={1} style={styles.feedImageAddress}><Ionicons name="location-outline" size={12} color="#FFFFFF" /> {property.address || `${property.suburb}, ${property.city}`}</Text></View><Ionicons name="arrow-forward-circle" size={28} color="#FFFFFF" /></View><View style={styles.feedImageFacts}><View style={styles.feedImageFact}><Ionicons name="bed-outline" size={13} color="#FFFFFF" /><Text style={styles.feedImageFactText}>{property.bedrooms} Bd</Text></View><View style={styles.feedImageFact}><Ionicons name="water-outline" size={13} color="#FFFFFF" /><Text style={styles.feedImageFactText}>{property.bathrooms} Ba</Text></View><View style={styles.feedImageFact}><Ionicons name="expand-outline" size={13} color="#FFFFFF" /><Text style={styles.feedImageFactText}>2,500 Sqft</Text></View></View></View> : <View style={styles.priceBadge}><Text style={styles.price}>{property.price}</Text></View>}
          </ImageBackground>
          ) : (
            <View style={[imageStyle, styles.noPhotoImage]}>
              <View style={styles.topRow}>
                <View style={styles.saleBadge}><View style={styles.saleDot} /><Text style={styles.saleText}>For sale</Text></View>
                <View style={styles.mediaBadge}>
                  <Ionicons name="camera-outline" size={13} color="#FFFFFF" />
                  <Text style={styles.mediaText}>{photoCount}</Text>
                </View>
              </View>
              <View>
                <Ionicons name="image-outline" size={28} color={colors.textMuted} />
                <Text style={styles.noPhotoText}>No photos uploaded</Text>
              </View>
              <View style={styles.priceBadge}>
                <Text style={styles.price}>{property.price}</Text>
              </View>
            </View>
          )}
        </Pressable>
      </Link>

      <View style={[styles.body, feed && styles.feedBody]}>
        <View style={[styles.titleRow, feed && styles.feedHidden]}>
          <View style={{ flex: 1 }}>
            <Text style={styles.title} numberOfLines={1}>{property.title}</Text>
            <Text style={styles.location} numberOfLines={1}>{property.suburb}, {property.city}</Text>
          </View>
          <Link href={`/property/${property.id}`} asChild>
            <Pressable style={styles.openButton}>
              <Ionicons name="chevron-forward" size={18} color={colors.muted} />
            </Pressable>
          </Link>
        </View>

        <View style={[styles.factRow, feed && styles.feedHidden]}>
          <Fact icon="bed-outline" label={`${property.bedrooms} beds`} />
          <Fact icon="water-outline" label={property.borehole ? "Borehole" : property.water} />
          <Fact icon="flash-outline" label={property.solarPower ? "Solar" : "Grid"} />
        </View>

        <View style={[styles.footerRow, feed && styles.feedHidden]}>
          <View style={styles.trustRow}>
            <Text style={depositStyle}>{supplierRole}</Text>
          </View>
          <Text style={styles.type}>{property.type}</Text>
        </View>
        {!feed ? (
          <View style={styles.supplierRow}>
            <Link href={supplierProfileHref} asChild>
              <Pressable style={styles.supplierNameButton}>
                <Text style={styles.supplierName} numberOfLines={1}>{supplierName}</Text>
              </Pressable>
            </Link>
            <Pressable onPress={toggleFollow} style={[styles.followButtonSmall, followingSupplier && styles.followButtonActive]}>
              <Text style={[styles.followTextSmall, followingSupplier && styles.followTextActive]}>{followingSupplier ? "Following" : "Follow"}</Text>
            </Pressable>
          </View>
        ) : null}
        {!feed ? <Text style={styles.depositLine} numberOfLines={1}>Deposit {property.deposit} · GPS {property.gps}</Text> : null}

        {feed && comments.length ? <Text style={styles.commentPreview} numberOfLines={1}>Latest comment: {comments[0].body}</Text> : null}
      </View>

      {feed ? (
        <CommentSheet
          comments={comments}
          commentDraft={commentDraft}
          imageUri={imageUri}
          onAddComment={addComment}
          onChangeDraft={setCommentDraft}
          onClose={() => setCommentOpen(false)}
          property={property}
          visible={commentOpen}
        />
      ) : null}
    </>
  );

  return <View style={cardStyle}>{cardContent}</View>;
}

type CommentItem = PropertyCommentItem;

function CommentSheet({
  comments,
  commentDraft,
  imageUri,
  onAddComment,
  onChangeDraft,
  onClose,
  property,
  visible,
}: {
  comments: CommentItem[];
  commentDraft: string;
  imageUri: string;
  onAddComment: () => void;
  onChangeDraft: (value: string) => void;
  onClose: () => void;
  property: Property;
  visible: boolean;
}) {
  const { colors: themeColors } = useTheme();
  const colors = themeColors;
  const styles = createStyles(themeColors);
  const canPostComment = Boolean(commentDraft.trim());
  const commentTotal = comments.length;

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <View style={styles.modalOverlay}>
        <Pressable style={styles.modalBackdrop} onPress={onClose} />
        <KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : undefined} style={styles.commentKeyboard}>
          <View style={styles.commentSheet}>
            <View style={styles.sheetHandle} />
            <View style={styles.sheetHeader}>
              <View style={styles.sheetTitleWrap}>
                <Text style={styles.sheetTitle}>Comments</Text>
                <Text style={styles.sheetSubtitle}>{commentTotal ? `${commentTotal} on this listing` : "Ask inside the app"}</Text>
              </View>
              <Pressable onPress={onClose} style={styles.sheetClose}>
                <Ionicons name="close" size={20} color={colors.text} />
              </Pressable>
            </View>

            <View style={styles.commentMediaRow}>
              {imageUri ? (
                <ImageBackground source={{ uri: imageUri }} resizeMode="cover" style={styles.commentMediaThumb}>
                  {property.videoCount ? (
                    <View style={styles.commentVideoPill}>
                      <Ionicons name="play" size={10} color="#FFFFFF" />
                      <Text style={styles.commentVideoText}>{property.videoCount}</Text>
                    </View>
                  ) : null}
                </ImageBackground>
              ) : (
                <View style={[styles.commentMediaThumb, styles.commentMediaEmpty]}>
                  <Ionicons name="image-outline" size={22} color={colors.textMuted} />
                </View>
              )}
              <View style={styles.commentMediaCopy}>
                <Text style={styles.commentMediaTitle} numberOfLines={1}>{property.title}</Text>
                <Text style={styles.commentMediaMeta} numberOfLines={2}>{property.price} · {property.suburb}, {property.city}</Text>
              </View>
            </View>

            <View style={styles.commentStatsRow}>
              <View style={styles.commentStat}>
                <Ionicons name="chatbubble-outline" size={14} color={colors.textMuted} />
                <Text style={styles.commentStatText}>{commentTotal} comments</Text>
              </View>
              <View style={styles.commentStat}>
                <Ionicons name="image-outline" size={14} color={colors.textMuted} />
                <Text style={styles.commentStatText}>{imageUri ? "Attached to media" : "Attached to listing"}</Text>
              </View>
            </View>

            <FlatList
              data={comments}
              keyExtractor={(comment) => comment.id}
              keyboardShouldPersistTaps="handled"
              style={styles.commentList}
              contentContainerStyle={[styles.commentListContent, !comments.length && styles.commentListEmptyContent]}
              ListEmptyComponent={
                <View style={styles.emptyComments}>
                  <Ionicons name="chatbubbles-outline" size={24} color={colors.textMuted} />
                  <Text style={styles.emptyCommentTitle}>No comments yet</Text>
                  <Text style={styles.emptyCommentText}>Ask about rent, viewing times, utilities, or the listing details.</Text>
                </View>
              }
              renderItem={({ item }) => (
                <View style={styles.commentItem}>
                  <View style={styles.commentAvatar}>
                    <Text style={styles.commentAvatarText}>{initials(item.author)}</Text>
                  </View>
                  <View style={styles.commentBubbleWrap}>
                    <View style={styles.commentBubble}>
                      <View style={styles.commentAuthorRow}>
                        <Text style={styles.commentAuthor}>{item.author}</Text>
                        <Text style={styles.commentTime}>{item.time}</Text>
                      </View>
                      <Text style={styles.commentText}>{item.body}</Text>
                      <Text style={styles.commentAttachment}>Commented on this listing</Text>
                    </View>
                    <View style={styles.commentActionRow}>
                      <Text style={styles.commentActionText}>Like</Text>
                      <Text style={styles.commentActionText}>Reply</Text>
                      <Text style={styles.commentActionText}>{item.likes ? `${item.likes} likes` : "0 likes"}</Text>
                    </View>
                  </View>
                </View>
              )}
            />

            <View style={styles.commentComposer}>
              <View style={styles.commentComposerAvatar}>
                <Text style={styles.commentComposerAvatarText}>Y</Text>
              </View>
              <View style={styles.commentInputWrap}>
                <TextInput
                  value={commentDraft}
                  onChangeText={onChangeDraft}
                  placeholder="Write a comment"
                  placeholderTextColor={colors.muted}
                  multiline
                  style={styles.commentInput}
                />
              </View>
              <Pressable disabled={!canPostComment} onPress={onAddComment} style={[styles.commentButton, !canPostComment && styles.commentButtonDisabled]}>
                <Ionicons name="send" size={15} color="#FFFFFF" />
              </Pressable>
            </View>
          </View>
        </KeyboardAvoidingView>
      </View>
    </Modal>
  );
}

function FeedMetric({ icon, value, active, activeColor, onPress }: { active?: boolean; activeColor?: string; icon: keyof typeof Ionicons.glyphMap; value: string; onPress?: () => void }) {
  const { colors: themeColors } = useTheme();
  const colors = themeColors;
  const styles = createStyles(themeColors);
  const color = active ? activeColor || colors.accent : colors.textMuted;
  return (
    <Pressable onPress={onPress} disabled={!onPress} style={styles.feedMetric}>
      <Ionicons name={icon} size={17} color={color} />
      <Text style={[styles.feedMetricText, active && { color }]}>{value}</Text>
    </Pressable>
  );
}

function Fact({ icon, label }: { icon: keyof typeof Ionicons.glyphMap; label: string }) {
  const { colors: themeColors } = useTheme();
  const styles = createStyles(themeColors);
  return (
    <View style={styles.fact}>
      <Ionicons name={icon} size={14} color={themeColors.textMuted} />
      <Text style={styles.factText} numberOfLines={1}>{label}</Text>
    </View>
  );
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

function createStyles(themeColors: typeof colors) {
  const colors = themeColors;
  return StyleSheet.create({
  card: {
    backgroundColor: colors.surfaceElevated,
    borderRadius: radius.xl,
    borderWidth: 1,
    borderColor: colors.border,
    overflow: "hidden",
    ...shadows.soft,
  },
  feedCard: {
    borderRadius: 18,
    shadowOpacity: 0.03,
  },
  feedHeader: {
    display: "none",
    minHeight: 52,
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    paddingHorizontal: 11,
    backgroundColor: colors.surfaceElevated,
  },
  feedAvatar: {
    width: 34,
    height: 34,
    borderRadius: 8,
    overflow: "hidden",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: colors.text,
  },
  feedAvatarImage: { width: "100%", height: "100%" },
  feedAvatarText: { color: "#FFFFFF", fontSize: 11, ...typography.button },
  feedHeaderCopy: { flex: 1, minWidth: 0 },
  feedNameRow: { flexDirection: "row", alignItems: "center", gap: 4 },
  supplierLink: { flexShrink: 1, minWidth: 0, flexDirection: "row", alignItems: "center", gap: 4 },
  feedName: { color: colors.text, fontSize: 13, lineHeight: 17, ...typography.title },
  feedHandle: { color: colors.textMuted, fontSize: 11, ...typography.label },
  feedMeta: { color: colors.textMuted, fontSize: 11, marginTop: 1, ...typography.body },
  followButton: { minHeight: 30, justifyContent: "center", borderRadius: 999, borderWidth: 1, borderColor: colors.accent, paddingHorizontal: 12, backgroundColor: colors.accent },
  followButtonActive: { borderColor: colors.accent, backgroundColor: "transparent" },
  followText: { color: "#FFFFFF", fontSize: 12, ...typography.button },
  followTextActive: { color: colors.accent },
  image: {
    height: 166,
    justifyContent: "space-between",
    padding: spacing.sm,
    backgroundColor: colors.border,
  },
  feedImage: {
    height: 300,
    padding: 12,
    marginHorizontal: 0,
    borderRadius: 0,
    overflow: "hidden",
  },
  noPhotoImage: {
    alignItems: "stretch",
    backgroundColor: colors.surfaceMuted,
    borderWidth: 1,
    borderColor: colors.border,
  },
  noPhotoText: {
    color: colors.textMuted,
    fontSize: 12,
    marginTop: 6,
    ...typography.label,
  },
  imageShade: {
    bottom: 0,
    left: 0,
    position: "absolute",
    right: 0,
    top: 0,
    backgroundColor: "rgba(0,0,0,0.12)",
  },
  topRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-start",
    gap: spacing.sm,
  },
  saleBadge: { minHeight: 30, flexDirection: "row", alignItems: "center", gap: 6, borderRadius: 15, paddingHorizontal: 10, backgroundColor: "rgba(17,19,21,0.52)" },
  saleDot: { width: 7, height: 7, borderRadius: 4, backgroundColor: colors.success },
  saleText: { color: "#FFFFFF", fontSize: 11, ...typography.button },
  favoriteButton: { width: 38, height: 38, alignItems: "center", justifyContent: "center", borderRadius: 19, backgroundColor: "rgba(17,19,21,0.46)" },
  feedImageBottom: { gap: 8 },
  feedImageSummary: { flexDirection: "row", alignItems: "flex-end", justifyContent: "space-between", gap: 10 },
  feedImageFacts: { flexDirection: "row", gap: 6 },
  feedImageFact: { minHeight: 27, flexDirection: "row", alignItems: "center", gap: 4, borderRadius: 8, paddingHorizontal: 8, backgroundColor: "rgba(17,19,21,0.46)" },
  feedImageFactText: { color: "#FFFFFF", fontSize: 10, ...typography.button },
  feedImagePrice: { color: "#FFFFFF", fontSize: 24, lineHeight: 29, textShadowColor: "rgba(0,0,0,0.4)", textShadowRadius: 6, ...typography.display },
  feedImagePriceUnit: { fontSize: 13, ...typography.body },
  feedImageAddress: { color: "rgba(255,255,255,0.9)", fontSize: 11, marginTop: 3, maxWidth: 280, ...typography.body },
  mediaStack: { alignItems: "flex-end", gap: 6 },
  verifiedBadge: {
    flexDirection: "row",
    alignItems: "center",
    gap: 5,
    backgroundColor: "rgba(16,16,16,0.86)",
    borderRadius: 999,
    paddingHorizontal: 9,
    paddingVertical: 6,
  },
  verifiedText: { color: colors.success, fontSize: 12, ...typography.button },
  mediaBadge: {
    flexDirection: "row",
    alignItems: "center",
    gap: 5,
    backgroundColor: "rgba(17,19,21,0.72)",
    borderRadius: 999,
    paddingHorizontal: 9,
    paddingVertical: 6,
  },
  mediaText: { color: "#FFFFFF", fontSize: 12, ...typography.button },
  priceBadge: {
    alignSelf: "flex-start",
    backgroundColor: colors.surfaceElevated,
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 7,
  },
  price: { color: colors.text, fontSize: 15, lineHeight: 19, ...typography.display },
  feedActions: {
    minHeight: 40,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 12,
    backgroundColor: colors.surfaceElevated,
  },
  feedMetric: { minHeight: 34, flexDirection: "row", alignItems: "center", gap: 4, paddingHorizontal: 2 },
  feedMetricText: { color: colors.textMuted, fontSize: 11, ...typography.label },
  body: { padding: 12, gap: spacing.sm },
  feedBody: { display: "none" },
  feedHidden: { display: "none" },
  titleRow: { flexDirection: "row", alignItems: "center", gap: spacing.sm },
  openButton: { width: 30, height: 30, alignItems: "center", justifyContent: "center" },
  title: { color: colors.text, fontSize: 16, lineHeight: 21, ...typography.title },
  location: { color: colors.textMuted, fontSize: 13, marginTop: 2, ...typography.body },
  factRow: { flexDirection: "row", gap: spacing.sm },
  fact: { flex: 1, minWidth: 0, flexDirection: "row", alignItems: "center", gap: 5 },
  factText: { flex: 1, minWidth: 0, color: colors.textMuted, fontSize: 12, ...typography.label },
  footerRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: spacing.sm, paddingTop: 2 },
  trustRow: { flex: 1, minWidth: 0, flexDirection: "row", alignItems: "center", gap: 5 },
  deposit: { flex: 1, minWidth: 0, color: colors.warning, fontSize: 12, ...typography.button },
  depositVerified: { color: colors.success },
  supplierRow: { minHeight: 34, flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: spacing.sm },
  supplierNameButton: { flex: 1, minWidth: 0, flexDirection: "row", alignItems: "center", gap: 5 },
  supplierName: { flexShrink: 1, color: colors.text, fontSize: 13, ...typography.title },
  followButtonSmall: { minHeight: 30, justifyContent: "center", borderRadius: 999, borderWidth: 1, borderColor: colors.accent, paddingHorizontal: 11, backgroundColor: colors.accent },
  followTextSmall: { color: "#FFFFFF", fontSize: 11, ...typography.button },
  depositLine: { color: colors.textMuted, fontSize: 11, ...typography.body },
  caption: { color: colors.text, fontSize: 13, lineHeight: 19, ...typography.body },
  commentPreview: { color: colors.textMuted, fontSize: 12, lineHeight: 17, ...typography.label },
  modalOverlay: { flex: 1, justifyContent: "flex-end" },
  modalBackdrop: { ...StyleSheet.absoluteFillObject, backgroundColor: "rgba(0,0,0,0.72)" },
  commentKeyboard: { justifyContent: "flex-end" },
  commentSheet: {
    maxHeight: "88%",
    borderTopLeftRadius: 18,
    borderTopRightRadius: 18,
    borderWidth: 1,
    borderBottomWidth: 0,
    borderColor: colors.border,
    paddingHorizontal: 14,
    paddingTop: 8,
    paddingBottom: 10,
    backgroundColor: colors.surfaceElevated,
  },
  sheetHandle: { alignSelf: "center", width: 44, height: 4, borderRadius: 2, backgroundColor: colors.muted, marginBottom: 8 },
  sheetHeader: { minHeight: 42, flexDirection: "row", alignItems: "center", justifyContent: "space-between", marginBottom: 8 },
  sheetTitleWrap: { flex: 1, minWidth: 0 },
  sheetTitle: { color: colors.text, fontSize: 18, lineHeight: 23, ...typography.title },
  sheetSubtitle: { color: colors.textMuted, fontSize: 12, lineHeight: 16, ...typography.body },
  sheetClose: { width: 34, height: 34, alignItems: "center", justifyContent: "center", borderRadius: 17, backgroundColor: colors.surfaceMuted },
  commentMediaRow: {
    flexDirection: "row",
    gap: 10,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: 10,
    padding: 8,
    backgroundColor: colors.surfaceMuted,
  },
  commentMediaThumb: { width: 74, height: 74, justifyContent: "flex-end", alignItems: "flex-start", padding: 6, borderRadius: 8, overflow: "hidden", backgroundColor: colors.border },
  commentMediaEmpty: { alignItems: "center", justifyContent: "center", backgroundColor: colors.surfaceMuted },
  commentVideoPill: { flexDirection: "row", alignItems: "center", gap: 3, borderRadius: 999, paddingHorizontal: 6, paddingVertical: 4, backgroundColor: "rgba(0,0,0,0.72)" },
  commentVideoText: { color: "#FFFFFF", fontSize: 10, ...typography.button },
  commentMediaCopy: { flex: 1, minWidth: 0, justifyContent: "center", gap: 3 },
  commentMediaTitle: { color: colors.text, fontSize: 14, lineHeight: 18, ...typography.title },
  commentMediaMeta: { color: colors.textMuted, fontSize: 12, lineHeight: 16, ...typography.body },
  commentMediaTrust: { color: colors.success, fontSize: 11, ...typography.button },
  commentStatsRow: { minHeight: 34, flexDirection: "row", alignItems: "center", gap: 12, borderBottomWidth: 1, borderBottomColor: colors.border },
  commentStat: { flexDirection: "row", alignItems: "center", gap: 5 },
  commentStatText: { color: colors.textMuted, fontSize: 11, ...typography.label },
  commentList: { maxHeight: 310 },
  commentListContent: { paddingTop: 12, paddingBottom: 10, gap: 12 },
  commentListEmptyContent: { minHeight: 190, justifyContent: "center" },
  commentItem: { flexDirection: "row", gap: 9, alignItems: "flex-start" },
  commentAvatar: { width: 32, height: 32, borderRadius: 16, alignItems: "center", justifyContent: "center", backgroundColor: colors.surfaceMuted, borderWidth: 1, borderColor: colors.border },
  commentAvatarText: { color: colors.text, fontSize: 11, ...typography.button },
  commentBubbleWrap: { flex: 1, minWidth: 0, gap: 5 },
  commentBubble: { alignSelf: "flex-start", maxWidth: "100%", borderRadius: 14, borderTopLeftRadius: 4, paddingHorizontal: 11, paddingVertical: 9, backgroundColor: colors.surfaceMuted },
  commentAuthorRow: { flexDirection: "row", alignItems: "center", gap: 7, marginBottom: 2 },
  commentAuthor: { color: colors.text, fontSize: 12, ...typography.title },
  commentTime: { color: colors.textMuted, fontSize: 10, ...typography.label },
  commentText: { color: colors.text, fontSize: 13, lineHeight: 18, ...typography.body },
  commentAttachment: { color: colors.textMuted, fontSize: 10, marginTop: 5, ...typography.body },
  commentActionRow: { flexDirection: "row", alignItems: "center", gap: 13, paddingLeft: 8 },
  commentActionText: { color: colors.textMuted, fontSize: 11, ...typography.button },
  emptyComments: { alignItems: "center", gap: 6, paddingHorizontal: 26 },
  emptyCommentTitle: { color: colors.text, fontSize: 15, ...typography.title },
  emptyCommentText: { color: colors.textMuted, fontSize: 12, lineHeight: 17, textAlign: "center", ...typography.body },
  commentComposer: { minHeight: 48, flexDirection: "row", alignItems: "flex-end", gap: 8, borderTopWidth: 1, borderTopColor: colors.border, paddingTop: 9 },
  commentComposerAvatar: { width: 30, height: 30, borderRadius: 15, alignItems: "center", justifyContent: "center", backgroundColor: colors.surfaceMuted, borderWidth: 1, borderColor: colors.border, marginBottom: 4 },
  commentComposerAvatarText: { color: colors.text, fontSize: 11, ...typography.button },
  commentInputWrap: { flex: 1, minWidth: 0, minHeight: 40, maxHeight: 96, justifyContent: "center", borderRadius: 20, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.surfaceMuted },
  commentInput: { minHeight: 40, maxHeight: 96, paddingHorizontal: 13, paddingTop: 9, paddingBottom: 9, color: colors.text, fontSize: 13, lineHeight: 18, outlineStyle: "none" as any, ...typography.body },
  commentButton: { width: 38, height: 38, alignItems: "center", justifyContent: "center", borderRadius: 19, backgroundColor: colors.accent },
  commentButtonDisabled: { opacity: 0.38 },
  type: { color: colors.textMuted, fontSize: 12, ...typography.label },
  });
}
