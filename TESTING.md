# Demo testing checklist

Use two separate browser sessions to verify account isolation. Import `schema.sql` before starting.

- [ ] Landing page opens at `http://localhost/grocery-system` with responsive cream/green layout.
- [ ] Sign up accepts valid details, hashes the password, and rejects a duplicate email / short password.
- [ ] Sign in succeeds; sign out clears the session. Five failed sign-ins trigger the 15-minute email lockout.
- [ ] Forms reject missing/invalid CSRF tokens; session ID changes after login.
- [ ] User A cannot list, edit, delete, export, or infer User B's products or suppliers.
- [ ] Create, search, edit and delete inventory products. Verify barcode field, quantity, unit, threshold, unit cost, storage, expiry and perishability.
- [ ] Scan or type a barcode into the product code field; save and verify the code is retained.
- [ ] Add supplier details and associate a supplier with a product; delete a supplier and verify product remains valid.
- [ ] Dashboard cards reflect product count, low stock, expiry within seven days, and stock value.
- [ ] Alerts show products at/below threshold and perishables expiring within 30 days.
- [ ] Inventory exports download CSV, Excel-compatible CSV and PDF; content is scoped to the active user.
- [ ] Enable email two-step verification with PHP mail configured; correct fresh code succeeds and expired/incorrect code fails.
- [ ] Free plan permits up to 50 products and directs further additions to Upgrade to Pro; Pro flag removes the cap.
- [ ] Upgrade page records a pending demo M-Pesa subscription; no real payment is attempted.
- [ ] Check pages at desktop and mobile widths; forms and tables remain usable.
- [ ] Create a customer, verify customer search/profile/order history and activate/deactivate action.
- [ ] Create a multi-item order; verify totals, payment record, stock reservation, delivery record and customer tracking URL.
- [ ] Filter/sort/page through orders and export orders/customer/delivery CSVs; verify all records belong to the active store.
- [ ] Update order state; cancelling restores the reserved product quantities only once.
- [ ] Create a rider, sign in in a separate session, and confirm the rider workspace cannot open admin routes or other riders' deliveries.
- [ ] Assign an available rider; confirm unavailable riders are rejected unless the admin override is selected.
- [ ] Progress through accepted, preparing, ready for pickup, picked up and out for delivery; verify timeline timestamps.
- [ ] Confirm delivery cannot complete without the correct customer proof code.
- [ ] Start GPS sharing on the rider device only during an active delivery; allow browser permission and verify last location timestamp appears on admin/customer map panels.
- [ ] Open the generated customer tracking link and verify it shows only its token-scoped order and location.
- [ ] Report and resolve a delivery exception; verify it appears in admin delivery operations.
- [ ] Confirm no active deliveries produces the real-data empty state and never displays sample coordinates.

## Current demo limitations

Email delivery depends on local PHP mail configuration. Daraja credentials, callback handling and payment verification are intentionally placeholders. PDF output is a one-page snapshot and lists up to 48 products. Excel export uses CSV format.
