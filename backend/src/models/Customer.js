const mongoose = require('mongoose');

const CustomerSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    name: {
      type: String,
      required: [true, 'Customer name is required'],
      trim: true,
    },
    phone: {
      type: String,
      trim: true,
      default: '',
    },
    email: {
      type: String,
      trim: true,
      lowercase: true,
      default: '',
    },
    billingAddress: {
      type: String,
      trim: true,
      default: '',
    },
    shippingAddress: {
      type: String,
      trim: true,
      default: '',
    },
    city: {
      type: String,
      trim: true,
      default: '',
    },
    state: {
      type: String,
      required: [true, 'Customer state is required for GST determination'],
      trim: true,
    },
    stateCode: {
      type: String,
      trim: true,
      default: '',
    },
    pincode: {
      type: String,
      trim: true,
      default: '',
    },
    gstin: {
      type: String,
      trim: true,
      uppercase: true,
      default: '',
    },
    pan: {
      type: String,
      trim: true,
      uppercase: true,
      default: '',
    },
    customerType: {
      type: String,
      enum: ['REGISTERED_B2B', 'UNREGISTERED_B2C'],
      default: 'UNREGISTERED_B2C',
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Customer', CustomerSchema);
