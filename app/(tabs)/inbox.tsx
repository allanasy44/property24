import { Ionicons } from "@expo/vector-icons";
import { CameraView, useCameraPermissions, useMicrophonePermissions } from "expo-camera";
import * as Contacts from "expo-contacts";
import Constants from "expo-constants";
import * as DocumentPicker from "expo-document-picker";
import * as ImagePicker from "expo-image-picker";
import { Link, useLocalSearchParams, type Href } from "expo-router";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { ImageBackground, KeyboardAvoidingView, Modal, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { AccessGuard } from "../../components/AccessGuard";
import { Screen } from "../../components/Screen";
import { colors, shadows, spacing, typography, useTheme } from "../../constants/theme";
import { ConversationCallSession, ConversationItem, ConversationMessage, MessageAttachmentInput, Property, useRentalPlatform } from "../../state/rentalPlatform";

type WebRtcModule = {
  mediaDevices: { getUserMedia: (constraints: any) => Promise<any> };
  RTCPeerConnection: new (configuration?: any) => any;
  RTCIceCandidate: new (candidate: any) => any;
  RTCSessionDescription: new (description: any) => any;
  RTCView: any;
};

let cachedWebRtcModule: WebRtcModule | null | undefined;
const canUseNativeWebRtc = Platform.OS !== "web" && Constants.appOwnership !== "expo";

function getWebRtcModule(): WebRtcModule | null {
  if (!canUseNativeWebRtc) return null;
  if (cachedWebRtcModule !== undefined) return cachedWebRtcModule;
  try {
    cachedWebRtcModule = require("react-native-webrtc") as WebRtcModule;
  } catch {
    cachedWebRtcModule = null;
  }
  return cachedWebRtcModule;
}

function OptionalRTCView(props: any) {
  const webRtc = getWebRtcModule();
  if (!webRtc?.RTCView) return null;
  const NativeRTCView = webRtc.RTCView;
  return <NativeRTCView {...props} />;
}

type ListingThread = {
  key: string;
  propertyId: string;
  conversation?: ConversationItem;
  title: string;
  contactName: string;
  contactRole: string;
  supplierId?: string;
  profilePicture?: string;
  gps?: string;
  address?: string;
  preview: string;
  time: string;
  unread: boolean;
  hasConversation: boolean;
  sortScore: number;
  contactLastSeenAt?: string;
  online: boolean;
};

export default function InboxScreen() {
  const { colors: themeColors } = useTheme();
  const colors = themeColors;
  const styles = createStyles(themeColors);
  const { propertyId, intent } = useLocalSearchParams<{ propertyId?: string; intent?: string }>();
  const {
    state,
    authUser,
    authToken,
    chatWebSocketUrl,
    refreshConversations,
    startPropertyConversation,
    fetchConversationMessages,
    sendConversationMessage,
    startConversationCall,
    fetchConversationCalls,
    endConversationCall,
  } = useRentalPlatform();
  const [selectedPropertyId, setSelectedPropertyId] = useState(propertyId ?? "");
  const [createdConversation, setCreatedConversation] = useState<ConversationItem | null>(null);
  const [messages, setMessages] = useState<ConversationMessage[]>([]);
  const [calls, setCalls] = useState<ConversationCallSession[]>([]);
  const [draft, setDraft] = useState("");
  const [loading, setLoading] = useState(false);
  const [notice, setNotice] = useState("");
  const [error, setError] = useState("");
  const [handledIntent, setHandledIntent] = useState("");
  const [searchQuery, setSearchQuery] = useState("");
  const [callOverlayVisible, setCallOverlayVisible] = useState(false);
  const [attachmentSheetVisible, setAttachmentSheetVisible] = useState(false);
  const [muted, setMuted] = useState(false);
  const [speakerOn, setSpeakerOn] = useState(false);
  const [cameraFacing, setCameraFacing] = useState<"front" | "back">("front");
  const [callSignalStatus, setCallSignalStatus] = useState("Secure signaling ready");
  const [localStreamUrl, setLocalStreamUrl] = useState("");
  const [remoteStreamUrl, setRemoteStreamUrl] = useState("");
  const [peerConnectionState, setPeerConnectionState] = useState("idle");
  const messagesRef = useRef<ScrollView>(null);
  const socketRef = useRef<WebSocket | null>(null);
  const typingTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const peerConnectionRef = useRef<any | null>(null);
  const localStreamRef = useRef<any | null>(null);
  const pendingIceCandidatesRef = useRef<any[]>([]);
  const [liveConnected, setLiveConnected] = useState(false);
  const [typingUser, setTypingUser] = useState("");
  const [presenceOverrides, setPresenceOverrides] = useState<Record<string, { online: boolean; lastSeenAt?: string }>>({});
  const [cameraPermission, requestCameraPermission] = useCameraPermissions();
  const [microphonePermission, requestMicrophonePermission] = useMicrophonePermissions();

  const threads = useMemo(() => buildListingThreads(state.properties, state.conversations, authUser?.id), [authUser?.id, state.conversations, state.properties]);
  const visibleThreads = useMemo(() => {
    const query = searchQuery.trim().toLowerCase();
    if (!query) return threads;
    return threads.filter((thread) =>
      [thread.contactName, thread.title, thread.preview, thread.contactRole].some((value) => value.toLowerCase().includes(query))
    );
  }, [searchQuery, threads]);
  useEffect(() => {
    if (propertyId) setSelectedPropertyId(propertyId);
  }, [propertyId]);

  const selectedThread = useMemo(
    () => threads.find((thread) => thread.propertyId === selectedPropertyId),
    [selectedPropertyId, threads]
  );
  const activeConversation =
    selectedThread?.conversation ?? (createdConversation?.propertyId === selectedThread?.propertyId ? createdConversation : null);
  const activeCall = calls.find((call) => call.status.toLowerCase() === "ringing");
  const contactId = selectedThread?.supplierId;
  const contactPresenceOverride = contactId ? presenceOverrides[contactId] : undefined;
  const contactOnline = contactPresenceOverride?.online ?? Boolean(selectedThread?.online);
  const contactLastSeenAt = contactPresenceOverride?.lastSeenAt || selectedThread?.contactLastSeenAt;
  const contactPresence = activeCall ? "Ringing" : contactOnline ? "Online" : formatLastSeen(contactLastSeenAt);
  const supplierProfileHref: Href | null = selectedThread?.supplierId
    ? { pathname: "/supplier/[id]", params: { id: selectedThread.supplierId, propertyId: selectedThread.propertyId } }
    : null;
  const chatIdentityContent = (
    <>
      <View style={styles.chatAvatar}>
        {selectedThread?.profilePicture ? (
          <ImageBackground source={{ uri: selectedThread.profilePicture }} resizeMode="cover" style={styles.chatAvatarImage} />
        ) : (
          <Text style={styles.chatAvatarText}>{initials(selectedThread?.contactName || "Listing")}</Text>
        )}
      </View>
      <View style={styles.chatTitleWrap}>
        <Text numberOfLines={1} style={styles.chatName}>{selectedThread?.contactName || "Listing contact"}</Text>
        <View style={styles.presenceRow}>
          {selectedThread ? <View style={[styles.presenceDot, contactOnline && styles.presenceDotOnline]} /> : null}
          <Text numberOfLines={1} style={[styles.chatStatus, contactOnline && styles.chatStatusOnline]}>
            {selectedThread ? `${contactPresence} · ${selectedThread.title}` : "Select a listing contact"}
          </Text>
        </View>
      </View>
      {selectedThread?.supplierId ? <Ionicons name="chevron-forward" size={17} color={colors.textMuted} /> : null}
    </>
  );

  const loadMessages = useCallback(
    async (conversationId: string) => {
      try {
        const nextMessages = await fetchConversationMessages(conversationId);
        setMessages(nextMessages);
        setError("");
      } catch (loadError) {
        setError(loadError instanceof Error ? loadError.message : "Messages could not be loaded");
      }
    },
    [fetchConversationMessages]
  );

  const loadCalls = useCallback(
    async (conversationId: string) => {
      try {
        const nextCalls = await fetchConversationCalls(conversationId);
        setCalls(nextCalls);
      } catch (loadError) {
        setError(loadError instanceof Error ? loadError.message : "Calls could not be loaded");
      }
    },
    [fetchConversationCalls]
  );

  const ensureConversation = useCallback(async () => {
    if (!selectedThread) throw new Error("Select a listing before chatting");
    if (activeConversation) return activeConversation;
    if (!authToken) throw new Error("Sign in is required before chatting with a listing contact");

    setLoading(true);
    try {
      const conversation = await startPropertyConversation(selectedThread.propertyId);
      setCreatedConversation(conversation);
      setNotice("Secure listing chat opened.");
      return conversation;
    } finally {
      setLoading(false);
    }
  }, [activeConversation, authToken, selectedThread, startPropertyConversation]);

  useEffect(() => {
    if (!activeConversation?.id) {
      setMessages([]);
      setCalls([]);
      setTypingUser("");
      return undefined;
    }

    loadMessages(activeConversation.id);
    loadCalls(activeConversation.id);
    const timer = setInterval(() => {
      void loadMessages(activeConversation.id);
      void loadCalls(activeConversation.id);
    }, liveConnected ? 15000 : 3500);
    return () => clearInterval(timer);
  }, [activeConversation?.id, liveConnected, loadCalls, loadMessages]);

  useEffect(() => {
    messagesRef.current?.scrollToEnd({ animated: true });
  }, [messages.length, activeConversation?.id]);

  useEffect(() => {
    if (activeCall) {
      setCallOverlayVisible(true);
      return;
    }
    setCallOverlayVisible(false);
    setMuted(false);
    setSpeakerOn(false);
    cleanupWebRtcCall();
  }, [activeCall?.id]);

  useEffect(() => {
    if (!activeCall || !activeConversation?.id) return undefined;
    const outgoing = String(activeCall.initiatorId) === String(authUser?.id || "");
    if (!outgoing || contactOnline) return undefined;

    const timer = setTimeout(() => {
      endConversationCall(activeConversation.id, activeCall.id, "missed")
        .then((missed) => {
          setCalls((current) => current.map((item) => item.id === missed.id ? missed : item));
          setCallOverlayVisible(false);
          setNotice("Call missed. The contact appears offline.");
          return loadCalls(activeConversation.id);
        })
        .catch((callError) => setError(callError instanceof Error ? callError.message : "Call could not be updated"));
    }, 16000);

    return () => clearTimeout(timer);
  }, [activeCall?.id, activeConversation?.id, authUser?.id, contactOnline, endConversationCall, loadCalls]);

  useEffect(() => {
    if (!authToken) return undefined;
    const timer = setInterval(() => refreshConversations().catch(() => undefined), 8000);
    return () => clearInterval(timer);
  }, [authToken, refreshConversations]);

  useEffect(() => {
    if (!chatWebSocketUrl || !authToken) {
      setLiveConnected(false);
      return undefined;
    }

    const socket = new WebSocket(chatWebSocketUrl);
    socketRef.current = socket;

    socket.onopen = () => {
      setLiveConnected(true);
      setError("");
      sendSocketEvent("presence.ping", {});
      if (activeConversation?.id) {
        sendSocketEvent("delivered", { conversation_id: activeConversation.id });
        sendSocketEvent("read", { conversation_id: activeConversation.id });
      }
    };

    socket.onmessage = (event) => {
      handleLiveChatEvent(event.data, {
        activeConversationId: activeConversation?.id || "",
        authUserId: authUser?.id || "",
        onCallEnded: (call) => {
          setCalls((current) => current.map((item) => item.id === call.id ? call : item));
          setCallSignalStatus("Call ended");
        },
        onCallStarted: (call) => {
          setCalls((current) => [call, ...current.filter((item) => item.id !== call.id)]);
          setCallSignalStatus("Incoming call signaling started");
          setCallOverlayVisible(true);
          if (String(call.initiatorId) !== String(authUser?.id || "")) {
            sendSocketEvent("call.signal", { conversation_id: call.conversationId, call_id: call.id, signal_type: "ready", signal: { accepted: true, media: call.mode } });
          }
        },
        onError: setError,
        onMessage: (message) => {
          setMessages((current) => upsertMessages(current, message));
          if (String(message.senderId) !== String(authUser?.id || "") && activeConversation?.id === message.conversationId) {
            sendSocketEvent("delivered", { conversation_id: activeConversation.id });
            sendSocketEvent("read", { conversation_id: activeConversation.id });
          }
          void refreshConversations().catch(() => undefined);
        },
        onDelivered: (payload) => {
          const ids = new Set((payload.message_ids || []).map(String));
          if (!ids.size) return;
          setMessages((current) => current.map((item) => ids.has(item.id) ? { ...item, deliveryStatus: item.deliveryStatus === "read" ? "read" : "delivered" } : item));
        },
        onCallSignal: (payload) => {
          void handleCallSignal(payload);
        },
        onPresence: (payload) => {
          setPresenceOverrides((current) => ({
            ...current,
            [String(payload.user_id)]: { online: Boolean(payload.online), lastSeenAt: payload.last_seen_at || undefined },
          }));
          void refreshConversations().catch(() => undefined);
        },
        onRead: (payload) => {
          const ids = new Set((payload.message_ids || []).map(String));
          if (!ids.size) return;
          setMessages((current) => current.map((item) => ids.has(item.id) ? { ...item, readAt: item.readAt || new Date().toISOString(), deliveryStatus: "read" } : item));
        },
        onTyping: (payload) => {
          if (String(payload.user_id) === String(authUser?.id || "") || String(payload.conversation_id) !== String(activeConversation?.id || "")) return;
          setTypingUser(payload.is_typing ? String(payload.name || "Contact") : "");
          if (typingTimerRef.current) clearTimeout(typingTimerRef.current);
          if (payload.is_typing) typingTimerRef.current = setTimeout(() => setTypingUser(""), 2200);
        },
      });
    };

    socket.onerror = () => setLiveConnected(false);
    socket.onclose = () => {
      if (socketRef.current === socket) socketRef.current = null;
      setLiveConnected(false);
    };

    const pingTimer = setInterval(() => sendSocketEvent("presence.ping", {}), 25000);
    return () => {
      clearInterval(pingTimer);
      if (socketRef.current === socket) socketRef.current = null;
      socket.close();
    };
  }, [activeConversation?.id, authToken, authUser?.id, chatWebSocketUrl, refreshConversations]);

  const sendSocketEvent = (type: string, payload: Record<string, unknown>) => {
    const socket = socketRef.current;
    if (!socket || socket.readyState !== WebSocket.OPEN) return false;
    socket.send(JSON.stringify({ type, ...payload }));
    return true;
  };

  const cleanupWebRtcCall = () => {
    pendingIceCandidatesRef.current = [];
    peerConnectionRef.current?.close();
    peerConnectionRef.current = null;
    localStreamRef.current?.getTracks().forEach((track: any) => track.stop());
    localStreamRef.current = null;
    setLocalStreamUrl("");
    setRemoteStreamUrl("");
    setPeerConnectionState("idle");
  };

  const createPeerConnection = (conversationId: string, callId: string) => {
    const webRtc = getWebRtcModule();
    if (!webRtc) {
      setCallSignalStatus("Native WebRTC requires a development build");
      return null;
    }
    peerConnectionRef.current?.close();
    const peerConnection = new webRtc.RTCPeerConnection({
      iceServers: rtcIceServers(),
    });

    peerConnection.onicecandidate = (event: any) => {
      if (!event.candidate) return;
      sendSocketEvent("call.signal", {
        conversation_id: conversationId,
        call_id: callId,
        signal_type: "ice-candidate",
        signal: event.candidate.toJSON ? event.candidate.toJSON() : event.candidate,
      });
    };
    peerConnection.ontrack = (event: any) => {
      const [stream] = event.streams || [];
      if (stream?.toURL) setRemoteStreamUrl(stream.toURL());
    };
    peerConnection.onconnectionstatechange = () => {
      setPeerConnectionState(peerConnection.connectionState || "connecting");
      if (peerConnection.connectionState === "connected") setCallSignalStatus("Media connected");
      if (["failed", "disconnected", "closed"].includes(peerConnection.connectionState || "")) setCallSignalStatus("Media connection interrupted");
    };
    peerConnectionRef.current = peerConnection;
    return peerConnection;
  };

  const ensureWebRtcSession = async (conversationId: string, call: ConversationCallSession, initiator: boolean) => {
    if (!canUseNativeWebRtc) {
      setCallSignalStatus("Native WebRTC calls require a development build");
      return null;
    }
    const webRtc = getWebRtcModule();
    if (!webRtc) {
      setCallSignalStatus("Install and run a development build for real calls");
      return null;
    }
    const peerConnection = peerConnectionRef.current || createPeerConnection(conversationId, call.id);
    if (!peerConnection) return null;
    if (!localStreamRef.current) {
      const stream = await webRtc.mediaDevices.getUserMedia({
        audio: true,
        video: call.mode === "video" ? { facingMode: cameraFacing === "front" ? "user" : "environment" } : false,
      } as any);
      localStreamRef.current = stream;
      setLocalStreamUrl(stream.toURL());
      stream.getTracks().forEach((track: any) => peerConnection.addTrack(track, stream));
    }
    setPeerConnectionState(peerConnection.connectionState || "connecting");
    setCallSignalStatus(initiator ? "Creating secure media offer" : "Preparing secure media answer");
    return peerConnection;
  };

  const processPendingIceCandidates = async () => {
    const peerConnection = peerConnectionRef.current;
    if (!peerConnection?.remoteDescription) return;
    const pending = [...pendingIceCandidatesRef.current];
    pendingIceCandidatesRef.current = [];
    for (const candidate of pending) {
      const webRtc = getWebRtcModule();
      if (webRtc) await peerConnection.addIceCandidate(new webRtc.RTCIceCandidate(candidate));
    }
  };

  const handleCallSignal = async (payload: any) => {
    if (String(payload.sender_id) === String(authUser?.id || "")) return;
    if (payload.target_user_id && String(payload.target_user_id) !== String(authUser?.id || "")) return;
    const call = calls.find((item) => String(item.id) === String(payload.call_id)) || activeCall;
    const conversationId = String(payload.conversation_id || activeConversation?.id || "");
    if (!call || !conversationId) return;
    const signalType = String(payload.signal_type || "");
    const signal = payload.signal || {};

    try {
      if (signalType === "offer") {
        const peerConnection = await ensureWebRtcSession(conversationId, call, false);
        if (!peerConnection) return;
        const webRtc = getWebRtcModule();
        if (!webRtc) return;
        await peerConnection.setRemoteDescription(new webRtc.RTCSessionDescription(signal));
        const answer = await peerConnection.createAnswer();
        await peerConnection.setLocalDescription(answer);
        sendSocketEvent("call.signal", { conversation_id: conversationId, call_id: call.id, signal_type: "answer", signal: answer });
        await processPendingIceCandidates();
        setCallSignalStatus("Media answer sent");
        return;
      }
      if (signalType === "answer") {
        const peerConnection = peerConnectionRef.current;
        if (!peerConnection) return;
        const webRtc = getWebRtcModule();
        if (!webRtc) return;
        await peerConnection.setRemoteDescription(new webRtc.RTCSessionDescription(signal));
        await processPendingIceCandidates();
        setCallSignalStatus("Media handshake complete");
        return;
      }
      if (signalType === "ice-candidate") {
        const peerConnection = peerConnectionRef.current;
        if (!peerConnection?.remoteDescription) {
          pendingIceCandidatesRef.current.push(signal);
        } else {
          const webRtc = getWebRtcModule();
          if (webRtc) await peerConnection.addIceCandidate(new webRtc.RTCIceCandidate(signal));
        }
        setCallSignalStatus("Network route updated");
        return;
      }
      if (signalType === "ready") setCallSignalStatus("Contact is ready for media");
      else if (signalType === "mute") setCallSignalStatus("Contact muted microphone");
      else if (signalType === "unmute") setCallSignalStatus("Contact unmuted microphone");
      else if (signalType === "camera-off") setCallSignalStatus("Contact turned camera off");
      else if (signalType === "camera-on") setCallSignalStatus("Contact turned camera on");
      else if (signalType === "reject" || signalType === "busy") setCallSignalStatus("Contact is unavailable");
    } catch (signalError) {
      setCallSignalStatus("Media signaling failed");
      setError(signalError instanceof Error ? signalError.message : "Call signaling failed");
    }
  };

  const sendWebRtcOffer = async (conversationId: string, call: ConversationCallSession) => {
    const peerConnection = await ensureWebRtcSession(conversationId, call, true);
    if (!peerConnection) return;
    const offer = await peerConnection.createOffer({ offerToReceiveAudio: true, offerToReceiveVideo: call.mode === "video" });
    await peerConnection.setLocalDescription(offer);
    sendSocketEvent("call.signal", { conversation_id: conversationId, call_id: call.id, signal_type: "offer", signal: offer });
    setCallSignalStatus("Media offer sent");
  };

  const handleDraftChange = (value: string) => {
    setDraft(value);
    if (activeConversation?.id) {
      sendSocketEvent("typing", { conversation_id: activeConversation.id, is_typing: Boolean(value.trim()) });
    }
  };

  const sendChatBody = async (body: string, clearDraft = false, attachment?: MessageAttachmentInput) => {
    const conversation = await ensureConversation();
    const sent = await sendConversationMessage(conversation.id, body.trim(), attachment);
    setMessages((current) => [...current.filter((item) => item.id !== sent.id), sent]);
    if (clearDraft) {
      setDraft("");
      sendSocketEvent("typing", { conversation_id: conversation.id, is_typing: false });
    }
    await loadMessages(conversation.id);
    await loadCalls(conversation.id);
  };

  const submit = async () => {
    if (!draft.trim() || loading) return;
    setError("");
    setNotice("");

    try {
      await sendChatBody(draft, true);
    } catch (sendError) {
      setError(sendError instanceof Error ? sendError.message : "Message could not be sent");
    }
  };

  const requestCallPermissions = async (mode: "voice" | "video") => {
    const micPermission = microphonePermission?.granted ? microphonePermission : await requestMicrophonePermission();
    if (!micPermission.granted) throw new Error("Microphone permission is required for in-app calls.");

    if (mode === "video") {
      const nextCameraPermission = cameraPermission?.granted ? cameraPermission : await requestCameraPermission();
      if (!nextCameraPermission.granted) throw new Error("Camera permission is required for video calls.");
    }
  };

  const startCall = async (mode: "voice" | "video") => {
    if (loading) return;
    setError("");
    setNotice("");
    try {
      await requestCallPermissions(mode);
      setLoading(true);
      const conversation = await ensureConversation();
      const call = await startConversationCall(conversation.id, mode);
      setCalls((current) => [call, ...current.filter((item) => item.id !== call.id)]);
      setCallOverlayVisible(true);
      setCallSignalStatus("Waiting for contact signaling");
      sendSocketEvent("call.signal", { conversation_id: conversation.id, call_id: call.id, signal_type: "ready", signal: { initiator: true, media: mode } });
      await sendWebRtcOffer(conversation.id, call);
      setNotice(`${mode === "video" ? "Video" : "Voice"} call started.`);
      await loadCalls(conversation.id);
    } catch (callError) {
      setError(callError instanceof Error ? callError.message : "Call could not be started");
    } finally {
      setLoading(false);
    }
  };

  const sendAttachmentMessage = async (body: string, attachment?: MessageAttachmentInput) => {
    if (loading) return;
    setError("");
    setNotice("");
    try {
      setLoading(true);
      await sendChatBody(body, false, attachment);
      setNotice("Shared in chat.");
    } catch (shareError) {
      setError(shareError instanceof Error ? shareError.message : "Attachment could not be shared");
    } finally {
      setLoading(false);
    }
  };

  const handleAttachmentAction = async (action: AttachmentActionKey) => {
    setAttachmentSheetVisible(false);
    if (!selectedThread) {
      setError("Select a listing contact before sharing.");
      return;
    }

    if (action === "camera") {
      const permission = await ImagePicker.requestCameraPermissionsAsync();
      if (!permission.granted) {
        setError("Camera permission is required to take a photo or video.");
        return;
      }
      const result = await ImagePicker.launchCameraAsync({ mediaTypes: ["images", "videos"], quality: 0.78, videoMaxDuration: 45 });
      if (result.canceled) return;
      const asset = result.assets?.[0];
      if (!asset) return;
      await sendAttachmentMessage(formatMediaShare("Camera", asset, selectedThread.title), imageAssetToMessageAttachment(asset));
      return;
    }

    if (action === "gallery") {
      const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (!permission.granted) {
        setError("Photo library permission is required to choose house media.");
        return;
      }
      const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ["images", "videos"], quality: 0.78, allowsMultipleSelection: false });
      if (result.canceled) return;
      const asset = result.assets?.[0];
      if (!asset) return;
      await sendAttachmentMessage(formatMediaShare("Gallery", asset, selectedThread.title), imageAssetToMessageAttachment(asset));
      return;
    }

    if (action === "document") {
      const result = await DocumentPicker.getDocumentAsync({ copyToCacheDirectory: true, multiple: false });
      if (result.canceled) return;
      const asset = result.assets?.[0];
      if (!asset) return;
      await sendAttachmentMessage(`[Document] ${asset.name} shared for ${selectedThread.title}.`, documentAssetToMessageAttachment(asset));
      return;
    }

    if (action === "location") {
      const coordinates = listingCoordinates(selectedThread.gps);
      if (!coordinates) {
        setError("This listing does not have a saved map pin yet. Add GPS on the listing first.");
        return;
      }
      const [latitude, longitude] = coordinates;
      const mapsUrl = `https://www.openstreetmap.org/?mlat=${latitude}&mlon=${longitude}#map=17/${latitude}/${longitude}`;
      await sendAttachmentMessage(`[Location] ${selectedThread.title} map pin: ${mapsUrl}`, { type: "location", url: mapsUrl, name: selectedThread.address || "Listing location" });
      return;
    }

    if (action === "contact") {
      const permission = await Contacts.requestPermissionsAsync();
      if (!permission.granted) {
        setError("Contacts permission is required to pick a contact.");
        return;
      }
      const picked = await Contacts.presentContactPickerAsync().catch(() => null);
      if (!picked) return;
      const phone = picked.phoneNumbers?.[0]?.number ? ` · ${picked.phoneNumbers[0].number}` : "";
      await sendAttachmentMessage(`[Contact] ${picked.name || "Contact"}${phone}`);
      return;
    }

    const quickMessage = attachmentMessageFor(action, selectedThread.title, selectedThread.contactName);
    await sendAttachmentMessage(quickMessage);
  };

  const endCall = async (call: ConversationCallSession) => {
    if (!activeConversation?.id || loading) return;
    setError("");
    setNotice("");
    try {
      setLoading(true);
      sendSocketEvent("call.signal", { conversation_id: activeConversation.id, call_id: call.id, signal_type: "reject", signal: { ended: true } });
      const ended = await endConversationCall(activeConversation.id, call.id);
      setCalls((current) => current.map((item) => item.id === ended.id ? ended : item));
      cleanupWebRtcCall();
      setCallOverlayVisible(false);
      setNotice("Call ended.");
      await loadCalls(activeConversation.id);
    } catch (callError) {
      setError(callError instanceof Error ? callError.message : "Call could not be ended");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const callIntent = intent === "voice" || intent === "video" ? intent : null;
    if (!callIntent || !selectedThread) return;

    const intentKey = `${selectedThread.propertyId}-${callIntent}`;
    if (handledIntent === intentKey) return;

    setHandledIntent(intentKey);
    void startCall(callIntent);
  }, [handledIntent, intent, selectedThread]);

  return (
    <AccessGuard section="inbox" roles={["tenant", "landlord", "agent"]}>
      <Screen>
        <KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : "height"} keyboardVerticalOffset={0} style={styles.wrap}>
          {!selectedThread ? (
            <View style={styles.listPanel}>
              <View style={styles.listTopBar}>
                <View>
                  <Text style={styles.listTitle}>Chats</Text>
                </View>
                <View style={styles.listActions}>
                  <Pressable style={styles.listActionButton}>
                    <Ionicons name="camera-outline" size={17} color={colors.text} />
                  </Pressable>
                  <Pressable style={styles.listActionButton}>
                    <Ionicons name="create-outline" size={17} color={colors.text} />
                  </Pressable>
                </View>
              </View>

              <View style={styles.searchBar}>
                <Ionicons name="search" size={16} color={colors.textMuted} />
                <TextInput
                  value={searchQuery}
                  onChangeText={setSearchQuery}
                  placeholder="Search chats"
                  placeholderTextColor={colors.textMuted}
                  style={styles.searchInput}
                />
              </View>

              <ScrollView style={styles.threadList} contentContainerStyle={styles.threadListContent} keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>
                {visibleThreads.map((thread) => (
                  <ThreadRow
                    key={thread.key}
                    selected={thread.propertyId === selectedPropertyId}
                    thread={thread}
                    onPress={() => {
                      setSelectedPropertyId(thread.propertyId);
                      setNotice("");
                      setError("");
                    }}
                  />
                ))}
                {!visibleThreads.length ? (
                  <View style={styles.emptyList}>
                    <Ionicons name="chatbubble-ellipses-outline" size={28} color={colors.textMuted} />
                    <Text style={styles.emptyTitle}>No listing chats found</Text>
                    <Text style={styles.emptyBody}>Landlord and agent conversations will appear here.</Text>
                  </View>
                ) : null}
              </ScrollView>
            </View>
          ) : (
          <View style={styles.chatPanel}>
            <View style={styles.chatHeader}>
              <Pressable onPress={() => setSelectedPropertyId("")} style={styles.backToListButton}>
                <Ionicons name="chevron-back" size={22} color={colors.text} />
              </Pressable>
              {supplierProfileHref ? (
                <Link href={supplierProfileHref} asChild>
                  <Pressable style={styles.chatIdentity}>{chatIdentityContent}</Pressable>
                </Link>
              ) : (
                <View style={styles.chatIdentity}>{chatIdentityContent}</View>
              )}
              <View style={styles.chatActions}>
                <Pressable onPress={() => startCall("voice")} disabled={!selectedThread || loading} style={styles.chatIconButton}>
                  <Ionicons name="call-outline" size={19} color={colors.accent} />
                </Pressable>
                <Pressable onPress={() => startCall("video")} disabled={!selectedThread || loading} style={styles.chatIconButton}>
                  <Ionicons name="videocam-outline" size={20} color={colors.accent} />
                </Pressable>
              </View>
            </View>

            <ScrollView ref={messagesRef} style={styles.messages} contentContainerStyle={styles.messagesContent} keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>
              <View style={styles.securityNotice}>
                <Ionicons name="lock-closed" size={12} color={colors.accent} />
                <Text style={styles.securityText}>Chats, calls, and video calls must start from a real listing contact. Phone numbers stay hidden.</Text>
              </View>
              {activeCall ? (
                <View style={styles.callBanner}>
                  <View style={styles.callBannerIcon}>
                    <Ionicons name={activeCall.mode === "video" ? "videocam" : "call"} size={17} color={colors.accentText} />
                  </View>
                  <View style={styles.callBannerCopy}>
                    <Text style={styles.callBannerTitle}>{activeCall.mode === "video" ? "Video call" : "Voice call"}</Text>
                    <Text style={styles.callBannerMeta}>{activeCall.status} · in-app session</Text>
                  </View>
                  <Pressable onPress={() => endCall(activeCall)} disabled={loading} style={styles.endCallButton}>
                    <Text style={styles.endCallText}>End</Text>
                  </Pressable>
                </View>
              ) : null}
              <View style={styles.liveStatusPill}>
                <View style={[styles.liveStatusDot, liveConnected && styles.liveStatusDotOnline]} />
                <Text style={styles.liveStatusText}>{liveConnected ? "Live chat connected" : "Reconnecting live chat"}</Text>
              </View>
              {typingUser ? <Text style={styles.typingText}>{typingUser} is typing...</Text> : null}
              {notice ? <Text style={styles.notice}>{notice}</Text> : null}
              {error ? <Text style={styles.error}>{error}</Text> : null}
              {!activeConversation ? (
                <View style={styles.startCard}>
                  <Ionicons name="chatbubble-ellipses-outline" size={24} color={colors.accent} />
                  <Text style={styles.startTitle}>{selectedThread ? "Start a secure listing chat" : "Open chat from a house post"}</Text>
                  <Text style={styles.startBody}>
                    {selectedThread
                      ? "Your first message will create an account conversation with the owner or assigned agent for this house."
                      : "Go to Home, choose a house, then open the supplier profile to message that landlord or agent."}
                  </Text>
                </View>
              ) : null}
              {messages.map((item) => {
                const mine = String(item.senderId) === String(authUser?.id);
                return (
                  <View key={item.id} style={[styles.bubbleRow, mine && styles.bubbleRowMine]}>
                    <View style={[styles.bubble, mine ? styles.bubbleMine : styles.bubbleTheirs]}>
                      {!mine ? <Text style={styles.senderName}>{item.sender}</Text> : null}
                      {item.attachmentUrl ? <MessageAttachment message={item} mine={mine} /> : null}
                      {item.body ? <Text style={[styles.bubbleText, mine && styles.bubbleTextMine]}>{item.body}</Text> : null}
                      <Text style={[styles.bubbleTime, mine && styles.bubbleTimeMine]}>{formatMessageMeta(item, mine)}</Text>
                    </View>
                  </View>
                );
              })}
            </ScrollView>

            <View style={styles.composer}>
              <Pressable onPress={() => setAttachmentSheetVisible(true)} disabled={!selectedThread || loading} style={styles.composerIcon}>
                <Ionicons name="add" size={24} color={selectedThread ? colors.text : colors.textMuted} />
              </Pressable>
              <TextInput
                value={draft}
                onChangeText={handleDraftChange}
                editable={Boolean(selectedThread) && !loading}
                placeholder={selectedThread ? "Message this listing contact" : "Select a listing"}
                placeholderTextColor={colors.textMuted}
                style={styles.composerInput}
                multiline
                onFocus={() => setTimeout(() => messagesRef.current?.scrollToEnd({ animated: true }), 180)}
              />
              <Pressable onPress={submit} disabled={!draft.trim() || !selectedThread || loading} style={[styles.sendButton, (!draft.trim() || !selectedThread || loading) && styles.sendButtonIdle]}>
                <Ionicons name="send" size={17} color={colors.accentText} />
              </Pressable>
            </View>
            <CallOverlay
              call={activeCall}
              contactName={selectedThread?.contactName || "Listing contact"}
              contactOnline={contactOnline}
              muted={muted}
              profilePicture={selectedThread?.profilePicture}
              speakerOn={speakerOn}
              visible={Boolean(activeCall && callOverlayVisible)}
              onEnd={(call) => endCall(call)}
              onMessage={() => setCallOverlayVisible(false)}
              onToggleMuted={() => {
                const nextMuted = !muted;
                localStreamRef.current?.getAudioTracks().forEach((track: any) => {
                  track.enabled = !nextMuted;
                });
                setMuted(nextMuted);
                if (activeConversation?.id && activeCall?.id) sendSocketEvent("call.signal", { conversation_id: activeConversation.id, call_id: activeCall.id, signal_type: nextMuted ? "mute" : "unmute", signal: { muted: nextMuted } });
              }}
              cameraFacing={cameraFacing}
              cameraReady={Boolean(cameraPermission?.granted)}
              onFlipCamera={() => setCameraFacing((value) => value === "front" ? "back" : "front")}
              onToggleSpeaker={() => setSpeakerOn((value) => !value)}
              connectionState={peerConnectionState}
              localStreamUrl={localStreamUrl}
              remoteStreamUrl={remoteStreamUrl}
              signalStatus={callSignalStatus}
            />
            <AttachmentSheet
              visible={attachmentSheetVisible}
              onClose={() => setAttachmentSheetVisible(false)}
              onSelect={handleAttachmentAction}
            />
          </View>
          )}
        </KeyboardAvoidingView>
      </Screen>
    </AccessGuard>
  );
}

type LiveChatHandlers = {
  activeConversationId: string;
  authUserId: string;
  onCallEnded: (call: ConversationCallSession) => void;
  onCallSignal: (payload: any) => void;
  onCallStarted: (call: ConversationCallSession) => void;
  onError: (message: string) => void;
  onMessage: (message: ConversationMessage) => void;
  onDelivered: (payload: any) => void;
  onPresence: (payload: any) => void;
  onRead: (payload: any) => void;
  onTyping: (payload: any) => void;
};

function handleLiveChatEvent(raw: string, handlers: LiveChatHandlers) {
  let event: any;
  try {
    event = JSON.parse(raw);
  } catch {
    return;
  }
  const payload = event.payload || {};
  if (event.type === "error") handlers.onError(String(payload.message || "Live chat error"));
  if (event.type === "message.created") handlers.onMessage(mapLiveMessage(payload));
  if (event.type === "message.edited") handlers.onMessage(mapLiveMessage(payload));
  if (event.type === "message.deleted") handlers.onMessage(mapLiveMessage(payload));
  if (event.type === "messages.delivered") handlers.onDelivered(payload);
  if (event.type === "messages.read") handlers.onRead(payload);
  if (event.type === "typing") handlers.onTyping(payload);
  if (event.type === "presence.changed") handlers.onPresence(payload);
  if (event.type === "call.signal") handlers.onCallSignal(payload);
  if (event.type === "call.started") handlers.onCallStarted(mapLiveCall(payload));
  if (event.type === "call.ended") handlers.onCallEnded(mapLiveCall(payload));
}

function rtcIceServers() {
  const raw = process.env.EXPO_PUBLIC_RTC_ICE_SERVERS;
  if (raw) {
    try {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed) && parsed.length) return parsed;
    } catch {
      return raw.split(",").map((url) => ({ urls: url.trim() })).filter((item) => item.urls);
    }
  }
  return [{ urls: "stun:stun.l.google.com:19302" }];
}

function mapLiveMessage(item: any): ConversationMessage {
  return {
    id: String(item.id),
    conversationId: String(item.conversation_id),
    senderId: String(item.sender_id),
    sender: item.sender || "Property24 user",
    body: item.body || "",
    attachmentUrl: item.attachment_url || undefined,
    attachmentType: item.attachment_type || undefined,
    clientMessageId: item.client_message_id || item.client_id || undefined,
    attachmentName: item.attachment_name || undefined,
    createdAt: item.created_at || new Date().toISOString(),
    readAt: item.read_at || undefined,
    editedAt: item.edited_at || undefined,
    deletedAt: item.deleted_at || undefined,
    deleted: Boolean(item.deleted),
    deliveryStatus: item.delivery_status || undefined,
    receipts: Array.isArray(item.receipts) ? item.receipts.map((receipt: any) => ({
      userId: String(receipt.user_id),
      deliveredAt: receipt.delivered_at || undefined,
      readAt: receipt.read_at || undefined,
    })) : [],
  };
}

function mapLiveCall(item: any): ConversationCallSession {
  return {
    id: String(item.id),
    conversationId: String(item.conversation_id),
    initiatorId: String(item.initiator_id),
    mode: item.mode === "video" ? "video" : "voice",
    status: titleize(item.status || "ringing"),
    createdAt: item.created_at || new Date().toISOString(),
    endedAt: item.ended_at || undefined,
  };
}

function upsertMessages(current: ConversationMessage[], message: ConversationMessage) {
  return [...current.filter((item) => item.id !== message.id), message].sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());
}

function CallOverlay({ call, cameraFacing, cameraReady, connectionState, contactName, contactOnline, localStreamUrl, muted, onEnd, onFlipCamera, onMessage, onToggleMuted, onToggleSpeaker, profilePicture, remoteStreamUrl, signalStatus, speakerOn, visible }: { call?: ConversationCallSession; cameraFacing: "front" | "back"; cameraReady: boolean; connectionState: string; contactName: string; contactOnline: boolean; localStreamUrl: string; muted: boolean; onEnd: (call: ConversationCallSession) => void; onFlipCamera: () => void; onMessage: () => void; onToggleMuted: () => void; onToggleSpeaker: () => void; profilePicture?: string; remoteStreamUrl: string; signalStatus: string; speakerOn: boolean; visible: boolean }) {
  const { colors: themeColors } = useTheme();
  const colors = themeColors;
  const styles = createStyles(themeColors);
  if (!call) return null;
  const callLabel = call.mode === "video" ? "Video call" : "Voice call";
  const status = contactOnline ? "Ringing..." : "Calling... contact appears offline";

  return (
    <Modal animationType="fade" transparent visible={visible} onRequestClose={onMessage}>
      <View style={styles.callOverlay}>
        <Pressable onPress={onMessage} style={styles.callMinimizeButton}>
          <Ionicons name="chevron-down" size={24} color={colors.text} />
        </Pressable>
        {call.mode === "video" ? (
          <View style={styles.videoCallStage}>
            {remoteStreamUrl ? (
              <OptionalRTCView objectFit="cover" streamURL={remoteStreamUrl} style={styles.callCameraPreview} />
            ) : cameraReady ? (
              <CameraView facing={cameraFacing} mirror={cameraFacing === "front"} style={styles.callCameraPreview} />
            ) : (
              <View style={styles.callCameraPermission}>
                <Ionicons name="videocam-off" size={28} color={colors.textMuted} />
                <Text style={styles.callCameraPermissionText}>Camera permission is needed for video.</Text>
              </View>
            )}
            {localStreamUrl ? <OptionalRTCView mirror objectFit="cover" streamURL={localStreamUrl} style={styles.localWebRtcPreview} /> : null}
            <View style={styles.remoteVideoCard}>
              <View style={styles.remoteAvatarSmall}>
                {profilePicture ? (
                  <ImageBackground source={{ uri: profilePicture }} resizeMode="cover" style={styles.callAvatarImage} />
                ) : (
                  <Text style={styles.remoteAvatarText}>{initials(contactName)}</Text>
                )}
              </View>
              <View style={styles.remoteCopy}>
                <Text numberOfLines={1} style={styles.remoteName}>{contactName}</Text>
                <Text style={styles.remoteStatus}>{remoteStreamUrl ? `Connected · ${connectionState}` : status}</Text>
                <Text numberOfLines={1} style={styles.callSignalText}>{signalStatus}</Text>
              </View>
            </View>
            <Pressable onPress={onFlipCamera} style={styles.flipCameraButton}>
              <Ionicons name="camera-reverse" size={22} color={colors.text} />
            </Pressable>
          </View>
        ) : (
          <View style={styles.callProfileBlock}>
            <View style={styles.callAvatarLarge}>
              {profilePicture ? (
                <ImageBackground source={{ uri: profilePicture }} resizeMode="cover" style={styles.callAvatarImage} />
              ) : (
                <Text style={styles.callAvatarText}>{initials(contactName)}</Text>
              )}
            </View>
            <Text numberOfLines={1} style={styles.callContactName}>{contactName}</Text>
            <View style={styles.callStatusRow}>
              <View style={[styles.presenceDot, contactOnline && styles.presenceDotOnline]} />
              <Text style={styles.callStatusText}>{status}</Text>
            </View>
            <Text style={styles.callModeText}>{callLabel} · {connectionState}</Text>
            <Text style={styles.callSignalText}>{signalStatus}</Text>
          </View>
        )}
        <View style={styles.callControls}>
          <Pressable onPress={onToggleMuted} style={[styles.callControlButton, muted && styles.callControlButtonActive]}>
            <Ionicons name={muted ? "mic-off" : "mic"} size={22} color={colors.text} />
            <Text style={styles.callControlText}>{muted ? "Muted" : "Mute"}</Text>
          </Pressable>
          <Pressable onPress={onMessage} style={styles.callControlButton}>
            <Ionicons name="chatbubble" size={21} color={colors.text} />
            <Text style={styles.callControlText}>Message</Text>
          </Pressable>
          <Pressable onPress={onToggleSpeaker} style={[styles.callControlButton, speakerOn && styles.callControlButtonActive]}>
            <Ionicons name={speakerOn ? "volume-high" : "volume-medium"} size={22} color={colors.text} />
            <Text style={styles.callControlText}>{speakerOn ? "Speaker" : "Audio"}</Text>
          </Pressable>
        </View>
        <Pressable onPress={() => onEnd(call)} style={styles.callEndLargeButton}>
          <Ionicons name="call" size={26} color={colors.accentText} />
        </Pressable>
      </View>
    </Modal>
  );
}

type AttachmentActionKey = "camera" | "gallery" | "document" | "location" | "contact" | "viewing" | "payment";

const attachmentActions: { key: AttachmentActionKey; label: string; helper: string; icon: keyof typeof Ionicons.glyphMap; tone: string }[] = [
  { key: "camera", label: "Camera", helper: "Photo or video", icon: "camera", tone: "#E50914" },
  { key: "gallery", label: "Gallery", helper: "House media", icon: "image", tone: "#8B5CF6" },
  { key: "document", label: "Document", helper: "Lease or ID", icon: "document-text", tone: "#2563EB" },
  { key: "location", label: "Location", helper: "Viewing pin", icon: "location", tone: "#16A34A" },
  { key: "contact", label: "Contact", helper: "Keep numbers private", icon: "person-circle", tone: "#F59E0B" },
  { key: "viewing", label: "Viewing", helper: "Schedule visit", icon: "calendar", tone: "#06B6D4" },
  { key: "payment", label: "Payment", helper: "After approval", icon: "card", tone: "#E50914" },
];

function AttachmentSheet({ onClose, onSelect, visible }: { onClose: () => void; onSelect: (action: AttachmentActionKey) => void; visible: boolean }) {
  const { colors: themeColors } = useTheme();
  const colors = themeColors;
  const styles = createStyles(themeColors);
  return (
    <Modal animationType="slide" transparent visible={visible} onRequestClose={onClose}>
      <Pressable onPress={onClose} style={styles.attachmentBackdrop}>
        <Pressable style={styles.attachmentSheet}>
          <View style={styles.attachmentHandle} />
          <View style={styles.attachmentHeader}>
            <Text style={styles.attachmentTitle}>Attach</Text>
            <Pressable onPress={onClose} style={styles.attachmentCloseButton}>
              <Ionicons name="close" size={20} color={colors.text} />
            </Pressable>
          </View>
          <View style={styles.attachmentGrid}>
            {attachmentActions.map((item) => (
              <Pressable key={item.key} onPress={() => onSelect(item.key)} style={styles.attachmentItem}>
                <View style={[styles.attachmentIcon, { backgroundColor: item.tone }]}>
                  <Ionicons name={item.icon} size={23} color="#FFFFFF" />
                </View>
                <Text numberOfLines={1} style={styles.attachmentLabel}>{item.label}</Text>
                <Text numberOfLines={1} style={styles.attachmentHelper}>{item.helper}</Text>
              </Pressable>
            ))}
          </View>
        </Pressable>
      </Pressable>
    </Modal>
  );
}

function MessageAttachment({ message, mine }: { message: ConversationMessage; mine: boolean }) {
  const { colors: themeColors } = useTheme();
  const colors = themeColors;
  const styles = createStyles(themeColors);
  const kind = message.attachmentType || mediaKindFromName(message.attachmentName || message.attachmentUrl || "");
  const isImage = kind === "image";
  const icon = kind === "video" ? "play-circle" : kind === "document" ? "document-text" : kind === "location" ? "location" : "attach";
  return (
    <View style={[styles.messageAttachment, mine && styles.messageAttachmentMine]}>
      {isImage && message.attachmentUrl ? (
        <ImageBackground source={{ uri: message.attachmentUrl }} resizeMode="cover" style={styles.messageAttachmentImage} />
      ) : (
        <View style={styles.messageAttachmentIcon}>
          <Ionicons name={icon} size={24} color={colors.accentText} />
        </View>
      )}
      <View style={styles.messageAttachmentCopy}>
        <Text numberOfLines={1} style={styles.messageAttachmentTitle}>{message.attachmentName || attachmentLabel(kind)}</Text>
        <Text numberOfLines={1} style={styles.messageAttachmentMeta}>{attachmentLabel(kind)}</Text>
      </View>
    </View>
  );
}

function ThreadRow({ onPress, selected, thread }: { onPress: () => void; selected: boolean; thread: ListingThread }) {
  const { colors: themeColors } = useTheme();
  const colors = themeColors;
  const styles = createStyles(themeColors);
  return (
    <Pressable onPress={onPress} style={[styles.threadRow, selected && styles.threadRowActive]}>
      <View style={styles.threadAvatar}>
        {thread.profilePicture ? (
          <ImageBackground source={{ uri: thread.profilePicture }} resizeMode="cover" style={styles.threadAvatarImage} />
        ) : (
          <Text style={styles.threadAvatarText}>{initials(thread.contactName)}</Text>
        )}
        {thread.online ? <View style={styles.threadOnlineDot} /> : null}
      </View>
      <View style={styles.threadCopy}>
        <View style={styles.threadNameRow}>
          <Text numberOfLines={1} style={[styles.threadName, thread.unread && styles.threadNameUnread]}>{thread.contactName}</Text>
          <Text style={[styles.threadTime, thread.unread && styles.threadTimeUnread]}>{thread.time}</Text>
        </View>
        <Text numberOfLines={1} style={[styles.threadPreview, thread.unread && styles.threadPreviewUnread]}>
          {thread.title} · {thread.preview}
        </Text>
      </View>
      <View style={styles.threadMeta}>
        {thread.unread ? <View style={styles.unreadDot} /> : <Ionicons name="chevron-forward" size={17} color={colors.textMuted} />}
      </View>
    </Pressable>
  );
}

function buildListingThreads(properties: Property[], conversations: ConversationItem[], authUserId?: string): ListingThread[] {
  const conversationByProperty = new Map<string, ConversationItem>();
  conversations.forEach((conversation) => {
    if (conversation.propertyId && !conversationByProperty.has(conversation.propertyId)) {
      conversationByProperty.set(conversation.propertyId, conversation);
    }
  });

  const propertyThreads = properties
    .filter((property) => property.verified && property.supplierVerified !== false)
    .map((property) => {
      const conversation = conversationByProperty.get(property.id);
      const contactName = property.supplierName || property.agentName || property.ownerName || otherParticipantName(conversation) || "Listing contact";
      const contactRole = property.supplierRole === "agent" || property.agentName ? "Agent" : "Landlord";
      const profilePicture = property.supplierProfilePicture || property.agentProfilePicture || property.ownerProfilePicture || otherParticipantPicture(conversation);
      const contactLastSeenAt = property.supplierLastSeenAt || property.agentLastSeenAt || property.ownerLastSeenAt || otherParticipantLastSeenAt(conversation);
      return {
        key: `property-${property.id}`,
        propertyId: property.id,
        conversation,
        title: property.title,
        contactName,
        contactRole,
        supplierId: property.supplierId || property.agentId || property.ownerId,
        profilePicture,
        gps: property.gps,
        address: `${property.address}, ${property.suburb}, ${property.city}`,
        preview: conversation?.preview || `${contactRole} · ${property.price}`,
        time: conversation?.time || "Listing",
        unread: Boolean(conversation?.lastMessageSenderId && String(conversation.lastMessageSenderId) !== String(authUserId || "")),
        hasConversation: Boolean(conversation),
        sortScore: conversationSortScore(conversation) || property.listingViews,
        contactLastSeenAt,
        online: isUserOnline(contactLastSeenAt),
      };
    });

  const conversationOnlyThreads = conversations
    .filter((conversation) => conversation.propertyId && !properties.some((property) => property.id === conversation.propertyId))
    .map((conversation) => ({
      key: `conversation-${conversation.id}`,
      propertyId: conversation.propertyId!,
      conversation,
      title: conversation.name,
      contactName: otherParticipantName(conversation) || conversation.name,
      contactRole: "Listing contact",
      supplierId: otherParticipantId(conversation),
      profilePicture: otherParticipantPicture(conversation),
      gps: undefined,
      address: undefined,
      preview: conversation.preview,
      time: conversation.time,
      unread: Boolean(conversation.lastMessageSenderId && String(conversation.lastMessageSenderId) !== String(authUserId || "")),
      hasConversation: true,
      sortScore: conversationSortScore(conversation),
      contactLastSeenAt: otherParticipantLastSeenAt(conversation),
      online: isUserOnline(otherParticipantLastSeenAt(conversation)),
    }));

  return [...propertyThreads, ...conversationOnlyThreads].sort((a, b) => {
    if (a.hasConversation !== b.hasConversation) return a.hasConversation ? -1 : 1;
    return b.sortScore - a.sortScore || a.contactName.localeCompare(b.contactName);
  });
}

function listingCoordinates(gps?: string): [string, string] | null {
  const [latitude, longitude] = String(gps || "").split(",").map((part) => part.trim());
  if (!latitude || !longitude) return null;
  if (Number.isNaN(Number(latitude)) || Number.isNaN(Number(longitude))) return null;
  return [Number(latitude).toFixed(6), Number(longitude).toFixed(6)];
}

function otherParticipantName(conversation?: ConversationItem) {
  return conversation?.participants.find((participant) => participant.role !== "tenant")?.name || conversation?.participants[0]?.name;
}

function otherParticipantId(conversation?: ConversationItem) {
  return conversation?.participants.find((participant) => participant.role !== "tenant")?.id || conversation?.participants[0]?.id;
}

function otherParticipantPicture(conversation?: ConversationItem) {
  return conversation?.participants.find((participant) => participant.role !== "tenant")?.profilePicture || conversation?.participants[0]?.profilePicture;
}

function otherParticipantLastSeenAt(conversation?: ConversationItem) {
  return conversation?.participants.find((participant) => participant.role !== "tenant")?.lastSeenAt || conversation?.participants[0]?.lastSeenAt;
}

function imageAssetToMessageAttachment(asset: ImagePicker.ImagePickerAsset): MessageAttachmentInput {
  const type = asset.type === "video" ? "video" : "image";
  return {
    file: {
      uri: asset.uri,
      name: asset.fileName || `${type}-${Date.now()}.${type === "video" ? "mp4" : "jpg"}`,
      type: asset.mimeType || (type === "video" ? "video/mp4" : "image/jpeg"),
    },
    type,
    name: asset.fileName || `${type}-${Date.now()}`,
  };
}

function documentAssetToMessageAttachment(asset: DocumentPicker.DocumentPickerAsset): MessageAttachmentInput {
  return {
    file: {
      uri: asset.uri,
      name: asset.name || `document-${Date.now()}`,
      type: asset.mimeType || "application/octet-stream",
    },
    type: "document",
    name: asset.name || "Document",
  };
}

function mediaKindFromName(value: string) {
  const normalized = value.toLowerCase();
  if (/\.(jpg|jpeg|png|webp|gif)$/.test(normalized)) return "image";
  if (/\.(mp4|mov|m4v|webm)$/.test(normalized)) return "video";
  if (normalized.includes("openstreetmap") || normalized.includes("location")) return "location";
  return "document";
}

function attachmentLabel(kind: string) {
  if (kind === "image") return "Photo";
  if (kind === "video") return "Video";
  if (kind === "location") return "Location";
  return "Document";
}

function attachmentMessageFor(action: AttachmentActionKey, title: string, contactName: string) {
  if (action === "document") return `[Document] I want to share a lease, proof, or rental document for ${title}.`;
  if (action === "location") return `[Location] Please share or confirm the viewing location for ${title}.`;
  if (action === "contact") return `[Contact] I want to exchange contact details with ${contactName} when it is appropriate in the rental process.`;
  if (action === "viewing") return `[Viewing] I would like to schedule a physical viewing for ${title}.`;
  return `[Payment] I want to discuss payment only after viewing and approval for ${title}.`;
}

function formatMediaShare(source: string, asset: ImagePicker.ImagePickerAsset | undefined, title: string) {
  const mediaType = asset?.type === "video" ? "video" : "photo";
  const name = asset?.fileName ? ` (${asset.fileName})` : "";
  return `[${mediaType === "video" ? "Video" : "Photo"}] ${source} ${mediaType}${name} selected for ${title}.`;
}

function titleize(value: string) {
  const clean = String(value || "").replace(/_/g, " ");
  return clean ? clean.charAt(0).toUpperCase() + clean.slice(1) : "";
}

function initials(name: string) {
  const value = name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("");
  return value || "P";
}

function conversationSortScore(conversation?: ConversationItem) {
  if (!conversation?.updatedAt) return 0;
  const value = new Date(conversation.updatedAt).getTime();
  return Number.isNaN(value) ? 0 : value;
}

function isUserOnline(value?: string) {
  if (!value) return false;
  const date = new Date(value);
  return !Number.isNaN(date.getTime()) && Date.now() - date.getTime() < 2 * 60 * 1000;
}

function formatLastSeen(value?: string) {
  if (!value) return "Offline";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "Offline";
  const diff = Date.now() - date.getTime();
  if (diff < 2 * 60 * 1000) return "Online";
  if (diff < 60 * 60 * 1000) return `Last seen ${Math.max(2, Math.floor(diff / 60000))}m ago`;
  return `Last seen ${date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}`;
}

function formatMessageMeta(message: ConversationMessage, mine: boolean) {
  const date = new Date(message.createdAt);
  const time = Number.isNaN(date.getTime()) ? "Now" : date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  if (!mine) return time;
  if (message.deleted) return `${time} · Deleted`;
  if (message.editedAt) return `${time} · Edited`;
  if (message.deliveryStatus === "read" || message.readAt) return `${time} · Read`;
  if (message.deliveryStatus === "delivered") return `${time} · Delivered`;
  return `${time} · Sent`;
}

function createStyles(themeColors: typeof colors) {
  const colors = themeColors;
  return StyleSheet.create({
  wrap: { flex: 1, backgroundColor: colors.surface },
  topBar: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: spacing.md, paddingHorizontal: 14, paddingTop: 12, paddingBottom: 10, backgroundColor: colors.surface, borderBottomWidth: 1, borderBottomColor: colors.border },
  kicker: { color: colors.textMuted, fontSize: 11, textTransform: "uppercase", ...typography.label },
  title: { color: colors.text, fontSize: 25, lineHeight: 31, marginTop: 2, ...typography.display },
  topBadge: { flexDirection: "row", alignItems: "center", gap: 6, borderWidth: 1, borderColor: colors.border, borderRadius: 999, paddingHorizontal: 10, paddingVertical: 7, backgroundColor: colors.surface },
  topBadgeText: { color: colors.accent, fontSize: 12, ...typography.button },
  listPanel: { flex: 1, backgroundColor: colors.surface },
  listTopBar: { minHeight: 46, flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 8, paddingHorizontal: 14, paddingTop: 2, paddingBottom: 2, backgroundColor: colors.surface },
  listTitle: { color: colors.text, fontSize: 26, lineHeight: 31, ...typography.display },
  listSubtitle: { color: colors.textMuted, fontSize: 9, marginTop: 0, ...typography.body },
  listActions: { flexDirection: "row", alignItems: "center", gap: 8 },
  listActionButton: { width: 34, height: 34, alignItems: "center", justifyContent: "center", borderRadius: 17, backgroundColor: colors.surfaceMuted },
  listBadge: { width: 26, height: 26, alignItems: "center", justifyContent: "center", borderRadius: 13, backgroundColor: colors.accentSoft },
  listBadgeText: { color: colors.accent, fontSize: 12, ...typography.button },
  searchBar: { minHeight: 38, flexDirection: "row", alignItems: "center", gap: 8, marginHorizontal: 14, marginTop: 2, marginBottom: 2, borderRadius: 19, paddingHorizontal: 12, backgroundColor: colors.surfaceMuted },
  searchInput: { flex: 1, minWidth: 0, color: colors.text, fontSize: 14, outlineStyle: "none" as any, ...typography.body },
  threadList: { flex: 1 },
  threadListContent: { paddingHorizontal: 10, paddingTop: 2, paddingBottom: 8 },
  threadRow: { minHeight: 60, flexDirection: "row", alignItems: "center", gap: 10, borderBottomWidth: 1, borderBottomColor: colors.border, paddingHorizontal: 4, paddingVertical: 6, backgroundColor: colors.surface },
  threadRowActive: { backgroundColor: colors.surfaceElevated },
  threadAvatar: { width: 46, height: 46, borderRadius: 23, overflow: "hidden", alignItems: "center", justifyContent: "center", backgroundColor: colors.accent },
  threadAvatarImage: { width: "100%", height: "100%" },
  threadAvatarText: { color: colors.accentText, fontSize: 13, ...typography.button },
  threadOnlineDot: { position: "absolute", right: 1, bottom: 1, width: 10, height: 10, borderRadius: 5, borderWidth: 1.5, borderColor: colors.background, backgroundColor: colors.success },
  threadCopy: { flex: 1, minWidth: 0, gap: 2 },
  threadNameRow: { flexDirection: "row", alignItems: "center", gap: 6 },
  threadName: { flex: 1, minWidth: 0, color: colors.text, fontSize: 15, ...typography.title },
  threadNameUnread: { color: colors.text },
  threadTime: { color: colors.textMuted, fontSize: 11, ...typography.body },
  threadTimeUnread: { color: colors.accent, ...typography.label },
  threadTitle: { color: colors.textMuted, fontSize: 12, ...typography.label },
  threadPreview: { color: colors.textMuted, fontSize: 12, lineHeight: 16, ...typography.body },
  threadPreviewUnread: { color: colors.text, ...typography.label },
  threadMeta: { width: 16, alignItems: "center", justifyContent: "center" },
  unreadDot: { width: 8, height: 8, borderRadius: 4, backgroundColor: colors.accent },
  emptyList: { alignItems: "center", justifyContent: "center", gap: 7, paddingVertical: 46, paddingHorizontal: 24 },
  emptyTitle: { color: colors.text, fontSize: 16, ...typography.title },
  emptyBody: { color: colors.textMuted, lineHeight: 19, textAlign: "center", ...typography.body },
  chatPanel: { flex: 1, backgroundColor: colors.background },
  chatHeader: { minHeight: 44, flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingLeft: 0, paddingRight: 6, backgroundColor: colors.surface, borderBottomWidth: 1, borderBottomColor: colors.border },
  backToListButton: { width: 30, height: 34, alignItems: "center", justifyContent: "center" },
  chatIdentity: { flex: 1, minWidth: 0, flexDirection: "row", alignItems: "center", gap: 7 },
  chatAvatar: { width: 30, height: 30, borderRadius: 15, overflow: "hidden", alignItems: "center", justifyContent: "center", backgroundColor: colors.accent },
  chatAvatarImage: { width: "100%", height: "100%" },
  chatAvatarText: { color: colors.accentText, fontSize: 12, ...typography.button },
  chatTitleWrap: { flex: 1, minWidth: 0 },
  chatName: { color: colors.text, fontSize: 15, lineHeight: 19, ...typography.title },
  presenceRow: { minHeight: 12, flexDirection: "row", alignItems: "center", gap: 4 },
  presenceDot: { width: 6, height: 6, borderRadius: 3, backgroundColor: colors.muted },
  presenceDotOnline: { backgroundColor: colors.success },
  chatStatus: { flex: 1, color: colors.textMuted, fontSize: 11, lineHeight: 14, marginTop: 0, ...typography.body },
  chatStatusOnline: { color: colors.success },
  chatActions: { flexDirection: "row", alignItems: "center", gap: 2 },
  chatIconButton: { width: 28, height: 28, alignItems: "center", justifyContent: "center", borderRadius: 14, backgroundColor: colors.accentSoft },
  messages: { flex: 1 },
  messagesContent: { paddingHorizontal: 7, paddingTop: 4, paddingBottom: 18, gap: 4 },
  securityNotice: { alignSelf: "center", maxWidth: "88%", flexDirection: "row", alignItems: "center", gap: 4, borderRadius: 999, paddingHorizontal: 8, paddingVertical: 4, backgroundColor: colors.surfaceElevated, borderWidth: 1, borderColor: colors.border },
  securityText: { flexShrink: 1, color: colors.textMuted, fontSize: 10, lineHeight: 13, textAlign: "center", ...typography.label },
  liveStatusPill: { alignSelf: "center", minHeight: 25, flexDirection: "row", alignItems: "center", gap: 6, borderRadius: 999, paddingHorizontal: 9, paddingVertical: 4, backgroundColor: colors.surface },
  liveStatusDot: { width: 7, height: 7, borderRadius: 3.5, backgroundColor: colors.warning },
  liveStatusDotOnline: { backgroundColor: colors.success },
  liveStatusText: { color: colors.textMuted, fontSize: 10, lineHeight: 13, ...typography.label },
  typingText: { alignSelf: "flex-start", color: colors.textMuted, fontSize: 11, lineHeight: 15, paddingLeft: 8, ...typography.body },
  callBanner: { alignSelf: "center", width: "94%", minHeight: 50, flexDirection: "row", alignItems: "center", gap: 10, borderWidth: 1, borderColor: "rgba(229,9,20,0.36)", borderRadius: 8, paddingHorizontal: 10, paddingVertical: 8, backgroundColor: colors.surfaceElevated, ...shadows.soft },
  callBannerIcon: { width: 34, height: 34, borderRadius: 17, alignItems: "center", justifyContent: "center", backgroundColor: colors.accent },
  callBannerCopy: { flex: 1, minWidth: 0 },
  callBannerTitle: { color: colors.text, fontSize: 13, ...typography.title },
  callBannerMeta: { color: colors.textMuted, fontSize: 11, marginTop: 1, ...typography.body },
  endCallButton: { minHeight: 32, justifyContent: "center", borderRadius: 999, paddingHorizontal: 12, backgroundColor: colors.danger },
  endCallText: { color: colors.accentText, fontSize: 12, ...typography.button },
  notice: { alignSelf: "center", color: colors.success, fontSize: 11, ...typography.label },
  error: { alignSelf: "center", color: colors.danger, fontSize: 11, textAlign: "center", ...typography.label },
  startCard: { alignSelf: "center", maxWidth: 270, alignItems: "center", borderRadius: 8, borderWidth: 1, borderColor: colors.border, padding: 12, gap: 5, backgroundColor: colors.surface, ...shadows.soft },
  startTitle: { color: colors.text, fontSize: 15, ...typography.title },
  startBody: { color: colors.textMuted, lineHeight: 19, textAlign: "center", ...typography.body },
  bubbleRow: { width: "100%", flexDirection: "row", justifyContent: "flex-start" },
  bubbleRowMine: { justifyContent: "flex-end" },
  bubble: { maxWidth: "80%", borderRadius: 17, paddingHorizontal: 10, paddingTop: 6, paddingBottom: 5, gap: 2 },
  bubbleMine: { backgroundColor: colors.accent, borderBottomRightRadius: 5 },
  bubbleTheirs: { backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border, borderBottomLeftRadius: 5 },
  senderName: { color: colors.textMuted, fontSize: 11, ...typography.label },
  bubbleText: { color: colors.text, fontSize: 15, lineHeight: 20, ...typography.body },
  bubbleTextMine: { color: colors.accentText },
  bubbleTime: { alignSelf: "flex-end", color: colors.textMuted, fontSize: 10, ...typography.label },
  bubbleTimeMine: { color: "rgba(237,246,255,0.78)" },
  messageAttachment: { minWidth: 190, maxWidth: "100%", minHeight: 54, flexDirection: "row", alignItems: "center", gap: 8, overflow: "hidden", borderRadius: 8, marginBottom: 4, backgroundColor: colors.surfaceMuted },
  messageAttachmentMine: { backgroundColor: "rgba(2,11,20,0.18)" },
  messageAttachmentImage: { width: 70, height: 70, backgroundColor: colors.surfaceMuted },
  messageAttachmentIcon: { width: 54, height: 54, alignItems: "center", justifyContent: "center", backgroundColor: colors.accent },
  messageAttachmentCopy: { flex: 1, minWidth: 0, paddingRight: 8 },
  messageAttachmentTitle: { color: colors.text, fontSize: 13, lineHeight: 17, ...typography.label },
  messageAttachmentMeta: { color: colors.textMuted, fontSize: 11, lineHeight: 14, marginTop: 1, ...typography.body },
  composer: { flexDirection: "row", alignItems: "flex-end", gap: 4, paddingHorizontal: 6, paddingTop: 4, paddingBottom: Platform.OS === "ios" ? 7 : 4, backgroundColor: colors.surface, borderTopWidth: 1, borderTopColor: colors.border },
  composerIcon: { width: 34, height: 36, alignItems: "center", justifyContent: "center", borderRadius: 17, backgroundColor: colors.surfaceMuted },
  composerInput: { flex: 1, minWidth: 0, maxHeight: 82, borderRadius: 18, paddingHorizontal: 12, paddingVertical: 8, color: colors.text, fontSize: 15, lineHeight: 20, backgroundColor: colors.surfaceMuted, outlineStyle: "none" as any, ...typography.body },
  sendButton: { width: 36, height: 36, borderRadius: 18, alignItems: "center", justifyContent: "center", backgroundColor: colors.accent },
  sendButtonIdle: { backgroundColor: colors.muted },
  attachmentBackdrop: { flex: 1, justifyContent: "flex-end", backgroundColor: "rgba(2,11,20,0.64)" },
  attachmentSheet: { borderTopLeftRadius: 18, borderTopRightRadius: 18, borderWidth: 1, borderBottomWidth: 0, borderColor: colors.border, paddingHorizontal: 16, paddingTop: 8, paddingBottom: Platform.OS === "ios" ? 28 : 18, backgroundColor: colors.surfaceElevated, ...shadows.card },
  attachmentHandle: { alignSelf: "center", width: 38, height: 4, borderRadius: 2, marginBottom: 10, backgroundColor: colors.muted },
  attachmentHeader: { minHeight: 36, flexDirection: "row", alignItems: "center", justifyContent: "space-between", marginBottom: 8 },
  attachmentTitle: { color: colors.text, fontSize: 18, lineHeight: 23, ...typography.title },
  attachmentCloseButton: { width: 34, height: 34, alignItems: "center", justifyContent: "center", borderRadius: 17, backgroundColor: colors.surfaceMuted },
  attachmentGrid: { flexDirection: "row", flexWrap: "wrap", rowGap: 16 },
  attachmentItem: { width: "25%", alignItems: "center", gap: 5, paddingHorizontal: 3 },
  attachmentIcon: { width: 52, height: 52, borderRadius: 26, alignItems: "center", justifyContent: "center" },
  attachmentLabel: { maxWidth: "100%", color: colors.text, fontSize: 12, lineHeight: 15, textAlign: "center", ...typography.label },
  attachmentHelper: { maxWidth: "100%", color: colors.textMuted, fontSize: 9, lineHeight: 12, textAlign: "center", ...typography.body },
  callOverlay: { flex: 1, alignItems: "center", justifyContent: "space-between", paddingTop: 46, paddingHorizontal: 24, paddingBottom: 34, backgroundColor: "rgba(2,11,20,0.98)" },
  callMinimizeButton: { alignSelf: "flex-start", width: 42, height: 42, alignItems: "center", justifyContent: "center", borderRadius: 21, backgroundColor: colors.surfaceMuted },
  callProfileBlock: { width: "100%", alignItems: "center", gap: 9, paddingTop: 18 },
  callAvatarLarge: { width: 112, height: 112, borderRadius: 56, overflow: "hidden", alignItems: "center", justifyContent: "center", borderWidth: 2, borderColor: colors.success, backgroundColor: colors.accent },
  callAvatarImage: { width: "100%", height: "100%" },
  callAvatarText: { color: colors.accentText, fontSize: 28, ...typography.display },
  callContactName: { maxWidth: "92%", color: colors.text, fontSize: 25, lineHeight: 31, textAlign: "center", ...typography.display },
  callStatusRow: { flexDirection: "row", alignItems: "center", gap: 6 },
  callStatusText: { color: colors.textMuted, fontSize: 13, ...typography.label },
  callModeText: { color: colors.textMuted, fontSize: 12, ...typography.body },
  callSignalText: { color: colors.success, fontSize: 11, lineHeight: 15, textAlign: "center", ...typography.label },
  videoCallStage: { width: "100%", flex: 1, position: "relative", overflow: "hidden", borderRadius: 8, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.background },
  callCameraPreview: { flex: 1 },
  localWebRtcPreview: { position: "absolute", right: 14, bottom: 88, width: 104, height: 148, borderRadius: 8, overflow: "hidden", borderWidth: 1, borderColor: colors.border, backgroundColor: colors.surface },
  callCameraPermission: { flex: 1, alignItems: "center", justifyContent: "center", gap: 8, paddingHorizontal: 20, backgroundColor: colors.surface },
  callCameraPermissionText: { color: colors.textMuted, fontSize: 13, lineHeight: 18, textAlign: "center", ...typography.body },
  remoteVideoCard: { position: "absolute", left: 12, right: 12, top: 12, minHeight: 56, flexDirection: "row", alignItems: "center", gap: 10, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 8, backgroundColor: "rgba(2,11,20,0.72)" },
  remoteAvatarSmall: { width: 38, height: 38, borderRadius: 19, overflow: "hidden", alignItems: "center", justifyContent: "center", backgroundColor: colors.accent },
  remoteAvatarText: { color: colors.accentText, fontSize: 12, ...typography.button },
  remoteCopy: { flex: 1, minWidth: 0 },
  remoteName: { color: colors.text, fontSize: 14, lineHeight: 18, ...typography.title },
  remoteStatus: { color: colors.textMuted, fontSize: 11, lineHeight: 15, marginTop: 1, ...typography.body },
  flipCameraButton: { position: "absolute", right: 14, bottom: 14, width: 46, height: 46, alignItems: "center", justifyContent: "center", borderRadius: 23, backgroundColor: "rgba(2,11,20,0.72)" },
  callControls: { width: "100%", flexDirection: "row", justifyContent: "space-between", gap: 10 },
  callControlButton: { flex: 1, minHeight: 68, alignItems: "center", justifyContent: "center", gap: 6, borderRadius: 8, backgroundColor: colors.surfaceMuted },
  callControlButtonActive: { backgroundColor: colors.accentSoft, borderWidth: 1, borderColor: "rgba(229,9,20,0.34)" },
  callControlText: { color: colors.text, fontSize: 11, ...typography.label },
  callEndLargeButton: { width: 64, height: 64, borderRadius: 32, alignItems: "center", justifyContent: "center", backgroundColor: colors.danger, transform: [{ rotate: "135deg" }], ...shadows.card },
  });
}
