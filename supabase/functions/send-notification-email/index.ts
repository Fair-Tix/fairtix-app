// FairTix — send-notification-email (Supabase Edge Function)
//
// Sends the EMAIL half of a notification through Gmail SMTP. The database
// triggers in supabase/notification_functions.sql write two rows per event
// into public.notifications: channel 'in_app' (shown in the app) and
// channel 'email'. A Database Webhook calls this function on every INSERT;
// it emails the 'email' rows and ignores the rest. Works for every role.
//
// SETUP
//   1. In the Gmail account that will send mail, turn on 2-Step Verification,
//      then create an App Password (Google Account -> Security -> App passwords).
//   2. Add these Edge Function secrets (Dashboard -> Edge Functions -> Secrets):
//        GMAIL_USER=yourname@gmail.com
//        GMAIL_APP_PASSWORD=<16-character app password, no spaces>
//        NOTIFICATION_WEBHOOK_SECRET=<same value the webhook sends>   (already set)
//   3. Deploy (done via Supabase). Webhook header x-webhook-secret stays as is.
//
// NOTES
//   * Uses port 465 (implicit TLS); Supabase blocks ports 25 and 587.
//   * Gmail always sends "from" the authenticated account. Free Gmail allows
//     roughly 500 recipients/day, plenty for a capstone demo.
//
// SECURITY: refuses any call without the matching x-webhook-secret header and
// re-reads the notification row from the database by id instead of trusting
// the request body.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
import { SMTPClient } from 'https://deno.land/x/denomailer@1.6.0/mod.ts';

const GMAIL_USER = Deno.env.get('GMAIL_USER') ?? '';
const GMAIL_APP_PASSWORD = (Deno.env.get('GMAIL_APP_PASSWORD') ?? '').replace(/\s+/g, '');
const WEBHOOK_SECRET = Deno.env.get('NOTIFICATION_WEBHOOK_SECRET') ?? '';
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

  if (!GMAIL_USER || !GMAIL_APP_PASSWORD) {
    return json({ error: 'GMAIL_USER / GMAIL_APP_PASSWORD are not set for this function.' }, 500);
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

    const client = new SMTPClient({
      connection: {
        hostname: 'smtp.gmail.com',
        port: 465,
        tls: true,
        auth: { username: GMAIL_USER, password: GMAIL_APP_PASSWORD },
      },
    });

    try {
      await client.send({
        from: `FairTix <${GMAIL_USER}>`,
        to: user.email,
        subject: `FairTix: ${notification.title}`,
        content: `${notification.title}\n\n${notification.message}`,
        html: renderHtml(user.full_name ?? 'there', notification.title, notification.message),
      });
    } finally {
      try {
        await client.close();
      } catch (_) {
        // ignore close errors
      }
    }

    return json({ sent: true });
  } catch (err) {
    // Non-2xx shows up in the webhook's delivery log and in
    // Supabase -> Edge Functions -> Logs (e.g. wrong app password).
    console.error('send-notification-email failed:', (err as Error).message);
    return json({ error: (err as Error).message }, 500);
  }
});
