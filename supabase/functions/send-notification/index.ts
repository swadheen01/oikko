// Sends a push notification to every subscribed device via FCM's HTTP v1
// API. This is the server-side piece that was missing: nothing pops up in
// a phone's notification bar just because a device registered a token —
// something has to actually call FCM's send API when e.g. a notice is
// posted, and that has to run somewhere other than the phone.
//
// Security model: the caller must be a real logged-in Firebase user AND
// present in the `admins` Firestore collection — the exact same check
// `isAdmin()` does in firestore.rules, reused here so there's one source
// of truth for "who is an admin", not two. Without this check, anyone who
// extracted the Supabase anon key from the app (trivial — it's public by
// design) could otherwise spam a push to every member, since Supabase's
// own request-level auth only proves "this is a request from the app",
// not "this caller is an admin".
//
// Deploy:
//   npx supabase link --project-ref ykamplbqfzedmhwhaucj
//   npx supabase functions deploy send-notification
//
// Requires the `firebase_key` secret (the full Firebase service-account
// JSON) to already be set — confirmed done.
//
// Invoke from Flutter via:
//   Supabase.instance.client.functions.invoke('send-notification', body: {
//     'title': ..., 'body': ..., 'idToken': await FirebaseAuth.instance.currentUser!.getIdToken(),
//   });

const FIREBASE_WEB_API_KEY = "AIzaSyD-kAoV3PtLWkVeKrWdHcn1bJmtVIIAr_s";

// A member submitting a "connect my account" link request needs to notify
// admins, but isn't an admin themselves — so this one topic is exempt from
// the admin check below (any signed-in Firebase user may send to it, never
// unauthenticated). Every other topic (all_members, member_*) still
// requires the caller to be in `admins`.
const ADMINS_TOPIC = "admins";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

function base64url(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

/// Exchanges the service account for a short-lived OAuth2 access token
/// scoped to both FCM send and Firestore read (used for the admin check).
async function getGoogleAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: sa.client_email,
    scope:
      "https://www.googleapis.com/auth/firebase.messaging https://www.googleapis.com/auth/datastore",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const signInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claims))}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signInput),
  );
  const jwt = `${signInput}.${base64url(new Uint8Array(signature))}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  if (!res.ok) {
    throw new Error(`token exchange failed: ${res.status} ${await res.text()}`);
  }
  const data = await res.json();
  return data.access_token as string;
}

/// Verifies the Firebase ID token is real and returns the uid it belongs
/// to. Google does the actual signature verification server-side; this
/// just relays to that endpoint rather than reimplementing JWT/JWKS
/// verification by hand.
async function verifyFirebaseIdToken(idToken: string): Promise<string> {
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${FIREBASE_WEB_API_KEY}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ idToken }),
    },
  );
  if (!res.ok) throw new Error("invalid or expired idToken");
  const data = await res.json();
  const uid = data.users?.[0]?.localId;
  if (!uid) throw new Error("invalid or expired idToken");
  return uid as string;
}

/// Mirrors firestore.rules' isAdmin(): checks the `admins/{uid}` marker
/// doc exists.
async function isAdmin(accessToken: string, projectId: string, uid: string): Promise<boolean> {
  const res = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/admins/${uid}`,
    { headers: { Authorization: `Bearer ${accessToken}` } },
  );
  return res.status === 200;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const jsonResponse = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    const { title, body, topic, idToken } = await req.json();
    if (!title || !body || !idToken) {
      return jsonResponse({ error: "title, body, and idToken are required" }, 400);
    }

    const raw = Deno.env.get("firebase_key");
    if (!raw) throw new Error("firebase_key secret is not set");
    const sa: ServiceAccount = JSON.parse(raw);

    const accessToken = await getGoogleAccessToken(sa);

    // Fail closed on any auth problem — an unrecognized caller or a
    // caller who isn't in `admins` gets 401/403, never a silent send.
    let uid: string;
    try {
      uid = await verifyFirebaseIdToken(idToken);
    } catch {
      return jsonResponse({ error: "unauthenticated" }, 401);
    }

    if (topic !== ADMINS_TOPIC) {
      const admin = await isAdmin(accessToken, sa.project_id, uid);
      if (!admin) {
        return jsonResponse({ error: "forbidden: admin only" }, 403);
      }
    }

    const fcmRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            topic: topic ?? "all_members",
            notification: { title, body },
          },
        }),
      },
    );
    const result = await fcmRes.json();
    if (!fcmRes.ok) return jsonResponse({ error: result }, fcmRes.status);

    return jsonResponse({ ok: true, result });
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
