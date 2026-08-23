# Oikko (ঐক্য) — Bangladesh Teachers Association App
## Full Planning & Architecture Document
**Baniyachong Upazila Branch, Habiganj**

**App Name:** Oikko

Prepared for: Mohammad Mohajjel Hossain, General Secretary
Contact: 01722 917 918

Prepared by: Swadheen Islam Robi
Leading University (CSE) | Baniyachong Adarsha High School (SSC-18)

---

## 1. Project Overview

**Goal:** Build a mobile + web app for a local teachers' association that centralizes member information, dues/financial tracking, notices, welfare-fund requests, and voting — usable by two roles: **Admin** (General Secretary) and **General Member**.

**Target Platforms:**
- Android (APK / Play Store)
- Web App (PWA — so iPhone users can use it via Safari without needing an Apple Developer Account initially)
- Native iOS (future phase — requires Apple Developer Account, ~$99/year, and a Mac for building)

**Framework:** Flutter (Dart) — single codebase for Android, Web, and iOS. Note: communication features (calling, SMS, WhatsApp) and push notifications require platform-specific handling (`if (kIsWeb) {...} else {...}`), since browsers can't trigger native phone calls/SMS.

**Who this doc is for:** Any developer or AI coding agent picking up this project should be able to understand the full feature scope, data model, and system architecture from this file alone.

---

## 2. Feature Categories (9 total)

### 1. Member Directory & Profile
- Individual profile per teacher: name, photo, designation, school name, blood group, educational qualification, phone number, email
- Smart search & filter (by school, subject, name, or blood group)
- One-tap contact: direct call, SMS, or WhatsApp message from profile
- Emergency directory: quickly find nearby blood donors by group
- **Privacy rule:** Any member can view other members' *profile* info (name, photo, designation, school, phone, blood group, qualification, email) via the directory — this is intentional, it's a shared association directory. This does **not** extend to financial data (see section 2's privacy rule) — profile visibility and payment visibility are separate rules.

### 2. Financial Management & Dashboard
- Admin panel: overview of total income/expense, total fund balance, monthly dues summary
- Digital receipt generation for dues collected
- Outstanding/due-payment list
- Add new income/expense entries; view past entries
- Personal statement per member: their own dues paid, dues pending, and past transaction history
- Download monthly/yearly statement as PDF
- **Privacy rule:** A general member can see only their own dues/payment amounts and transaction history — never another member's. The Admin (General Secretary) can see all members' payments and the full financial picture. This applies to both the Firestore security rules and the UI (the finance dashboard must be scoped per-role, not shown as one shared list to everyone).

### 3. Notices & Communication
- Digital notice board for meetings, decisions, and announcements
- Push notifications the moment a new notice is posted
- Annual calendar & events (meetings, picnics, special occasions) with date/location

### 4. Welfare Fund & Requests
- Welfare fund / loan request form submitted through the app
- Application status tracking (pending / approved) visible from member's own profile

### 5. Security & Admin Control
- Role-based access:
  - **Admin (General Secretary):** approve new members, edit records, post notices, full app control
  - **General Member:** view own account, view other members' profiles, read notices only
- Secure login via Email/Password (Firebase Auth, free tier — see section 4.2)

### 6. Reports & Analytics
- Graphical reports for admin: dues payment rate, outstanding trend over time
- Auto-generated financial summary report for the Annual General Meeting (AGM)

### 7. Online Poll / Voting
- In-app polling system for committee elections or general decisions
- Real-time results view for admin

### 8. Document & Resource Hub *(future phase)*
- Downloadable files: constitution/bylaws, meeting minutes, forms
- Photo/video gallery for events

### 9. Platform & Supporting Features
- **Offline support:** previously loaded profile/data viewable without internet (local caching)
- **Multi-language:** Bangla as default, with an English toggle
- **Backup & data export:** admin can export the full database (members, financial records) as Excel/CSV

---

## 3. Development Roadmap (Phased)

| Phase | Features | Why |
|---|---|---|
| **Phase 1 (MVP)** | Login/Register (Email/Password), member directory, profile, notice board | Core functionality — nothing else works without this |
| **Phase 2** | Financial management (admin panel + personal statements) | Core need — tracking dues |
| **Phase 3** | Push notifications, calendar/events | Improves communication |
| **Phase 4** | Welfare fund requests, online polling | Increases member engagement |
| **Phase 5** | Reports/analytics, data export, offline support | Polish & scale |
| **Phase 6 (future)** | Document hub, native iOS build | Once demand grows |

### 3.1 Actual Implementation Status (keep this updated — it drifts from the phase table above)

Far more than Phase 1–2 is built. As of this writing:

- ✅ **Auth & account linking** — Email/Password login/register, email verification gate, Flow A (auto-match by phone), Flow B (search-by-name + admin-approved link request), **Flow D (Member ID linking — see 4.9)**. Flow C (manual admin re-link UI) is still **not built**.
- ✅ **Member directory** — searchable, blood-group filter, tap-through profile, one-tap call/SMS/WhatsApp.
- ✅ **Profile** — view + edit own profile (name, school, designation, qualification, blood group, photo upload).
- ✅ **Finance** — admin sees all transactions + association total; each member sees only their own statement (both UI-scoped and Firestore-rule-enforced). Admin can log a payment against any member (`AddPaymentScreen`).
- ✅ **Admin: bulk member provisioning** — `AddMemberScreen` (generates a shareable Member ID), `MemberIdsScreen` (list + CSV export via clipboard).
- ✅ **Admin: link-request approval** — `LinkRequestsScreen` (this was previously a dead gap — `link_requests` existed with no UI consuming it; now closed).
- ✅ **Notices** — CRUD (admin) + read (members), with push notification on publish.
- ✅ **Welfare fund** — request (member) → approve/reject (admin), with push notification on decision.
- ✅ **Polls** — create (admin), vote (member, double-vote guarded), with push notification on creation.
- ✅ **Push notifications** — real, working, server-triggered (see 4.6 — this is **not** the Cloud-Functions design originally sketched in this doc; it now runs on a Supabase Edge Function instead, see 4.2).
- ✅ **File storage** — profile photos, via **Supabase Storage**, not Firebase Storage (see 4.2 for why).
- ❌ **Not built yet**: PDF statement export, reports/analytics/charts, calendar/events, offline persistence, CSV export of the full DB (only the Member ID list exports), document hub.

---

## 4. System Architecture

### 4.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Client Apps (Flutter)                 │
│   Android APK   |   Web (PWA)   |   iOS (future)          │
└───────────────┬─────────────────────────────┬─────────────┘
                │ HTTPS / SDK calls            │ HTTPS / SDK calls
                ▼                              ▼
┌───────────────────────────────┐   ┌─────────────────────────────┐
│      Firebase Backend (BaaS)   │   │   Supabase (file storage +  │
│  ┌───────────────┐ ┌─────────┐ │   │   the one server-side piece │
│  │ Firebase Auth  │ │ Cloud   │ │   │   this app needs)          │
│  │(Email/Password)│ │Firestore│ │   │  ┌────────────────────┐    │
│  │                │ │(Database│ │   │  │ Storage (photos)   │    │
│  └───────────────┘ └─────────┘ │   │  └────────────────────┘    │
│  ┌───────────────┐             │   │  ┌────────────────────┐    │
│  │ Firebase Cloud │             │   │  │ Edge Function       │   │
│  │ Messaging (FCM)│◀────────────┼───┼──│ send-notification   │   │
│  │ (Push receive) │  FCM v1 API │   │  │ (push SEND trigger)│    │
│  └───────────────┘             │   │  └────────────────────┘    │
└───────────────────────────────┘   └─────────────────────────────┘
```
**Why two backends:** everything started on Firebase (Auth, Firestore, FCM). Two pieces — Cloud Storage and Cloud Functions — got moved to Supabase mid-project because Google now requires the paid Blaze plan just to *enable* either one, even for usage that never leaves the free tier. Supabase's free tier needs no card on file for either equivalent. See 4.2 for the specifics. This is a deliberate, load-bearing decision — don't "simplify" it back to all-Firebase without re-reading 4.2 first, the free-tier blocker is real and current (checked live against this project in mid-2026).

### 4.2 Why Firebase (BaaS) instead of a custom backend
- No server to manage — good fit for a small association project maintained by non-full-time developers
- Built-in Auth, real-time database (Firestore), and push notification *receiving* all in one platform
- **Auth method decision:** Firebase Phone-number OTP requires the paid "Blaze" (pay-as-you-go) billing plan to be enabled on the project, even though actual usage cost for a small association would be near-zero. To avoid requiring a credit/debit card on file at all, this project uses **Email/Password authentication instead**, which works fully on Firebase's free "Spark" plan. Phone number is still collected and stored (for the directory, one-tap calling, and as an alternate login lookup key — see section 4.9), but it is not used for OTP verification. If the association's needs change later, Phone Auth can be added back by upgrading to Blaze.
- **Storage decision (changed from the original plan):** as of late 2024, Firebase Cloud Storage also requires Blaze just to be enabled — not just for usage beyond the free tier, for the feature to exist on the project at all. Same objection as Phone Auth: avoid requiring a card on file. So file uploads (currently just profile photos — `lib/core/services/storage_service.dart`) go to **Supabase Storage** instead; a free Supabase project (no card) covers it. Auth and all data (Firestore) stayed on Firebase — this is *not* a full migration, just the storage layer. Setup: `ADMIN_SETUP.md` Step 5 (a one-time SQL script creating the bucket + policies). Config: `lib/core/constants/supabase_config.dart`. **Known tradeoff:** the upload policy grants the `anon` role write access to the bucket (scoped to that one bucket only) rather than checking per-user ownership, because Supabase Storage's RLS policies key off Supabase's own auth, and this app authenticates users with Firebase Auth instead — there's no cheap way to bridge the two without a backend. Acceptable for low-stakes profile photos in a small trusted-membership app; **do not reuse this bucket/policy pattern for anything sensitive** without adding real per-user verification first.
- **Push-notification-sending decision (changed from the original plan):** Firebase Cloud Functions *also* now requires Blaze (it runs on Cloud Run/Cloud Build under the hood). Since *something* has to run server-side to call FCM's send API when e.g. a notice is posted, that job moved to a **Supabase Edge Function** (`supabase/functions/send-notification/`, free, no card) instead of a Cloud Function. See 4.6 for the full flow — it is meaningfully different from the Cloud-Function design this doc originally sketched.
- Free tier is generous enough for a small association (a few hundred members)

### 4.3 App-Side (Flutter) Folder Structure — Recommended

```
lib/
├── main.dart
├── app.dart                     # App root widget, theming, routing
├── core/
│   ├── constants/                # Colors, strings, app-wide constants
│   ├── theme/                    # Light/dark theme, typography
│   ├── utils/                    # Helper functions, validators
│   └── services/
│       ├── auth_service.dart     # Firebase Auth wrapper
│       ├── firestore_service.dart
│       ├── notification_service.dart
│       └── storage_service.dart
├── models/
│   ├── member.dart
│   ├── transaction.dart
│   ├── notice.dart
│   ├── welfare_request.dart
│   └── poll.dart
├── features/
│   ├── auth/                     # Login, Register, Email-verification screens
│   ├── directory/                # Member directory & profile
│   ├── finance/                  # Dashboard, statements, receipts
│   ├── notices/                  # Notice board, calendar/events
│   ├── welfare/                  # Welfare fund requests
│   ├── polls/                    # Voting feature
│   └── admin/                    # Admin-only screens
├── widgets/                      # Shared/reusable UI components
└── routes/
    └── app_router.dart
```
> This was the *planned* structure; actual has diverged in normal ways as features were added — notably `features/admin/screens/` + `features/admin/widgets/` (member provisioning, link-request approval, the admin speed-dial FAB), `features/profile/screens/edit_profile_screen.dart`, `features/about/`, `features/account_linking/` (Flows B/D), and no `routes/app_router.dart` (navigation is plain `Navigator.push`, no named-route table exists — don't call `pushNamed()` anywhere, it'll throw). There's also a `supabase/functions/send-notification/` directory at the repo root (Deno, not Dart) — see 4.6.

### 4.4 Data Model (Firestore Collections)

**`members` collection**
```
members/{memberId}
  - name: string
  - photoUrl: string
  - designation: string
  - schoolName: string
  - bloodGroup: string
  - qualification: string
  - phone: string
  - email: string
  - role: "admin" | "member"
  - status: "pending" | "approved"
  - authUid: string | null      // null until the teacher signs up and links this record
  - isClaimed: boolean          // false = admin-entered only, true = linked to a real login
  - createdAt: timestamp
  - memberCode: string          // short shareable ID (see below) — '' for records that predate this feature
  - fcmToken: string            // this device's push token; overwritten on each login, not a history
```
> Note: `memberId` (the document ID) is a system-generated ID, independent of phone number. This lets the admin pre-create a member's record (with dues, transactions, etc.) *before* that teacher ever opens the app — see section 4.9 for the full account-linking flow.
>
> **`memberCode`:** generated once, at creation, by `FirestoreService.createMemberByAdmin()` — it's just the first 6 characters of the (already globally-unique) Firestore doc ID, uppercased. No collision check needed or done. This is the human-shareable "Member ID" an admin hands a teacher so they can self-link (Flow D, section 4.9) instead of searching by name. Records created via self-registration (`createPendingMember`) don't get one (stays `''`) — that's also how the homepage "sync your payment info" banner (`HomeScreen`) decides whether to show: it appears exactly when `memberCode.isEmpty`, meaning this account isn't yet linked to an admin-provisioned record.
>
> **Login identifier:** Members can log in with either their email or phone number (the app resolves a phone number to its linked account's email before calling Firebase Auth — see `findEmailByPhone()` in the Firestore service). Since phone numbers are not OTP-verified under Email/Password auth, **email verification is required** before a claimed member record is treated as trusted (Firebase's built-in `sendEmailVerification()` / `emailVerified` flag) — this is the safeguard that replaces phone verification in the account-linking flow (section 4.9).

**`transactions` collection** (dues, income, expense)
```
transactions/{transactionId}
  - memberId: string (nullable — null for general association expense)
  - type: "due_payment" | "income" | "expense"
  - amount: number
  - date: timestamp
  - description: string
  - receiptUrl: string (optional)
  - createdBy: string (admin uid)
```

**`notices` collection**
```
notices/{noticeId}
  - title: string
  - body: string
  - postedBy: string (admin uid)
  - createdAt: timestamp
  - eventDate: timestamp (optional, for calendar items)
  - location: string (optional)
```

**`welfare_requests` collection**
```
welfare_requests/{requestId}
  - memberId: string
  - reason: string
  - amountRequested: number
  - status: "pending" | "approved" | "rejected"
  - submittedAt: timestamp
  - reviewedBy: string (admin uid, optional)
```

**`polls` collection**
```
polls/{pollId}
  - question: string
  - options: array<string>
  - createdByUid: string
  - createdByName: string
  - votes: map<optionIndex, count>
  - voterIds: array<string>   // to prevent double-voting
  - isActive: boolean
  - createdAt: timestamp
  - closesAt: timestamp
```

**`link_requests` collection** (see section 4.9 for context)
```
link_requests/{requestId}
  - memberId: string           // the pre-existing member record being claimed
  - requestedByUid: string     // the auth UID of the user requesting the link
  - requestedPhone: string     // the phone number they logged in with
  - status: "pending" | "approved" | "rejected"
  - requestedAt: timestamp
  - reviewedBy: string (admin uid, optional)
```
> Approval is done from `LinkRequestsScreen` (admin), which also **unlinks any other member doc currently pointing at that same authUid** in the same batch (`FirestoreService.approveLinkRequest`) — a member can only ever be linked to one auth account at a time, and without this a teacher who self-registered (creating an empty auto-provisioned record) and later linked a real admin-provisioned record via Member ID would end up with two docs pointing at them simultaneously, which `watchMemberByAuthUid`'s `limit(1)` query can't handle deterministically.

**`admins` collection** — access-control marker only, no app data
```
admins/{authUid}                // document ID = that user's Firebase Auth UID; content doesn't matter, only existence
```
> Exists purely because Firestore/Storage security rules can't look up "the members doc for the current caller" without knowing its doc ID in advance, and `memberId` is never the same as `authUid` (see the note above). `isAdmin()` in `firestore.rules` and `storage.rules` both check `exists(/databases/.../admins/{request.auth.uid})` — that's the actual, only source of truth for admin permissions. Setting `role: "admin"` on a `members` doc alone does **nothing** for security rules; it's purely a UI/display convenience (`Member.isAdmin`) that must be paired with an `admins/{uid}` doc, or every admin action gets silently denied. See `ADMIN_SETUP.md` Step 4 for how this is created (manually, via Firebase Console — there is no in-app "promote to admin" screen).

### 4.5 Security Rules (Firestore) — Key Principles

**⚠️ `role == "admin"` is never checked directly anywhere in `firestore.rules` or `storage.rules`.** Every admin gate goes through `isAdmin()`, which checks `exists(/databases/.../documents/admins/{request.auth.uid})` — see the `admins` collection note above for why (`memberId` doc IDs are never the same as `authUid`, so rules can't `get()` "my own member doc" directly). This tripped up an earlier version of these rules badly enough that welfare-request visibility, admin writes, and self-profile-edits were all silently broken in production before it was caught and fixed — if you're debugging a mysterious `permission-denied`, check the `admins/{uid}` doc exists before anything else.

- `isOwnMemberRecord(memberId)` is the other core helper: given a `members` doc ID (as stored in a `transactions` or `welfare_requests` doc's `memberId` field), it reads that member doc and checks `authUid == request.auth.uid`. This is how "is this my own record" gets checked anywhere that only has a `memberId`, not a direct doc reference.
- Any authenticated user can read all `members` documents (approved or pending, claimed or unclaimed) — needed for directory search and self-linking (section 4.9)
- A user may set `authUid` on a `members` document **only if**: `authUid` is currently `null` AND `request.resource.data.authUid == request.auth.uid` AND `request.auth.token.email_verified == true` (auto-claim / Flow A and D — email verification is the trust check here, since phone numbers/Member IDs are otherwise unverified)
- A user can never directly overwrite another member's already-set `authUid`
- The already-linked owner of a member doc may edit their own profile fields (name, school, photo, blood group, etc.) but the rule explicitly pins `role`, `status`, `authUid`, and `isClaimed` to their existing values in the same write — self-edits can't touch those four fields, only `isAdmin()` can
- `isAdmin()` can do anything to any `members` doc, including delete
- Only `isAdmin()` can write to `notices`, and create/update/delete `transactions`
- **`transactions` read rule:** `isOwnMemberRecord(resource.data.memberId) || isAdmin()` — a member only ever reads their own transactions, checked via the helper above (guarded against `memberId == null`, the general-expense case). The finance dashboard/screen is likewise split: `FinanceDashboardScreen(isAdmin: true)` for the admin "all transactions" view vs. `FinanceDashboardScreen(memberId: ...)` for a member's own statement — both the rule and the UI enforce this, not just one or the other.
- **`welfare_requests`:** same `isOwnMemberRecord()` pattern for both read and create (a member can only create a request with their own `memberId`) — `isAdmin()` for approve/reject.
- `link_requests`: any authenticated user can create one for themselves (`requestedByUid == request.auth.uid` enforced in the rule, not just convention) — only `isAdmin()` can approve/reject.
- Any authenticated user can read `notices` and `polls`
- Vote writes must check the requester's uid is not already in `voterIds`

### 4.6 Push Notification Flow (actual — not the Cloud Functions design this doc originally sketched)

Receiving a push is free and pure-client (FCM needs no billing plan for that). *Sending* one needs something running server-side to notice "a notice was posted" and call FCM's API — that piece can't be a Firestore-triggered Cloud Function per the original plan, because Cloud Functions (2nd gen) now requires Blaze too, same blocker as Storage (see 4.2). Instead:

1. Every device subscribes to two **FCM topics** on login (`NotificationService.init()`, called from `AuthWrapper._registerPushToken`, once per member per session):
   - `all_members` — broadcasts (new notice, new poll)
   - `member_{memberId}` — targeted at just that one member (welfare request decision, link-request approved)

   Topic-based rather than per-device-token specifically so sending never has to look up or loop over individual tokens — it's always exactly one call, to one topic.

2. The admin action itself (post notice / create poll / approve-reject welfare / approve link request) writes to Firestore as normal, **then** the client directly calls a **Supabase Edge Function** named `send-notification` (`supabase/functions/send-notification/index.ts`), passing `{title, body, topic, idToken}` — no Firestore trigger, no Cloud Function, the Flutter app calls it directly right after the write succeeds. A failed push never blocks or rolls back the Firestore write; the screens show a secondary "saved, but push failed: ..." toast instead of treating it as a hard error.

3. The Edge Function is the one place holding real credentials — a Firebase **service account** JSON, stored as the Supabase secret `firebase_key` (set once via the Supabase dashboard, never shipped in the app). It:
   - **Re-verifies the caller is really an admin**, independently of the client — this matters because Supabase's own request auth only proves "a request came from the app" (the anon key is public by design, embedded in the binary), not "this caller is an admin". It verifies the passed Firebase ID token via `identitytoolkit.googleapis.com/v1/accounts:lookup` (Google does the actual signature verification), then checks that uid exists in the `admins` Firestore collection via the Firestore REST API — the exact same check `isAdmin()` does in `firestore.rules`. Fails closed (401/403) on any problem.
   - Exchanges the service account for a short-lived Google OAuth2 access token (hand-rolled JWT-bearer flow using Web Crypto — no external libraries, since Deno's edge runtime doesn't reliably support the Node-oriented Google auth libraries).
   - Calls `https://fcm.googleapis.com/v1/projects/{project_id}/messages:send` targeting the given topic.

4. Client app receives and displays the notification (foreground/background handling in Flutter, FCM's default OS-level behavior for background/terminated).

**Deploying/changing this function:** `npx supabase login` (interactive, one-time) → `npx supabase link --project-ref ykamplbqfzedmhwhaucj` → `npx supabase functions deploy send-notification`. The `firebase_key` secret must already be set in the Supabase dashboard (Project Settings → Edge Functions → Secrets) — it is not part of the deployed code and won't be recreated by redeploying.

### 4.7 Offline Support Strategy
- Firestore has built-in offline persistence — enable it for cached reads on member directory and notices
- For Web (PWA), use a service worker to cache static assets and last-fetched data

### 4.8 Platform-Specific Notes
| Feature | Android | Web (PWA) | iOS |
|---|---|---|---|
| Direct call/SMS | Native support | Not supported directly (can use `tel:`/`sms:` links which open the phone's dialer/messaging app if available) | Native support |
| Push notifications | Full FCM support | Supported but limited on iOS Safari; more reliable on desktop/Android Chrome | Full FCM support (native) |
| Offline caching | Full support | Supported via service worker | Full support |
| Email/Password login | Full support | Supported | Full support |

### 4.9 Member Account-Linking System (Pre-Provisioned Records)

**Problem this solves:** The admin will often add a teacher's data (dues, transactions, profile info) *before* that teacher has ever opened the app or created a login. When the teacher later signs up, their existing data must automatically appear in their profile — not create a fresh, empty one.

> **Auth method note:** The app uses **Email/Password** authentication (not Phone OTP — see the "Auth method decision" note in section 4.2). This means the phone number a teacher enters at registration is **not independently verified** by Firebase the way an OTP would be. To keep the auto-claim step trustworthy, the app requires the account's **email to be verified** (via Firebase's built-in verification email) before any claim/link action is finalized. This is the equivalent trust checkpoint that OTP would have provided.

**Flow A — Auto-match by phone number (default, no admin action needed)**
1. Admin creates a `members` document with the teacher's phone number, dues, etc. `authUid` is left `null` and `isClaimed = false`.
2. The teacher later registers in the app with their email and password, entering the same phone number on the registration form.
3. Firebase sends a verification email; the app blocks further access via `EmailVerificationScreen` until the teacher confirms it (`user.emailVerified == true`).
4. Once verified, the app queries `members` where `phone == <entered phone>` and `authUid == null`.
5. If a match is found, the app sets `authUid` on that existing document (per the security rule in 4.5, which checks `email_verified`) and sets `isClaimed = true`. The teacher immediately sees all their pre-existing dues/transaction history.
6. If no match is found, a new `members` document is created with `status: "pending"`, awaiting admin approval as a new member.

**Flow B — Manual "Find My Profile & Request Link" (when the phone number doesn't match)**
This handles real-world cases: the teacher registers with a different/new number than what the admin originally entered, or the admin made a typo.
1. If auto-match (Flow A) finds nothing, the app prompts: *"Is your information already listed? Search for your name."*
2. The teacher searches the directory (by name/school) among **unclaimed** records (`isClaimed == false`) and finds their own entry.
3. They tap **"This is me"**, which creates a `link_requests` document (status: `pending`) — it does *not* set `authUid` directly, to prevent anyone from falsely claiming someone else's record.
4. The request appears in the Admin Panel. The admin verifies (e.g., by calling the teacher) and approves or rejects it.
5. On approval, `authUid` is set on the target `members` document and `isClaimed` becomes `true` — the teacher now sees their full history.

**Flow C — Manual admin override *(not built)***
- The plan was an admin screen to directly update a member's phone number or manually attach/detach an `authUid` — useful for a lost phone, an incorrect entry, or a teacher who can't access their registered email. This does **not exist yet**. Today the only way to fix a bad link is to edit Firestore directly in the console.

**Flow D — Connect via Member ID (the primary path admins are expected to use now)**
This is the newer, more direct alternative to Flow B's name search, built alongside the bulk member-provisioning feature — an admin adding ~500 members up front hands each one a short ID rather than relying on name matching.
1. Admin bulk-creates member records via `AddMemberScreen` (name required, everything else optional) — each gets a `memberCode` (see 4.4) shown immediately with a copy button, and all of them are listable/exportable via `MemberIdsScreen` (CSV to clipboard) for handing out later.
2. The teacher, on `FindProfileScreen` (shown either right after registration when no member is linked yet, or reachable anytime from the homepage's "sync your payment info" banner — see 4.4's `memberCode` note), enters that ID into the "Connect with member ID" field instead of searching by name.
3. `FirestoreService.findUnclaimedMemberByCode()` looks it up (`memberCode` + `isClaimed == false`) and, if found, routes into the **same** `ProfileMatchScreen` → `link_requests` flow as Flow B from here on — same confirmation screen, same admin-approval queue (`LinkRequestsScreen`), same underlying mechanism. Flow B (name search) is still available as a fallback on the same screen for members without a code.
4. On approval, `FirestoreService.approveLinkRequest()` also unlinks any other member doc already pointing at that authUid first (see the `link_requests` note in 4.4) — this is what makes it safe to run Flow D on an account that was previously auto-linked via Flow A to an empty self-registered record.

**Summary of the full flow:**
```
Register (Email/Password) ──▶ Verify email ──▶ Auto-match by phone?
                                                    ├─ Yes ──▶ Auto-link (authUid set, isClaimed = true)
                                                    └─ No  ──▶ FindProfileScreen
                                                                   ├─ Has a Member ID? ──▶ Flow D: look up by code
                                                                   └─ No code ──▶ Flow B: search by name (unclaimed records)
                                                                          (either path, once matched) ──▶ Send link_request
                                                                                                        ──▶ Admin approves (LinkRequestsScreen,
                                                                                                             unlinks any prior member doc first)
                                                                                                        ──▶ Linked
                                                                   Neither found ──▶ New pending member record (no memberCode)
Login (existing account) ──▶ Email or phone accepted as identifier
                              (phone is resolved to its linked email via findEmailByPhone(), then signed in with Firebase Auth)
Admin can bulk-provision ahead of time via AddMemberScreen; Flow C (manual re-link) is not built — console-only for now.
```

---

## 5. Suggested Tech Stack Summary

| Layer | Choice |
|---|---|
| Frontend | Flutter (Dart) |
| Backend (data, auth, push receiving) | Firebase (Auth, Firestore, FCM) |
| Backend (file storage, push sending) | **Supabase** (Storage + one Edge Function) — moved off Firebase Storage/Cloud Functions because both now require the paid Blaze plan just to enable, see section 4.2 |
| Web Hosting | Firebase Hosting (as PWA) |
| Future payment integration | bKash/Nagad API (if online due collection is added later) |

---

## 6. Development Environment (Reference Snapshot)

To avoid version-mismatch issues (a common problem when Flutter/Android/JDK versions drift apart), this project should be built and tested against the following confirmed working environment. Any AI agent or new developer joining the project should match these versions where possible, or at minimum be aware of them before upgrading anything.

| Tool | Version | Notes |
|---|---|---|
| OS | Windows 11 (25H2) | |
| Flutter SDK | 3.44.9 (stable channel) | |
| Dart SDK | 3.12.2 | Bundled with the Flutter version above |
| Android SDK | 36.0.0 | Platform `android-36`, build-tools `36.0.0` |
| JDK (for Android builds) | **21.0.6** (OpenJDK, bundled with Android Studio at `C:\Program Files\Android\Android Studio\jbr`) | This is the JDK Flutter actually uses for Android/Gradle builds — set via `flutter config --jdk-dir`. |
| System-wide `java -version` | 24.0.1 | ⚠️ Not the JDK used for building — Flutter is explicitly configured to use JDK 21 (above) instead, since Android Gradle Plugin compatibility with JDK 24 is not guaranteed. Do not assume the system `java` version is what builds the app. |

**Known local setup gaps (non-blocking for Android/Web development):**
- Chrome browser not found at the default path — only needed for `flutter run -d chrome` (live web debugging). Edge works as a substitute for now; `flutter build web` (the actual production build) does not require Chrome at all.
- Visual Studio (C++ workload) not installed — only required for building native **Windows desktop** apps, which is out of scope for this project (we target Android + Web only).

**Rule of thumb for any agent/developer picking up this project:** if a `flutter build apk` or `flutter build web` fails with a JDK/Gradle-related error, first check which JDK Flutter is configured to use (`flutter config` or check `android/gradle.properties` for `org.gradle.java.home`) rather than assuming the system-wide `java -version`.

---

## 7. Next Steps

Scaffolding, Firebase setup, and Phase 1–2 MVP are long done — see section 3.1 for what's actually built. Remaining, in rough priority order:

1. **Flow C** (manual admin re-link) — currently the only way to fix a bad account link is editing Firestore directly in the console; a small admin screen would close this
2. PDF statement export (`pdf` package is already a dependency, unused)
3. Reports/analytics/charts for the admin dashboard
4. Calendar/events view for notices with `eventDate` set
5. Offline persistence (Firestore's built-in cache isn't explicitly enabled yet)
6. Full-database CSV/Excel export (today only the Member ID list exports, via `MemberIdsScreen`)
7. Document hub, native iOS build — still explicitly future-phase, no active need yet

---

*This document can be updated as development progresses. Any AI agent or developer picking up this project should treat sections 2–4 as the source of truth for features and architecture.*
