const notificationRepository = require('../repositories/notificationRepository');

class NotificationService {
  async checkDatabaseHealth() {
    try {
      const result = await notificationRepository.healthCheck();
      return { status: 'healthy', timestamp: result.now };
    } catch (error) {
      throw new Error('Database unhealthy: ' + error.message);
    }
  }
}

module.exports = new NotificationService();
