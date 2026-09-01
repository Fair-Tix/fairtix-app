// FairTix — PayMongo webhook (Supabase Edge Function)
//
// This is the AUTHORITATIVE fulfillment path: PayMongo's own servers call
// this endpoint once a Sandbox payment actually clears, so ticket issuance
// no longer has to trust the buyer's "I've Completed Payment" tap in the
// app (that tap in checkout_screen.dart is only a fast client-side path —
// see purchase_functions.sql for how the two converge without ever
// double-issuing a ticket for one payment).
//
// SETUP (one-time, in the PayMongo Dashboard → Developers → Webhooks):
//   1. Deploy this function first:
//        supabase functions deploy paymongo-webhook --no-verify-jwt
//      (--no-verify-jwt is required — PayMongo calls this anonymously, it
//      has no Supabase session to attach a JWT to.)
//   2. Add a webhook in the PayMongo Dashboard (Sandbox mode) pointing to:
//        https://<your-project-ref>.supabase.co/functions/v1/paymongo-webhook
//      Subscribe it to the "link.payment.paid" event.
//   3. Copy the "Signing Secret" PayMongo shows you (starts with whsk_...)
//      and set it here:
//        supabase secrets set PAYMONGO_WEBHOOK_SECRET=whsk_...
//   4. This function also needs the project's service_role key (to call
//      fulfill_ticket_purchase, which is deliberately locked to
//      service_role — see purchase_functions.sql). Supabase sets
//      SUPABASE_SERVICE_ROLE_KEY automatically for every Edge Function —
//      no manual step needed for that one.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const PAYMONGO_WEBHOOK_SECRET = Deno.env.get('PAYMONGO_WEBHOOK_SECRET') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

/// Verifies PayMongo's `Paymongo-Signature` header, shaped like:
///   t=1690000000,te=<hex hmac over unsigned mode>,li=<hex hmac over live mode>
/// We're in Sandbox, so we check the `te` (test) digest: HMAC-SHA256 of
/// "`${timestamp}.${rawBody}`" using the webhook signing secret, and
/// compare it to the `te` value PayMongo sent.
async function isValidSignature(rawBody: string, signatureHeader: string | null): Promise<boolean> {
  if (!PAYMONGO_WEBHOOK_SECRET || !signatureHeader) return false;

  const parts = Object.fromEntries(
    signatureHeader.split(',').map((part) => {
      const [key, value] = part.split('=');
      return [key, value];
    }),
  );
  const timestamp = parts['t'];
  const providedDigest = parts['te'];
  if (!timestamp || !providedDigest) return false;

  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(PAYMONGO_WEBHOOK_SECRET),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signed = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${timestamp}.${rawBody}`));
  const computedDigest = Array.from(new Uint8Array(signed))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');

  // Constant-time-ish compare (length-checked first) to avoid short-circuit
  // timing leaks on the common case where lengths already differ.
  if (computedDigest.length !== providedDigest.length) return false;
  let mismatch = 0;
  for (let i = 0; i < computedDigest.length; i++) {
    mismatch |= computedDigest.charCodeAt(i) ^ providedDigest.charCodeAt(i);
  }
  return mismatch === 0;
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const rawBody = await req.text();
  const signatureHeader = req.headers.get('Paymongo-Signature');

  if (!(await isValidSignature(rawBody, signatureHeader))) {
    return new Response(JSON.stringify({ error: 'Invalid webhook signature.' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  try {
    const event = JSON.parse(rawBody);
    const eventType = event?.data?.attributes?.type;

    // Only "link.payment.paid" actually confirms money moved; ignore
    // everything else (link.payment.expired, etc.) with a 200 so PayMongo
    // doesn't keep retrying a delivery we deliberately don't act on.
    if (eventType !== 'link.payment.paid') {
      return new Response(JSON.stringify({ received: true, ignored: eventType }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const linkData = event.data.attributes.data;
    const linkId = linkData.id as string;
    const remarksRaw = linkData.attributes.remarks as string | null;
    if (!remarksRaw) {
      throw new Error(`Link ${linkId} has no remarks metadata — was it created outside paymongo-checkout?`);
    }

    const { tier_id: tierId, buyer_id: buyerId } = JSON.parse(remarksRaw);
    if (!tierId || !buyerId) {
      throw new Error(`Link ${linkId} remarks missing tier_id/buyer_id.`);
    }

    // Deterministic token: matches what checkout_screen.dart computes
    // client-side ('FTX-' + link_id), so whichever fulfillment path lands
    // first wins and the other becomes a safe idempotent no-op — see
    // _do_ticket_purchase in purchase_functions.sql.
    const qrCodeToken = `FTX-${linkId}`;

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { error } = await supabase.rpc('fulfill_ticket_purchase', {
      p_tier_id: tierId,
      p_buyer_id: buyerId,
      p_qr_code_token: qrCodeToken,
    });

    if (error) throw new Error(error.message);

    return new Response(JSON.stringify({ received: true, fulfilled: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    // Non-2xx tells PayMongo to retry the delivery, which is the right
    // call for a transient failure — the idempotent token means a retry
    // that eventually succeeds still only issues one ticket.
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
