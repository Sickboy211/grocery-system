# FreshStock Grocery Management System

A beginner-readable grocery inventory prototype built with PHP 8, PDO, MySQL/MariaDB, HTML, CSS and vanilla JavaScript. No framework, build step, package manager or external library is used.

## XAMPP setup

1. Install XAMPP and start **Apache** and **MySQL** in the XAMPP Control Panel.
2. Copy this project folder into `C:\xampp\htdocs\grocery-system` (or the equivalent `htdocs` folder on your installation).
3. Open `http://localhost/phpmyadmin`, choose **Import**, select this project's `schema.sql`, and run the import. It creates the `grocery_system` database and tables.
4. Review `config.php`. Defaults are `localhost`, database `grocery_system`, user `root`, and an empty password.
5. Open `http://localhost/grocery-system` and create your account.

### Updating an existing XAMPP database

If this project was already installed before the login security table was added, do not drop or re-import the database (that could delete accounts and inventory). In phpMyAdmin, select `grocery_system`, choose **Import**, and run `database_migrations/001_login_attempts.sql`. The current `index.php` also creates this missing table automatically when the database user has CREATE TABLE permission.

If signup says the database is out of date, check in phpMyAdmin that `grocery_system` has all six tables: `users`, `login_attempts`, `suppliers`, `products`, `verification_codes`, and `subscriptions`. The supplied `schema.sql` uses `CREATE TABLE IF NOT EXISTS`, so it can be imported again to add missing tables without dropping existing data. Do not use **Drop database** to repair an install.

## Included pages

- Welcome page, sign up, sign in and sign out
- Overview dashboard, inventory, supplier list, stock alerts, security and Pro upgrade
- Orders, customer profiles and operational delivery tracking with a restricted rider workspace
- Product barcode input, storage location, supplier, low-stock threshold and expiry
- User scoped data, CSRF tokens, hashed passwords, login rate limit and optional emailed verification code
- CSV / Excel-compatible CSV / PDF inventory exports

## Local notes

- The database connection uses PDO with native prepared statements. Every product and supplier query is scoped to the authenticated user's ID.
- Email two-step verification uses PHP `mail()`. Configure a local mail transport in XAMPP/PHP before enabling it; without one, the code cannot arrive. Verification codes expire after ten minutes.
- M-Pesa is intentionally a pending subscription hook. Add Daraja app credentials, access-token handling, callback URL, and payment-result verification in the marked upgrade action before accepting real payments. Do not commit live credentials.
- The Free tier supports up to 50 products; Pro removes that cap. Pro is a demo upgrade placeholder and does not automatically activate on a pending payment.
- The PDF export is a small self-contained PDF writer for a one-page inventory snapshot; long inventories are limited to 48 listed rows. Excel export is UTF-8 CSV that opens in Excel.
- Delivery maps use Leaflet from its public CDN and OpenStreetMap tiles, so map tiles require an internet connection. The application and database remain local. GPS is requested only after an assigned rider selects **Out for Delivery** and explicitly starts GPS sharing. Tracking refresh uses PHP polling at 15-second intervals. ETA uses actual GPS and manually saved destination coordinates with a configurable-speed straight-line estimate; it is not a road-route or traffic guarantee.
- Rider GPS is never fabricated. Without a rider location or saved destination coordinates, the map and ETA show an empty/unavailable state. The line between known map points is a direct visual connector, not turn-by-turn routing.
- Order creation reserves inventory in a database transaction; cancelling an order restores reserved quantities once. Completing delivery requires the customer proof code created with the order. The customer tracking URL is a long random bearer token; share it only with the intended customer.
- Currency in the overview is shown as `$` for the prototype; the upgrade demo price is shown in KES. Update currency formatting to the store's market before production use.

## Security and deployment

Use HTTPS and a database user with limited privileges outside local development. Configure PHP mail before enabling email verification. Set a real Daraja callback endpoint and verify callback signatures/results before changing subscription status. `APP_URL` is available in `config.php` for project-level configuration; navigation uses query-string routing at the project root.
