import type { Href } from "expo-router";

type QuickAction = {
  title: string;
  subtitle: string;
  icon: string;
  href: Href;
  roles: Array<"tenant" | "landlord" | "agent" | "admin">;
};

export const quickActions: QuickAction[] = [
  { title: "Search homes", subtitle: "Find verified rentals", icon: "search-outline", href: "/", roles: ["tenant"] },
  { title: "Apply for rental", subtitle: "Use tenant profile", icon: "send-outline", href: "/", roles: ["tenant"] },
  { title: "Post property", subtitle: "Add a verified listing", icon: "add-circle-outline", href: "/listings", roles: ["landlord", "agent"] },
  { title: "Create lease", subtitle: "Draft a digital contract", icon: "document-text-outline", href: "/leases", roles: ["landlord"] },
  { title: "Open analytics", subtitle: "View portfolio health", icon: "analytics-outline", href: "/analytics", roles: ["landlord", "admin"] },
  { title: "Schedule viewing", subtitle: "Coordinate property access", icon: "calendar-outline", href: "/operations", roles: ["agent"] },
  { title: "Track commissions", subtitle: "Review earned fees", icon: "cash-outline", href: "/operations", roles: ["agent"] },
  { title: "Verify user", subtitle: "Review identity checks", icon: "shield-checkmark-outline", href: "/verification", roles: ["admin"] },
  { title: "Review reports", subtitle: "Resolve disputes", icon: "alert-circle-outline", href: "/operations", roles: ["admin"] },
];

export const roleCards = [
  {
    title: "Tenant",
    description: "Search verified homes, pay rent, chat, and report maintenance.",
    icon: "home-outline",
    accent: "#E50914",
    accentSoft: "rgba(229,9,20,0.14)",
  },
  {
    title: "Landlord",
    description: "Manage properties, collect rent, and keep leases organized.",
    icon: "business-outline",
    accent: "#E50914",
    accentSoft: "rgba(229,9,20,0.14)",
  },
  {
    title: "Agent",
    description: "List homes, book viewings, and track commissions.",
    icon: "people-outline",
    accent: "#E50914",
    accentSoft: "rgba(229,9,20,0.14)",
  },
  {
    title: "Administrator",
    description: "Verify users, remove fake adverts, and resolve disputes.",
    icon: "shield-checkmark-outline",
    accent: "#E50914",
    accentSoft: "rgba(229,9,20,0.14)",
  },
];

export const trustSignals = [
  { title: "Identity verification", description: "National ID, selfie, and phone checks before publishing.", icon: "shield-checkmark-outline" },
  { title: "Lease protection", description: "Digital contracts with e-signatures and receipts.", icon: "document-lock-outline" },
  { title: "Fraud controls", description: "Admins can remove fake adverts and resolve disputes.", icon: "ban-outline" },
  { title: "Rent history", description: "Track payments, arrears, and proof of payment.", icon: "receipt-outline" },
];

export const searchFilters = ["City", "Suburb", "Rent range", "Bedrooms", "House", "Flat", "Cottage", "Student accommodation", "Commercial property"];

export const categories = [
  { title: "House", meta: "Family and long-term rentals", icon: "home-outline" },
  { title: "Flat", meta: "Compact city living", icon: "layers-outline" },
  { title: "Cottage", meta: "Affordable standalone options", icon: "leaf-outline" },
  { title: "Student accommodation", meta: "Rooms and cottages near campuses", icon: "school-outline" },
  { title: "Commercial property", meta: "Retail and office space", icon: "storefront-outline" },
];

export const accountSections = [
  { title: "Verification center", meta: "ID, selfie, agency registration, and ownership proof", icon: "shield-checkmark-outline" },
  { title: "Lease documents", meta: "Generate contracts and keep signatures organized", icon: "document-text-outline" },
  { title: "Reporting", meta: "Disputes, platform health, and moderation workflow", icon: "analytics-outline" },
];

export const supportQueue = [
  { title: "Maintenance", meta: "Plumbing, electrical, roofing, painting" },
  { title: "Disputes", meta: "Escalations, verifications, and fake listings" },
];

export const paymentMethods = [
  { name: "EcoCash", detail: "Fast mobile money payments" },
  { name: "ZIPIT", detail: "Bank transfer reference tracking" },
  { name: "Visa / Mastercard", detail: "Card gateway integration" },
  { name: "Bank transfer", detail: "Direct account settlements" },
];

export const maintenanceCategories = ["Plumbing", "Electricity", "Roofing", "Painting", "General repairs"];

export const verificationChecks = ["National ID verification", "Selfie verification", "Proof of ownership or authorization to let", "Phone verification", "Agency registration for agents"];

export const journeyPoints = {
  Tenant: ["Search verified homes", "Apply with a digital profile", "Pay rent and receive receipts", "Report maintenance with photos", "Sign leases digitally", "Chat without exposing phone numbers"],
  Landlord: ["Add listings with photos and GPS", "Approve verified tenants", "Track rent and arrears", "Organize leases and receipts", "Review maintenance queues", "Monitor listing performance"],
  Agent: ["Manage multiple landlords", "Schedule viewings quickly", "Track applications by property", "Monitor commissions", "Publish and edit listings", "Coordinate chats securely"],
  Administrator: ["Review user verification", "Detect and remove fake listings", "Resolve payment disputes", "Approve agency registrations", "Monitor trust and fraud metrics", "Escalate critical issues"],
};
