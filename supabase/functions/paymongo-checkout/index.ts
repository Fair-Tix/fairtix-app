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
//     'description': 'VIP – Some Concert',
//     'tierId': tier.id,           // the ticket_tiers.tier_id being bought
//   })
// To buy a RESALE listing instead, send { description, listingId } (no tierId):
// the price is the listing price, validated by resale_checkout_quote in
// supabase/resale_payment.sql, and the ticket is handed over by
// paymongo-verify / paymongo-webhook once PayMongo confirms payment.
// The price is computed server-side (checkout_quote in
// supabase/checkout_guard.sql); any `amount` sent by the app is ignored.
// Returns: { "checkout_url": "https://pm.link/...", "reference_number": "...", "link_id": "..." }
// For a FREE (price 0) tier there is no payment: the ticket is issued
// immediately and the response is { "free": true, "ticket_id": "...", "qr_code_token": "..." }
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
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
// Checkout Sessions (not Payment Links): only Checkout Sessions accept a
// success_url / cancel_url, which is what lets PayMongo send the buyer
// straight back into the app after paying, with no manual button tap.
const PAYMONGO_API = 'https://api.paymongo.com/v1/checkout_sessions';

// Where PayMongo sends the buyer after paying. This is a deep link the Flutter
// app listens for (see AndroidManifest.xml + checkout_screen.dart). If PayMongo
// ever rejects a custom scheme, set this secret to an https relay page that
// forwards to the app:  supabase secrets set APP_RETURN_URL_BASE=https://your-domain/payment-return
const APP_RETURN_URL_BASE = Deno.env.get('APP_RETURN_URL_BASE') ?? 'fairtix://payment';

// Organizer subscription plans live in the public.subscription_plans table
// (edited by the admin in Platform Settings; see supabase/subscription_plans.sql).
// The price is read from there HERE, never sent by the app.

// Where PayMongo sends an ORGANIZER after paying for a plan. Organizers use
// the web app, where a fairtix:// deep link does nothing, so set this to the
// https address of the organizer app if you want the payment tab to land
// somewhere useful:  supabase secrets set ORGANIZER_RETURN_URL_BASE=https://your-domain
// The plan screen confirms payment by polling paymongo-verify, so activation
// does not depend on this redirect.
const ORGANIZER_RETURN_URL_BASE = Deno.env.get('ORGANIZER_RETURN_URL_BASE') ?? APP_RETURN_URL_BASE;

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

    const { description, tierId, listingId, planId, planName } = await req.json();

    // ORGANIZER SUBSCRIPTION: an organizer pays for a plan through the same
    // PayMongo Checkout Session. The price comes from the saved plan in
    // subscription_plans (the app sends no amount) and only an active
    // organizer account may buy an active plan.
    // paymongo-verify / paymongo-webhook activate it once PayMongo says paid.
    const hasPlanId = typeof planId === 'string' && planId.length > 0;
    if (hasPlanId || (typeof planName === 'string' && planName.length > 0)) {
      const adminForPlan = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
      const planQuery = adminForPlan
        .from('subscription_plans')
        .select('plan_id, name, monthly_fee, is_active');
      const { data: planRow, error: planError } = await (
        hasPlanId ? planQuery.eq('plan_id', planId) : planQuery.eq('name', planName)
      ).maybeSingle();
      if (planError || !planRow || !planRow.is_active) {
        throw new Error('That subscription plan is not available.');
      }
      const planPrice = Number(planRow.monthly_fee);
      if (!Number.isFinite(planPrice) || planPrice < 20) {
        throw new Error('That subscription plan has an invalid price.');
      }
      const { data: profile, error: profileError } = await adminForPlan
        .from('users')
        .select('role, account_status')
        .eq('id', user.id)
        .single();
      if (profileError || profile?.role !== 'organizer') {
        throw new Error('Only organizer accounts can subscribe to a plan.');
      }
      if (profile.account_status !== 'active') {
        throw new Error('Your account is not active, so a plan cannot be purchased.');
      }

      const planItemName = `FairTix ${planRow.name} Plan - monthly subscription`;
      const planResponse = await fetch(PAYMONGO_API, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Basic ${btoa(`${PAYMONGO_SECRET_KEY}:`)}`,
        },
        body: JSON.stringify({
          data: {
            attributes: {
              line_items: [
                { currency: 'PHP', amount: Math.round(planPrice * 100), name: planItemName, quantity: 1 },
              ],
              payment_method_types: ['gcash', 'paymaya', 'card', 'grab_pay'],
              description: planItemName,
              // plan_price is the amount charged. paymongo-verify / webhook
              // activate exactly this plan at exactly this price.
              metadata: {
                plan_id: planRow.plan_id,
                plan_name: planRow.name,
                plan_price: String(planPrice),
                buyer_id: user.id,
              },
              success_url: `${ORGANIZER_RETURN_URL_BASE}/subscription-success`,
              cancel_url: `${ORGANIZER_RETURN_URL_BASE}/subscription-cancel`,
            },
          },
        }),
      });
      const planPayload = await planResponse.json();
      if (!planResponse.ok) {
        throw new Error(planPayload?.errors?.[0]?.detail ?? 'PayMongo request failed.');
      }
      return new Response(
        JSON.stringify({
          checkout_url: planPayload.data.attributes.checkout_url,
          reference_number: planPayload.data.attributes.reference_number,
          session_id: planPayload.data.id,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }
    const isResale = typeof listingId === 'string' && listingId.length > 0;

    if (!isResale && (typeof tierId !== 'string' || tierId.length === 0)) {
      throw new Error('tierId is required.');
    }

    // The server decides whether this buyer may buy this tier, and what it
    // costs. The `amount` the app sends is deliberately IGNORED: trusting it
    // would let someone pay PHP 1 for a VIP ticket. checkout_quote (see
    // supabase/checkout_guard.sql) raises a plain-sentence error if the event
    // isn't on sale, the tier is sold out, or the buyer already holds (or has
    // resold) a ticket for this event day, so no payment link is created.
    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: quoteData, error: quoteError } = isResale
      ? await admin.rpc('resale_checkout_quote', {
          p_listing_id: listingId,
          p_buyer_id: user.id,
        })
      : await admin.rpc('checkout_quote', {
          p_tier_id: tierId,
          p_buyer_id: user.id,
        });
    if (quoteError) {
      throw new Error(quoteError.message);
    }
    const quote = Array.isArray(quoteData) ? quoteData[0] : quoteData;
    const amount = Number(quote.out_amount);
    if (!Number.isFinite(amount) || amount < 0) {
      throw new Error('Could not work out the price for this ticket.');
    }

    // FREE TIER (price 0): PayMongo cannot charge zero, so there is nothing
    // to pay. Issue the ticket right away through the same server-side path a
    // paid purchase uses (so stock, the one-ticket-per-day limit, the
    // transaction row and the purchase notification all behave identically).
    // This only happens when the SERVER-computed price is 0 — the app has no
    // way to ask for it, since the amount it sends is ignored. No platform
    // fee applies (fee = 0% of 0). Each call uses a fresh token because
    // there's no PayMongo link id to derive one from; a repeat call can't
    // issue a second ticket because checkout_quote above would already have
    // refused it (the buyer now holds one for this event day).
    if (amount === 0) {
      const { data: freeData, error: freeError } = isResale
        ? await admin.rpc('fulfill_resale_purchase', {
            p_listing_id: listingId,
            p_buyer_id: user.id,
            p_payment_ref: `FTX-RS-FREE-${crypto.randomUUID()}`,
          })
        : await admin.rpc('fulfill_ticket_purchase', {
            p_tier_id: tierId,
            p_buyer_id: user.id,
            p_qr_code_token: `FTX-FREE-${crypto.randomUUID()}`,
          });
      if (freeError) {
        throw new Error(freeError.message);
      }
      const freeTicket = Array.isArray(freeData) ? freeData[0] : freeData;
      return new Response(
        JSON.stringify({
          free: true,
          ticket_id: freeTicket.ticket_id,
          qr_code_token: freeTicket.qr_code_token,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // PayMongo amounts are in centavos (smallest currency unit).
    const amountInCentavos = Math.round(amount * 100);

    // Stored in the session's `metadata` — paymongo-webhook and
    // paymongo-verify read this back once PayMongo confirms payment, so they
    // know which tier/buyer to fulfil the ticket for.
    const metadata = isResale
      ? { listing_id: listingId, buyer_id: user.id }
      : { tier_id: tierId, buyer_id: user.id };
    const itemName = (description ?? 'FairTix ticket purchase').toString().slice(0, 250);

    const response = await fetch(PAYMONGO_API, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Basic ${btoa(`${PAYMONGO_SECRET_KEY}:`)}`,
      },
      body: JSON.stringify({
        data: {
          attributes: {
            line_items: [
              { currency: 'PHP', amount: amountInCentavos, name: itemName, quantity: 1 },
            ],
            payment_method_types: ['gcash', 'paymaya', 'card', 'grab_pay'],
            description: itemName,
            metadata,
            success_url: `${APP_RETURN_URL_BASE}/success`,
            cancel_url: `${APP_RETURN_URL_BASE}/cancel`,
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
        session_id: payload.data.id,
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
