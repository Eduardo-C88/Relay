require('dotenv').config();

const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const pool = require('./database');

const app = express();
app.use(express.json());

let refreshTokens = []

function generateAccessToken(user) {
    return jwt.sign(user, process.env.ACCESS_TOKEN_SECRET, { expiresIn: '15m' })
}

app.post('/register', async (req, res) => {
    const { name, email, password } = req.body;
  
    if (!name || !email || !password)
      return res.status(400).send('Name, email, and password required');
  
    try {
      //const hashed = await bcrypt.hash(password, 10);
      const hashed = password; // For simplicity, not hashing in this example
      await pool.query(
        'INSERT INTO users (name, email, password) VALUES ($1, $2, $3)',
        [name, email, hashed]
      );
      res.status(201).send('User registered');
    } catch (err) {
      console.error(err);
      if (err.code === '23505') {
        return res.status(409).send('Email already exists');
      }
      res.sendStatus(500);
    }
  });

app.post('/token', async (req, res) => {
    const refreshToken = req.body.token
    if(refreshToken == null) return res.sendStatus(401)

    if(!refreshTokens.includes(refreshToken)) return res.sendStatus(403)

    jwt.verify(refreshToken, process.env.REFRESH_TOKEN_SECRET, (err, user) => {
        if(err) return res.sendStatus(403)
        const accessToken = generateAccessToken({ email: user.email })
        res.json({ accessToken: accessToken })
    })
})

app.delete('/logout', async (req, res) => {
    refreshTokens = refreshTokens.filter(token => token !== req.body.token)
    res.sendStatus(204)
})

app.post('/login', async (req, res) => {
    // Authenticate User
    const { email, password } = req.body;

    // 1. Find user
    const userResult = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    const user = userResult.rows[0];
    if (!user) return res.status(400).json({ message: 'User not found' });
  
    // 2. Verify password
    //const valid = await bcrypt.compare(password, user.password);
    const valid = password === user.password; // For simplicity, not hashing in this example
    if (!valid) return res.status(403).json({ message: 'Invalid password' });

    // 3. Generate tokens
    const payload = { id: user.id, email: user.email };

    const accessToken = generateAccessToken(payload);
    const refreshToken = jwt.sign(payload, process.env.REFRESH_TOKEN_SECRET);
    
    refreshTokens.push(refreshToken);
    // Store refreshToken in DB or memory

    res.json({ accessToken: accessToken, refreshToken: refreshToken });
})

app.listen(4000)