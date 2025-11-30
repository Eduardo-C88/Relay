-- ==============================
-- AUTH & USERS SERVICE DATABASE
-- ==============================

CREATE TABLE IF NOT EXISTS roles (
  id SERIAL PRIMARY KEY,
  name VARCHAR(30) NOT NULL
);

CREATE TABLE IF NOT EXISTS universities (
  id SERIAL PRIMARY KEY,
  name VARCHAR(150),
  location VARCHAR(150),
  website VARCHAR(200),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS courses (
  id SERIAL PRIMARY KEY,
  university_id INT,
  name VARCHAR(150)
  -- ALTER TABLE courses ADD FOREIGN KEY (university_id) REFERENCES universities(id);
);

CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100),
  email VARCHAR(150) UNIQUE NOT NULL,
  password VARCHAR(255) NOT NULL,
  course_id INT,
  university_id INT,
  reputation INT DEFAULT 75,
  address VARCHAR(255) DEFAULT '',
  latitude FLOAT DEFAULT 0,
  longitude FLOAT DEFAULT 0,
  role_id INT DEFAULT 2,
  created_at TIMESTAMP DEFAULT NOW()
  -- ALTER TABLE users ADD FOREIGN KEY (course_id) REFERENCES courses(id);
  -- ALTER TABLE users ADD FOREIGN KEY (university_id) REFERENCES universities(id);
  -- ALTER TABLE users ADD FOREIGN KEY (role_id) REFERENCES roles(id);
);

-- Índices
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role_id ON users(role_id);

-- Seed data
INSERT INTO roles (name) VALUES
('admin'), ('student'), ('staff');

INSERT INTO universities (name, location, website) VALUES
('Tech University', 'New York, USA', 'https://techuniversity.edu'),
('Greenfield College', 'London, UK', 'https://greenfield.ac.uk');

INSERT INTO courses (university_id, name) VALUES
(1, 'Computer Science'),
(1, 'Electrical Engineering'),
(2, 'Business Administration'),
(2, 'Design & Media');

INSERT INTO users (name, email, password, course_id, university_id, reputation, address, latitude, longitude, role_id)
VALUES
('Alice Johnson', 'alice@example.com', 'hashed_pw_1', 1, 1, 120, '123 University Ave, NY', 40.7128, -74.0060, 2),
('Bob Smith', 'bob@example.com', 'hashed_pw_2', 2, 1, 80, '456 Campus Rd, NY', 40.7130, -74.0100, 2),
('Charlie Davis', 'charlie@example.com', 'hashed_pw_3', 3, 2, 50, '789 Green St, London', 51.5074, -0.1278, 2),
('Admin User', 'admin@example.com', 'hashed_pw_admin', NULL, NULL, 999, 'System HQ', 0, 0, 1);
