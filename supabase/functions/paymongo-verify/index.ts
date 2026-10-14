// FairTix — PayMongo payment verifier (Supabase Edge Function)
//
// Called by the app automatically when PayMongo redirects the buyer back via
// the fairtix://payment/success deep link (and when the app returns to the
// foreground). Instead of trusting the redirect, this function asks PayMongo's
// API directly whether the Checkout Session is actually PAID, and only then
// issues the ticket (via fulfill_ticket_purchase, which is locked to
// service_role). A failed, abandoned, or canceled payment therefore never
// produces a ticket.
//
// The tier and buyer come from the link's `remarks` (written server-side
// by paymongo-checkout), NOT from the request body, so a client can't pay
// for a cheap tier and claim an expensive one, or claim someone else's
// payment: the link's buyer_id must match the signed-in caller.
//
// Deploy with:
//   supabase functions deploy paymongo-verify
// (uses the same PAYMONGO_SECRET_KEY secret as paymongo-checkout; the
// service role key is provided automatically by Supabase.)
//
// Called from Flutter as:
//   supabase.functions.invoke('paymongo-verify', body: {'sessionId': sessionId})
// Returns: { ticket_id, qr_code_token } on success, or a non-2xx with
// { error } if the payment isn't confirmed.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const PAYMONGO_SECRET_KEY = Deno.env.get('PAYMONGO_SECRET_KEY') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const PAYMONGO_API = 'https://api.paymongo.com/v1/checkout_sessions';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (!PAYMONGO_SECRET_KEY) {
    return json({ error: 'PAYMONGO_SECRET_KEY is not configured on this function.' }, 500);
  }

  try {
    // Identify the caller from their Supabase session.
    const authHeader = req.headers.get('Authorization') ?? '';
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();
    if (userError || !user) {
      return json({ error: 'You need to be signed in to verify a payment.' }, 401);
    }

    const { sessionId } = await req.json();
    if (typeof sessionId !== 'string' || sessionId.length === 0) {
      return json({ error: 'sessionId is required.' }, 400);
    }

    // Ask PayMongo itself — this is the source of truth for payment status.
    const pmResponse = await fetch(`${PAYMONGO_API}/${encodeURIComponent(sessionId)}`, {
      method: 'GET',
      headers: { Authorization: `Basic ${btoa(`${PAYMONGO_SECRET_KEY}:`)}` },
    });
    const pmPayload = await pmResponse.json();
    if (!pmResponse.ok) {
      const message = pmPayload?.errors?.[0]?.detail ?? 'Could not check the payment with PayMongo.';
      return json({ error: message }, 502);
    }

    const attrs = pmPayload.data.attributes;
    // A Checkout Session is paid once one of its payments has status "paid"
    // (or its payment intent has succeeded).
    const payments: Array<{ attributes?: { status?: string } }> = attrs.payments ?? [];
    const isPaid =
      payments.some((p) => p?.attributes?.status === 'paid') ||
      attrs.payment_intent?.attributes?.status === 'succeeded';
    if (!isPaid) {
      return json(
        {
          error:
            'We have not received a successful payment for this checkout. If you canceled or the payment failed, no ticket was issued and you have not been charged. You can try again.',
          payment_status: attrs.status ?? 'unpaid',
        },
        402,
      );
    }

    // Payment is confirmed. Read tier/buyer from the server-written metadata.
    const remarks: { tier_id?: string; buyer_id?: string } = attrs.metadata ?? {};
    if (!remarks.tier_id || !remarks.buyer_id) {
      return json({ error: 'This payment was not created by FairTix checkout.' }, 400);
    }
    if (remarks.buyer_id !== user.id) {
      return json({ error: 'This payment belongs to a different account.' }, 403);
    }

    // Same deterministic token as paymongo-webhook, so whichever of the two
    // runs first issues the ticket and the other is a harmless no-op.
    const qrCodeToken = `FTX-${sessionId}`;
    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data, error } = await admin.rpc('fulfill_ticket_purchase', {
      p_tier_id: remarks.tier_id,
      p_buyer_id: remarks.buyer_id,
      p_qr_code_token: qrCodeToken,
    });
    if (error) {
      return json({ error: error.message }, 400);
    }

    const ticket = Array.isArray(data) ? data[0] : data;
    return json({ ticket_id: ticket.ticket_id, qr_code_token: ticket.qr_code_token }, 200);
  } catch (err) {
    return json({ error: (err as Error).message }, 500);
  }
});
