# SARVEX India — launch readiness

**Last reviewed:** 16 November 2026  
**Working branch:** `fix/public-seller-sync-security`  
**Live deployment:** Not performed  
**Release status:** Not production-ready

This document separates implemented and tested code from external integrations and launch work that are still outstanding. A successful CI run is not proof of a live marketplace.

## Implemented and checked on the working branch

- React, TypeScript, Vite and Capacitor Android app; no demo orders, sales or seeded fake products.
- Supabase client configuration validates the public URL/key and rejects service-role or secret keys in the app.
- Seller and customer state sync, cart/wishlist persistence, order RPC hardening, and role/ownership protections.
- Public seller profile projection excludes private banking, identity and contact details.
- Supplier and reseller onboarding/review tables and RPCs.
- Supplier fulfilment controls for accept/reject, pack and supplier-reported dispatch/tracking. Tracking is not courier-verified.
- Public reseller catalogue RPC exposes retail fields only and excludes supplier wholesale cost and reseller margin.
- Dropship stock reservations are atomic, idempotent, expire after 15 minutes and release stock on cancellation/expiry. They do not create an order.
- A service-role-only dropship payment confirmation ledger records webhook events only after an external server verifies the provider signature; it checks INR amount against the reservation, rejects conflicting payment-ID replays, and quarantines amount/state mismatches. It does not create an order or issue refunds.
- COD checkout is fail-closed for public clients. UI and store both block COD until required courier/payment operations exist.
- Seller/platform commission launch policy is 0%. The migration resets seller shop commission rates to 0%, enforces the constraint and preserves historical order-item snapshots.
- PostgreSQL 15 and 16 runtime migrations/tests, TypeScript/production web build, branch validation and Android debug APK workflow have passed for the latest verified code revision.

## Not enabled — do not advertise as working

1. **Live database:** GitHub Actions has a Supabase project URL/public key configured and its read-only `GET /products` connectivity check passed. This proves only that the REST endpoint responded; it does not prove schema readiness or safe writes. The live project still has only the four legacy public tables (`cart_items`, `customer_profiles`, `products`, `seller_shops`), and no production migration has been applied. The inspected legacy grants/policies are too broad for real marketplace use. Do not enable customer transactions until the reviewed migrations and owner-bound RLS/grants are applied and re-audited.
2. **Customer checkout:** Direct-seller COD is disabled. No alternative online payment provider is configured.
3. **Courier operations:** No courier account/API is connected. PIN-code serviceability, rate quotes, pickup booking, AWB generation, courier event tracking, COD cash collection and remittance are not verified.
4. **Seller settlement:** No live COD/payment reconciliation or automated seller payout exists.
5. **Dropship checkout:** A server-only payment-event recording boundary now exists, but no payment provider/webhook verifier is connected. No payment-confirmed reservation conversion, supplier allocation creation, customer order, COD or customer checkout UI exists. Verified events remain pending conversion; mismatched/late events require manual review and must be reconciled/refunded before stock is released.
6. **Returns/refunds:** A complete customer return, refund, failed-delivery/RTO and seller liability workflow is not live.
7. **Store release:** The CI artifact is a debug APK. A signed release build requires a user-controlled signing key and release configuration.

## Approved launch pricing recorded in code

- Seller registration/listing fee: ₹0.
- Seller/platform commission: 0%.
- Customer platform fee: ₹0.
- COD handling fee: not enabled; no fee is charged.
- Shipping: actual provider/seller cost only when a real quote is available. Do not display free shipping or invent a charge.

Changing these prices requires an explicit policy decision and a reviewed migration. Do not silently introduce a 1% customer fee, COD handling fee or commission.

## External prerequisites before real launch

- Apply the reviewed migrations to the intended Supabase project only after explicit deployment approval; then re-audit live RLS/grants. Never put service-role keys in the Android app.
- Configure Supabase Authentication → URL Configuration with the real HTTPS app Site URL and exact Redirect URL. The app uses `VITE_APP_URL` (or a non-local HTTPS hosting origin) for email confirmation; localhost and Capacitor's local origin are deliberately not used as email redirects. Android deep-link return still needs a separately verified app-link configuration and device test.
- First administrator bootstrap through the documented privileged procedure.
- Real approved sellers, authorized product images/descriptions, inventory and seller payout/KYC information.
- A courier/provider merchant account and credentials for serviceability, shipment creation, tracking and COD remittance. Provider costs and service terms must be reviewed first.
- If online payments are offered, a payment-gateway merchant account, verified webhook signature handling, refunds and settlement reconciliation.
- Written supplier/seller agreements covering dispatch SLA, returns, failed delivery, damage/loss, customer support and remittance.
- Authorized supplier catalogues or official APIs/feeds for third-party product sourcing. Do not scrape or copy marketplace listings/images without permission.

## Deployment safety

- All changes remain on `fix/public-seller-sync-security`.
- `main` has not been merged or modified by this work.
- No live Supabase SQL was executed and no production deployment was made.
- Do not merge, deploy, enable COD or issue a production-ready claim until the missing external integrations and end-to-end tests are complete.
