const express = require('express');

// Load environment variables from .env file
require('dotenv').config();

const app = express();


// Import user routes
app.use('/api/users/', require('./routes/authRoutes'));
const PORT = process.env.AUTH_PORT || 4000;

app.listen(PORT, () => {
    console.log(`Server is running on http://localhost:${PORT}`);
});