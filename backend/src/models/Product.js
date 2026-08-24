const mongoose = require('mongoose');

const ProductSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    name: {
      type: String,
      required: [true, 'Product or Service name is required'],
      trim: true,
    },
    description: {
      type: String,
      trim: true,
      default: '',
    },
    hsnSac: {
      type: String,
      trim: true,
      default: '',
    },
    itemType: {
      type: String,
      enum: ['PRODUCT', 'SERVICE'],
      default: 'PRODUCT',
    },
    unit: {
      type: String,
      trim: true,
      default: 'PCS',
    },
    price: {
      type: Number,
      required: [true, 'Price is required'],
      min: [0, 'Price must be positive'],
    },
    gstRate: {
      type: Number,
      required: [true, 'GST rate is required'],
      enum: [0, 0.1, 0.25, 3, 5, 12, 18, 28],
      default: 18,
    },
    imageUrl: {
      type: String,
      default: '',
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Product', ProductSchema);
