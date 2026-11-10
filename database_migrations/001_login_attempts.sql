-- Apply this to an existing grocery_system database if login_attempts is missing.
-- Safe to run more than once; it does not delete or alter existing account data.
USE grocery_system;

CREATE TABLE IF NOT EXISTS login_attempts (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(190) NOT NULL,
    attempted_at DATETIME NOT NULL,
    INDEX idx_login_email_time (email, attempted_at)
) ENGINE=InnoDB;
