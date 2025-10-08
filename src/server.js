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

app.get('/users', async (req, res) => {
    const result = await pool.query('SELECT * FROM users');
    res.json(result.rows);
})

app.get('/usersWithToken', authenticateToken, async (req, res) => {
    //res.json(users.filter(user => user.email === req.user.email));
    const result = await pool.query('SELECT name, email FROM users WHERE email = $1', [req.user.email]);
    res.json(result.rows);
})

app.listen(3000)