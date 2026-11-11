-- DevCase Notification System Database Schema

CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    role VARCHAR(50) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    team VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS devices (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(50) REFERENCES users(id) ON DELETE CASCADE,
    fcm_token VARCHAR(255) UNIQUE NOT NULL,
    platform VARCHAR(50),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    module VARCHAR(50) NOT NULL, -- 'case', 'order_diff', 'bank_issue'
    reference_id VARCHAR(50) NOT NULL, -- caseId or order Card ID
    target_user_id VARCHAR(50) REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    subtitle TEXT,
    icon VARCHAR(100),
    icon_color VARCHAR(50),
    icon_bg VARCHAR(50),
    is_read BOOLEAN DEFAULT FALSE,
    actor_user_id VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_notifications_target_user ON notifications(target_user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_reference ON notifications(reference_id);

CREATE TABLE IF NOT EXISTS notification_outbox (
    id SERIAL PRIMARY KEY,
    notification_id INTEGER REFERENCES notifications(id) ON DELETE CASCADE,
    status VARCHAR(50) DEFAULT 'PENDING', -- PENDING, SENT, FAILED
    retry_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
