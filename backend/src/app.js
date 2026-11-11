const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const healthRoutes = require('./routes/healthRoutes');
const errorHandler = require('./middleware/errorHandler');

const app = express();

// Security and utility middlewares
app.use(helmet());
app.use(cors());
app.use(express.json());

// Routes
app.use('/api', healthRoutes);

// Root route
app.get('/', (req, res) => {
  res.json({ message: 'Welcome to DevCase Notification Backend API (Phase 1)' });
});

// Error handling middleware
app.use(errorHandler);

module.exports = app;
