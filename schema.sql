CREATE DATABASE IF NOT EXISTS grocery_system CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE grocery_system;

CREATE TABLE IF NOT EXISTS users (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 name VARCHAR(120) NOT NULL,
 email VARCHAR(190) NOT NULL UNIQUE,
 password_hash VARCHAR(255) NOT NULL,
 plan ENUM('free','pro') NOT NULL DEFAULT 'free',
 two_factor_enabled TINYINT(1) NOT NULL DEFAULT 0,
 role ENUM('admin','rider') NOT NULL DEFAULT 'admin',
 owner_id BIGINT UNSIGNED NULL,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
-- Upgrade accounts created before rider authentication was introduced.
ALTER TABLE users ADD COLUMN IF NOT EXISTS role ENUM('admin','rider') NOT NULL DEFAULT 'admin';
ALTER TABLE users ADD COLUMN IF NOT EXISTS owner_id BIGINT UNSIGNED NULL;
CREATE TABLE IF NOT EXISTS login_attempts (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 email VARCHAR(190) NOT NULL,
 attempted_at DATETIME NOT NULL,
 INDEX idx_login_email_time(email,attempted_at)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS suppliers (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 user_id BIGINT UNSIGNED NOT NULL,
 name VARCHAR(160) NOT NULL,
 phone VARCHAR(40) NULL,
 email VARCHAR(190) NULL,
 notes VARCHAR(500) NULL,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE KEY uq_supplier_user_name(user_id,name), INDEX idx_supplier_user(user_id),
 CONSTRAINT fk_suppliers_user FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS products (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 user_id BIGINT UNSIGNED NOT NULL,
 supplier_id BIGINT UNSIGNED NULL,
 name VARCHAR(180) NOT NULL,
 code VARCHAR(100) NULL,
 quantity DECIMAL(12,3) NOT NULL DEFAULT 0,
 low_stock_threshold DECIMAL(12,3) NOT NULL DEFAULT 0,
 unit VARCHAR(30) NOT NULL DEFAULT 'units',
 unit_cost DECIMAL(12,2) NOT NULL DEFAULT 0,
 storage_location VARCHAR(120) NULL,
 expiry_date DATE NULL,
 is_perishable TINYINT(1) NOT NULL DEFAULT 0,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 INDEX idx_product_user(user_id), INDEX idx_product_code(user_id,code), INDEX idx_product_expiry(user_id,expiry_date),
 CONSTRAINT fk_products_user FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
 CONSTRAINT fk_products_supplier FOREIGN KEY(supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS verification_codes (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 user_id BIGINT UNSIGNED NOT NULL,
 code_hash VARCHAR(255) NOT NULL,
 expires_at DATETIME NOT NULL,
 INDEX idx_verify_user(user_id),
 CONSTRAINT fk_verify_user FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS subscriptions (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 user_id BIGINT UNSIGNED NOT NULL,
 provider VARCHAR(40) NOT NULL DEFAULT 'mpesa',
 amount DECIMAL(12,2) NOT NULL,
 status ENUM('pending','completed','failed') NOT NULL DEFAULT 'pending',
 checkout_request_id VARCHAR(120) NULL,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 INDEX idx_subscription_user(user_id),
 CONSTRAINT fk_subscriptions_user FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Orders, customer records and operational delivery tracking.
CREATE TABLE IF NOT EXISTS customers (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 owner_id BIGINT UNSIGNED NOT NULL,
 full_name VARCHAR(160) NOT NULL,
 email VARCHAR(190) NULL,
 phone VARCHAR(40) NULL,
 status ENUM('active','inactive') NOT NULL DEFAULT 'active',
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 INDEX idx_customers_owner(owner_id), INDEX idx_customers_email(owner_id,email),
 CONSTRAINT fk_customers_owner FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS customer_addresses (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 customer_id BIGINT UNSIGNED NOT NULL,
 label VARCHAR(80) NOT NULL DEFAULT 'Delivery address',
 address_text VARCHAR(500) NOT NULL,
 latitude DECIMAL(10,7) NULL,
 longitude DECIMAL(10,7) NULL,
 is_default TINYINT(1) NOT NULL DEFAULT 0,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 INDEX idx_customer_addresses(customer_id),
 CONSTRAINT fk_addresses_customer FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS delivery_riders (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 owner_id BIGINT UNSIGNED NOT NULL,
 user_id BIGINT UNSIGNED NOT NULL UNIQUE,
 phone VARCHAR(40) NULL,
 vehicle VARCHAR(100) NULL,
 availability ENUM('available','unavailable') NOT NULL DEFAULT 'available',
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 INDEX idx_riders_owner(owner_id,availability),
 CONSTRAINT fk_riders_owner FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE,
 CONSTRAINT fk_riders_user FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS orders (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 owner_id BIGINT UNSIGNED NOT NULL,
 customer_id BIGINT UNSIGNED NOT NULL,
 order_number VARCHAR(40) NOT NULL,
 source ENUM('website','mobile','in_store') NOT NULL DEFAULT 'in_store',
 status ENUM('pending','processing','completed','cancelled') NOT NULL DEFAULT 'pending',
 payment_status ENUM('pending','paid','failed','refunded') NOT NULL DEFAULT 'pending',
 payment_method VARCHAR(60) NULL,
 subtotal DECIMAL(12,2) NOT NULL DEFAULT 0,
 delivery_fee DECIMAL(12,2) NOT NULL DEFAULT 0,
 discount DECIMAL(12,2) NOT NULL DEFAULT 0,
 total_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
 delivery_address VARCHAR(500) NULL,
 departure_location VARCHAR(250) NULL,
 stock_reserved TINYINT(1) NOT NULL DEFAULT 0,
 stock_restored_at DATETIME NULL,
 ordered_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 UNIQUE KEY uq_order_owner_number(owner_id,order_number),
 INDEX idx_orders_owner_date(owner_id,ordered_at), INDEX idx_orders_owner_status(owner_id,status), INDEX idx_orders_customer(customer_id),
 CONSTRAINT fk_orders_owner FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE,
 CONSTRAINT fk_orders_customer FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE
) ENGINE=InnoDB;
-- Existing installs may still have the earlier restrictive relation. Rebuild this
-- single FK idempotently so removing a store account can cascade its own records.
ALTER TABLE orders DROP FOREIGN KEY IF EXISTS fk_orders_customer;
ALTER TABLE orders ADD CONSTRAINT fk_orders_customer FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS stock_reserved TINYINT(1) NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS stock_restored_at DATETIME NULL;

CREATE TABLE IF NOT EXISTS order_items (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 order_id BIGINT UNSIGNED NOT NULL,
 product_id BIGINT UNSIGNED NULL,
 product_name VARCHAR(180) NOT NULL,
 quantity DECIMAL(12,3) NOT NULL,
 unit_price DECIMAL(12,2) NOT NULL,
 line_total DECIMAL(12,2) NOT NULL,
 INDEX idx_order_items_order(order_id),
 CONSTRAINT fk_items_order FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE,
 CONSTRAINT fk_items_product FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS payments (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 order_id BIGINT UNSIGNED NOT NULL,
 amount DECIMAL(12,2) NOT NULL,
 method VARCHAR(60) NULL,
 status ENUM('pending','paid','failed','refunded') NOT NULL DEFAULT 'pending',
 transaction_reference VARCHAR(120) NULL,
 paid_at DATETIME NULL,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 INDEX idx_payments_order(order_id,status),
 CONSTRAINT fk_payments_order FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS deliveries (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 owner_id BIGINT UNSIGNED NOT NULL,
 order_id BIGINT UNSIGNED NOT NULL UNIQUE,
 rider_id BIGINT UNSIGNED NULL,
 tracking_code VARCHAR(32) NOT NULL UNIQUE,
 tracking_token_hash CHAR(64) NOT NULL UNIQUE,
 status ENUM('assigned','accepted','preparing','ready_for_pickup','picked_up','out_for_delivery','delivered','cancelled','returned','failed','exception') NOT NULL DEFAULT 'assigned',
 scheduled_at DATETIME NULL,
 started_at DATETIME NULL,
 delivered_at DATETIME NULL,
 eta_at DATETIME NULL,
 origin_latitude DECIMAL(10,7) NULL,
 origin_longitude DECIMAL(10,7) NULL,
 destination_latitude DECIMAL(10,7) NULL,
 destination_longitude DECIMAL(10,7) NULL,
 current_latitude DECIMAL(10,7) NULL,
 current_longitude DECIMAL(10,7) NULL,
 route_distance_km DECIMAL(8,2) NULL,
 last_location_at DATETIME NULL,
 proof_code_hash VARCHAR(255) NOT NULL,
 proof_verified_at DATETIME NULL,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 INDEX idx_deliveries_owner_status(owner_id,status), INDEX idx_deliveries_rider(rider_id,status),
 CONSTRAINT fk_deliveries_owner FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE,
 CONSTRAINT fk_deliveries_order FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE,
 CONSTRAINT fk_deliveries_rider FOREIGN KEY(rider_id) REFERENCES delivery_riders(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS delivery_events (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 delivery_id BIGINT UNSIGNED NOT NULL,
 actor_user_id BIGINT UNSIGNED NULL,
 status VARCHAR(32) NOT NULL,
 note VARCHAR(500) NULL,
 latitude DECIMAL(10,7) NULL,
 longitude DECIMAL(10,7) NULL,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 INDEX idx_delivery_events(delivery_id,created_at),
 CONSTRAINT fk_events_delivery FOREIGN KEY(delivery_id) REFERENCES deliveries(id) ON DELETE CASCADE,
 CONSTRAINT fk_events_actor FOREIGN KEY(actor_user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS delivery_locations (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 delivery_id BIGINT UNSIGNED NOT NULL,
 rider_id BIGINT UNSIGNED NOT NULL,
 latitude DECIMAL(10,7) NOT NULL,
 longitude DECIMAL(10,7) NOT NULL,
 recorded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 INDEX idx_delivery_locations(delivery_id,recorded_at),
 CONSTRAINT fk_locations_delivery FOREIGN KEY(delivery_id) REFERENCES deliveries(id) ON DELETE CASCADE,
 CONSTRAINT fk_locations_rider FOREIGN KEY(rider_id) REFERENCES delivery_riders(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS delivery_exceptions (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 delivery_id BIGINT UNSIGNED NOT NULL,
 rider_id BIGINT UNSIGNED NULL,
 category ENUM('customer_unavailable','incorrect_address','cannot_reach','transport_problem','delayed','customer_cancelled','other') NOT NULL,
 description VARCHAR(1000) NOT NULL,
 image_path VARCHAR(255) NULL,
 latitude DECIMAL(10,7) NULL,
 longitude DECIMAL(10,7) NULL,
 resolved_at DATETIME NULL,
 resolved_by BIGINT UNSIGNED NULL,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 INDEX idx_exceptions_delivery(delivery_id,resolved_at),
 CONSTRAINT fk_exceptions_delivery FOREIGN KEY(delivery_id) REFERENCES deliveries(id) ON DELETE CASCADE,
 CONSTRAINT fk_exceptions_rider FOREIGN KEY(rider_id) REFERENCES delivery_riders(id) ON DELETE SET NULL,
 CONSTRAINT fk_exceptions_resolver FOREIGN KEY(resolved_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;
