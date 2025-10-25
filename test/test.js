const supertest = require('supertest');
// We import the app objects from your server files.
// IMPORTANT: This requires your server.js and authServer.js to export the app.
// e.g., add 'module.exports = app;' at the bottom of those files.
const app = require('../src/server.js'); 
const authApp = require('../src/authServer.js');
const pool = require('../src/database.js');

// Wrap the apps in supertest
const request = supertest(app);
const authRequest = supertest(authApp);

// Hold the auth token for protected route tests
let testToken;
let testUserId;

// Clean up the database before running tests
beforeAll(async () => {
    try {
        await pool.query('TRUNCATE TABLE users, resources, categories, universities, courses, roles RESTART IDENTITY CASCADE');
        
        // Seed database with necessary lookup data
        await pool.query("INSERT INTO roles (name) VALUES ('student'), ('admin')");
        await pool.query("INSERT INTO universities (name) VALUES ('Test University')");
        await pool.query("INSERT INTO courses (university_id, name) VALUES (1, 'Test Course')");
        await pool.query("INSERT INTO categories (name) VALUES ('Test Category')");
        await pool.query("INSERT INTO statuses (name) VALUES ('Available')");

    } catch (err) {
        console.error("Database setup failed", err);
        process.exit(1); // Exit if setup fails
    }
});

// Close the database connection pool after all tests are done
afterAll(async () => {
    await pool.end();
});

// --- Auth Server Tests (authServer.js) ---
describe('Auth Server API (/auth)', () => {

    it('POST /auth/register -> should create a new user', async () => {
        const res = await authRequest
            .post('/auth/register')
            .send({
                name: "Test User",
                email: "test@example.com",
                password: "password123"
            });
        expect(res.statusCode).toEqual(201);
        expect(res.text).toContain("User registered");
    });

    it('POST /auth/register -> should fail to create a duplicate user', async () => {
        const res = await authRequest
            .post('/auth/register')
            .send({
                name: "Test User 2",
                email: "test@example.com", // Same email
                password: "password123"
            });
        expect(res.statusCode).toEqual(409); // Conflict
    });

    it('POST /auth/login -> should login the user and return tokens', async () => {
        const res = await authRequest
            .post('/auth/login')
            .send({
                email: "test@example.com",
                password: "password123"
            });
        expect(res.statusCode).toEqual(200);
        expect(res.body).toHaveProperty('accessToken');
        expect(res.body).toHaveProperty('refreshToken');
        
        // Save token for other tests
        testToken = res.body.accessToken; 
        
        // Decode token to get user ID for profile tests
        const payload = JSON.parse(Buffer.from(testToken.split('.')[1], 'base64').toString());
        testUserId = payload.id;
    });

    it('POST /auth/login -> should fail with wrong password', async () => {
        const res = await authRequest
            .post('/auth/login')
            .send({
                email: "test@example.com",
                password: "wrongpassword"
            });
        expect(res.statusCode).toEqual(403);
    });
});


// --- App Server Tests (server.js) ---
describe('App Server API (/api)', () => {
    
    it('GET /health -> should return 200 OK', async () => {
        const res = await request.get('/health');
        expect(res.statusCode).toEqual(200);
        expect(res.body.status).toEqual('healthy');
    });

    // --- User Endpoint Tests ---
    it('GET /users/me -> should fail with 401 without a token', async () => {
        const res = await request.get('/users/me');
        expect(res.statusCode).toEqual(401);
    });

    it('GET /users/me -> should return user data with a valid token', async () => {
        const res = await request
            .get('/users/me')
            .set('Authorization', `Bearer ${testToken}`);
        
        expect(res.statusCode).toEqual(200);
        expect(res.body.email).toEqual('test@example.com');
    });

    it('PUT /users/:id/profile -> should update the user profile', async () => {
        const res = await request
            .put(`/users/${testUserId}/profile`)
            .set('Authorization', `Bearer ${testToken}`)
            .send({
                course_id: 1,
                university_id: 1,
                address: "123 Test St"
            });
        
        expect(res.statusCode).toEqual(200);
        expect(res.text).toContain('Profile updated successfully');
    });

    it('PUT /users/:id/profile -> should fail with 403 if user ID is wrong', async () => {
        const wrongId = testUserId + 10; // A different user ID
        const res = await request
            .put(`/users/${wrongId}/profile`) // Trying to update another user
            .set('Authorization', `Bearer ${testToken}`)
            .send({ address: "456 Hacker Ave" });
        
        expect(res.statusCode).toEqual(403); // Forbidden
    });

    // --- Resource Endpoint Tests ---
    it('POST /resources -> should fail with 401 without a token', async () => {
        const res = await request
            .post('/resources')
            .send({ title: "Test Book", category_id: 1, status_id: 1 });
            
        expect(res.statusCode).toEqual(401);
    });

    it('POST /resources -> should create a resource with a valid token', async () => {
        const res = await request
            .post('/resources')
            .set('Authorization', `Bearer ${testToken}`)
            .send({
                title: "My Test Book",
                description: "A great book.",
                category_id: 1,
                status_id: 1,
                price: 25.50
            });
        
        expect(res.statusCode).toEqual(201);
        expect(res.body).toHaveProperty('resourceId');
    });

    it('GET /resources -> should list all resources', async () => {
        const res = await request.get('/resources');
        expect(res.statusCode).toEqual(200);
        expect(res.body.length).toBeGreaterThan(0);
        expect(res.body[0].title).toEqual('My Test Book');
    });
});
