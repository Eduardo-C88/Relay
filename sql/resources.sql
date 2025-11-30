-- =========================
-- RESOURCES SERVICE DATABASE
-- =========================

CREATE TABLE IF NOT EXISTS statuses (
  id SERIAL PRIMARY KEY,
  name VARCHAR(30) NOT NULL
);

CREATE TABLE IF NOT EXISTS categories (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100),
  description TEXT
);

CREATE TABLE IF NOT EXISTS resources (
  id SERIAL PRIMARY KEY,
  owner_id INT,
  category_id INT,
  title VARCHAR(150),
  description TEXT,
  status_id INT,
  price FLOAT,
  created_at TIMESTAMP DEFAULT NOW()
  -- ALTER TABLE resources ADD FOREIGN KEY (owner_id) REFERENCES users(id);
  -- ALTER TABLE resources ADD FOREIGN KEY (category_id) REFERENCES categories(id);
  -- ALTER TABLE resources ADD FOREIGN KEY (status_id) REFERENCES statuses(id);
);

CREATE TABLE IF NOT EXISTS resource_images (
  id SERIAL PRIMARY KEY,
  resource_id INT,
  image_url VARCHAR(255)
  -- ALTER TABLE resource_images ADD FOREIGN KEY (resource_id) REFERENCES resources(id);
);

CREATE TABLE IF NOT EXISTS requests (
  id SERIAL PRIMARY KEY,
  requester_id INT,
  title VARCHAR(150),
  description TEXT,
  category_id INT,
  status_id INT,
  created_at TIMESTAMP DEFAULT NOW()
  -- ALTER TABLE requests ADD FOREIGN KEY (requester_id) REFERENCES users(id);
  -- ALTER TABLE requests ADD FOREIGN KEY (category_id) REFERENCES categories(id);
  -- ALTER TABLE requests ADD FOREIGN KEY (status_id) REFERENCES statuses(id);
);

-- Índices
CREATE INDEX idx_resources_owner ON resources(owner_id);
CREATE INDEX idx_resources_category ON resources(category_id);
CREATE INDEX idx_requests_requester ON requests(requester_id);
CREATE INDEX idx_requests_category ON requests(category_id);

-- Seed data
INSERT INTO statuses (name) VALUES
('available'), ('borrowed'), ('sold'), ('pending'), ('approved'), ('rejected');

INSERT INTO categories (name, description) VALUES
('Books', 'Academic and non-academic books'),
('Electronics', 'Laptops, tablets, calculators, etc.'),
('Furniture', 'Desks, chairs, and other study furniture'),
('Stationery', 'Pens, notebooks, and other supplies');

INSERT INTO resources (owner_id, category_id, title, description, status_id, price) VALUES
(1, 1, 'Intro to Algorithms', 'A clean copy of CLRS 3rd edition.', 1, 60.00),
(2, 2, 'Texas Instruments TI-84 Calculator', 'Works perfectly, minor scratches.', 1, 50.00),
(3, 3, 'IKEA Study Desk', 'Light wood desk, great for dorm rooms.', 1, 80.00);

INSERT INTO resource_images (resource_id, image_url) VALUES
(1, 'https://example.com/images/book1.jpg'),
(2, 'https://example.com/images/calculator.jpg'),
(3, 'https://example.com/images/desk.jpg');

INSERT INTO requests (requester_id, title, description, category_id, status_id) VALUES
(2, 'Looking for a physics textbook', 'Need it for next semester’s mechanics course.', 1, 4),
(3, 'Need an ergonomic chair', 'For better posture during study sessions.', 3, 1);
