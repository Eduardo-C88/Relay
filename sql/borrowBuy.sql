-- ===============================
-- BORROW / BUY SERVICE DATABASE
-- ===============================

CREATE TABLE IF NOT EXISTS statuses (
  id SERIAL PRIMARY KEY,
  name VARCHAR(30) NOT NULL
);

CREATE TABLE IF NOT EXISTS borrowings (
  id SERIAL PRIMARY KEY,
  resource_id INT,
  borrower_id INT,
  owner_id INT,
  status_id INT,
  start_date DATE,
  end_date DATE,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS purchases (
  id SERIAL PRIMARY KEY,
  resource_id INT,
  buyer_id INT,
  seller_id INT,
  agreed_price NUMERIC(10,2),
  status_id INT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_borrowings_resource ON borrowings(resource_id);
CREATE INDEX idx_borrowings_borrower ON borrowings(borrower_id);
CREATE INDEX idx_borrowings_owner ON borrowings(owner_id);
CREATE INDEX idx_borrowings_status ON borrowings(status_id);

CREATE INDEX idx_purchases_resource ON purchases(resource_id);
CREATE INDEX idx_purchases_buyer ON purchases(buyer_id);
CREATE INDEX idx_purchases_seller ON purchases(seller_id);
CREATE INDEX idx_purchases_status ON purchases(status_id);

-- Seed data
INSERT INTO statuses (name) VALUES
('pending'), ('approved'), ('rejected'), ('borrowed'), ('returned'), ('sold');
