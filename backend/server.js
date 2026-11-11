require('dotenv').config();
const app = require('./src/app');

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`DevCase Notification Backend server is running on port ${PORT}`);
});
