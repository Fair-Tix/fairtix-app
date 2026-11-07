-- =============================================================================
-- FairTix - deployment check (STRICTLY READ-ONLY)
--
-- Paste into the Supabase SQL Editor and run it. It is ONE select statement
-- that reads only database metadata (information_schema, pg_proc, pg_class,
-- pg_trigger, pg_policies). It does not read any user or business record
-- (no users, tickets, transactions, events ... rows), and it does not insert,
-- update, delete, create, alter or drop anything. Safe to run any time.
--
-- Output: one row per check, problems first. The first row is a summary.
--   status OK        = found
--   status MISSING   = not found: the matching supabase/*.sql file has probably
--                      not been run on this project (or the project uses a
--                      different name, so check the project's SQL file first)
--
-- The lists below were taken from the project's own SQL files and the Flutter
-- code. They prove an object EXISTS, not that its body is the latest version
-- of the file, and not that it behaves correctly. NOT checked here (verify in
-- the Supabase Dashboard): storage buckets and storage policies
-- (event_banners, event documents, profile photos), Edge Function deployments
-- (paymongo-checkout, paymongo-verify, paymongo-webhook, send-notification-
-- email, send-push-notification), function secrets, the PayMongo webhook,
-- Realtime settings, grants/revokes, and the data itself.
-- =============================================================================

with
req_tables(t) as (values
  ('users'), ('events'), ('ticket_tiers'), ('tickets'), ('transactions'),
  ('refunds'), ('resale_listings'), ('notifications'),
  ('organizer_subscriptions'), ('subscription_plans'), ('scanner_sessions'),
  ('qr_scan_logs'), ('ticket_checkins'), ('fraud_alerts'),
  ('account_reviews'), ('admin_audit_log')
),
req_columns(t, c) as (values
  ('users', 'id'), ('users', 'email'), ('users', 'full_name'),
  ('users', 'role'), ('users', 'id_verification_status'),
  ('users', 'account_status'), ('users', 'created_at'),
  ('users', 'verified_at'), ('users', 'organization_name'),

  ('events', 'event_id'), ('events', 'parent_event_id'),
  ('events', 'day_number'), ('events', 'organizer_id'), ('events', 'title'),
  ('events', 'status'), ('events', 'event_type'),
  ('events', 'event_start_date'), ('events', 'event_end_date'),
  ('events', 'start_time'), ('events', 'ticket_scope'),
  ('events', 'banner_image_url'), ('events', 'created_at'),
  ('events', 'deleted_at'),

  ('ticket_tiers', 'tier_id'), ('ticket_tiers', 'event_id'),
  ('ticket_tiers', 'tier_name'), ('ticket_tiers', 'base_price'),
  ('ticket_tiers', 'total_quantity'), ('ticket_tiers', 'remaining_quantity'),

  ('tickets', 'ticket_id'), ('tickets', 'tier_id'),
  ('tickets', 'ticket_status'), ('tickets', 'purchase_price'),
  ('tickets', 'service_fee'), ('tickets', 'qr_code_token'),

  ('transactions', 'transaction_id'), ('transactions', 'ticket_id'),
  ('transactions', 'buyer_id'), ('transactions', 'seller_id'),
  ('transactions', 'transaction_type'), ('transactions', 'amount'),
  ('transactions', 'platform_fee'), ('transactions', 'status'),
  ('transactions', 'created_at'),

  ('refunds', 'refund_id'), ('refunds', 'amount'), ('refunds', 'reason'),
  ('refunds', 'status'), ('refunds', 'created_at'),
  ('refunds', 'processed_at'),

  ('subscription_plans', 'plan_id'), ('subscription_plans', 'name'),
  ('subscription_plans', 'monthly_fee'),
  ('subscription_plans', 'platform_fee_rate'),
  ('subscription_plans', 'max_events_per_month'),
  ('subscription_plans', 'max_tickets_per_day'),
  ('subscription_plans', 'max_multiday_days'),
  ('subscription_plans', 'can_export'), ('subscription_plans', 'benefits'),
  ('subscription_plans', 'badge'), ('subscription_plans', 'sort_order'),
  ('subscription_plans', 'is_active'),

  ('organizer_subscriptions', 'user_id'),
  ('organizer_subscriptions', 'plan_id'),
  ('organizer_subscriptions', 'monthly_fee'),
  ('organizer_subscriptions', 'start_date'),
  ('organizer_subscriptions', 'end_date'),
  ('organizer_subscriptions', 'status'),

  ('qr_scan_logs', 'log_id'), ('qr_scan_logs', 'scan_result'),
  ('qr_scan_logs', 'scanned_at'), ('qr_scan_logs', 'session_id'),

  -- the columns list_my_scanner_sessions() (organizer_tools.sql) reads
  ('scanner_sessions', 'session_id'), ('scanner_sessions', 'event_id'),
  ('scanner_sessions', 'organizer_id'), ('scanner_sessions', 'session_pin'),
  ('scanner_sessions', 'session_token'), ('scanner_sessions', 'status'),
  ('scanner_sessions', 'created_at'), ('scanner_sessions', 'expires_at'),

  ('notifications', 'channel'), ('notifications', 'sent_at'),

  ('fraud_alerts', 'alert_id'), ('fraud_alerts', 'alert_type'),
  ('fraud_alerts', 'source'), ('fraud_alerts', 'severity'),
  ('fraud_alerts', 'status'), ('fraud_alerts', 'user_id'),
  ('fraud_alerts', 'event_id'), ('fraud_alerts', 'ticket_id'),
  ('fraud_alerts', 'listing_id'), ('fraud_alerts', 'details'),
  ('fraud_alerts', 'created_at'), ('fraud_alerts', 'reviewed_by'),
  ('fraud_alerts', 'reviewed_at'), ('fraud_alerts', 'resolution_note'),

  ('account_reviews', 'review_id'), ('account_reviews', 'applicant_type'),
  ('account_reviews', 'action'), ('account_reviews', 'reason'),
  ('account_reviews', 'actor_id'), ('account_reviews', 'created_at'),

  ('admin_audit_log', 'log_id'), ('admin_audit_log', 'actor_id'),
  ('admin_audit_log', 'action'), ('admin_audit_log', 'target_type'),
  ('admin_audit_log', 'target_id'), ('admin_audit_log', 'target_label'),
  ('admin_audit_log', 'details'), ('admin_audit_log', 'created_at')
),
req_functions(f) as (values
  ('is_admin'), ('notify_user'), ('admin_review_account'),
  ('send_announcement'), ('admin_save_subscription_plans'),
  ('_organizer_plan'), ('plan_fee_rate'), ('organizer_fee_rate'),
  ('create_event_with_days'), ('update_event_details'), ('cancel_event'),
  -- purchase_ticket is NOT listed: purchase_functions.sql drops it on purpose
  -- (it issued tickets without checking payment). Tickets now come only from
  -- fulfill_ticket_purchase, called by paymongo-verify / paymongo-webhook.
  ('delete_event'), ('fulfill_ticket_purchase'),
  ('_do_ticket_purchase'), ('_do_resale_purchase'), ('checkout_quote'),
  ('resale_checkout_quote'), ('ticket_slot_used'), ('event_slot_ids'),
  ('list_ticket_for_resale'), ('cancel_resale_listing'),
  ('get_resale_market'), ('expire_resale_listings'), ('scan_ticket'),
  ('get_my_transactions'), ('admin_transaction_report'),
  ('admin_revenue_report'), ('admin_revenue_by_plan'),
  ('admin_revenue_daily'), ('admin_revenue_monthly'),
  ('organizer_escrow_overview'), ('organizer_tier_sales'),
  ('get_event_summary'), ('event_feed_organizers'),
  ('resubmit_organizer_application'), ('admin_process_refund'),
  -- list_my_scanner_sessions and send_organizer_announcement are both in
  -- organizer_tools.sql; organizer_tier_sales is in organizer_escrow.sql.
  ('list_my_scanner_sessions'), ('send_organizer_announcement'),
  -- trigger FUNCTIONS (the triggers themselves are checked below)
  ('trg_set_verified_at'), ('trg_notify_user_review'),
  ('trg_notify_transaction')
),
-- (table, trigger name) as created by user_verified_at.sql and
-- notification_functions.sql. The trigger names differ from their functions.
req_triggers(t, tg) as (values
  ('users', 'set_verified_at'),
  ('users', 'notify_on_user_review'),
  ('transactions', 'notify_on_transaction')
),
req_rls(t) as (values
  ('users'), ('events'), ('ticket_tiers'), ('tickets'), ('transactions'),
  ('refunds'), ('resale_listings'), ('notifications'),
  ('organizer_subscriptions'), ('subscription_plans'), ('scanner_sessions'),
  ('qr_scan_logs'), ('fraud_alerts'), ('account_reviews'),
  ('admin_audit_log')
),
req_policies(t, p) as (values
  ('users', 'users_select_own_or_admin'),
  ('users', 'users_update_own_or_admin'),
  ('subscription_plans', 'subscription_plans_select_signed_in')
),
checks as (
  select 1 as ord, 'table' as kind, 'public.' || t as item,
         exists (select 1 from information_schema.tables
                  where table_schema = 'public' and table_name = t
                    and table_type = 'BASE TABLE') as ok
    from req_tables
  union all
  select 2, 'column', 'public.' || t || '.' || c,
         exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = t
                    and column_name = c)
    from req_columns
  union all
  select 3, 'function', 'public.' || f || '()',
         exists (select 1 from pg_proc p
                   join pg_namespace n on n.oid = p.pronamespace
                  where n.nspname = 'public' and p.proname = f)
    from req_functions
  union all
  -- fix_notify_user_overloads.sql: only ONE notify_user may exist.
  select 3, 'function', 'public.notify_user() has exactly one definition',
         (select count(*) from pg_proc p
            join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname = 'notify_user') = 1
  union all
  select 4, 'trigger', 'public.' || t || ' : ' || tg,
         exists (select 1 from pg_trigger x
                   join pg_class c on c.oid = x.tgrelid
                   join pg_namespace n on n.oid = c.relnamespace
                  where not x.tgisinternal and x.tgname = tg
                    and n.nspname = 'public' and c.relname = t)
    from req_triggers
  union all
  select 5, 'row level security', 'public.' || t || ' (RLS enabled)',
         coalesce((select c.relrowsecurity from pg_class c
                     join pg_namespace n on n.oid = c.relnamespace
                    where n.nspname = 'public' and c.relname = t
                      and c.relkind = 'r'), false)
    from req_rls
  union all
  select 6, 'policy', 'public.' || t || ' has at least one policy',
         exists (select 1 from pg_policies
                  where schemaname = 'public' and tablename = t)
    from req_rls
  union all
  select 6, 'policy', 'public.' || t || ' : ' || p,
         exists (select 1 from pg_policies
                  where schemaname = 'public' and tablename = t
                    and policyname = p)
    from req_policies
)
select kind, item, status
from (
  select 0 as ord, 'summary' as kind,
         (count(*) filter (where not ok))::text || ' missing of '
           || count(*)::text || ' checks' as item,
         case when count(*) filter (where not ok) = 0
              then 'OK' else 'ATTENTION' end as status
    from checks
  union all
  select ord, kind, item, case when ok then 'OK' else 'MISSING' end
    from checks
) s
order by (status = 'OK'), ord, item;
