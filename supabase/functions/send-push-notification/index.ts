// FairTix — send-push-notification (Supabase Edge Function)
//
// Sends the PUSH half of a notification. notify_user() in
// supabase/notification_functions.sql writes a row with channel 'push' for
// events that should reach the phone (e.g. account / organizer approval).
// A Database Webhook calls this function for every new notifications row;
// this function pushes the 'push' ones through Firebase Cloud Messaging and
// ignores everything else. It mirrors send-notification-email.
//
// ONE-TIME SETUP
//   1. Create a Firebase project (https://console.firebase.google.com), add
//      the Android (and iOS) app, and run `flutterfire configure` in the app.
//   2. Firebase Console → Project settings → Service accounts → Generate new
//      private key. Save the JSON, then set it as a secret:
//        supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat service-account.json)"
//      Also reuse the secret already made for the email function:
//        NOTIFICATION_WEBHOOK_SECRET=<same long random string>
//      SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically.
//   3. Deploy:  supabase functions deploy send-push-notification
//   4. Create the webhook (Dashboard → Database → Webhooks → Create a new hook):
//        Name:   send-push-notification
//        Table:  notifications           Events: Insert
//        Type:   Supabase Edge Functions → send-push-notification
//        HTTP Headers: add   x-webhook-secret = <the same string as step 2>
//   5. Run supabase/push_notifications.sql in the SQL Editor (device tokens).
//
// SECURITY: same model as the email function. The call is refused without the
// matching x-webhook-secret header, and the request body is never trusted for
// content: the notification is re-read from the database by id and only sent
// if it is a 'push' notification. Tokens that FCM reports as dead are deleted.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const WEBHOOK_SECRET = Deno.env.get('NOTIFICATION_WEBHOOK_SECRET') ?? '';
const SERVICE_ACCOUNT_JSON = Deno.env.get('FIREBASE_SERVICE_ACCOUNT') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

type ServiceAccount = { project_id: string; client_email: string; private_key: string };

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function b64url(bytes: Uint8Array): string {
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToDer(pem: string): ArrayBuffer {
  const body = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const raw = atob(body);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out.buffer;
}

// Google OAuth2 access token for FCM, signed with the service account key.
// Cached until shortly before it expires.
let cachedToken: { value: string; expiresAt: number } | null = null;

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt - 60 > now) return cachedToken.value;

  const enc = new TextEncoder();
  const header = b64url(enc.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claim = b64url(
    enc.encode(
      JSON.stringify({
        iss: sa.client_email,
        scope: 'https://www.googleapis.com/auth/firebase.messaging',
        aud: 'https://oauth2.googleapis.com/token',
        iat: now,
        exp: now + 3600,
      }),
    ),
  );
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, enc.encode(`${header}.${claim}`)),
  );
  const assertion = `${header}.${claim}.${b64url(signature)}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!response.ok) {
    throw new Error(`Google token request failed (${response.status}): ${await response.text()}`);
  }
  const data = await response.json();
  cachedToken = { value: data.access_token, expiresAt: now + (data.expires_in ?? 3600) };
  return cachedToken.value;
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  if (!WEBHOOK_SECRET || req.headers.get('x-webhook-secret') !== WEBHOOK_SECRET) {
    return json({ error: 'Unauthorized' }, 401);
  }

  if (!SERVICE_ACCOUNT_JSON) {
    return json({ error: 'FIREBASE_SERVICE_ACCOUNT is not set for this function.' }, 500);
  }

  try {
    const payload = await req.json();

    if (payload?.type && payload.type !== 'INSERT') {
      return json({ ignored: `event type ${payload.type}` });
    }
    const notificationId = payload?.record?.notification_id as string | undefined;
    if (!notificationId) {
      return json({ ignored: 'no notification_id in payload' });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Re-read from the database instead of trusting the request body.
    const { data: notification, error: notificationError } = await supabase
      .from('notifications')
      .select('notification_id, user_id, title, message, channel, type')
      .eq('notification_id', notificationId)
      .maybeSingle();
    if (notificationError) throw new Error(notificationError.message);

    if (!notification || notification.channel !== 'push') {
      return json({ ignored: 'not a push notification' });
    }

    const { data: tokens, error: tokensError } = await supabase
      .from('device_tokens')
      .select('token')
      .eq('user_id', notification.user_id);
    if (tokensError) throw new Error(tokensError.message);
    if (!tokens || tokens.length === 0) {
      // Not an error: the user has no signed-in device (or no push permission).
      return json({ ignored: 'recipient has no registered device' });
    }

    const sa = JSON.parse(SERVICE_ACCOUNT_JSON) as ServiceAccount;
    const accessToken = await getAccessToken(sa);

    let sent = 0;
    const dead: string[] = [];
    const failures: string[] = [];

    for (const { token } of tokens) {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token,
              notification: { title: notification.title, body: notification.message },
              data: { notification_id: notification.notification_id, type: String(notification.type) },
              android: { priority: 'HIGH' },
            },
          }),
        },
      );

      if (response.ok) {
        sent++;
        continue;
      }
      const text = await response.text();
      // 404 / UNREGISTERED = the app was uninstalled or the token expired.
      if (response.status === 404 || text.includes('UNREGISTERED')) {
        dead.push(token);
      } else {
        failures.push(`${response.status}: ${text}`);
      }
    }

    if (dead.length > 0) {
      await supabase.from('device_tokens').delete().in('token', dead);
    }
    if (sent === 0 && failures.length > 0) {
      // Shows up in the webhook's delivery log.
      throw new Error(`FCM rejected the push: ${failures[0]}`);
    }

    return json({ sent, removedDeadTokens: dead.length });
  } catch (err) {
    return json({ error: (err as Error).message }, 500);
  }
});
