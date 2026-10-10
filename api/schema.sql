CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(64) PRIMARY KEY,
  email VARCHAR(254) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(120) NOT NULL,
  phone VARCHAR(24) NOT NULL,
  location VARCHAR(255) NOT NULL,
  bio TEXT NOT NULL,
  verified BOOLEAN NOT NULL DEFAULT FALSE,
  email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  phone_verified BOOLEAN NOT NULL DEFAULT FALSE,
  id_verified BOOLEAN NOT NULL DEFAULT FALSE,
  photo BOOLEAN NOT NULL DEFAULT FALSE,
  location_allowed BOOLEAN NOT NULL DEFAULT FALSE,
  phone_privacy VARCHAR(20) NOT NULL DEFAULT 'Private',
  email_privacy VARCHAR(20) NOT NULL DEFAULT 'Private',
  rating DECIMAL(3,2) NOT NULL DEFAULT 0,
  completed INT NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS sessions (
  token_hash CHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  expires_at DATETIME NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS wallets (
  user_id VARCHAR(64) PRIMARY KEY,
  available DECIMAL(14,2) NOT NULL DEFAULT 0,
  total_earnings DECIMAL(14,2) NOT NULL DEFAULT 0,
  refunds DECIMAL(14,2) NOT NULL DEFAULT 0,
  FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS errands (
  id VARCHAR(64) PRIMARY KEY,
  owner_id VARCHAR(64) NOT NULL,
  runner_id VARCHAR(64) NULL,
  title VARCHAR(160) NOT NULL,
  category VARCHAR(60) NOT NULL,
  description TEXT NOT NULL,
  pickup VARCHAR(500) NOT NULL,
  destination VARCHAR(500) NOT NULL,
  area VARCHAR(255) NOT NULL,
  transport VARCHAR(60) NOT NULL,
  instructions TEXT NOT NULL,
  budget DECIMAL(14,2) NOT NULL,
  budget_currency VARCHAR(3) NOT NULL DEFAULT 'CY',
  budget_method VARCHAR(60) NOT NULL DEFAULT 'Legacy coins',
  fee DECIMAL(14,2) NOT NULL,
  service_fee DECIMAL(14,2) NOT NULL DEFAULT 5,
  distance DOUBLE NOT NULL,
  pickup_lat DOUBLE NULL,
  pickup_lon DOUBLE NULL,
  destination_lat DOUBLE NULL,
  destination_lon DOUBLE NULL,
  distance_source VARCHAR(20) NOT NULL DEFAULT 'manual',
  route_seconds DOUBLE NULL,
  deadline DATETIME(6) NOT NULL,
  posted_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  urgent BOOLEAN NOT NULL DEFAULT FALSE,
  status ENUM('posted','accepted','ongoing','waiting','completed','cancelled','expired') NOT NULL DEFAULT 'posted',
  progress INT NOT NULL DEFAULT -1,
  actual_cost DECIMAL(14,2) NULL,
  receipt BOOLEAN NOT NULL DEFAULT FALSE,
  item_photo BOOLEAN NOT NULL DEFAULT FALSE,
  handoff_verified BOOLEAN NOT NULL DEFAULT FALSE,
  completion_pin VARCHAR(6) NULL,
  pin_attempts INT NOT NULL DEFAULT 0,
  cancellation_reason TEXT NULL,
  cancel_requested_by VARCHAR(64) NULL,
  cancel_requested_at DATETIME(6) NULL,
  cancel_reviewed_by VARCHAR(64) NULL,
  cancel_refund_coins DECIMAL(12,2) NULL,
  cancel_refund_purchase DECIMAL(12,2) NULL,
  cancel_runner_payment DECIMAL(12,2) NULL,
  pin_reset_at DATETIME(6) NULL,
  payment_method VARCHAR(60) NOT NULL DEFAULT 'Errandly Wallet',
  FOREIGN KEY (owner_id) REFERENCES users(id),
  FOREIGN KEY (runner_id) REFERENCES users(id),
  INDEX (status, deadline), INDEX (owner_id, status), INDEX (runner_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS errand_progress (
  errand_id VARCHAR(64) NOT NULL,
  step INT NOT NULL,
  happened_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (errand_id, step),
  FOREIGN KEY (errand_id) REFERENCES errands(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS proof_files (
  id CHAR(32) PRIMARY KEY,
  errand_id VARCHAR(64) NOT NULL,
  kind ENUM('receipt','item','delivery') NOT NULL,
  uploaded_by VARCHAR(64) NOT NULL,
  file_name VARCHAR(180) NOT NULL,
  mime_type VARCHAR(32) NOT NULL,
  byte_size INT UNSIGNED NOT NULL,
  sha256 CHAR(64) NOT NULL,
  payload MEDIUMBLOB NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  UNIQUE KEY (errand_id,kind),
  FOREIGN KEY (errand_id) REFERENCES errands(id) ON DELETE CASCADE,
  FOREIGN KEY (uploaded_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS wallet_entries (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  errand_id VARCHAR(64) NULL,
  type VARCHAR(60) NOT NULL,
  amount DECIMAL(14,2) NOT NULL,
  currency VARCHAR(3) NOT NULL DEFAULT 'CY',
  peso_amount DECIMAL(12,2) NULL,
  note TEXT NOT NULL,
  status VARCHAR(30) NOT NULL DEFAULT 'Completed',
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (errand_id) REFERENCES errands(id), INDEX (user_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS notifications (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  errand_id VARCHAR(64) NULL,
  type VARCHAR(60) NOT NULL,
  text TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (errand_id) REFERENCES errands(id), INDEX (user_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS messages (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  errand_id VARCHAR(64) NOT NULL,
  sender_id VARCHAR(64) NOT NULL,
  recipient_id VARCHAR(64) NULL,
  text TEXT NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  FOREIGN KEY (errand_id) REFERENCES errands(id),
  FOREIGN KEY (sender_id) REFERENCES users(id),
  FOREIGN KEY (recipient_id) REFERENCES users(id), INDEX (errand_id, id), INDEX (recipient_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS reviews (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  errand_id VARCHAR(64) NOT NULL,
  from_id VARCHAR(64) NOT NULL,
  to_id VARCHAR(64) NOT NULL,
  stars TINYINT NOT NULL,
  text TEXT NOT NULL,
  scores LONGTEXT NOT NULL,
  UNIQUE (errand_id, from_id),
  FOREIGN KEY (errand_id) REFERENCES errands(id),
  FOREIGN KEY (from_id) REFERENCES users(id),
  FOREIGN KEY (to_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS reports (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  errand_id VARCHAR(64) NULL,
  reason VARCHAR(500) NOT NULL,
  description TEXT NOT NULL,
  evidence BOOLEAN NOT NULL DEFAULT FALSE,
  status VARCHAR(30) NOT NULL DEFAULT 'Submitted',
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (errand_id) REFERENCES errands(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS user_links (
  user_id VARCHAR(64) NOT NULL,
  target_id VARCHAR(64) NOT NULL,
  type ENUM('friend','favorite','blocked') NOT NULL,
  PRIMARY KEY (user_id, target_id, type),
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (target_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS saved_errands (
  user_id VARCHAR(64) NOT NULL,
  errand_id VARCHAR(64) NOT NULL,
  PRIMARY KEY (user_id, errand_id),
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (errand_id) REFERENCES errands(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
