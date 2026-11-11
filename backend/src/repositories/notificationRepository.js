const db = require('../config/db');

class NotificationRepository {
  async healthCheck() {
    const res = await db.query('SELECT NOW()');
    return res.rows[0];
  }
}

module.exports = new NotificationRepository();
