import AsyncStorage from "@react-native-async-storage/async-storage";
import Constants from "expo-constants";
import * as FileSystem from "expo-file-system";
import { Dispatch, ReactNode, createContext, useContext, useEffect, useMemo, useReducer, useState } from "react";
import { Platform } from "react-native";


type NotificationsModule = typeof import("expo-notifications");
type MediaLibraryModule = typeof import("expo-media-library");

let cachedNotificationsModule: NotificationsModule | null | undefined;
let cachedMediaLibraryModule: MediaLibraryModule | null | undefined;

function getNotificationsModule(): NotificationsModule | null {
  if (Platform.OS === "web") return null;
  if (cachedNotificationsModule !== undefined) return cachedNotificationsModule;
  try {
    cachedNotificationsModule = require("expo-notifications") as NotificationsModule;
    cachedNotificationsModule.setNotificationHandler({
      handleNotification: async () => ({
        shouldPlaySound: true,
        shouldSetBadge: true,
        shouldShowBanner: true,
        shouldShowList: true,
      }),
    });
  } catch {
    cachedNotificationsModule = null;
  }
  return cachedNotificationsModule;
}

function getMediaLibraryModule(): MediaLibraryModule | null {
  if (Platform.OS === "web") return null;
  if (cachedMediaLibraryModule !== undefined) return cachedMediaLibraryModule;
  try {
    cachedMediaLibraryModule = require("expo-media-library") as MediaLibraryModule;
  } catch {
    cachedMediaLibraryModule = null;
  }
  return cachedMediaLibraryModule;
}

export type Property = {
  id: string;
  ownerId?: string;
  ownerName?: string;
  ownerRole?: AccountRole;
  ownerVerified?: boolean;
  ownerProfilePicture?: string;
  ownerCoverPhoto?: string;
  ownerBio?: string;
  ownerLastSeenAt?: string;
  agentId?: string;
  agentName?: string;
  agentVerified?: boolean;
  agentProfilePicture?: string;
  agentCoverPhoto?: string;
  agentBio?: string;
  agentLastSeenAt?: string;
  supplierId?: string;
  supplierName?: string;
  supplierRole?: AccountRole;
  supplierVerified?: boolean;
  supplierProfilePicture?: string;
  supplierCoverPhoto?: string;
  supplierBio?: string;
  supplierLastSeenAt?: string;
  title: string;
  address: string;
  city: string;
  suburb: string;
  price: string;
  deposit: string;
  type: string;
  bedrooms: number;
  bathrooms: number;
  furnished: string;
  parking: string;
  power: string;
  solarPower: boolean;
  water: string;
  borehole: boolean;
  gps: string;
  videoCount: number;
  tourAvailable: boolean;
  petFriendly: boolean;
  verified: boolean;
  description: string;
  photos: string[];
  listingViews: number;
  savedCount: number;
  applicationsCount: number;
  commentsCount?: number;
};

export type LiveEvent = {
  id: string;
  title: string;
  meta: string;
  status: string;
  tone: "success" | "warning" | "info" | "danger";
};

export type AccountRole = "tenant" | "landlord" | "agent" | "admin";
export type PublicAccountRole = Extract<AccountRole, "tenant" | "landlord">;

export type AccountContext = {
  accountType: AccountRole;
  visibleSections: string[];
  hiddenSections: string[];
  capabilities: string[];
  onboardingRequirements: string[];
  isVerified: boolean;
  emailVerified: boolean;
  phoneVerified: boolean;
  accountOnboardingComplete: boolean;
  fullVerificationRequired: boolean;
};

export type PaymentItem = {
  id: string;
  tenantId?: string;
  propertyId?: string;
  tenant: string;
  property: string;
  amount: string;
  method: string;
  status: string;
  time: string;
  receiptId: string;
  reminderStatus: string;
};

export type MaintenanceItem = {
  id: string;
  propertyId?: string;
  tenantId?: string;
  issue: string;
  category: string;
  property: string;
  tenant: string;
  description: string;
  photoCount: number;
  status: string;
  priority: string;
  updatedAt: string;
};

export type LeaseItem = {
  id: string;
  propertyId?: string;
  tenantId?: string;
  property: string;
  tenant: string;
  landlord: string;
  startDate: string;
  endDate: string;
  monthlyRent: string;
  deposit: string;
  term: string;
  pdf: string;
  status: string;
  signedByTenant: boolean;
  signedByLandlord: boolean;
};

export type VerificationItem = {
  id: string;
  name: string;
  role: string;
  checks: string[];
  status: string;
  reviewedBy: string;
};

export type ApplicationItem = {
  id: string;
  propertyId?: string;
  tenantId?: string;
  applicant: string;
  property: string;
  role: string;
  status: string;
  score: number;
  time: string;
};

export type ViewingItem = {
  id: string;
  propertyId?: string;
  tenantId?: string;
  property: string;
  agent: string;
  tenant: string;
  date: string;
  time: string;
  status: string;
};

export type ConversationItem = {
  id: string;
  propertyId?: string;
  name: string;
  time: string;
  preview: string;
  status: string;
  updatedAt?: string;
  lastMessageSenderId?: string;
  participants: ConversationParticipant[];
  phoneNumbersRevealed: boolean;
};

export type ConversationParticipant = {
  id: string;
  name: string;
  role: AccountRole;
  verified: boolean;
  profilePicture?: string;
  coverPhoto?: string;
  bio?: string;
  lastSeenAt?: string;
};

export type ConversationMessageReceipt = {
  userId: string;
  deliveredAt?: string;
  readAt?: string;
};

export type ConversationMessage = {
  id: string;
  conversationId: string;
  senderId: string;
  sender: string;
  body: string;
  clientMessageId?: string;
  attachmentUrl?: string;
  attachmentType?: string;
  attachmentName?: string;
  createdAt: string;
  readAt?: string;
  editedAt?: string;
  deletedAt?: string;
  deleted?: boolean;
  deliveryStatus?: "sent" | "delivered" | "read";
  receipts?: ConversationMessageReceipt[];
};

export type ConversationCallSession = {
  id: string;
  conversationId: string;
  initiatorId: string;
  mode: "voice" | "video";
  status: string;
  createdAt: string;
  endedAt?: string;
};

export type CallHistoryItem = ConversationCallSession & {
  contactId?: string;
  contactName: string;
  propertyTitle: string;
  conversationTitle: string;
};

export type MediaAsset = {
  id: string;
  scope: string;
  mediaType: "image" | "video" | "document" | "audio" | "other";
  access: "public" | "private";
  status: string;
  processingStatus: string;
  originalName: string;
  mimeType: string;
  sizeBytes: number;
  width?: number;
  height?: number;
  durationSeconds?: number;
  sourceModel: string;
  sourceId: string;
  url: string;
  thumbnailUrl: string;
  createdAt: string;
  updatedAt: string;
};

export type MediaAssetFilter = {
  scope?: string;
  sourceModel?: string;
  sourceId?: string;
  propertyId?: string;
  conversationId?: string;
};

export type PropertyCommentItem = {
  id: string;
  propertyId: string;
  authorId: string;
  author: string;
  authorRole: AccountRole;
  authorVerified: boolean;
  body: string;
  mediaUri: string;
  likes: number;
  createdAt: string;
  time: string;
};

export type PropertyCommentInput = {
  body: string;
  mediaUri?: string;
  parentId?: string;
};

export type RentalPlatformState = {
  properties: Property[];
  payments: PaymentItem[];
  maintenance: MaintenanceItem[];
  leases: LeaseItem[];
  verifications: VerificationItem[];
  applications: ApplicationItem[];
  viewings: ViewingItem[];
  conversations: ConversationItem[];
  liveEvents: LiveEvent[];
};

export type AuthUser = {
  id: string;
  name: string;
  email: string;
  phone: string;
  role: AccountRole;
  verified: boolean;
  emailVerified: boolean;
  phoneVerified: boolean;
  accountOnboardingComplete: boolean;
  profileStatus: string;
  authProvider: string;
  googleEmailVerified: boolean;
  profilePicture?: string;
  coverPhoto?: string;
  bio?: string;
  lastSeenAt?: string;
};

export type SignInPayload = {
  username: string;
  password: string;
};

export type RegisterAccountPayload = {
  accountType: PublicAccountRole;
  name: string;
  email: string;
  password: string;
};

export type LandlordAgentInput = {
  name: string;
  email: string;
  phone: string;
  password?: string;
};

export type RegistrationOtpChallenge = {
  otpRequired: boolean;
  challengeId: string;
  deliveryChannel: "email" | "sms";
  destination: string;
  email: string;
  phone: string;
  expiresInSeconds: number;
  message?: string;
};

export type VerificationEmailOtpChallenge = {
  otpRequired: boolean;
  challengeId: string;
  email: string;
  deliveryChannel: "email" | "provider_required";
  expiresInSeconds: number;
  message?: string;
};

export type VerificationPhoneOtpChallenge = {
  otpRequired: boolean;
  challengeId: string;
  phone: string;
  deliveryChannel: "sms" | "provider_required";
  expiresInSeconds: number;
  message?: string;
};

export type VerificationIdExtraction = {
  extractedNationalIdNumber: string;
  confidence: string;
  requiresConfirmation: boolean;
};

export type VerificationSubmissionPayload = {
  role: AccountRole;
  name?: string;
  phone?: string;
  country_of_residence?: string;
  privacy_notice_accepted?: boolean;
  document_issue_country?: string;
  document_type?: string;
  residential_address?: string;
  address_gps_confirmed?: boolean;
  proof_of_address_confirmed?: boolean;
  politically_exposed_person?: boolean;
  declaration_accepted?: boolean;
  national_id_number: string;
  phone_verified?: boolean;
  email_verified?: boolean;
  selfie_uploaded: boolean;
  identity_confirmed?: boolean;
  extracted_national_id_number?: string;
  idFrontFile?: AccountMediaFile;
  idBackFile?: AccountMediaFile;
  livenessFile?: AccountMediaFile;
  selfieFile?: AccountMediaFile;
  proofOfAddressFile?: AccountMediaFile;
  ownershipOrAuthorizationFile?: AccountMediaFile;
  estate_agency_registration?: string;
  agency_name?: string;
  contact_details?: string;
};

export type AccountProfileUpdatePayload = {
  name?: string;
  bio?: string;
  profilePicture?: string;
  coverPhoto?: string;
  profilePictureFile?: AccountMediaFile;
  coverPhotoFile?: AccountMediaFile;
  removeProfilePicture?: boolean;
  removeCoverPhoto?: boolean;
};

export type AccountMediaFile = {
  uri: string;
  name: string;
  type: string;
};

export type MessageAttachmentInput = {
  file?: AccountMediaFile;
  url?: string;
  type: string;
  name?: string;
};

type PropertyInput = Omit<Property, "id" | "verified" | "photos" | "listingViews" | "savedCount" | "applicationsCount"> & {
  verified?: boolean;
  photos?: string[];
  photoFiles?: AccountMediaFile[];
  videoFiles?: AccountMediaFile[];
  listingViews?: number;
  savedCount?: number;
  applicationsCount?: number;
};
type PaymentInput = Omit<PaymentItem, "id" | "time" | "status" | "receiptId" | "reminderStatus"> & {
  status?: string;
  time?: string;
  receiptId?: string;
  reminderStatus?: string;
};
type MaintenanceInput = Omit<MaintenanceItem, "id" | "updatedAt" | "status"> & { status?: string; updatedAt?: string };
type LeaseInput = Omit<LeaseItem, "id" | "status" | "signedByTenant" | "signedByLandlord" | "pdf"> & {
  status?: string;
  signedByTenant?: boolean;
  signedByLandlord?: boolean;
  pdf?: string;
};
type VerificationInput = Omit<VerificationItem, "id" | "status" | "reviewedBy"> & { status?: string; reviewedBy?: string };
type ApplicationInput = Omit<ApplicationItem, "id" | "status" | "time"> & { status?: string; time?: string };
type ViewingInput = Omit<ViewingItem, "id" | "status"> & { status?: string };
type ConversationInput = Omit<ConversationItem, "id" | "time" | "status" | "participants" | "phoneNumbersRevealed"> & {
  time?: string;
  status?: string;
  participants?: ConversationParticipant[];
  phoneNumbersRevealed?: boolean;
};

const STORAGE_KEY = "property24-zimbabwe-rental-platform-v3";
const ACCOUNT_ROLE_STORAGE_KEY = "property24-zimbabwe-account-role";
const API_TOKEN_STORAGE_KEY = "property24-zimbabwe-api-token";
const DEFAULT_API_PORT = "8010";
const API_BASE_URL = resolveApiBaseUrl();
const defaultAccountRole: AccountRole = "tenant";

export const accountContexts: Record<AccountRole, Omit<AccountContext, "accountType" | "hiddenSections" | "isVerified" | "emailVerified" | "phoneVerified" | "accountOnboardingComplete" | "fullVerificationRequired">> = {
  tenant: {
    visibleSections: ["index", "inbox", "profile", "calls", "maintenance", "leases", "verification"],
    capabilities: ["search_properties", "save_properties", "submit_tenant_verification", "apply_for_rentals", "view_rental_history", "report_maintenance", "sign_leases", "message_landlord_or_agent"],
    onboardingRequirements: ["email_verification"],
  },
  landlord: {
    visibleSections: ["index", "listings", "inbox", "profile", "calls", "maintenance", "leases", "analytics", "verification"],
    capabilities: ["add_properties", "upload_property_media", "create_agents", "submit_landlord_verification", "approve_tenants", "manage_maintenance", "view_landlord_reports", "message_tenants"],
    onboardingRequirements: ["email_verification"],
  },
  agent: {
    visibleSections: ["index", "listings", "inbox", "profile", "calls", "operations"],
    capabilities: ["list_properties", "submit_agent_verification", "schedule_viewings", "manage_landlords", "track_applications", "track_commissions", "message_clients"],
    onboardingRequirements: ["email_verification"],
  },
  admin: {
    visibleSections: ["index", "profile", "calls", "verification", "operations", "analytics"],
    capabilities: ["verify_users", "remove_fake_listings", "resolve_disputes", "review_reports", "manage_all_accounts"],
    onboardingRequirements: [],
  },
};

const allSections = Array.from(new Set(Object.values(accountContexts).flatMap((context) => context.visibleSections)));

const initialState: RentalPlatformState = createEmptyRentalPlatformState();

function createEmptyRentalPlatformState(): RentalPlatformState {
  return {
    properties: [],
    payments: [],
    maintenance: [],
    leases: [],
    verifications: [],
    applications: [],
    viewings: [],
    conversations: [],
    liveEvents: [],
  };
}

type RentalPlatformAction =
  | { type: "hydrate"; state: RentalPlatformState }
  | { type: "addProperty"; payload: PropertyInput }
  | { type: "updateProperty"; propertyId: string; payload: Partial<PropertyInput> }
  | { type: "deleteProperty"; propertyId: string }
  | { type: "addPayment"; payload: PaymentInput }
  | { type: "addMaintenance"; payload: MaintenanceInput }
  | { type: "addLease"; payload: LeaseInput }
  | { type: "addVerification"; payload: VerificationInput }
  | { type: "addApplication"; payload: ApplicationInput }
  | { type: "addViewing"; payload: ViewingInput }
  | { type: "addConversation"; payload: ConversationInput }
  | { type: "addLiveEvent"; payload: LiveEvent };

const RentalPlatformContext = createContext<RentalPlatformContextValue | null>(null);

function reducer(state: RentalPlatformState, action: RentalPlatformAction): RentalPlatformState {
  switch (action.type) {
    case "hydrate":
      return action.state;
    case "addProperty": {
      const id = makeId("prop");
      const nextProperty: Property = {
        ...action.payload,
        id,
        verified: action.payload.verified ?? false,
        photos: action.payload.photos?.filter(Boolean) ?? [],
        listingViews: action.payload.listingViews ?? 0,
        savedCount: action.payload.savedCount ?? 0,
        applicationsCount: action.payload.applicationsCount ?? 0,
      };

      return {
        ...state,
        properties: [nextProperty, ...state.properties],
        liveEvents: [
          {
            id: makeId("event"),
            title: "Property added",
            meta: `${nextProperty.title} · ${nextProperty.suburb}`,
            status: "Now",
            tone: "success",
          },
          ...state.liveEvents,
        ],
      };
    }
    case "updateProperty": {
      const current = state.properties.find((property) => property.id === action.propertyId);
      if (!current) return state;
      return {
        ...state,
        properties: state.properties.map((property) => property.id === action.propertyId ? { ...property, ...action.payload, photos: action.payload.photos?.filter(Boolean) ?? property.photos } : property),
        liveEvents: [
          {
            id: makeId("event"),
            title: "Property updated",
            meta: `${current.title} · ${current.suburb}`,
            status: "Now",
            tone: "info",
          },
          ...state.liveEvents,
        ],
      };
    }
    case "deleteProperty": {
      const deleted = state.properties.find((property) => property.id === action.propertyId);
      if (!deleted) return state;
      return {
        ...state,
        properties: state.properties.filter((property) => property.id !== action.propertyId),
        liveEvents: [
          {
            id: makeId("event"),
            title: "Property removed",
            meta: `${deleted.title} · ${deleted.suburb}`,
            status: "Now",
            tone: "warning",
          },
          ...state.liveEvents,
        ],
      };
    }
    case "addPayment":
      return {
        ...state,
        payments: [
          {
            ...action.payload,
            id: makeId("pay"),
            status: action.payload.status ?? "Received",
            time: action.payload.time ?? "Just now",
            receiptId: action.payload.receiptId ?? makeReceiptId(),
            reminderStatus: action.payload.reminderStatus ?? "Reminder scheduled",
          },
          ...state.payments,
        ],
        liveEvents: [
          {
            id: makeId("event"),
            title: "Rent payment recorded",
            meta: `${action.payload.amount} · ${action.payload.method}`,
            status: "Now",
            tone: "info",
          },
          ...state.liveEvents,
        ],
      };
    case "addMaintenance":
      return {
        ...state,
        maintenance: [
          {
            ...action.payload,
            id: makeId("mnt"),
            status: action.payload.status ?? "Open",
            updatedAt: action.payload.updatedAt ?? "Just now",
          },
          ...state.maintenance,
        ],
        liveEvents: [
          {
            id: makeId("event"),
            title: "Maintenance request opened",
            meta: `${action.payload.issue} · ${action.payload.category}`,
            status: "Now",
            tone: "warning",
          },
          ...state.liveEvents,
        ],
      };
    case "addLease":
      return {
        ...state,
        leases: [
          {
            ...action.payload,
            id: makeId("lease"),
            status: action.payload.status ?? "Draft",
            signedByTenant: action.payload.signedByTenant ?? false,
            signedByLandlord: action.payload.signedByLandlord ?? false,
            pdf: action.payload.pdf ?? "Residential Lease Agreement",
          },
          ...state.leases,
        ],
        liveEvents: [
          {
            id: makeId("event"),
            title: "Lease created",
            meta: `${action.payload.property} · ${action.payload.tenant}`,
            status: "Now",
            tone: "success",
          },
          ...state.liveEvents,
        ],
      };
    case "addVerification":
      return {
        ...state,
        verifications: [
          {
            ...action.payload,
            id: makeId("ver"),
            status: action.payload.status ?? "Reviewing",
            reviewedBy: action.payload.reviewedBy ?? "Admin",
          },
          ...state.verifications,
        ],
        liveEvents: [
          {
            id: makeId("event"),
            title: "Verification submitted",
            meta: `${action.payload.name} · ${action.payload.role}`,
            status: "Now",
            tone: "info",
          },
          ...state.liveEvents,
        ],
      };
    case "addApplication":
      return {
        ...state,
        applications: [
          {
            ...action.payload,
            id: makeId("app"),
            status: action.payload.status ?? "Under review",
            time: action.payload.time ?? "Now",
          },
          ...state.applications,
        ],
      };
    case "addViewing":
      return {
        ...state,
        viewings: [
          {
            ...action.payload,
            id: makeId("view"),
            status: action.payload.status ?? "Pending",
          },
          ...state.viewings,
        ],
      };
    case "addConversation":
      return {
        ...state,
        conversations: [
          {
            ...action.payload,
            id: makeId("chat"),
            time: action.payload.time ?? "Now",
            status: action.payload.status ?? "Active",
            participants: action.payload.participants ?? [],
            phoneNumbersRevealed: action.payload.phoneNumbersRevealed ?? false,
          },
          ...state.conversations,
        ],
      };
    case "addLiveEvent":
      return {
        ...state,
        liveEvents: [action.payload, ...state.liveEvents],
      };
    default:
      return state;
  }
}

type RentalPlatformContextValue = {
  state: RentalPlatformState;
  ready: boolean;
  authUser: AuthUser | null;
  authToken: string | null;
  authError: string;
  authLoading: boolean;
  account: AccountContext;
  chatWebSocketUrl: string;
  signIn: (payload: SignInPayload) => Promise<void>;
  registerAccount: (payload: RegisterAccountPayload) => Promise<void>;
  googleSignIn: (idToken: string, accountType?: PublicAccountRole, details?: { name?: string; phone?: string }) => Promise<void>;
  signOut: () => Promise<void>;
  submitVerification: (payload: VerificationSubmissionPayload) => Promise<void>;
  sendVerificationEmailOtp: (email: string) => Promise<VerificationEmailOtpChallenge>;
  verifyVerificationEmailOtp: (challengeId: string, otp: string) => Promise<{ emailVerified: boolean; email: string }>;
  sendVerificationPhoneOtp: (phone: string) => Promise<VerificationPhoneOtpChallenge>;
  verifyVerificationPhoneOtp: (challengeId: string, otp: string) => Promise<{ phoneVerified: boolean; phone: string }>;
  extractVerificationId: (payload: { idFrontFile: AccountMediaFile; idBackFile: AccountMediaFile }) => Promise<VerificationIdExtraction>;
  updateAccountProfile: (payload: AccountProfileUpdatePayload) => Promise<void>;
  createLandlordAgent: (payload: LandlordAgentInput) => Promise<AuthUser>;
  fetchLandlordAgents: () => Promise<AuthUser[]>;
  reviewVerification: (verificationId: string, status: "approved" | "rejected" | "reviewing") => Promise<void>;
  canAccessSection: (section: string) => boolean;
  hasCapability: (capability: string) => boolean;
  addProperty: (payload: PropertyInput) => Promise<Property | void>;
  updateProperty: (propertyId: string, payload: Partial<PropertyInput>) => Promise<Property | void>;
  deleteProperty: (propertyId: string) => Promise<void>;
  addPayment: (payload: PaymentInput) => void;
  addMaintenance: (payload: MaintenanceInput) => void;
  addLease: (payload: LeaseInput) => void;
  addApplication: (payload: ApplicationInput) => void;
  addViewing: (payload: ViewingInput) => void;
  addConversation: (payload: ConversationInput) => void;
  refreshConversations: () => Promise<void>;
  startPropertyConversation: (propertyId: string) => Promise<ConversationItem>;
  fetchConversationMessages: (conversationId: string) => Promise<ConversationMessage[]>;
  sendConversationMessage: (conversationId: string, body: string, attachment?: MessageAttachmentInput) => Promise<ConversationMessage>;
  startConversationCall: (conversationId: string, mode: "voice" | "video") => Promise<ConversationCallSession>;
  fetchConversationCalls: (conversationId: string) => Promise<ConversationCallSession[]>;
  fetchCallHistory: () => Promise<CallHistoryItem[]>;
  endConversationCall: (conversationId: string, callId: string, status?: "ended" | "missed") => Promise<ConversationCallSession>;
  fetchMediaAssets: (filters?: MediaAssetFilter) => Promise<MediaAsset[]>;
  deleteMediaAsset: (mediaId: string) => Promise<MediaAsset>;
  saveMediaAssetToDevice: (asset: MediaAsset) => Promise<string>;
  fetchPropertyComments: (propertyId: string) => Promise<PropertyCommentItem[]>;
  addPropertyComment: (propertyId: string, payload: PropertyCommentInput) => Promise<PropertyCommentItem>;
  toggleSupplierFollow: (supplierId: string, following: boolean) => Promise<void>;
  addLiveEvent: (payload: LiveEvent) => void;
};

export function RentalPlatformProvider({ children }: { children: ReactNode }) {
  const [state, dispatch] = useReducer(reducer, initialState);
  const [accountRole, setAccountRole] = useState<AccountRole>(defaultAccountRole);
  const [authUser, setAuthUser] = useState<AuthUser | null>(null);
  const [authToken, setAuthToken] = useState<string | null>(null);
  const [authError, setAuthError] = useState("");
  const [authLoading, setAuthLoading] = useState(false);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    let isMounted = true;

    hydrateRentalPlatformSession()
      .then((result) => {
        if (!isMounted) return;
        if (result?.state) dispatch({ type: "hydrate", state: result.state });
        setAuthToken(result?.authToken ?? null);
        setAuthUser(result?.authUser ?? null);
        setAccountRole(result?.authUser?.role ?? result?.accountRole ?? defaultAccountRole);
      })
      .finally(() => {
        if (isMounted) setReady(true);
      });

    return () => {
      isMounted = false;
    };
  }, []);

  useEffect(() => {
    if (!ready) return;
    AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(state)).catch(() => undefined);
  }, [ready, state]);

  useEffect(() => {
    if (!ready || !authToken || !authUser) return;
    registerDeviceForPush(authToken).catch(() => undefined);
  }, [ready, authToken, authUser?.id]);

  const value = useMemo<RentalPlatformContextValue>(
    () => {
      const baseAccount = accountContexts[accountRole];
      const isVerified = Boolean(authUser?.verified);
      const emailVerified = Boolean(authUser?.emailVerified);
      const phoneVerified = Boolean(authUser?.phoneVerified);
      const accountOnboardingComplete = Boolean(isVerified || authUser?.accountOnboardingComplete);
      const onboardingRequirements = authUser
        ? baseAccount.onboardingRequirements.filter((requirement) => {
            if (accountOnboardingComplete) return false;
            if (requirement === "email_verification") return !emailVerified;
            if (requirement === "phone_verification") return !phoneVerified;
            return true;
          })
        : baseAccount.onboardingRequirements;
      const account: AccountContext = {
        accountType: accountRole,
        ...baseAccount,
        onboardingRequirements,
        isVerified,
        emailVerified,
        phoneVerified,
        accountOnboardingComplete,
        fullVerificationRequired: Boolean(authUser && ["tenant", "landlord"].includes(accountRole) && accountOnboardingComplete && !isVerified),
        hiddenSections: allSections.filter((section) => !baseAccount.visibleSections.includes(section)),
      };

      return {
        state,
        ready,
        authUser,
        authToken,
        authError,
        authLoading,
        account,
        chatWebSocketUrl: buildChatWebSocketUrl(authToken),
        signIn: async (payload) => {
          setAuthLoading(true);
          setAuthError("");
          try {
            const response = await postAuth("auth/login/", { username: payload.username.trim(), password: payload.password });
            await applyAuthPayload(response, { dispatch, setAccountRole, setAuthUser, setAuthToken });
          } catch (error) {
            const message = error instanceof Error ? error.message : "Sign in failed";
            setAuthError(message);
            throw error;
          } finally {
            setAuthLoading(false);
          }
        },
        registerAccount: async (payload) => {
          setAuthLoading(true);
          setAuthError("");
          try {
            await AsyncStorage.multiRemove([API_TOKEN_STORAGE_KEY, ACCOUNT_ROLE_STORAGE_KEY]);
            setAuthToken(null);
            setAuthUser(null);
            const response = await postAuth("auth/register/", {
              account_type: payload.accountType,
              name: payload.name.trim(),
              email: payload.email.trim(),
              username: payload.email.trim(),
              password: payload.password,
            });
            if (!response.user) {
              throw new Error("Account creation failed");
            }
            await AsyncStorage.multiRemove([API_TOKEN_STORAGE_KEY, ACCOUNT_ROLE_STORAGE_KEY]);
            setAuthToken(null);
            setAuthUser(null);
            setAccountRole(defaultAccountRole);
          } catch (error) {
            const message = error instanceof Error ? error.message : "Account creation failed";
            setAuthError(message);
            throw error;
          } finally {
            setAuthLoading(false);
          }
        },
        googleSignIn: async (idToken, selectedAccountType, details) => {
          setAuthLoading(true);
          setAuthError("");
          try {
            const payload: Record<string, string> = { id_token: idToken };
            if (selectedAccountType) payload.account_type = selectedAccountType;
            if (details?.name?.trim()) payload.name = details.name.trim();
            if (details?.phone?.trim()) payload.phone = details.phone.trim();
            const response = await postAuth("auth/google/", payload);
            await applyAuthPayload(response, { dispatch, setAccountRole, setAuthUser, setAuthToken });
          } catch (error) {
            const message = error instanceof Error ? error.message : "Google sign-in failed";
            setAuthError(message);
            throw error;
          } finally {
            setAuthLoading(false);
          }
        },
        signOut: async () => {
          setAuthLoading(true);
          setAuthError("");
          try {
            await AsyncStorage.multiRemove([API_TOKEN_STORAGE_KEY, ACCOUNT_ROLE_STORAGE_KEY]);
            setAuthToken(null);
            setAuthUser(null);
            setAccountRole(defaultAccountRole);
            if (API_BASE_URL) {
              try {
                dispatch({ type: "hydrate", state: await fetchRentalPlatformState(API_BASE_URL, null) });
              } catch {
                dispatch({ type: "hydrate", state: initialState });
              }
            }
          } finally {
            setAuthLoading(false);
          }
        },
        submitVerification: async (payload) => {
          setAuthLoading(true);
          setAuthError("");
          try {
            const requestPayload = payload.selfieFile || payload.idFrontFile || payload.idBackFile || payload.livenessFile ? buildVerificationFormData(payload) : payload;
            await postProtected("verifications/", authToken, requestPayload);
            if (API_BASE_URL && authToken) {
              const me = await fetchJson(`${API_BASE_URL}/auth/me/`, authToken);
              const nextUser = mapAuthUser(me.user, me.account);
              setAuthUser(nextUser);
              setAccountRole(nextUser.role);
              await AsyncStorage.setItem(ACCOUNT_ROLE_STORAGE_KEY, nextUser.role);
            }
            refreshRentalPlatform(dispatch, authToken).catch(() => undefined);
          } catch (error) {
            const message = error instanceof Error ? error.message : "Verification submission failed";
            setAuthError(message);
            throw error;
          } finally {
            setAuthLoading(false);
          }
        },
        sendVerificationEmailOtp: async (email) => {
          setAuthLoading(true);
          setAuthError("");
          try {
            const response = await postProtected("verifications/email-otp/", authToken, { email: email.trim() });
            return {
              otpRequired: Boolean(response.otp_required),
              challengeId: String(response.challenge_id || ""),
              email: response.email || "",
              deliveryChannel: response.delivery_channel === "email" ? "email" : "provider_required",
              expiresInSeconds: Number(response.expires_in_seconds) || 30,
              message: response.message || "",
            };
          } catch (error) {
            const message = error instanceof Error ? error.message : "Email OTP could not be sent";
            setAuthError(message);
            throw error;
          } finally {
            setAuthLoading(false);
          }
        },
        verifyVerificationEmailOtp: async (challengeId, otp) => {
          setAuthLoading(true);
          setAuthError("");
          try {
            const response = await postProtected("verifications/email-otp/verify/", authToken, { challenge_id: challengeId, otp: otp.trim() });
            if (response.user) {
              const nextUser = mapAuthUser(response.user, response.account);
              setAuthUser(nextUser);
              setAccountRole(nextUser.role);
              await AsyncStorage.setItem(ACCOUNT_ROLE_STORAGE_KEY, nextUser.role);
            }
            return { emailVerified: Boolean(response.email_verified), email: response.email || "" };
          } catch (error) {
            const message = error instanceof Error ? error.message : "Email OTP verification failed";
            setAuthError(message);
            throw error;
          } finally {
            setAuthLoading(false);
          }
        },
        sendVerificationPhoneOtp: async (phone) => {
          setAuthLoading(true);
          setAuthError("");
          try {
            const response = await postProtected("verifications/phone-otp/", authToken, { phone: phone.trim() });
            return {
              otpRequired: Boolean(response.otp_required),
              challengeId: String(response.challenge_id || ""),
              phone: response.phone || phone.trim(),
              deliveryChannel: response.delivery_channel === "sms" ? "sms" : "provider_required",
              expiresInSeconds: Number(response.expires_in_seconds) || 30,
              message: response.message || "",
            };
          } catch (error) {
            const message = error instanceof Error ? error.message : "Phone OTP could not be sent";
            setAuthError(message);
            throw error;
          } finally {
            setAuthLoading(false);
          }
        },
        verifyVerificationPhoneOtp: async (challengeId, otp) => {
          setAuthLoading(true);
          setAuthError("");
          try {
            const response = await postProtected("verifications/phone-otp/verify/", authToken, { challenge_id: challengeId, otp: otp.trim() });
            if (response.user) {
              const nextUser = mapAuthUser(response.user, response.account);
              setAuthUser(nextUser);
              setAccountRole(nextUser.role);
              await AsyncStorage.setItem(ACCOUNT_ROLE_STORAGE_KEY, nextUser.role);
            }
            return { phoneVerified: Boolean(response.phone_verified), phone: response.phone || "" };
          } catch (error) {
            const message = error instanceof Error ? error.message : "Phone OTP verification failed";
            setAuthError(message);
            throw error;
          } finally {
            setAuthLoading(false);
          }
        },
        extractVerificationId: async (payload) => {
          setAuthLoading(true);
          setAuthError("");
          try {
            const formData = new FormData();
            formData.append("id_front_document", payload.idFrontFile as unknown as Blob);
            formData.append("id_back_document", payload.idBackFile as unknown as Blob);
            const response = await postProtected("verifications/id-extract/", authToken, formData);
            return {
              extractedNationalIdNumber: response.extracted_national_id_number || "",
              confidence: response.confidence || "manual_review_required",
              requiresConfirmation: Boolean(response.requires_confirmation),
            };
          } catch (error) {
            const message = error instanceof Error ? error.message : "ID extraction failed";
            setAuthError(message);
            throw error;
          } finally {
            setAuthLoading(false);
          }
        },
        updateAccountProfile: async (payload) => {
          setAuthLoading(true);
          setAuthError("");
          try {
            const hasMediaPayload = Boolean(payload.profilePictureFile || payload.coverPhotoFile || payload.removeProfilePicture || payload.removeCoverPhoto);
            const requestPayload = hasMediaPayload ? buildAccountProfileFormData(payload) : {
              name: payload.name,
              bio: payload.bio,
              profile_picture_url: payload.profilePicture,
              cover_photo_url: payload.coverPhoto,
            };
            const response = await protectedRequest("auth/profile/", authToken, "POST", requestPayload);
            const nextUser = mapAuthUser(response.user, response.account);
            setAuthUser(nextUser);
            setAccountRole(nextUser.role);
            await AsyncStorage.setItem(ACCOUNT_ROLE_STORAGE_KEY, nextUser.role);
            await refreshRentalPlatform(dispatch, authToken);
          } catch (error) {
            const message = error instanceof Error ? error.message : "Profile update failed";
            setAuthError(message);
            throw error;
          } finally {
            setAuthLoading(false);
          }
        },
        createLandlordAgent: async (payload) => {
          setAuthLoading(true);
          setAuthError("");
          try {
            const response = await postProtected("landlord/agents/", authToken, {
              name: payload.name.trim(),
              email: payload.email.trim(),
              username: payload.email.trim(),
              phone: payload.phone.trim(),
              password: payload.password?.trim() || undefined,
            });
            await refreshRentalPlatform(dispatch, authToken);
            return mapAuthUser(response.user);
          } catch (error) {
            const message = error instanceof Error ? error.message : "Agent account could not be created";
            setAuthError(message);
            throw error;
          } finally {
            setAuthLoading(false);
          }
        },
        fetchLandlordAgents: async () => {
          if (!API_BASE_URL || !authToken) return [];
          try {
            const response = await fetchJson(`${API_BASE_URL}/landlord/agents/`, authToken);
            return (response.results || []).map((item: any) => mapAuthUser(item));
          } catch (error) {
            const message = error instanceof Error ? error.message : "Agents could not be loaded";
            setAuthError(message);
            throw error;
          }
        },
        reviewVerification: async (verificationId, status) => {
          setAuthLoading(true);
          setAuthError("");
          try {
            await postProtected(`verifications/${verificationId}/review/`, authToken, { status });
            await refreshRentalPlatform(dispatch, authToken);
          } catch (error) {
            const message = error instanceof Error ? error.message : "Verification review failed";
            setAuthError(message);
            throw error;
          } finally {
            setAuthLoading(false);
          }
        },
        canAccessSection: (section) => account.visibleSections.includes(section),
        hasCapability: (capability) => account.capabilities.includes(capability),
        addProperty: async (payload) => {
          if (API_BASE_URL && authToken) {
            setAuthLoading(true);
            setAuthError("");
            try {
              const created = mapApiProperty(await postProtected("properties/", authToken, buildPropertyApiPayload(payload)));
              const photos = (payload.photoFiles || []).slice(0, 10);
              for (let index = 0; index < photos.length; index += 1) {
                await postProtected(`properties/${created.id}/photos/`, authToken, buildPropertyPhotoFormData(photos[index], index));
              }
              for (const video of payload.videoFiles || []) {
                await postProtected(`properties/${created.id}/videos/`, authToken, buildPropertyVideoFormData(video));
              }
              await refreshRentalPlatform(dispatch, authToken);
              return created;
            } catch (error) {
              const message = error instanceof Error ? error.message : "Property could not be saved";
              setAuthError(message);
              throw error;
            } finally {
              setAuthLoading(false);
            }
          }
          dispatch({ type: "addProperty", payload });
        },
        updateProperty: async (propertyId, payload) => {
          if (API_BASE_URL && authToken) {
            setAuthLoading(true);
            setAuthError("");
            try {
              const updated = mapApiProperty(await protectedRequest(`properties/${propertyId}/`, authToken, "PATCH", buildPropertyApiPayload(payload as PropertyInput)));
              await refreshRentalPlatform(dispatch, authToken);
              return updated;
            } catch (error) {
              const message = error instanceof Error ? error.message : "Property could not be updated";
              setAuthError(message);
              throw error;
            } finally {
              setAuthLoading(false);
            }
          }
          dispatch({ type: "updateProperty", propertyId, payload });
        },
        deleteProperty: async (propertyId) => {
          if (API_BASE_URL && authToken) {
            setAuthLoading(true);
            setAuthError("");
            try {
              await protectedRequest(`properties/${propertyId}/`, authToken, "DELETE");
              await refreshRentalPlatform(dispatch, authToken);
            } catch (error) {
              const message = error instanceof Error ? error.message : "Property could not be deleted";
              setAuthError(message);
              throw error;
            } finally {
              setAuthLoading(false);
            }
            return;
          }
          dispatch({ type: "deleteProperty", propertyId });
        },
        addPayment: (payload) => {
          if (API_BASE_URL && authToken && payload.propertyId) {
            void postProtected("payments/", authToken, {
              property_id: payload.propertyId,
              tenant_id: payload.tenantId || authUser?.id || "",
              amount: cleanMoney(payload.amount),
              method: payload.method,
              reminder_status: payload.reminderStatus,
            })
              .then(() => refreshRentalPlatform(dispatch, authToken))
              .catch((error) => setAuthError(error instanceof Error ? error.message : "Payment could not be recorded"));
            return;
          }
          dispatch({ type: "addPayment", payload });
        },
        addMaintenance: (payload) => {
          if (API_BASE_URL && authToken && payload.propertyId) {
            void postProtected("maintenance/", authToken, {
              property_id: payload.propertyId,
              issue: payload.issue,
              category: payload.category,
              description: payload.description,
              status: payload.status,
              priority: payload.priority,
            })
              .then(() => refreshRentalPlatform(dispatch, authToken))
              .catch((error) => setAuthError(error instanceof Error ? error.message : "Maintenance request could not be created"));
            return;
          }
          dispatch({ type: "addMaintenance", payload });
        },
        addLease: (payload) => {
          if (API_BASE_URL && authToken && payload.propertyId && payload.tenantId) {
            void postProtected("leases/", authToken, {
              property_id: payload.propertyId,
              tenant_id: payload.tenantId,
              start_date: payload.startDate,
              end_date: payload.endDate,
              monthly_rent: cleanMoney(payload.monthlyRent),
              deposit: cleanMoney(payload.deposit),
              term: payload.term,
            })
              .then(() => refreshRentalPlatform(dispatch, authToken))
              .catch((error) => setAuthError(error instanceof Error ? error.message : "Lease could not be created"));
            return;
          }
          dispatch({ type: "addLease", payload });
        },
        addApplication: (payload) => {
          if (API_BASE_URL && authToken && payload.propertyId) {
            void postProtected("applications/", authToken, {
              property_id: payload.propertyId,
              message: payload.role || "Tenant application",
            })
              .then(() => refreshRentalPlatform(dispatch, authToken))
              .catch((error) => setAuthError(error instanceof Error ? error.message : "Application could not be submitted"));
            return;
          }
          dispatch({ type: "addApplication", payload });
        },
        addViewing: (payload) => {
          if (API_BASE_URL && authToken && payload.propertyId) {
            void postProtected("viewings/", authToken, {
              property_id: payload.propertyId,
              scheduled_for: buildScheduledFor(payload.date, payload.time),
              status: "pending",
              notes: "Tenant requested a physical viewing before application or payment.",
            })
              .then(() => refreshRentalPlatform(dispatch, authToken))
              .catch((error) => setAuthError(error instanceof Error ? error.message : "Viewing could not be requested"));
            return;
          }
          dispatch({ type: "addViewing", payload });
        },
        addConversation: (payload) => dispatch({ type: "addConversation", payload }),
        refreshConversations: async () => {
          await refreshRentalPlatform(dispatch, authToken);
        },
        startPropertyConversation: async (propertyId) => {
          const conversation = mapApiConversation(await postProtected("conversations/", authToken, { property_id: propertyId }));
          await refreshRentalPlatform(dispatch, authToken);
          return conversation;
        },
        fetchConversationMessages: async (conversationId) => {
          if (!API_BASE_URL) throw new Error("Set EXPO_PUBLIC_API_URL to the account API before using chat");
          if (!authToken) throw new Error("Sign in is required to load chat messages");
          const response = await fetchJson(`${API_BASE_URL}/conversations/${conversationId}/messages/`, authToken);
          return response.results.map(mapApiConversationMessage);
        },
        sendConversationMessage: async (conversationId, body, attachment) => {
          const clientMessageId = `msg-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
          const payload = attachment ? buildMessageFormData(body, attachment, clientMessageId) : { body, client_message_id: clientMessageId };
          const message = mapApiConversationMessage(await postProtected(`conversations/${conversationId}/messages/`, authToken, payload));
          await refreshRentalPlatform(dispatch, authToken);
          return message;
        },
        startConversationCall: async (conversationId, mode) => {
          const call = mapApiConversationCall(await postProtected(`conversations/${conversationId}/calls/`, authToken, { mode }));
          await refreshRentalPlatform(dispatch, authToken);
          return call;
        },
        fetchConversationCalls: async (conversationId) => {
          if (!API_BASE_URL) throw new Error("Set EXPO_PUBLIC_API_URL to the account API before using calls");
          if (!authToken) throw new Error("Sign in is required to load calls");
          const response = await fetchJson(`${API_BASE_URL}/conversations/${conversationId}/calls/`, authToken);
          return response.results.map(mapApiConversationCall);
        },
        fetchCallHistory: async () => {
          if (!API_BASE_URL) throw new Error("Set EXPO_PUBLIC_API_URL to the account API before using call history");
          if (!authToken) throw new Error("Sign in is required to load call history");
          const response = await fetchJson(`${API_BASE_URL}/calls/`, authToken);
          return response.results.map(mapApiCallHistoryItem);
        },
        endConversationCall: async (conversationId, callId, status = "ended") => {
          const call = mapApiConversationCall(await protectedRequest(`conversations/${conversationId}/calls/${callId}/`, authToken, "PATCH", { status }));
          await refreshRentalPlatform(dispatch, authToken);
          return call;
        },
        fetchMediaAssets: async (filters = {}) => {
          if (!API_BASE_URL) throw new Error("Set EXPO_PUBLIC_API_URL to the account API before using media");
          if (!authToken) throw new Error("Sign in is required to load media");
          const query = new URLSearchParams();
          Object.entries(filters).forEach(([key, value]) => {
            if (value) query.set(snakeCase(key), String(value));
          });
          const suffix = query.toString() ? `?${query.toString()}` : "";
          const response = await fetchJson(`${API_BASE_URL}/media/${suffix}`, authToken);
          return response.results.map(mapApiMediaAsset);
        },
        deleteMediaAsset: async (mediaId) => {
          if (!mediaId) throw new Error("Media item is required");
          return mapApiMediaAsset(await protectedRequest(`media/${mediaId}/`, authToken, "DELETE"));
        },
        saveMediaAssetToDevice: async (asset) => {
          return saveMediaToDevice(asset);
        },
        fetchPropertyComments: async (propertyId) => {
          if (!API_BASE_URL) throw new Error("Set EXPO_PUBLIC_API_URL to the account API before using comments");
          if (!authToken) throw new Error("Sign in is required to view comments");
          const response = await fetchJson(`${API_BASE_URL}/properties/${propertyId}/comments/`, authToken);
          return response.results.map(mapApiPropertyComment);
        },
        addPropertyComment: async (propertyId, payload) => {
          return mapApiPropertyComment(await postProtected(`properties/${propertyId}/comments/`, authToken, {
            body: payload.body,
            media_url: payload.mediaUri || "",
            parent_id: payload.parentId || "",
          }));
        },
        toggleSupplierFollow: async (supplierId, following) => {
          if (!supplierId) throw new Error("Verified supplier account is required");
          await protectedRequest(`users/${supplierId}/follow/`, authToken, following ? "POST" : "DELETE");
        },
        addLiveEvent: (payload) => dispatch({ type: "addLiveEvent", payload }),
      };
    },
    [accountRole, authError, authLoading, authToken, authUser, ready, state]
  );

  return <RentalPlatformContext.Provider value={value}>{children}</RentalPlatformContext.Provider>;
}

export function useRentalPlatform() {
  const context = useContext(RentalPlatformContext);
  if (!context) {
    throw new Error("useRentalPlatform must be used inside RentalPlatformProvider");
  }

  return context;
}

export function useRentalPlatformStats() {
  const { state } = useRentalPlatform();

  return useMemo(
    () => ({
      verifiedProperties: state.properties.filter((item) => item.verified).length,
      listings: state.properties.length,
      receivedPayments: state.payments.filter((item) => item.status === "Received").length,
      maintenanceOpen: state.maintenance.filter((item) => item.status !== "Resolved").length,
      occupiedRate: state.leases.length ? Math.round((state.leases.filter((item) => item.status === "Active").length / state.leases.length) * 100) : 0,
      applications: state.applications.length,
      verifications: state.verifications.length,
      viewings: state.viewings.length,
    }),
    [state]
  );
}

function cleanMoney(value: string) {
  return value.replace(/[^0-9.]/g, "") || "0";
}

function buildScheduledFor(date: string, time: string) {
  const fallback = new Date(Date.now() + 24 * 60 * 60 * 1000);
  const value = `${date || fallback.toISOString().slice(0, 10)}T${time || "10:00"}:00`;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? fallback.toISOString() : parsed.toISOString();
}

function makeId(prefix: string) {
  return `${prefix}-${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
}

function makeReceiptId() {
  return `RCT-${new Date().getFullYear()}-${Math.random().toString(10).slice(2, 6)}`;
}

async function hydrateRentalPlatformSession(): Promise<{ state: RentalPlatformState | null; accountRole?: AccountRole; authUser?: AuthUser | null; authToken?: string | null } | null> {
  const savedRole = await readSavedRole();
  if (API_BASE_URL) {
    try {
      const token = await AsyncStorage.getItem(API_TOKEN_STORAGE_KEY);
      if (!token) {
        return { state: await fetchRentalPlatformState(API_BASE_URL, null), accountRole: defaultAccountRole, authToken: null, authUser: null };
      }

      const me = await fetchJson(`${API_BASE_URL}/auth/me/`, token);
      const authUser = mapAuthUser(me.user, me.account);
      await AsyncStorage.setItem(ACCOUNT_ROLE_STORAGE_KEY, authUser.role);
      return { state: await fetchRentalPlatformState(API_BASE_URL, token), accountRole: authUser.role, authToken: token, authUser };
    } catch {
      await AsyncStorage.multiRemove([API_TOKEN_STORAGE_KEY, ACCOUNT_ROLE_STORAGE_KEY]);
      return { state: createEmptyRentalPlatformState(), accountRole: defaultAccountRole, authToken: null, authUser: null };
    }
  }

  return { state: createEmptyRentalPlatformState(), accountRole: savedRole ?? defaultAccountRole, authToken: null, authUser: null };
}

async function fetchRentalPlatformState(baseUrl: string, token: string | null): Promise<RentalPlatformState> {
  const properties = await fetchJson(`${baseUrl}/properties/`, token);

  if (!token) {
    return {
      ...createEmptyRentalPlatformState(),
      properties: properties.results.map(mapApiProperty),
    };
  }

  const [payments, maintenance, leases, verifications, applications, viewings, conversations] = await Promise.all([
    fetchJson(`${baseUrl}/payments/`, token),
    fetchJson(`${baseUrl}/maintenance/`, token),
    fetchJson(`${baseUrl}/leases/`, token),
    fetchJson(`${baseUrl}/verifications/`, token),
    fetchJson(`${baseUrl}/applications/`, token),
    fetchJson(`${baseUrl}/viewings/`, token),
    fetchJson(`${baseUrl}/conversations/`, token),
  ]);

  return {
    ...createEmptyRentalPlatformState(),
    properties: properties.results.map(mapApiProperty),
    payments: payments.results.map(mapApiPayment),
    maintenance: maintenance.results.map(mapApiMaintenance),
    leases: leases.results.map(mapApiLease),
    verifications: verifications.results.map(mapApiVerification),
    applications: applications.results.map(mapApiApplication),
    viewings: viewings.results.map(mapApiViewing),
    conversations: conversations.results.map(mapApiConversation),
  };
}

async function fetchJson(url: string, token?: string | null) {
  const response = await fetch(url, token ? { headers: { Authorization: `Bearer ${token}` } } : undefined);
  if (!response.ok) throw new Error(`API request failed: ${response.status}`);
  return response.json();
}

async function postAuth(endpoint: string, payload: Record<string, unknown>) {
  if (!API_BASE_URL) {
    throw new Error("Set EXPO_PUBLIC_API_URL to the account API before signing in");
  }

  const response = await fetch(`${API_BASE_URL}/${endpoint}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  const body = await readApiResponseBody(response);
  if (!response.ok) throw new Error(formatApiError(body, "Authentication request failed", response));
  return body;
}

async function postProtected(endpoint: string, token: string | null, payload: Record<string, unknown> | FormData) {
  return protectedRequest(endpoint, token, "POST", payload);
}

function buildVerificationFormData(payload: VerificationSubmissionPayload) {
  const formData = new FormData();
  formData.append("role", payload.role);
  if (payload.name) formData.append("name", payload.name);
  if (payload.phone) formData.append("phone", payload.phone);
  if (payload.country_of_residence) formData.append("country_of_residence", payload.country_of_residence);
  if (payload.privacy_notice_accepted !== undefined) formData.append("privacy_notice_accepted", String(payload.privacy_notice_accepted));
  if (payload.document_issue_country) formData.append("document_issue_country", payload.document_issue_country);
  if (payload.document_type) formData.append("document_type", payload.document_type);
  if (payload.residential_address) formData.append("residential_address", payload.residential_address);
  if (payload.address_gps_confirmed !== undefined) formData.append("address_gps_confirmed", String(payload.address_gps_confirmed));
  if (payload.proof_of_address_confirmed !== undefined) formData.append("proof_of_address_confirmed", String(payload.proof_of_address_confirmed));
  if (payload.politically_exposed_person !== undefined) formData.append("politically_exposed_person", String(payload.politically_exposed_person));
  if (payload.declaration_accepted !== undefined) formData.append("declaration_accepted", String(payload.declaration_accepted));
  formData.append("national_id_number", payload.national_id_number);
  if (payload.phone_verified !== undefined) formData.append("phone_verified", String(payload.phone_verified));
  if (payload.email_verified !== undefined) formData.append("email_verified", String(payload.email_verified));
  formData.append("selfie_uploaded", String(payload.selfie_uploaded));
  if (payload.identity_confirmed !== undefined) formData.append("identity_confirmed", String(payload.identity_confirmed));
  if (payload.extracted_national_id_number) formData.append("extracted_national_id_number", payload.extracted_national_id_number);
  if (payload.estate_agency_registration) formData.append("estate_agency_registration", payload.estate_agency_registration);
  if (payload.agency_name) formData.append("agency_name", payload.agency_name);
  if (payload.contact_details) formData.append("contact_details", payload.contact_details);
  if (payload.idFrontFile) formData.append("id_front_document", payload.idFrontFile as unknown as Blob);
  if (payload.idBackFile) formData.append("id_back_document", payload.idBackFile as unknown as Blob);
  if (payload.livenessFile) formData.append("liveness_document", payload.livenessFile as unknown as Blob);
  if (payload.selfieFile) formData.append("selfie_document", payload.selfieFile as unknown as Blob);
  if (payload.proofOfAddressFile) formData.append("proof_of_address_document", payload.proofOfAddressFile as unknown as Blob);
  if (payload.ownershipOrAuthorizationFile) formData.append("ownership_or_authorization_document", payload.ownershipOrAuthorizationFile as unknown as Blob);
  return formData;
}

function buildAccountProfileFormData(payload: AccountProfileUpdatePayload) {
  const formData = new FormData();
  if (payload.name !== undefined) formData.append("name", payload.name);
  if (payload.bio !== undefined) formData.append("bio", payload.bio);
  if (payload.profilePicture !== undefined) formData.append("profile_picture_url", payload.profilePicture);
  if (payload.coverPhoto !== undefined) formData.append("cover_photo_url", payload.coverPhoto);
  if (payload.removeProfilePicture) formData.append("remove_profile_picture", "true");
  if (payload.removeCoverPhoto) formData.append("remove_cover_photo", "true");
  if (payload.profilePictureFile) formData.append("profile_picture", payload.profilePictureFile as unknown as Blob);
  if (payload.coverPhotoFile) formData.append("cover_photo", payload.coverPhotoFile as unknown as Blob);
  return formData;
}

function buildMessageFormData(body: string, attachment: MessageAttachmentInput, clientMessageId?: string) {
  const formData = new FormData();
  formData.append("body", body);
  if (clientMessageId) formData.append("client_message_id", clientMessageId);
  formData.append("attachment_type", attachment.type);
  if (attachment.name) formData.append("attachment_name", attachment.name);
  if (attachment.url) formData.append("attachment_url", attachment.url);
  if (attachment.file) formData.append("attachment", attachment.file as unknown as Blob);
  return formData;
}

function buildPropertyApiPayload(payload: PropertyInput) {
  const [latitude, longitude] = parseGpsCoordinates(payload.gps);
  return {
    title: payload.title,
    address: payload.address,
    city: payload.city,
    suburb: payload.suburb,
    monthly_rent: cleanMoney(payload.price),
    deposit_required: cleanMoney(payload.deposit),
    property_type: payload.type,
    bedrooms: payload.bedrooms,
    bathrooms: payload.bathrooms,
    furnished: payload.furnished.toLowerCase().includes("furnished") && !payload.furnished.toLowerCase().includes("unfurnished"),
    parking: payload.parking,
    solar_power: payload.solarPower,
    water_availability: payload.water,
    borehole: payload.borehole,
    pet_friendly: payload.petFriendly,
    has_360_tour: payload.tourAvailable,
    description: payload.description,
    agent_id: payload.agentId || undefined,
    latitude,
    longitude,
  };
}

function buildPropertyPhotoFormData(file: AccountMediaFile, sortOrder: number) {
  const formData = new FormData();
  formData.append("image", file as unknown as Blob);
  formData.append("caption", file.name || "Property photo");
  formData.append("sort_order", String(sortOrder));
  return formData;
}

function buildPropertyVideoFormData(file: AccountMediaFile) {
  const formData = new FormData();
  formData.append("video", file as unknown as Blob);
  formData.append("caption", file.name || "Property video");
  return formData;
}

function parseGpsCoordinates(value: string): [string | undefined, string | undefined] {
  const [latitude, longitude] = String(value || "").split(",").map((part) => part.trim());
  if (!latitude || !longitude) return [undefined, undefined];
  if (Number.isNaN(Number(latitude)) || Number.isNaN(Number(longitude))) return [undefined, undefined];
  return [latitude, longitude];
}

async function protectedRequest(endpoint: string, token: string | null, method: "POST" | "PATCH" | "DELETE", payload?: Record<string, unknown> | FormData): Promise<any> {
  if (!API_BASE_URL) {
    throw new Error("Set EXPO_PUBLIC_API_URL to the account API before using protected actions");
  }
  if (!token) {
    throw new Error("Sign in is required for this action");
  }

  const isMultipart = typeof FormData !== "undefined" && payload instanceof FormData;
  const headers: Record<string, string> = { Authorization: `Bearer ${token}` };
  const requestBody = isMultipart ? payload : payload ? JSON.stringify(payload) : undefined;
  if (!isMultipart) headers["Content-Type"] = "application/json";

  const response = await fetch(`${API_BASE_URL}/${endpoint}`, {
    method,
    headers,
    body: requestBody,
  });
  const responseBody = await readApiResponseBody(response);
  if (!response.ok) throw new Error(formatApiError(responseBody, "Protected request failed", response));
  return responseBody;
}

async function readApiResponseBody(response: Response) {
  const text = await response.text().catch(() => "");
  if (!text) return {};
  try {
    return JSON.parse(text);
  } catch {
    return { raw: text.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim().slice(0, 220) };
  }
}

function formatApiError(responseBody: any, fallback: string, response?: Response) {
  const errors = responseBody?.errors;
  if (Array.isArray(errors)) return errors.join("\n");
  if (errors && typeof errors === "object") {
    const values = Object.values(errors).flat().filter(Boolean).map(String);
    if (values.length) return values.join("\n");
  }
  if (responseBody?.error) return responseBody.error;
  if (responseBody?.raw) return `${fallback}: ${response?.status || ""} ${response?.statusText || ""}. ${responseBody.raw}`.trim();
  if (response) return `${fallback}: ${response.status} ${response.statusText}`.trim();
  return fallback;
}

async function refreshRentalPlatform(dispatch: Dispatch<RentalPlatformAction>, token: string | null) {
  if (!API_BASE_URL || !token) return;
  dispatch({ type: "hydrate", state: await fetchRentalPlatformState(API_BASE_URL, token) });
}

async function applyAuthPayload(
  payload: any,
  setters: {
    dispatch: Dispatch<RentalPlatformAction>;
    setAccountRole: (role: AccountRole) => void;
    setAuthUser: (user: AuthUser | null) => void;
    setAuthToken: (token: string | null) => void;
  }
) {
  const token = payload.tokens?.access;
  if (!token) throw new Error("The account service did not return an access token");

  const user = mapAuthUser(payload.user, payload.account);
  await AsyncStorage.multiSet([
    [API_TOKEN_STORAGE_KEY, token],
    [ACCOUNT_ROLE_STORAGE_KEY, user.role],
  ]);

  setters.setAuthToken(token);
  setters.setAuthUser(user);
  setters.setAccountRole(user.role);

  if (API_BASE_URL) {
    fetchRentalPlatformState(API_BASE_URL, token)
      .then((state) => setters.dispatch({ type: "hydrate", state }))
      .catch(() => undefined);
  }
}

async function readSavedRole(): Promise<AccountRole | undefined> {
  const value = await AsyncStorage.getItem(ACCOUNT_ROLE_STORAGE_KEY);
  return value === "tenant" || value === "landlord" || value === "agent" || value === "admin" ? value : undefined;
}

function mapAuthUser(user: any, account?: any): AuthUser {
  const role = toAccountRole(account?.account_type || user?.account_type || user?.role);
  return {
    id: String(user?.id ?? ""),
    name: user?.name || user?.email || user?.phone || "Property24 user",
    email: user?.email || "",
    phone: user?.phone || "",
    role,
    verified: Boolean(user?.verified ?? account?.is_verified),
    emailVerified: Boolean(user?.email_verified ?? account?.email_verified),
    phoneVerified: Boolean(user?.phone_verified ?? account?.phone_verified),
    accountOnboardingComplete: Boolean(user?.account_onboarding_complete ?? account?.account_onboarding_complete),
    profileStatus: user?.profile_status || (user?.verified || account?.is_verified ? "verified" : user?.account_onboarding_complete || account?.account_onboarding_complete ? "account_ready" : "onboarding_required"),
    authProvider: user?.auth_provider || "password",
    googleEmailVerified: Boolean(user?.google_email_verified),
    profilePicture: resolveMediaUrl(user?.profile_picture),
    coverPhoto: resolveMediaUrl(user?.cover_photo),
    bio: user?.bio || "",
    lastSeenAt: user?.last_seen_at || undefined,
  };
}

function toAccountRole(value: string): AccountRole {
  if (value === "landlord" || value === "agent" || value === "admin") return value;
  return "tenant";
}

function mapApiProperty(item: any): Property {
  const supplier = item.agent || item.owner;
  const supplierRole = supplier?.role ? toAccountRole(supplier.role) : undefined;
  return {
    id: String(item.id),
    ownerId: item.owner?.id ? String(item.owner.id) : undefined,
    ownerName: item.owner?.name,
    ownerRole: item.owner?.role ? toAccountRole(item.owner.role) : undefined,
    ownerVerified: Boolean(item.owner?.verified),
    ownerProfilePicture: resolveMediaUrl(item.owner?.profile_picture),
    ownerCoverPhoto: resolveMediaUrl(item.owner?.cover_photo),
    ownerBio: item.owner?.bio || "",
    ownerLastSeenAt: item.owner?.last_seen_at || undefined,
    agentId: item.agent?.id ? String(item.agent.id) : undefined,
    agentName: item.agent?.name,
    agentVerified: item.agent ? Boolean(item.agent.verified) : undefined,
    agentProfilePicture: resolveMediaUrl(item.agent?.profile_picture),
    agentCoverPhoto: resolveMediaUrl(item.agent?.cover_photo),
    agentBio: item.agent?.bio || "",
    agentLastSeenAt: item.agent?.last_seen_at || undefined,
    supplierId: supplier?.id ? String(supplier.id) : undefined,
    supplierName: supplier?.name,
    supplierRole,
    supplierVerified: Boolean(supplier?.verified),
    supplierProfilePicture: resolveMediaUrl(supplier?.profile_picture),
    supplierCoverPhoto: resolveMediaUrl(supplier?.cover_photo),
    supplierBio: supplier?.bio || "",
    supplierLastSeenAt: supplier?.last_seen_at || undefined,
    title: item.title,
    address: item.address,
    city: item.city,
    suburb: item.suburb,
    price: `$${item.monthly_rent} / month`,
    deposit: `$${item.deposit_required}`,
    type: titleize(item.property_type),
    bedrooms: Number(item.bedrooms) || 0,
    bathrooms: Number(item.bathrooms) || 0,
    furnished: item.furnished ? "Furnished" : "Unfurnished",
    parking: item.parking || "Parking available",
    power: item.solar_power ? "Grid + solar backup" : "Grid",
    solarPower: Boolean(item.solar_power),
    water: item.water_availability || "Available",
    borehole: Boolean(item.borehole),
    gps: item.gps || "Unknown",
    videoCount: item.videos?.length ?? 0,
    tourAvailable: Boolean(item.has_360_tour),
    petFriendly: Boolean(item.pet_friendly),
    verified: Boolean(item.verified),
    description: item.description,
    photos: item.photos?.length ? item.photos.map(resolveMediaUrl).filter(Boolean) : [],
    listingViews: Number(item.listing_views) || 0,
    savedCount: Number(item.saved_count) || 0,
    applicationsCount: Number(item.applications_count) || 0,
    commentsCount: Number(item.comments_count) || 0,
  };
}

function mapApiPropertyComment(item: any): PropertyCommentItem {
  const author = item.author || {};
  const createdAt = String(item.created_at || "");
  return {
    id: String(item.id),
    propertyId: String(item.property_id || ""),
    authorId: String(item.author_id || author.id || ""),
    author: author.name || "Property24 user",
    authorRole: toAccountRole(author.role),
    authorVerified: Boolean(author.verified),
    body: String(item.body || ""),
    mediaUri: String(item.media_url || ""),
    likes: Number(item.likes_count) || 0,
    createdAt,
    time: formatCommentTime(createdAt),
  };
}

function formatCommentTime(value: string) {
  if (!value) return "Now";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "Now";
  return date.toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

function mapApiPayment(item: any): PaymentItem {
  return {
    id: String(item.id),
    tenantId: item.tenant_id ? String(item.tenant_id) : undefined,
    propertyId: item.property_id ? String(item.property_id) : undefined,
    tenant: item.tenant,
    property: item.property,
    amount: `$${item.amount}`,
    method: titleize(item.method),
    status: titleize(item.status),
    time: item.paid_at ? new Date(item.paid_at).toLocaleDateString() : "Recorded",
    receiptId: item.receipt_number,
    reminderStatus: item.reminder_status,
  };
}

function mapApiMaintenance(item: any): MaintenanceItem {
  return {
    id: String(item.id),
    propertyId: item.property_id ? String(item.property_id) : undefined,
    tenantId: item.tenant_id ? String(item.tenant_id) : undefined,
    issue: item.issue,
    category: titleize(item.category),
    property: item.property,
    tenant: item.tenant,
    description: item.description,
    photoCount: item.photo ? 1 : 0,
    status: titleize(item.status),
    priority: titleize(item.priority),
    updatedAt: item.updated_at ? new Date(item.updated_at).toLocaleDateString() : "Updated",
  };
}

function mapApiLease(item: any): LeaseItem {
  return {
    id: String(item.id),
    propertyId: item.property_id ? String(item.property_id) : undefined,
    tenantId: item.tenant_id ? String(item.tenant_id) : undefined,
    property: item.property,
    tenant: item.tenant,
    landlord: item.landlord,
    startDate: item.start_date,
    endDate: item.end_date,
    monthlyRent: `$${item.monthly_rent}`,
    deposit: `$${item.deposit}`,
    term: item.term,
    pdf: item.pdf || "Residential Lease Agreement",
    status: titleize(item.status),
    signedByTenant: Boolean(item.signed_by_tenant),
    signedByLandlord: Boolean(item.signed_by_landlord),
  };
}

function mapApiVerification(item: any): VerificationItem {
  return {
    id: String(item.id),
    name: item.name,
    role: titleize(item.role),
    checks: item.checks ?? [],
    status: titleize(item.status),
    reviewedBy: item.reviewed_by || "Admin",
  };
}

function mapApiApplication(item: any): ApplicationItem {
  return {
    id: String(item.id),
    propertyId: item.property_id ? String(item.property_id) : undefined,
    tenantId: item.tenant_id ? String(item.tenant_id) : undefined,
    applicant: item.tenant,
    property: item.property,
    role: "Tenant",
    status: titleize(item.status),
    score: Number(item.score) || 0,
    time: item.created_at ? new Date(item.created_at).toLocaleDateString() : "Submitted",
  };
}

function mapApiViewing(item: any): ViewingItem {
  const scheduledFor = item.scheduled_for ? new Date(item.scheduled_for) : null;
  return {
    id: String(item.id),
    propertyId: item.property_id ? String(item.property_id) : undefined,
    tenantId: item.tenant_id ? String(item.tenant_id) : undefined,
    property: item.property,
    agent: item.agent || "Unassigned",
    tenant: item.tenant,
    date: scheduledFor ? scheduledFor.toLocaleDateString() : "",
    time: scheduledFor ? scheduledFor.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }) : "",
    status: titleize(item.status),
  };
}

function mapApiConversation(item: any): ConversationItem {
  const participants = (item.participants ?? []).map(mapApiConversationParticipant);
  return {
    id: String(item.id),
    propertyId: item.property_id ? String(item.property_id) : undefined,
    name: item.title || participants.map((participant: ConversationParticipant) => participant.name).join(" and ") || "Conversation",
    time: item.updated_at ? new Date(item.updated_at).toLocaleDateString() : "Updated",
    preview: item.last_message?.body || "Phone numbers remain hidden.",
    status: item.phone_numbers_revealed ? "Contact shared" : "Active",
    updatedAt: item.updated_at || "",
    lastMessageSenderId: item.last_message?.sender_id ? String(item.last_message.sender_id) : undefined,
    participants,
    phoneNumbersRevealed: Boolean(item.phone_numbers_revealed),
  };
}

function mapApiConversationParticipant(item: any): ConversationParticipant {
  return {
    id: String(item.id),
    name: item.name || "Property24 user",
    role: toAccountRole(item.role || item.account_type),
    verified: Boolean(item.verified),
    profilePicture: resolveMediaUrl(item.profile_picture),
    coverPhoto: resolveMediaUrl(item.cover_photo),
    bio: item.bio || "",
    lastSeenAt: item.last_seen_at || undefined,
  };
}

function mapApiConversationMessage(item: any): ConversationMessage {
  return {
    id: String(item.id),
    conversationId: String(item.conversation_id),
    senderId: String(item.sender_id),
    sender: item.sender || "Property24 user",
    body: item.body || "",
    clientMessageId: item.client_message_id || undefined,
    attachmentUrl: resolveMediaUrl(item.attachment_url),
    attachmentType: item.attachment_type || undefined,
    attachmentName: item.attachment_name || undefined,
    createdAt: item.created_at,
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

function mapApiMediaAsset(item: any): MediaAsset {
  return {
    id: String(item.id),
    scope: item.scope || "",
    mediaType: item.media_type || "other",
    access: item.access || "private",
    status: item.status || "active",
    processingStatus: item.processing_status || "pending",
    originalName: item.original_name || "",
    mimeType: item.mime_type || "",
    sizeBytes: Number(item.size_bytes || 0),
    width: item.width || undefined,
    height: item.height || undefined,
    durationSeconds: item.duration_seconds || undefined,
    sourceModel: item.source_model || "",
    sourceId: String(item.source_id || ""),
    url: resolveMediaUrl(item.url),
    thumbnailUrl: resolveMediaUrl(item.thumbnail_url),
    createdAt: item.created_at,
    updatedAt: item.updated_at,
  };
}

function mapApiConversationCall(item: any): ConversationCallSession {
  return {
    id: String(item.id),
    conversationId: String(item.conversation_id),
    initiatorId: String(item.initiator_id),
    mode: item.mode === "video" ? "video" : "voice",
    status: titleize(item.status),
    createdAt: item.created_at,
    endedAt: item.ended_at || undefined,
  };
}

function mapApiCallHistoryItem(item: any): CallHistoryItem {
  return {
    ...mapApiConversationCall(item),
    contactId: item.contact_id ? String(item.contact_id) : undefined,
    contactName: item.contact_name || "Unknown contact",
    propertyTitle: item.property_title || "Property conversation",
    conversationTitle: item.conversation_title || "Call",
  };
}

function buildChatWebSocketUrl(token: string | null) {
  if (!API_BASE_URL || !token) return "";
  try {
    const url = new URL(API_BASE_URL);
    url.protocol = url.protocol === "https:" ? "wss:" : "ws:";
    url.pathname = url.pathname.replace(/\/?api\/?$/, "/ws/conversations/");
    if (!url.pathname.endsWith("/ws/conversations/")) {
      url.pathname = "/ws/conversations/";
    }
    url.search = `token=${encodeURIComponent(token)}`;
    return url.toString();
  } catch {
    return "";
  }
}

function resolveApiBaseUrl() {
  const explicitUrl = process.env.EXPO_PUBLIC_API_URL?.trim();
  if (explicitUrl) return normalizeApiUrlForDevice(trimTrailingSlash(explicitUrl));

  if (Platform.OS === "web") {
    return `http://127.0.0.1:${DEFAULT_API_PORT}/api`;
  }

  const hostUri = Constants.expoConfig?.hostUri || Constants.manifest2?.extra?.expoGo?.debuggerHost;
  const host = hostUri?.split(":")[0];
  if (host) {
    return `http://${host}:${DEFAULT_API_PORT}/api`;
  }

  if (Platform.OS === "android") {
    return `http://10.0.2.2:${DEFAULT_API_PORT}/api`;
  }

  return `http://127.0.0.1:${DEFAULT_API_PORT}/api`;
}

function normalizeApiUrlForDevice(value: string) {
  if (Platform.OS === "web") return value;

  try {
    const url = new URL(value);
    if (!["127.0.0.1", "localhost", "0.0.0.0"].includes(url.hostname)) {
      return value;
    }

    const hostUri = Constants.expoConfig?.hostUri || Constants.manifest2?.extra?.expoGo?.debuggerHost;
    const host = hostUri?.split(":")[0];
    if (!host) return value;

    url.hostname = host;
    return url.toString().replace(/\/+$/, "");
  } catch {
    return value;
  }
}

async function registerDeviceForPush(authToken: string) {
  if (Platform.OS === "web" || Constants.appOwnership === "expo") return;
  const Notifications = getNotificationsModule();
  if (!Notifications) return;
  if (Platform.OS === "android") {
    await Notifications.setNotificationChannelAsync("messages", {
      name: "Messages and calls",
      importance: Notifications.AndroidImportance.MAX,
      vibrationPattern: [0, 250, 250, 250],
      lightColor: "#E50914",
    });
  }

  const existing = await Notifications.getPermissionsAsync();
  const permission = existing.granted ? existing : await Notifications.requestPermissionsAsync();
  if (!permission.granted) return;

  const projectId = (Constants as any).expoConfig?.extra?.eas?.projectId || (Constants as any).easConfig?.projectId;
  const tokenResult = await Notifications.getExpoPushTokenAsync(projectId ? { projectId } : undefined);
  if (!tokenResult.data) return;
  await protectedRequest("push/devices/", authToken, "POST", { token: tokenResult.data, platform: "expo" });
}

async function saveMediaToDevice(asset: MediaAsset) {
  if (!asset.url) throw new Error("Media download URL is not available");
  if (Platform.OS === "web") {
    window.open(asset.url, "_blank", "noopener,noreferrer");
    return asset.url;
  }

  const MediaLibrary = getMediaLibraryModule();
  if (!MediaLibrary) throw new Error("Media library requires a development build on this device");
  const permission = await MediaLibrary.requestPermissionsAsync();
  if (!permission.granted) {
    throw new Error("Allow media library access to save this file");
  }
  const extension = extensionForMedia(asset);
  const safeName = (asset.originalName || `property24-${asset.id}`).replace(/[^a-zA-Z0-9._-]/g, "_");
  const filename = safeName.includes(".") ? safeName : `${safeName}${extension}`;
  const targetFile = new FileSystem.File(FileSystem.Paths.cache, filename);
  const downloaded = await FileSystem.File.downloadFileAsync(asset.url, targetFile, { idempotent: true });
  const saved = await MediaLibrary.createAssetAsync(downloaded.uri);
  return saved.uri;
}

function extensionForMedia(asset: MediaAsset) {
  if (asset.mimeType === "image/png") return ".png";
  if (asset.mimeType === "image/webp") return ".webp";
  if (asset.mimeType?.startsWith("video/")) return ".mp4";
  if (asset.mimeType === "application/pdf") return ".pdf";
  if (asset.mimeType?.startsWith("audio/")) return ".m4a";
  return asset.mediaType === "image" ? ".jpg" : "";
}

function snakeCase(value: string) {
  return value.replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`);
}

function resolveMediaUrl(value?: string | null) {
  const mediaPath = String(value || "").trim();
  if (!mediaPath) return "";

  try {
    const mediaUrl = new URL(mediaPath);
    if (Platform.OS !== "web" && ["127.0.0.1", "localhost", "0.0.0.0"].includes(mediaUrl.hostname)) {
      const apiUrl = new URL(API_BASE_URL);
      mediaUrl.protocol = apiUrl.protocol;
      mediaUrl.hostname = apiUrl.hostname;
      mediaUrl.port = apiUrl.port;
    }
    return mediaUrl.toString();
  } catch {
    if (!mediaPath.startsWith("/")) return mediaPath;
    try {
      const apiUrl = new URL(API_BASE_URL);
      return `${apiUrl.protocol}//${apiUrl.host}${mediaPath}`;
    } catch {
      return mediaPath;
    }
  }
}

function trimTrailingSlash(value: string) {
  return value.replace(/\/+$/, "");
}

function titleize(value: string) {
  return String(value || "")
    .replace(/_/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}
