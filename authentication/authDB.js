const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.AUTH_DATABASE_HOST,
  user: process.env.AUTH_DATABASE_USER,
  password: process.env.AUTH_DATABASE_PASSWORD,
  database: process.env.AUTH_DATABASE_NAME,
  port: parseInt(process.env.AUTH_DATABASE_PORT),
});

module.exports = pool;