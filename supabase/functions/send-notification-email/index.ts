// FairTix — send-notification-email (Supabase Edge Function)
//
// Sends the EMAIL half of a notification. The database triggers in
// supabase/notification_functions.sql write two rows per event into
// public.notifications: one with channel 'in_app' (shown in the app) and
// one with channel 'email'. A Database Webhook calls this function every
// time a new row is inserted; this function emails the 'email' ones and
// ignores everything else. Works for every role (event goer, organizer,
// admin) because it simply emails whoever the notification is addressed to.
//
// ONE-TIME SETUP
//   1. Create a free Resend account (https://resend.com) and make an API key.
//        NOTE: until you verify a sending domain in Resend, Resend only
//        delivers to the email address that owns the Resend account. To
//        email other people (e.g. testers), verify a domain and set
//        NOTIFICATION_FROM_EMAIL below to an address on it.
//   2. Add these Edge Function secrets
//      (Supabase Dashboard → Edge Functions → Secrets, or the CLI):
//        RESEND_API_KEY=re_...
//        NOTIFICATION_WEBHOOK_SECRET=<any long random string you make up>
//        NOTIFICATION_FROM_EMAIL=FairTix <notifications@yourdomain.com>   (optional;
//          defaults to Resend's test sender, which only reaches your own email)
//      SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically.
//   3. Deploy this function (Dashboard → Edge Functions → Deploy a new
//      function → paste this file, name it exactly "send-notification-email",
//      or: supabase functions deploy send-notification-email).
//   4. Create the webhook (Dashboard → Database → Webhooks → Create a new hook):
//        Name:   send-notification-email
//        Table:  notifications           Events: Insert
//        Type:   Supabase Edge Functions → send-notification-email
//        HTTP Headers: add   x-webhook-secret = <the same string as step 2>
//
// SECURITY: the function refuses any call without the matching
// x-webhook-secret header, and it never trusts the request body for the
// email's content — it re-reads the notification row from the database by
// id, and only sends if that row exists and is an 'email' notification.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? '';
const WEBHOOK_SECRET = Deno.env.get('NOTIFICATION_WEBHOOK_SECRET') ?? '';
const FROM_EMAIL = Deno.env.get('NOTIFICATION_FROM_EMAIL') ?? 'FairTix <onboarding@resend.dev>';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function renderHtml(name: string, title: string, message: string): string {
  return `<!doctype html>
<html>
  <body style="margin:0;padding:24px;background:#f7f6fa;font-family:Arial,Helvetica,sans-serif;color:#1c1526;">
    <div style="max-width:480px;margin:0 auto;background:#ffffff;border-radius:14px;padding:28px;">
      <div style="font-size:20px;font-weight:800;font-style:italic;color:#7c3aed;margin-bottom:18px;">FairTix</div>
      <p style="margin:0 0 6px;font-size:14px;color:#8b87a0;">Hi ${escapeHtml(name)},</p>
      <h2 style="margin:0 0 10px;font-size:18px;">${escapeHtml(title)}</h2>
      <p style="margin:0;font-size:14px;line-height:1.5;">${escapeHtml(message)}</p>
      <hr style="border:none;border-top:1px solid #e3e0ee;margin:22px 0 12px;" />
      <p style="margin:0;font-size:11px;color:#8b87a0;">You received this because of activity on your FairTix account.</p>
    </div>
  </body>
</html>`;
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  // Only our own Database Webhook (which knows the shared secret) may call this.
  if (!WEBHOOK_SECRET || req.headers.get('x-webhook-secret') !== WEBHOOK_SECRET) {
    return json({ error: 'Unauthorized' }, 401);
  }

  if (!RESEND_API_KEY) {
    return json({ error: 'RESEND_API_KEY is not set for this function.' }, 500);
  }

  try {
    const payload = await req.json();

    // Database Webhook shape: { type: 'INSERT', table, record: {...}, ... }
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
      .select('notification_id, user_id, title, message, channel')
      .eq('notification_id', notificationId)
      .maybeSingle();
    if (notificationError) throw new Error(notificationError.message);

    if (!notification || notification.channel !== 'email') {
      return json({ ignored: 'not an email notification' });
    }

    const { data: user, error: userError } = await supabase
      .from('users')
      .select('email, full_name')
      .eq('id', notification.user_id)
      .maybeSingle();
    if (userError) throw new Error(userError.message);
    if (!user?.email) {
      return json({ ignored: 'recipient has no email address' });
    }

    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: FROM_EMAIL,
        to: [user.email],
        subject: `FairTix: ${notification.title}`,
        html: renderHtml(user.full_name ?? 'there', notification.title, notification.message),
        text: `${notification.title}\n\n${notification.message}`,
      }),
    });

    if (!response.ok) {
      // Non-2xx shows up in the webhook's delivery log, which is where to
      // look first if emails stop arriving (e.g. unverified domain).
      throw new Error(`Resend rejected the email (${response.status}): ${await response.text()}`);
    }

    return json({ sent: true });
  } catch (err) {
    return json({ error: (err as Error).message }, 500);
  }
});
