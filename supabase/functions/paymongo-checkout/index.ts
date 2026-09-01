// FairTix — PayMongo Sandbox checkout link creator (Supabase Edge Function)
//
// WHY THIS IS AN EDGE FUNCTION AND NOT CLIENT CODE: creating a PayMongo
// Payment Link requires your PayMongo *secret* key. A secret key must
// never ship inside the Flutter app (anyone could decompile the app and
// drain/misuse your PayMongo account with it) — unlike the Supabase
// anon/publishable key, which is safe client-side because RLS enforces
// access. This function holds the PayMongo secret key server-side (as an
// Edge Function secret) and the Flutter app calls this function instead
// of PayMongo directly.
//
// Deploy with:
//   supabase functions deploy paymongo-checkout
//   supabase secrets set PAYMONGO_SECRET_KEY=sk_test_xxxxxxxx
// (Get a free sk_test_... key from the PayMongo Dashboard → Sandbox mode
// → Developers → API Keys: https://dashboard.paymongo.com)
//
// Called from Flutter as:
//   supabase.functions.invoke('paymongo-checkout', body: {
//     'amount': totalPesos,        // e.g. 550.0
//     'description': 'VIP – Some Concert',
//     'tierId': tier.id,           // the ticket_tiers.tier_id being bought
//   })
// Returns: { "checkout_url": "https://pm.link/...", "reference_number": "...", "link_id": "..." }
//
// The caller's Supabase auth session (sent automatically by
// `functions.invoke`) is used to look up their user id server-side, which
// gets embedded (along with tierId) into the PayMongo link's `remarks`
// field so paymongo-webhook can fulfil the right ticket once payment
// clears.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const PAYMONGO_SECRET_KEY = Deno.env.get('PAYMONGO_SECRET_KEY') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const PAYMONGO_API = 'https://api.paymongo.com/v1/links';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (!PAYMONGO_SECRET_KEY) {
    return new Response(
      JSON.stringify({
        error:
          'PAYMONGO_SECRET_KEY is not configured on this function. Run: supabase secrets set PAYMONGO_SECRET_KEY=sk_test_...',
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  try {
    // Identify the buyer server-side from their Supabase session, rather
    // than trusting a client-supplied buyer id — this is the identity the
    // paymongo-webhook function will later use to fulfil the ticket, so it
    // must be verified, not just asserted by the client.
    const authHeader = req.headers.get('Authorization') ?? '';
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();
    if (userError || !user) {
      throw new Error('You need to be signed in to start a checkout.');
    }

    const { amount, description, tierId } = await req.json();

    if (typeof amount !== 'number' || amount <= 0) {
      throw new Error('amount must be a positive number (in pesos).');
    }
    if (typeof tierId !== 'string' || tierId.length === 0) {
      throw new Error('tierId is required.');
    }

    // PayMongo amounts are in centavos (smallest currency unit).
    const amountInCentavos = Math.round(amount * 100);

    // Packed into `remarks` since the Links API has no dedicated metadata
    // field — paymongo-webhook parses this back out once PayMongo confirms
    // payment, so it knows which tier/buyer to fulfil the ticket for.
    const remarks = JSON.stringify({ tier_id: tierId, buyer_id: user.id });

    const response = await fetch(PAYMONGO_API, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Basic ${btoa(`${PAYMONGO_SECRET_KEY}:`)}`,
      },
      body: JSON.stringify({
        data: {
          attributes: {
            amount: amountInCentavos,
            description: description ?? 'FairTix ticket purchase',
            remarks,
          },
        },
      }),
    });

    const payload = await response.json();

    if (!response.ok) {
      const message = payload?.errors?.[0]?.detail ?? 'PayMongo request failed.';
      throw new Error(message);
    }

    const attrs = payload.data.attributes;
    return new Response(
      JSON.stringify({
        checkout_url: attrs.checkout_url,
        reference_number: attrs.reference_number,
        link_id: payload.data.id,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
