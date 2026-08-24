const mongoose = require('mongoose');

const connectDB = async () => {
  const connUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/gst_billing_app';

  try {
    mongoose.set('strictQuery', false);
    const conn = await mongoose.connect(connUri, {
      serverSelectionTimeoutMS: 10000,
      socketTimeoutMS: 45000,
    });
    console.log(`[MongoDB] ✅ Connected: ${conn.connection.host}`);
  } catch (error) {
    console.error(`[MongoDB] ❌ Connection failed: ${error.message}`);
    console.error('[MongoDB] Make sure MONGODB_URI is set and the IP is whitelisted in Atlas.');
    // On Render, exit so the platform auto-restarts with a fresh connection attempt
    process.exit(1);
  }
};

// Reconnect on unexpected disconnection
mongoose.connection.on('disconnected', () => {
  console.warn('[MongoDB] Disconnected. Attempting to reconnect...');
});

mongoose.connection.on('reconnected', () => {
  console.log('[MongoDB] ✅ Reconnected successfully.');
});

module.exports = connectDB;
