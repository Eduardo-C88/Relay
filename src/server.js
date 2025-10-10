require('dotenv').config();

const express = require('express');
const app = express();
const pool = require('./database');

const jwt = require('jsonwebtoken');

app.use(express.json());

function authenticateToken(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]
    if (token == null) return res.sendStatus(401)

    jwt.verify(token, process.env.ACCESS_TOKEN_SECRET, (err, user) => {
        if (err) return res.sendStatus(403)
        req.user = user
        next()
    })
}

//clear all tables
app.post('/clear', async (req, res) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        await client.query(`
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
        res.sendStatus(500);
    } finally {
        client.release();
    }
});

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
        res.sendStatus(204); // No content (successful)
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error clearing users table:', err);
        res.sendStatus(500);
    } finally {
        client.release();
    }
});

app.get('/users', async (req, res) => {
    const result = await pool.query('SELECT * FROM users');
    res.json(result.rows);
})

app.get('/usersWithToken', authenticateToken, async (req, res) => {
    //res.json(users.filter(user => user.email === req.user.email));
    const result = await pool.query('SELECT name, email FROM users WHERE email = $1', [req.user.email]);
    res.json(result.rows);
})

// Update extra fields in users table
app.put('/users/:id/profile', async (req, res) => {
    const { course_id, university_id, address, latitude, longitude, role_id } = req.body;
    const userId = req.params.id;
  
    try {
      await pool.query(
        `UPDATE users
         SET course_id = $1,
             university_id = $2,
             address = $3,
             latitude = $4,
             longitude = $5,
             role_id = $6
         WHERE id = $7`,
        [course_id, university_id, address, latitude, longitude, role_id, userId]
      );
  
      res.status(200).send('Profile updated');
    } catch (err) {
      console.error(err);
      res.sendStatus(500);
    }
});

app.listen(3000)