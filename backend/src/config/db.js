const mongoose = require('mongoose');

const connectDB = async () => {
  const connUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/gst_billing_app';
  try {
    const conn = await mongoose.connect(connUri, {
      serverSelectionTimeoutMS: 6000,
    });
    console.log(`[MongoDB] Connected successfully to Atlas Cluster: ${conn.connection.host}`);
  } catch (error) {
    console.warn(`\n-----------------------------------------------------------`);
    console.warn(`[MongoDB Warning] Could not connect to Atlas Cluster: ${error.message}`);
    if (error.message.includes('Could not connect to any servers') || error.message.includes('whitelist')) {
      console.warn(`\n[Action Required in MongoDB Atlas]:`);
      console.warn(`1. Open https://cloud.mongodb.com/`);
      console.warn(`2. Navigate to: Security -> Network Access`);
      console.warn(`3. Click "+ Add IP Address" -> "Allow Access From Anywhere" (0.0.0.0/0) or "Add Current IP"`);
      console.warn(`4. Click Confirm. It will connect automatically within 30-60 seconds!`);
    }
    console.warn(`-----------------------------------------------------------\n`);
  }
};

module.exports = connectDB;
