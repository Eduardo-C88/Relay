-- ========================================
-- REPUTATION & REVIEWS / ANALYTICS & REPORTING
-- ========================================

CREATE TABLE IF NOT EXISTS reviews (
  id SERIAL PRIMARY KEY,
  reviewer_id INT,
  reviewed_id INT,
  resource_id INT,
  rating INT,
  comment TEXT,
  created_at TIMESTAMP DEFAULT NOW()
  -- ALTER TABLE reviews ADD FOREIGN KEY (reviewer_id) REFERENCES users(id);
  -- ALTER TABLE reviews ADD FOREIGN KEY (reviewed_id) REFERENCES users(id);
  -- ALTER TABLE reviews ADD FOREIGN KEY (resource_id) REFERENCES resources(id);
);

CREATE TABLE IF NOT EXISTS reports (
  id SERIAL PRIMARY KEY,
  reporter_id INT,
  reported_user_id INT,
  reason TEXT,
  status_id INT,
  created_at TIMESTAMP DEFAULT NOW()
  -- ALTER TABLE reports ADD FOREIGN KEY (reporter_id) REFERENCES users(id);
  -- ALTER TABLE reports ADD FOREIGN KEY (reported_user_id) REFERENCES users(id);
  -- ALTER TABLE reports ADD FOREIGN KEY (status_id) REFERENCES statuses(id);
);

-- Índices
CREATE INDEX idx_reviews_reviewer ON reviews(reviewer_id);
CREATE INDEX idx_reviews_reviewed ON reviews(reviewed_id);

CREATE INDEX idx_reports_reporter ON reports(reporter_id);
CREATE INDEX idx_reports_reported ON reports(reported_user_id);
CREATE INDEX idx_reports_status ON reports(status_id);

-- Seed data
INSERT INTO reviews (reviewer_id, reviewed_id, resource_id, rating, comment) VALUES
(2, 1, 1, 5, 'Book was in excellent condition, very helpful!'),
(3, 2, 2, 4, 'Calculator worked fine, fast transaction.');

INSERT INTO reports (reporter_id, reported_user_id, reason, status_id) VALUES
(1, 3, 'User did not respond to messages about return.', 4);
