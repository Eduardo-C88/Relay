CREATE TABLE "users" (
  "id" serial PRIMARY KEY,
  "name" varchar(100),
  "email" varchar(150) UNIQUE,
  "password" varchar(255),
  "course_id" int,
  "university_id" int,
  "reputation" int,
  "address" varchar(255),
  "latitude" float,
  "longitude" float,
  "role_id" int,
  "created_at" timestamp DEFAULT (now())
);

CREATE TABLE "roles" (
  "id" serial PRIMARY KEY,
  "name" varchar(30)
);

CREATE TABLE "universities" (
  "id" serial PRIMARY KEY,
  "name" varchar(150),
  "location" varchar(150),
  "website" varchar(200),
  "created_at" timestamp DEFAULT (now())
);

CREATE TABLE "courses" (
  "id" serial PRIMARY KEY,
  "university_id" int,
  "name" varchar(150)
);

CREATE TABLE "categories" (
  "id" serial PRIMARY KEY,
  "name" varchar(100),
  "description" text
);

CREATE TABLE "resources" (
  "id" serial PRIMARY KEY,
  "owner_id" int,
  "category_id" int,
  "title" varchar(150),
  "description" text,
  "status_id" int,
  "price" float,
  "created_at" timestamp DEFAULT (now())
);

CREATE TABLE "statuses" (
  "id" serial PRIMARY KEY,
  "name" varchar(30)
);

CREATE TABLE "resource_images" (
  "id" serial PRIMARY KEY,
  "resource_id" int,
  "image_url" varchar(255)
);

CREATE TABLE "borrowings" (
  "id" serial PRIMARY KEY,
  "resource_id" int,
  "borrower_id" int,
  "owner_id" int,
  "status_id" int,
  "start_date" date,
  "end_date" date,
  "created_at" timestamp DEFAULT (now())
);

CREATE TABLE "purchases" (
  "id" serial PRIMARY KEY,
  "resource_id" int,
  "buyer_id" int,
  "seller_id" int,
  "agreed_price" numeric(10,2),
  "status_id" int,
  "created_at" timestamp DEFAULT (now())
);

CREATE TABLE "reviews" (
  "id" serial PRIMARY KEY,
  "reviewer_id" int,
  "reviewed_id" int,
  "resource_id" int,
  "rating" int,
  "comment" text,
  "created_at" timestamp DEFAULT (now())
);

CREATE TABLE "reports" (
  "id" serial PRIMARY KEY,
  "reporter_id" int,
  "reported_user_id" int,
  "reason" text,
  "status_id" int,
  "created_at" timestamp DEFAULT (now())
);

CREATE TABLE "requests" (
  "id" serial PRIMARY KEY,
  "requester_id" int,
  "title" varchar(150),
  "description" text,
  "category_id" int,
  "status_id" int,
  "created_at" timestamp DEFAULT (now())
);

ALTER TABLE "users" ADD FOREIGN KEY ("course_id") REFERENCES "courses" ("id");

ALTER TABLE "users" ADD FOREIGN KEY ("university_id") REFERENCES "universities" ("id");

ALTER TABLE "users" ADD FOREIGN KEY ("role_id") REFERENCES "roles" ("id");

ALTER TABLE "courses" ADD FOREIGN KEY ("university_id") REFERENCES "universities" ("id");

ALTER TABLE "resources" ADD FOREIGN KEY ("owner_id") REFERENCES "users" ("id");

ALTER TABLE "resources" ADD FOREIGN KEY ("category_id") REFERENCES "categories" ("id");

ALTER TABLE "resources" ADD FOREIGN KEY ("status_id") REFERENCES "statuses" ("id");

ALTER TABLE "resource_images" ADD FOREIGN KEY ("resource_id") REFERENCES "resources" ("id");

ALTER TABLE "borrowings" ADD FOREIGN KEY ("resource_id") REFERENCES "resources" ("id");

ALTER TABLE "borrowings" ADD FOREIGN KEY ("borrower_id") REFERENCES "users" ("id");

ALTER TABLE "borrowings" ADD FOREIGN KEY ("owner_id") REFERENCES "users" ("id");

ALTER TABLE "borrowings" ADD FOREIGN KEY ("status_id") REFERENCES "statuses" ("id");

ALTER TABLE "purchases" ADD FOREIGN KEY ("resource_id") REFERENCES "resources" ("id");

ALTER TABLE "purchases" ADD FOREIGN KEY ("buyer_id") REFERENCES "users" ("id");

ALTER TABLE "purchases" ADD FOREIGN KEY ("seller_id") REFERENCES "users" ("id");

ALTER TABLE "purchases" ADD FOREIGN KEY ("status_id") REFERENCES "statuses" ("id");

ALTER TABLE "reviews" ADD FOREIGN KEY ("reviewer_id") REFERENCES "users" ("id");

ALTER TABLE "reviews" ADD FOREIGN KEY ("reviewed_id") REFERENCES "users" ("id");

ALTER TABLE "reviews" ADD FOREIGN KEY ("resource_id") REFERENCES "resources" ("id");

ALTER TABLE "reports" ADD FOREIGN KEY ("reporter_id") REFERENCES "users" ("id");

ALTER TABLE "reports" ADD FOREIGN KEY ("reported_user_id") REFERENCES "users" ("id");

ALTER TABLE "reports" ADD FOREIGN KEY ("status_id") REFERENCES "statuses" ("id");

ALTER TABLE "requests" ADD FOREIGN KEY ("requester_id") REFERENCES "users" ("id");

ALTER TABLE "requests" ADD FOREIGN KEY ("category_id") REFERENCES "categories" ("id");

ALTER TABLE "requests" ADD FOREIGN KEY ("status_id") REFERENCES "statuses" ("id");

-- ========================================
-- SET DEFAULT VALUES FOR USERS TABLE
-- ========================================
ALTER TABLE users
  ALTER COLUMN reputation SET DEFAULT 75;

ALTER TABLE users
  ALTER COLUMN role_id SET DEFAULT 2; -- 2 = student

ALTER TABLE users
  ALTER COLUMN address SET DEFAULT '';

ALTER TABLE users
  ALTER COLUMN latitude SET DEFAULT 0;

ALTER TABLE users
  ALTER COLUMN longitude SET DEFAULT 0;

-- ========================================
-- SEED DATA FOR UNIVERSITY RESOURCE SYSTEM
-- ========================================

-- ROLES
INSERT INTO roles (name) VALUES
('admin'),
('student'),
('staff');

-- STATUSES
INSERT INTO statuses (name) VALUES
('available'),
('borrowed'),
('sold'),
('pending'),
('approved'),
('rejected');

-- UNIVERSITIES
INSERT INTO universities (name, location, website) VALUES
('Tech University', 'New York, USA', 'https://techuniversity.edu'),
('Greenfield College', 'London, UK', 'https://greenfield.ac.uk');

-- COURSES
INSERT INTO courses (university_id, name) VALUES
(1, 'Computer Science'),
(1, 'Electrical Engineering'),
(2, 'Business Administration'),
(2, 'Design & Media');

-- CATEGORIES
INSERT INTO categories (name, description) VALUES
('Books', 'Academic and non-academic books'),
('Electronics', 'Laptops, tablets, calculators, etc.'),
('Furniture', 'Desks, chairs, and other study furniture'),
('Stationery', 'Pens, notebooks, and other supplies');

-- USERS
INSERT INTO users (name, email, password, course_id, university_id, reputation, address, latitude, longitude, role_id)
VALUES
('Alice Johnson', 'alice@example.com', 'hashed_pw_1', 1, 1, 120, '123 University Ave, NY', 40.7128, -74.0060, 2),
('Bob Smith', 'bob@example.com', 'hashed_pw_2', 2, 1, 80, '456 Campus Rd, NY', 40.7130, -74.0100, 2),
('Charlie Davis', 'charlie@example.com', 'hashed_pw_3', 3, 2, 50, '789 Green St, London', 51.5074, -0.1278, 2),
('Admin User', 'admin@example.com', 'hashed_pw_admin', NULL, NULL, 999, 'System HQ', 0, 0, 1);

-- RESOURCES
INSERT INTO resources (owner_id, category_id, title, description, status_id)
VALUES
(1, 1, 'Intro to Algorithms', 'A clean copy of CLRS 3rd edition.', 1),
(2, 2, 'Texas Instruments TI-84 Calculator', 'Works perfectly, minor scratches.', 1),
(3, 3, 'IKEA Study Desk', 'Light wood desk, great for dorm rooms.', 1);

-- RESOURCE IMAGES
INSERT INTO resource_images (resource_id, image_url) VALUES
(1, 'https://example.com/images/book1.jpg'),
(2, 'https://example.com/images/calculator.jpg'),
(3, 'https://example.com/images/desk.jpg');

-- BORROWINGS
INSERT INTO borrowings (resource_id, borrower_id, owner_id, status_id, start_date, end_date)
VALUES
(1, 2, 1, 2, '2025-10-01', '2025-10-15');

-- PURCHASES
INSERT INTO purchases (resource_id, buyer_id, seller_id, agreed_price, status_id)
VALUES
(2, 3, 2, 45.00, 3);

-- REVIEWS
INSERT INTO reviews (reviewer_id, reviewed_id, resource_id, rating, comment)
VALUES
(2, 1, 1, 5, 'Book was in excellent condition, very helpful!'),
(3, 2, 2, 4, 'Calculator worked fine, fast transaction.');

-- REPORTS
INSERT INTO reports (reporter_id, reported_user_id, reason, status_id)
VALUES
(1, 3, 'User did not respond to messages about return.', 4);

-- REQUESTS
INSERT INTO requests (requester_id, title, description, category_id, status_id)
VALUES
(2, 'Looking for a physics textbook', 'Need it for next semester’s mechanics course.', 1, 4),
(3, 'Need an ergonomic chair', 'For better posture during study sessions.', 3, 1);

-- ========================================
-- END OF SEED DATA
-- ========================================
