# SARVEX Supplier and Dropshipping Design

## Status

Foundation and a read-only public catalogue projection implemented on the working branch only. The repository contains private supplier/stock/offer/reseller/allocation/event tables, authenticated supplier/reseller RPCs, a seller-side supplier workspace, an admin review queue, and an anonymous-safe retail-only catalogue RPC. This is not a live deployment and does not enable customer dropship checkout, supplier order allocation, COD, or courier automation.

## Business roles

- **Supplier:** An approved business that owns or controls stock. A supplier may sell its own stock directly to customers and may separately offer eligible stock to approved resellers.
- **Dropshipping seller (reseller):** An approved SARVEX seller who selects an active supplier offer, sets a retail price, and sells to a customer without holding the stock.
- **Customer:** Buys at the public retail price. Supplier cost and reseller margin are private.
- **SARVEX admin:** Reviews supplier and reseller onboarding, handles disputes, and configures platform fees.

A supplier may also be a normal seller, but supplier capability must be separately approved. Do not infer supplier status from an ordinary seller account.

## Product and offer model

Keep the existing public product/catalog identity separate from the supplier's commercial offer:

1. A supplier-owned stock record identifies the supplier, product, available quantity, dispatch origin, and fulfilment terms.
2. A supplier offer records the supplier's wholesale/dropship price, currency (INR), minimum order quantity, active state, and whether direct-to-customer dispatch is permitted.
3. A reseller listing references one approved supplier offer and stores the reseller's retail price and public product presentation.
4. Direct supplier retail listings remain supported and must not expose supplier-only wholesale prices.

Do not put supplier cost or margin in public product rows, public views, browser storage, or customer-facing APIs.

## Order and money model

At checkout, the database must snapshot (not later recalculate) the following per order item:

- fulfilment mode: seller-dispatch or supplier-dropship;
- supplier and reseller seller IDs, where applicable;
- supplier cost, reseller retail price, quantity, shipping charge and who is responsible for it;
- SARVEX fee rate and amount, and the calculated payable amounts;
- the supplier offer and stock record used.

All money calculations must be server-side in a trusted PostgreSQL transaction using fixed-precision NUMERIC values. Client-provided supplier cost, commission, margin, payable, stock, or supplier identity must never be trusted.

For a dropship item, the customer pays the retail amount through the configured payment method. The database must separately record the amount owed to the supplier and the reseller's gross margin before applicable fees/expenses. Do not claim that SARVEX can collect, split, or settle money automatically until a real payment/payout provider and reconciliation process have been integrated and tested.

## Stock and fulfilment safety

- Reserve supplier stock atomically during checkout; prevent overselling under concurrent orders.
- Revalidate offer active state, supplier approval, price, stock, dispatch eligibility and destination coverage in the checkout transaction.
- A supplier must accept or reject an order within a configured period. Unaccepted orders must not silently remain confirmed.
- Supplier dispatch must capture courier name, tracking reference, dispatch time and proof-of-dispatch metadata.
- Keep supplier dispatch and reseller/customer communication responsibilities explicit.
- Do not expose supplier contact, internal notes, wholesale price, or other suppliers' stock to customers or unrelated sellers.
- Cancellation, return, refund, damaged/lost parcel, failed delivery and COD remittance responsibilities must be defined before enabling real orders.
- COD must remain disabled for dropship offers until supplier collection/remittance, failed-delivery and return reconciliation are implemented and tested.
- Do not invent courier integrations, tracking events, serviceability, delivery dates, supplier verification, or stock availability.

## Security and database requirements

The implementation must use separate private tables for supplier profiles, stock, supplier offers, reseller listings, supplier order allocations, and fulfilment events. Apply RLS and least-privilege grants to each table. Public catalog views must expose only approved retail fields.

Use database constraints and SECURITY DEFINER RPCs with fixed search_path for sensitive transitions. Revoke function execution from PUBLIC/anon by default. Check exact ownership and approval state on every mutation. Prevent sellers from changing supplier identity, wholesale price snapshots, supplier payable, fee snapshots, or order ownership after checkout.

Extend the existing strict policy-verification and smoke-test framework deliberately; do not weaken it or silently permit unknown policies. Add PostgreSQL 15 and 16 tests for:
- supplier approval and isolation;
- direct supplier retail vs reseller offer visibility;
- private wholesale price and margin isolation;
- atomic stock reservation under concurrent checkout;
- tampered price, supplier ID, quantity and payout rejection;
- supplier acceptance, dispatch and tracking permissions;
- cancellation, refund, return and COD restrictions;
- migration re-application and existing-data preservation.

## Delivery plan

1. **Schema and threat-model review:** map the current checkout RPC, order-item triggers, views, RLS policies, and app interfaces. No live database writes.
2. **Database foundation:** add idempotent supplier/offer/reseller tables, constraints, private views and trusted RPCs. Add PG15/16 tests before UI integration.
3. **Supplier portal:** supplier onboarding, admin approval, stock/offer management, order acceptance and dispatch tracking.
4. **Reseller portal:** browse approved dropship offers, set retail price, manage listings and view supplier fulfilment status without seeing private supplier data.
5. **Customer and admin flows:** clear delivery/return terms, accurate order tracking, dispute tools and fee reporting.
6. **Enablement gate:** keep dropshipping checkout disabled until database tests, app build, security review, and live Supabase/device verification are all complete.

## Current limitations

The existing customer checkout still supports only seller-owned products and the current COD order RPC. The supplier foundation now models supplier profiles, private stock, wholesale offers, reseller listings, supplier order allocations, and fulfilment event records. Authenticated RPCs support supplier application, supplier stock entry, offer submission, reseller listing submission, admin approval, and scoped workspace/discovery reads. The Seller Portal has supplier/reseller forms and the Admin Dashboard has review queues. An incremental migration adds `browse_public_reseller_catalogue()`, which returns only approved retail-facing fields for active listings with approved supplier/reseller shops, active direct-dispatch offers, active stock, and sufficient quantity. Its anonymous-access test asserts wholesale cost, supplier contact/address, supplier IDs, and reseller margin are absent. The catalogue remains a read-only projection; it does not provide cart, checkout, reservation, payment, or fulfilment.e not joined into the customer catalogue or checkout. No supplier order allocation is created at purchase time; no customer-facing dropship order, supplier acceptance workflow, payment split, courier booking, live tracking, COD remittance, or returns automation is implemented.

## External marketplace links and delivery automation

A pasted product URL is an **import request**, not permission to copy or resell the item. The import flow must first identify the source and use an approved method:

- Prefer a supplier-provided catalogue/feed, a signed supplier integration, or an official marketplace API for which SARVEX and the relevant seller/partner have valid access.
- Flipkart's published Marketplace APIs are seller/partner APIs. Its documentation requires seller registration and application/token setup; it describes listing and order-management functions. Do not treat them as a public API for scraping arbitrary consumer product pages or as automatic permission to resell another seller's stock.
- Meesho connector availability, eligibility, and permitted resale/catalogue access must be confirmed directly with Meesho or an authorised integration partner before implementation. Do not assume a public API exists or scrape its website/app.
- If no authorised connector exists, allow a manual supplier-approved product form or catalogue file instead. Show a review screen for title, images, variant, price, stock, shipping origin, rights/permission and supplier identity before publishing.
- Never ask users to paste marketplace passwords, session cookies, OTPs, or private access tokens into product-link import. Store any approved integration credentials server-side only, encrypted and scoped to the connected seller.

A safe connector should use source-specific adapters behind a server-side interface. Each import must record source, external item/SKU ID, supplier identity, permission/connection owner, last verified price/stock timestamp, and sync status. Price or stock changes must pause or update the listing according to configured rules; stale or unavailable source data must not be presented as live stock. Keep the public SARVEX listing's own retail price separate from the source/wholesale cost.

### Delivery automation

Use a courier adapter layer, not a hard-coded promise of a particular courier. A provider integration can, when the account and service support it, check serviceability/rates, create a shipment, book pickup, retrieve labels/AWB, receive tracking webhooks, and initiate eligible returns. Shiprocket publishes APIs for order creation, courier/shipment operations and tracking; actual account eligibility, fees, pickup coverage and COD settlement must be checked before enabling it.

For supplier-dropship orders, the pickup origin must be the supplier's approved dispatch address. The supplier must authorise SARVEX to create the shipment from that address and provide package weight/dimensions and dispatch readiness. Never silently use SARVEX or reseller address as the pickup point. If a supplier is not connected to the selected courier account, route the order to a manual supplier-fulfilment state rather than claiming automatic dispatch.

Automated delivery is a staged capability:
1. provider account and API access approved;
2. secure server-side credentials and webhook signature verification;
3. sandbox shipment/label/tracking tests;
4. pickup-origin ownership and serviceability checks;
5. COD remittance, RTO, cancellation and return reconciliation tests;
6. live low-risk pilot with explicit supplier consent.

Until these gates pass, label shipment actions as manual/pending. Never show a generated tracking number, delivery ETA, pickup booking, or successful courier handoff unless the provider confirms it.


## Repository checkout review (2026-11-15)

Reviewed the current root migration, checkout RPC, seller order view, smoke assertions, and the marketplace store client. This is a source review only; no SQL was executed and no live database was contacted.

### Verified current checkout behavior

- Checkout is authenticated and uses the database-side `place_sarvex_order` RPC (the 9-argument idempotent form, with an 8-argument compatibility wrapper).
- The RPC accepts product IDs and quantities from the client, but reads authoritative product price, seller ownership, seller approval, commission rate, and stock from PostgreSQL.
- It groups duplicate product IDs, sorts product UUIDs before row locking, checks stock, calculates the order total and seller commission server-side, inserts the order and order items, deducts stock in the same transaction, clears the customer's database cart, and stores an idempotency response.
- The current order-item schema has a single `seller_shop_id` and seller commission/payable fields. It has no supplier ID, supplier offer, reseller ID, fulfilment-mode snapshot, supplier payable, courier shipment, or dispatch-event fields.
- Checkout currently writes payment method `cod` directly. This is not a configurable dropshipping payment gate and must not be reused for supplier dropship orders.
- `seller_order_items_view` exposes the delivery details needed by an approved seller to fulfil their own items. It is not a supplier-specific access view and must not be broadened to expose customer details to every supplier or reseller.
- The app store currently loads the existing `products` table and calls the existing checkout RPC. It has no supplier offer, reseller listing, product-source import, courier provider, or shipment-webhook integration.

### Implementation decisions before changing SQL

1. Preserve the existing direct-seller checkout path and its RPC signatures. Do not silently change its semantics while adding dropshipping.
2. Introduce supplier capabilities as separately approved records; an approved seller is not automatically an approved supplier.
3. Model supplier stock/offers and reseller listings independently from public catalogue rows. The public catalogue must expose only approved retail fields; wholesale costs, supplier contact details, private dispatch address, and reseller margin remain private.
4. For the first database milestone, support only an explicitly approved supplier offer and supplier-managed dispatch record. Do not claim automated courier booking until a provider account, server-side credentials, signed webhooks, pickup-origin checks, and sandbox tests exist.
5. Keep dropship COD unavailable. The existing COD-only RPC is not safe to extend by simply accepting a client-supplied fulfilment flag. A separate trusted transaction path must validate the approved offer, lock and reserve supplier stock, snapshot all commercial amounts, and create supplier allocation records atomically.
6. A pasted Flipkart/Meesho URL must never be treated as proof of resale permission or a valid source feed. The first safe release should accept a manually reviewed supplier-authorised catalogue entry; source-specific API adapters can be added only after documented access is available.
7. Add PG15 and PG16 tests for supplier/reseller ownership isolation, wholesale privacy, approval gates, concurrent stock reservation, tampered amounts/IDs, supplier accept/reject, fulfilment event permissions, idempotency, and rerunnable migration. Existing checkout tests must continue passing unchanged.

### Review status

- Existing seller checkout source mapping: REVIEWED.
- Private supplier/reseller schema: IMPLEMENTED on the working branch; no live Supabase migration applied.
- Supplier/reseller authenticated RPCs and role checks: IMPLEMENTED; isolated PostgreSQL 15/16 migration + smoke + idempotency workflow PASS at commit 8177ee5.
- Seller Portal supplier application, stock, offer and reseller listing forms: IMPLEMENTED; TypeScript and production web build PASS at commit 3753971.
- Admin supplier/offer/listing review queue: IMPLEMENTED; TypeScript and production web build PASS at commit 3753971.
- Customer-facing dropship catalogue and checkout/order allocation: NOT IMPLEMENTED; intentionally disabled.
- Supplier accept/reject, dispatch proof, shipment tracking, courier API and COD reconciliation: NOT IMPLEMENTED.
- Flipkart/Meesho product-link import: NOT IMPLEMENTED; requires authorised API/feed or supplier permission.
- Live Supabase verification and physical Android verification: NOT VERIFIED.
