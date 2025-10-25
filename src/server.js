require('dotenv').config();

const express = require('express');
const app = express();
const pool = require('./database'); // Assuming './database' exports the PostgreSQL pool

const jwt = require('jsonwebtoken');

// --- Middleware ---
app.use(express.json());

// Assuming your JWT payload includes the user's ID as 'id'
function authenticateToken(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]
    
    if (token == null) {
        return res.status(401).json({ error: "Access token required" });
    }

    jwt.verify(token, process.env.ACCESS_TOKEN_SECRET, (err, user) => {
        if (err) {
            // 403 Forbidden: Token is invalid or expired
            return res.status(403).json({ error: "Invalid or expired token" });
        }
        // Attach the user information (including ID) to the request
        req.user = user
        next()
    })
}

// --- Development/Health Endpoints ---

// Health check endpoint for Kubernetes probes
app.get('/health', (req, res) => {
    res.status(200).json({ 
      status: 'healthy', 
      timestamp: new Date().toISOString()
    });
});

// Clear ALL tables (Use ONLY for testing/development)
app.post('/clear', async (req, res) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        await client.query(`
            -- TRUNCATING TABLES IN DEPENDENCY ORDER, using CASCADE for safety
            TRUNCATE TABLE
                requests,
                reports,
                reviews,
                purchases,
                borrowings,
                resource_images,
                resources,
                categories,
                statuses,
                users,
                courses,
                universities,
                roles
            RESTART IDENTITY
            CASCADE;
        `);
        await client.query('COMMIT');
        res.sendStatus(204);
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error clearing database:', err);
        res.status(500).json({ error: 'Database clear failed' });
    } finally {
        client.release();
    }
});

// Clear only users (Use ONLY for testing/development)
app.post('/clear/users', async (req, res) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        await client.query(`
            TRUNCATE TABLE users
            RESTART IDENTITY
            CASCADE;
        `);
        await client.query('COMMIT');
        res.sendStatus(204); 
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error clearing users table:', err);
        res.status(500).json({ error: 'User table clear failed' });
    } finally {
        client.release();
    }
});


// --- USER ENDPOINTS ---

// Public listing of all users (UNSAFE - Use only for development or protected Admin routes)
app.get('/users', async (req, res) => {
    // Note: In production, this should be secured and filtered/paginated
    try {
        const result = await pool.query('SELECT id, name, email, reputation, university_id FROM users');
        res.json(result.rows);
    } catch (err) {
        console.error(err);
        res.sendStatus(500);
    }
});

// GET authenticated user's profile (renamed from /usersWithToken)
app.get('/users/me', authenticateToken, async (req, res) => {
    try {
        // Fetch user data using the ID from the JWT payload
        const result = await pool.query(
            `SELECT u.id, u.name, u.email, u.reputation, u.address, u.latitude, u.longitude,
                    r.name AS role, uni.name AS university, c.name AS course
             FROM users u
             LEFT JOIN roles r ON u.role_id = r.id
             LEFT JOIN universities uni ON u.university_id = uni.id
             LEFT JOIN courses c ON u.course_id = c.id
             WHERE u.id = $1`, 
            [req.user.id]
        );
        
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }
        res.json(result.rows[0]);
    } catch (err) {
        console.error('Error fetching authenticated user:', err);
        res.sendStatus(500);
    }
});

// Update specific fields in users table (Profile update)
app.put('/users/:id/profile', authenticateToken, async (req, res) => {
    const { course_id, university_id, address, latitude, longitude, role_id } = req.body;
    const userId = parseInt(req.params.id);

    // Authorization Check: User can only update their own profile
    if (req.user.id !== userId) {
        return res.status(403).json({ error: "Forbidden: You can only update your own profile." });
    }
 
    try {
      const result = await pool.query(
        `UPDATE users
         SET course_id = COALESCE($1, course_id),
             university_id = COALESCE($2, university_id),
             address = COALESCE($3, address),
             latitude = COALESCE($4, latitude),
             longitude = COALESCE($5, longitude),
             role_id = COALESCE($6, role_id)
         WHERE id = $7
         RETURNING id`,
        [course_id, university_id, address, latitude, longitude, role_id, userId]
      );
      
      if (result.rows.length === 0) {
        return res.status(404).send('User not found.');
      }
 
      res.status(200).send('Profile updated successfully.');
    } catch (err) {
      console.error('Error updating user profile:', err);
      res.sendStatus(500);
    }
});


// --- RESOURCE ENDPOINTS (CORE PLATFORM FUNCTIONALITY) ---

// POST: Create a new resource
app.post('/resources', authenticateToken, async (req, res) => {
    const { title, description, category_id, status_id, price, image_urls } = req.body;
    const owner_id = req.user.id; // Owner ID comes from the authenticated token
    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        // 1. Insert Resource
        const resourceResult = await client.query(
            `INSERT INTO resources (owner_id, category_id, title, description, status_id, price)
             VALUES ($1, $2, $3, $4, $5, $6)
             RETURNING id`,
            [owner_id, category_id, title, description, status_id, price]
        );
        const resourceId = resourceResult.rows[0].id;

        // 2. Insert Images (if provided)
        if (image_urls && Array.isArray(image_urls) && image_urls.length > 0) {
            const imageQueries = image_urls.map(url =>
                `INSERT INTO resource_images (resource_id, image_url) VALUES (${resourceId}, '${url}')`
            ).join('; ');
            
            await client.query(imageQueries);
        }

        await client.query('COMMIT');
        res.status(201).json({ message: 'Resource created successfully', resourceId });

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error creating resource:', err);
        res.status(500).json({ error: 'Failed to create resource' });
    } finally {
        client.release();
    }
});

// GET: List and search resources (Basic implementation)
app.get('/resources', async (req, res) => {
    const { category_id, search, limit = 10, offset = 0 } = req.query;
    
    let query = `
        SELECT r.*, c.name AS category_name, u.name AS owner_name
        FROM resources r
        JOIN categories c ON r.category_id = c.id
        JOIN users u ON r.owner_id = u.id
        WHERE 1 = 1
    `;
    const params = [];

    if (category_id) {
        params.push(category_id);
        query += ` AND r.category_id = $${params.length}`;
    }

    if (search) {
        params.push(`%${search}%`);
        query += ` AND (r.title ILIKE $${params.length} OR r.description ILIKE $${params.length})`;
    }

    query += ` LIMIT ${limit} OFFSET ${offset}`;

    try {
        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (err) {
        console.error('Error listing resources:', err);
        res.sendStatus(500);
    }
});

// GET: Get resource details
app.get('/resources/:id', async (req, res) => {
    const resourceId = req.params.id;

    try {
        // 1. Fetch Resource Details
        const resourceResult = await pool.query(
            `SELECT r.*, 
                    u.name AS owner_name, u.email AS owner_email, u.reputation AS owner_reputation,
                    c.name AS category_name, s.name AS status_name
             FROM resources r
             JOIN users u ON r.owner_id = u.id
             JOIN categories c ON r.category_id = c.id
             JOIN statuses s ON r.status_id = s.id
             WHERE r.id = $1`,
            [resourceId]
        );

        if (resourceResult.rows.length === 0) {
            return res.status(404).json({ error: 'Resource not found' });
        }

        const resource = resourceResult.rows[0];

        // 2. Fetch Images
        const imageResult = await pool.query(
            'SELECT image_url FROM resource_images WHERE resource_id = $1',
            [resourceId]
        );
        resource.images = imageResult.rows.map(row => row.image_url);

        res.json(resource);

    } catch (err) {
        console.error('Error fetching resource details:', err);
        res.sendStatus(500);
    }
});

// PUT: Update resource details (Protected, requires ownership)
app.put('/resources/:id', authenticateToken, async (req, res) => {
    const resourceId = req.params.id;
    const { title, description, category_id, status_id, price } = req.body;
    const owner_id = req.user.id;

    try {
        // First: Verify ownership
        const ownerCheck = await pool.query(
            'SELECT owner_id FROM resources WHERE id = $1', [resourceId]
        );

        if (ownerCheck.rows.length === 0) {
            return res.status(404).json({ error: 'Resource not found' });
        }

        if (ownerCheck.rows[0].owner_id !== owner_id) {
            return res.status(403).json({ error: 'Forbidden: Only the owner can update this resource' });
        }

        // Second: Update the resource
        await pool.query(
            `UPDATE resources
             SET title = COALESCE($1, title),
                 description = COALESCE($2, description),
                 category_id = COALESCE($3, category_id),
                 status_id = COALESCE($4, status_id),
                 price = COALESCE($5, price)
             WHERE id = $6`,
            [title, description, category_id, status_id, price, resourceId]
        );

        res.status(200).send('Resource updated successfully.');

    } catch (err) {
        console.error('Error updating resource:', err);
        res.sendStatus(500);
    }
});

// DELETE: Delete a resource (Protected, requires ownership)
app.delete('/resources/:id', authenticateToken, async (req, res) => {
    const resourceId = req.params.id;
    const owner_id = req.user.id;
    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        // 1. Verify ownership (and check if it exists)
        const ownerCheck = await client.query(
            'SELECT owner_id FROM resources WHERE id = $1', [resourceId]
        );

        if (ownerCheck.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ error: 'Resource not found' });
        }

        if (ownerCheck.rows[0].owner_id !== owner_id) {
            await client.query('ROLLBACK');
            return res.status(403).json({ error: 'Forbidden: Only the owner can delete this resource' });
        }

        // 2. Delete related images (CASCADE should handle this, but explicit delete is safer)
        await client.query('DELETE FROM resource_images WHERE resource_id = $1', [resourceId]);

        // 3. Delete resource (CASCADE will handle borrowings, purchases, reviews, etc. if set up)
        const result = await client.query('DELETE FROM resources WHERE id = $1 RETURNING id', [resourceId]);

        if (result.rows.length === 0) {
             // Should not happen if ownerCheck passed, but good practice
            await client.query('ROLLBACK');
            return res.status(404).send('Resource not found');
        }

        await client.query('COMMIT');
        res.status(204).send(); // 204 No Content on successful deletion

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error deleting resource:', err);
        res.sendStatus(500);
    } finally {
        client.release();
    }
});


// --- LOOKUP ENDPOINTS (Metadata) ---

// GET: List all categories
app.get('/categories', async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM categories ORDER BY name');
        res.json(result.rows);
    } catch (err) {
        console.error('Error fetching categories:', err);
        res.sendStatus(500);
    }
});

// GET: List all universities
app.get('/universities', async (req, res) => {
    try {
        const result = await pool.query('SELECT id, name, location FROM universities ORDER BY name');
        res.json(result.rows);
    } catch (err) {
        console.error('Error fetching universities:', err);
        res.sendStatus(500);
    }
});

// GET: List courses for a specific university
app.get('/universities/:id/courses', async (req, res) => {
    const universityId = req.params.id;
    try {
        const result = await pool.query(
            'SELECT id, name FROM courses WHERE university_id = $1 ORDER BY name', 
            [universityId]
        );
        res.json(result.rows);
    } catch (err) {
        console.error('Error fetching courses:', err);
        res.sendStatus(500);
    }
});


// --- Server Startup ---
const PORT = 3000;
// Only run the server (app.listen) if this file is executed directly
if (require.main === module) {
    app.listen(PORT, () => {
        console.log(`Server running on port ${PORT}`);
    })
}

module.exports = app;