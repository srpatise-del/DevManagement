const notificationService = require('../services/notificationService');

async function getHealth(req, res, next) {
  try {
    const dbStatus = await notificationService.checkDatabaseHealth();
    res.status(200).json({
      success: true,
      status: 'UP',
      timestamp: new Date().toISOString(),
      database: dbStatus,
    });
  } catch (error) {
    next(error);
  }
}

module.exports = {
  getHealth,
};
