# SARVEX INDIA — Safe Repair Report (2026-11-10)

## Scope and safety
- Work was performed on a separate extracted copy of the uploaded `sarvex-india.zip`.
- The original uploaded ZIP was not modified.
- No live Supabase project was contacted and no SQL migration was executed.
- Both SQL migration files and `supabase-schema.sql` were intentionally left unchanged because the two migration files differ substantially and must be reconciled before any database deployment.

## Changes applied

### 1. Demo/fake marketplace data removed from application state
- Seeded seller, product, review, and order arrays are now empty.
- The initial cart and wishlist are empty.
- Hard-coded category item counts were reset to zero.
- Existing localStorage marketplace cache is no longer restored or written; this prevents old demo records and private profile/shop/order data from being treated as authoritative local records.
- Product ratings, rating counts, seller names, badges, and images no longer receive invented fallback values when database fields are absent.
- Product cards/details now show neutral no-image/no-rating states when those values are missing.

### 2. Authentication and transaction behaviour hardened
- Offline/demo login success was removed. Sign-in/sign-up now require Supabase configuration and real Supabase Auth.
- Sign-up creates a customer profile by default. A seller role cannot be self-assigned; seller access depends on an approved shop in the database.
- Failed profile creation no longer reports a successful account registration.
- COD checkout is blocked unless Supabase is connected, the customer is authenticated, and the cart contains products.
- Checkout calls the 9-argument `place_sarvex_order` RPC with an idempotency key. The same pending payload reuses its key on retry.
- The client requires a database-confirmed order response before creating a local order confirmation.
- Checkout address fields no longer start with fabricated New Delhi address/PIN details.

### 3. Seller isolation and real database writes
- Seller Portal selects only the shop owned by the authenticated user; the test seller switcher was removed.
- Seller applications require an authenticated account and are saved to Supabase before being shown as submitted.
- Seller applications start pending; commission is left to the database default/trigger (10% in the root migration), not client-controlled.
- Product creation requires the current user's approved shop and a successful database insert.
- Sellers cannot choose SARVEX assurance badges; the database controls those fields.
- Product deletion, seller approval/rejection, and order-item status changes update the database first. Local UI state changes only after the database confirms the operation.
- Seller order fulfilment reads from `seller_order_items_view`, not the customer/admin-only base `orders` table.

### 4. Reviews and status data
- Review submission requires authenticated Supabase and a real product UUID.
- Verified-buyer status is submitted as false and is determined by database triggers, not client-side order-cache checks.
- Helpful votes require a successful database RPC; no local-only vote count is fabricated.
- `packed` was added to the app's order status type and visible status choices.
- Order tracking copy no longer promises SARVEX Express logistics, guaranteed returns, or payment collection that is not integrated.

### 5. Misleading UI claims reduced
- Supabase configuration is labelled as configured, not connected/active, until a connection test is run.
- The “copy SQL schema” helper containing unsafe public insert/select policies was removed.
- Fake discount, commission, return, seller-verification, and delivery claims were removed or changed to conditional/under-review wording.

## Files changed
- `src/lib/marketplaceStore.ts`
- `src/types/marketplace.ts`
- `src/components/SellerPortal.tsx`
- `src/components/CheckoutModal.tsx`
- `src/components/DatabaseSettingsCard.tsx`
- `src/components/Header.tsx`
- `src/components/AdminDashboard.tsx`
- `src/components/BannerSlider.tsx`
- `src/components/ProductCard.tsx`
- `src/components/ProductDetailModal.tsx`
- `src/components/ProductReviews.tsx`
- `src/components/AuthModal.tsx`
- `src/components/OrderTrackingModal.tsx`
- `src/App.tsx`

## Verification status
- ZIP archive integrity before changes: PASS (original archive was readable).
- Static TypeScript/JSX parse-oriented check: no non-dependency diagnostics were emitted for the changed files.
- Full TypeScript check: BLOCKED because project dependencies are not installed and `vite/client`, React, Supabase and icon packages are unavailable in this environment.
- Dependency installation: BLOCKED; offline npm cache does not contain required packages. No package downloads were attempted.
- Production build: NOT RUN / BLOCKED by missing dependencies.
- Automated tests: NOT RUN; no installed test runner/dependencies were available.
- Live Supabase connection, RLS, Auth, RPC and storage behaviour: NOT VERIFIED; no live project access was used.
- SQL migration consistency/security: NOT VERIFIED by execution. The SQL files were not changed.

## Important remaining blockers before launch
1. Compare and reconcile `supabase-production-migration.sql` (root) with `public/supabase-production-migration.sql` (public folder). They are different files; do not run both.
2. Confirm the exact deployed schema matches the root migration, especially `seller_order_items_view`, `place_sarvex_order` overloads, and RLS policies.
3. Run a full build and tests in an environment with the exact package dependencies installed.
4. Verify Supabase Auth signup, seller application, admin approval, product creation, COD checkout retry, reviews and seller order status using a separate test project before production.
5. Configure and test delivery, returns/refunds, seller payouts, KYC workflow, customer order history, and release signing. These are not complete merely because UI components exist.

## Launch assessment
**NOT READY FOR PRODUCTION.** The changes remove important demo/fallback behaviours and improve client-side safety, but server-side security and end-to-end functionality still require verification against the actual Supabase project.
