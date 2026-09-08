# Oikko - Admin Panel Setup

## Admin Features Added

### 1. Admin Panel Screens

**Notice Management** (`lib/features/notices/screens/notice_create_screen.dart`)

- Create and publish notices
- Support for event notices with date & location
- Admin-only feature

**Welfare Approval** (`lib/features/welfare/screens/welfare_approval_screen.dart`)

- Review pending welfare fund requests
- Approve or reject requests with one-click actions
- Admin-only feature

**Poll Management** (`lib/features/polls/screens/poll_create_screen.dart`)

- Create polls with dynamic options
- Add/remove poll options before publishing
- Admin-only feature

**Admin Shell** (`lib/features/admin/admin_shell.dart`)

- Bottom-tab navigation for admin features
- Three tabs: Welfare Approval, Notice Creation, Poll Creation

---

## Setup Instructions

### Step 1: Add Admin Route to Auth Wrapper

In `lib/features/auth/auth_wrapper.dart`, add this check after member lookup:

```dart
// Check if user is admin
if (member.role == 'admin') {
  return const AdminShell();
}
```

### Step 2: Deploy Firestore Security Rules

1. Go to Firebase Console → Firestore Database → Rules
2. Replace with content from `firestore.rules`
3. Publish

### Step 3: Create Firestore Indexes

1. Go to Firebase Console → Firestore Database → Indexes
2. Import from `firestore.indexes.json`
3. Wait for indexes to build (5-10 minutes)

### Step 4: Set Admin Role in Firestore

In your Firestore `members` collection, set `role: "admin"` for authorized users.

**Also required** — the security rules can't grant admin permissions just from the `role` field (see `firestore.rules` for why: a member doc's ID is never the same as their Firebase Auth uid, so rules can't look up "the current user's member doc" directly). Instead, create a document in a separate `admins` collection whose **document ID is that user's Firebase Auth UID** (found in Firebase Console → Authentication → Users). The document's content doesn't matter — it only needs to exist, e.g. `{ "grantedAt": <timestamp> }`. Without this doc, that user's `role: "admin"` is cosmetic only and every admin action (approving welfare requests, posting notices, creating polls, logging payments) will be denied by the security rules.

To revoke admin access, delete both the `admins/{uid}` doc and reset `role` back to `"member"`.

### Every admin has equal, full power

There is no separate "super admin" tier — that two-tier model was removed. Every account with an `admins/{uid}` marker document has the same full power as every other admin:

- Publishing/deleting notices, creating/stopping/deleting polls, logging payments and expenses
- Promoting or demoting **any** other admin, including the one who promoted them
- "Clear all" on payments and notices (irreversible, association-wide)

All of this is managed entirely from inside the app (Members tab → tap a member → "Make admin"/"Remove admin") once at least one admin exists. **The very first admin still has to be created by hand**, the same way as before (Step 4 above) — the app can't grant the first admin its own permissions, since nobody with admin rights exists yet to click the button. After that first one, no Firestore console visit is ever needed again for admin management.

There's still one owner-identity account (`contactwith.swadheen@gmail.com`, referenced as `AdminSession.superAdminEmail` in code) that's excluded from member counts/listings because it intentionally has no `members` document — but that's just an identity filter for display purposes, not a permission tier. It has no power beyond any other admin.

⚠️ Because every admin is now fully equal, any admin can remove any other admin — including the very first one. There is no protected account and no built-in recovery beyond the Firebase Console (create a fresh `admins/{uid}` doc there if everyone gets locked out).

**How to tell if this step is missing:** the admin panel shows a red "Admin permissions are not set up" banner at the top, with the exact UID to use as the document ID. Without that banner, the only symptom is a `permission-denied` error on each admin action separately (publishing a notice, adding a payment, approving a link request), which looks like several unrelated bugs instead of one missing document.

### Step 5: Create the Supabase Storage Bucket (one-time, required for photo upload)

File uploads (profile photos, receipts) use Supabase Storage instead of Firebase Storage — Firebase Storage now requires the paid Blaze plan just to be enabled, even for usage that stays within its free tier, whereas Supabase's free tier needs no card on file. Auth and all data (members, transactions, notices, etc.) stay on Firebase; only file storage moved. See `lib/core/services/storage_service.dart` for the client-side code and `lib/core/constants/supabase_config.dart` for the project URL/key.

This bucket doesn't exist until you create it once:

1. Open your Supabase project → **SQL Editor** → **New query**
2. Paste and run:

```sql
-- Creates the single bucket used for all app file uploads (public read,
-- since profile photos need to be viewable via a plain URL).
insert into storage.buckets (id, name, public)
values ('app-uploads', 'app-uploads', true)
on conflict (id) do nothing;

-- The app authenticates end users with Firebase, not Supabase Auth, so
-- every request Supabase sees comes in as the `anon` role — these policies
-- grant that role write access, scoped to this one bucket only. This is a
-- deliberate tradeoff for a small trusted-membership app with non-sensitive
-- photo uploads (no per-user ownership check on writes); do not reuse this
-- bucket/policy pattern for anything sensitive.
drop policy if exists "anon insert app-uploads" on storage.objects;
create policy "anon insert app-uploads"
on storage.objects for insert
to anon
with check (bucket_id = 'app-uploads');

drop policy if exists "anon update app-uploads" on storage.objects;
create policy "anon update app-uploads"
on storage.objects for update
to anon
using (bucket_id = 'app-uploads')
with check (bucket_id = 'app-uploads');

drop policy if exists "anon delete app-uploads" on storage.objects;
create policy "anon delete app-uploads"
on storage.objects for delete
to anon
using (bucket_id = 'app-uploads');
```

3. Run it — you should see "Success. No rows returned." The `drop policy if exists` lines make this script safe to re-run any time (e.g. if photo re-uploads start failing with a 403/row-level-security error — that means one of these three policies is missing or wrong, and re-running this script from scratch fixes it). A SQL Editor run stops at the first error, so without the `drop if exists` guards, re-running after a partial failure could silently skip later policies.

That's it; no further steps needed, the bucket is public-read by the `public: true` flag set above.

---

## File Structure

```
lib/
  features/
    admin/
      admin_shell.dart          # Admin panel navigation
    notices/
      screens/
        notice_create_screen.dart
    welfare/
      screens/
        welfare_approval_screen.dart
    polls/
      screens/
        poll_create_screen.dart
```

---

## Security Notes

- Only users with `role: "admin"` can access admin features
- Firestore rules enforce role-based access
- Members can only see their own welfare requests
- All changes are timestamped for audit trail

---

## Next Steps

1. Test admin features locally
2. Deploy Firestore rules
3. Create Cloud Functions for push notifications (optional)
4. Set up CI/CD pipeline
