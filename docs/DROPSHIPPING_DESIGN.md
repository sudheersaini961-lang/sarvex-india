# SARVEX Supplier and Dropshipping Design

## Status

Planning only. This document does not enable dropshipping, change the database, create supplier accounts, or alter checkout. The current marketplace supports seller-owned products and seller-managed dispatch; supplier fulfilment is not implemented.

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

The repository currently has a single seller-shop model, seller-owned products, and seller order fulfilment. It does not yet model suppliers, wholesale offers, reseller listings, supplier allocations, supplier dispatch events, automated payment splitting, or COD remittance. This design is not a claim that any of those capabilities are live.
