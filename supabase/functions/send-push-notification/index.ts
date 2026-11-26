import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

interface NotificationRecord {
  id: string;
  user_id: string;
  actor_id?: string | null;
  module: string;
  reference_id?: string | null;
  reference_uuid?: string | null;
  title: string;
  subtitle?: string | null;
}

interface WebhookPayload {
  type?: string;
  table?: string;
  schema?: string;
  record?: NotificationRecord;
}

interface FirebaseServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const PUSH_WEBHOOK_SECRET = Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "";

function getConfiguredSecretKeys(): string[] {
  const keys: string[] = [];
  if (SUPABASE_SERVICE_ROLE_KEY) keys.push(SUPABASE_SERVICE_ROLE_KEY);
  const rawSecretKeys = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (rawSecretKeys) {
    try {
      const parsed = JSON.parse(rawSecretKeys) as Record<string, string>;
      for (const val of Object.values(parsed)) {
        if (typeof val === "string" && val.trim()) {
          keys.push(val.trim());
        }
      }
    } catch {
      // ignore malformed env
    }
  }
  return keys;
}

function base64UrlEncode(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const cleaned = pem
    .replace(/\\n/g, "\n")
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const binary = atob(cleaned);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

async function getFirebaseAccessToken(sa: FirebaseServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claimSet = base64UrlEncode(
    JSON.stringify({
      iss: sa.client_email,
      sub: sa.client_email,
      aud: "https://oauth2.googleapis.com/token",
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      iat: now,
      exp: now + 3600,
    }),
  );

  const unsignedJwt = `${header}.${claimSet}`;
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signatureBuffer = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedJwt),
  );

  const assertion = `${unsignedJwt}.${base64UrlEncode(new Uint8Array(signatureBuffer))}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  const tokenJson = await tokenRes.json();
  if (!tokenRes.ok || !tokenJson.access_token) {
    throw new Error(`Failed to obtain Firebase OAuth token: ${JSON.stringify(tokenJson)}`);
  }
  return tokenJson.access_token as string;
}

function parseServiceAccount(): FirebaseServiceAccount | null {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")?.trim();
  if (!raw) return null;

  try {
    const jsonStr = raw.startsWith("{") ? raw : atob(raw);
    const parsed = JSON.parse(jsonStr) as Partial<FirebaseServiceAccount>;
    if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
      throw new Error("Missing project_id, client_email, or private_key in FIREBASE_SERVICE_ACCOUNT_JSON");
    }
    return {
      project_id: parsed.project_id,
      client_email: parsed.client_email,
      private_key: parsed.private_key,
    };
  } catch (err) {
    throw new Error(`Invalid FIREBASE_SERVICE_ACCOUNT_JSON format: ${(err as Error).message}`);
  }
}

async function isAuthorized(req: Request): Promise<boolean> {
  const authHeader = req.headers.get("authorization") ?? "";
  const bearerToken = authHeader.startsWith("Bearer ") ? authHeader.slice(7).trim() : "";
  const apiKeyHeader = (req.headers.get("apikey") ?? "").trim();
  const webhookSecretHeader = (req.headers.get("x-webhook-secret") ?? "").trim();

  if (PUSH_WEBHOOK_SECRET && webhookSecretHeader === PUSH_WEBHOOK_SECRET) {
    return true;
  }

  const secretKeys = getConfiguredSecretKeys();
  if (bearerToken && secretKeys.includes(bearerToken)) {
    return true;
  }
  if (apiKeyHeader && secretKeys.includes(apiKeyHeader)) {
    return true;
  }

  // Support Supabase new sb_secret_... API keys via gateway admin verification
  const candidateSecret = apiKeyHeader.startsWith("sb_secret_")
    ? apiKeyHeader
    : (bearerToken.startsWith("sb_secret_") ? bearerToken : "");

  if (candidateSecret && SUPABASE_URL) {
    try {
      const verifyRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users?page=1&per_page=1`, {
        method: "GET",
        headers: {
          apikey: candidateSecret,
          Authorization: `Bearer ${candidateSecret}`,
        },
      });
      if (verifyRes.ok) {
        return true;
      }
    } catch {
      return false;
    }
  }

  return false;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!(await isAuthorized(req))) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const payload = (await req.json()) as WebhookPayload;
    const record = payload.record;

    if (!record || !record.user_id || !record.title) {
      return new Response(JSON.stringify({ ok: true, skipped: true, reason: "Missing notification record fields" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const serviceAccount = parseServiceAccount();
    if (!serviceAccount) {
      return new Response(
        JSON.stringify({
          ok: true,
          skipped: true,
          reason: "FIREBASE_SERVICE_ACCOUNT_JSON secret not configured yet",
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: tokens, error: tokenErr } = await supabase
      .from("user_device_tokens")
      .select("id, fcm_token, platform")
      .eq("user_id", record.user_id);

    if (tokenErr) {
      throw new Error(`Failed querying user_device_tokens: ${tokenErr.message}`);
    }

    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ ok: true, sent: 0, reason: "No registered device tokens for user" }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    const accessToken = await getFirebaseAccessToken(serviceAccount);
    const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

    const staleTokenIds: string[] = [];
    let sentCount = 0;
    const errors: Array<{ tokenId: string; status: number; detail: unknown }> = [];

    await Promise.all(
      tokens.map(async (row) => {
        const fcmBody = {
          message: {
            token: row.fcm_token,
            notification: {
              title: record.title,
              body: record.subtitle ?? "",
            },
            data: {
              notification_id: String(record.id ?? ""),
              module: String(record.module ?? "case"),
              reference_id: String(record.reference_id ?? ""),
              reference_uuid: String(record.reference_uuid ?? ""),
            },
            android: {
              priority: "HIGH",
              notification: {
                channel_id: "high_importance_channel",
                sound: "default",
                click_action: "FLUTTER_NOTIFICATION_CLICK",
              },
            },
            apns: {
              headers: {
                "apns-priority": "10",
              },
              payload: {
                aps: {
                  sound: "default",
                  badge: 1,
                },
              },
            },
          },
        };

        const res = await fetch(fcmEndpoint, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify(fcmBody),
        });

        if (res.ok) {
          sentCount += 1;
          return;
        }

        const errData = await res.json().catch(() => ({}));
        const errCode = errData?.error?.details?.[0]?.errorCode ?? errData?.error?.status ?? "";
        if (errCode === "UNREGISTERED" || res.status === 404) {
          staleTokenIds.push(row.id);
        } else {
          errors.push({ tokenId: row.id, status: res.status, detail: errData });
        }
      }),
    );

    if (staleTokenIds.length > 0) {
      await supabase.from("user_device_tokens").delete().in("id", staleTokenIds);
    }

    return new Response(
      JSON.stringify({
        ok: true,
        sent: sentCount,
        cleaned_stale_tokens: staleTokenIds.length,
        errors,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("[send-push-notification] Error:", err);
    return new Response(
      JSON.stringify({ ok: false, error: (err as Error).message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
