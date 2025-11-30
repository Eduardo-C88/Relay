const jwt = require('jsonwebtoken');
require('dotenv').config();

// Middleware to generate a token
function generateAccessToken(user) {
    return jwt.sign(user, process.env.ACCESS_TOKEN_SECRET, { expiresIn: '15m' })
}

// Middleware to verify a token
const authenticateToken = (req, res, next) => {
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
};

module.exports = {
    generateAccessToken,
    authenticateToken
};