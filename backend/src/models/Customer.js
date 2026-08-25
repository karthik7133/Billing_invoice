const mongoose = require('mongoose');

const CustomerSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    companyId: {
      type: String,
      trim: true,
      default: '',
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
      trim: true,
      default: 'Andhra Pradesh',
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
    billingName: {
      type: String,
      trim: true,
      default: '',
    },
    openingBalance: {
      type: Number,
      default: 0,
    },
    partyType: {
      type: String,
      enum: ['CUSTOMER', 'SUPPLIER'],
      default: 'CUSTOMER',
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
