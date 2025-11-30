const router = require('express').Router();
const authController = require('../controllers/authController');
const { authenticateToken } = require('../middleware/authMiddleware');

// Health check endpoint
router.get('/health', authController.healt);
// User registration endpoint
router.post('/register', authController.register);
// Token refresh endpoint
router.post('/token', authController.refreshToken);
// User logout endpoint
router.delete('/logout', authenticateToken, authController.logout);
// User login endpoint
router.post('/login', authController.login);

module.exports = router;