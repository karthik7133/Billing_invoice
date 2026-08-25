const mongoose = require('mongoose');

const InvoiceItemSchema = new mongoose.Schema({
  productId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Product',
    default: null,
  },
  name: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    default: '',
  },
  hsnSac: {
    type: String,
    default: '',
  },
  unit: {
    type: String,
    default: 'PCS',
  },
  quantity: {
    type: Number,
    required: true,
    min: 0.01,
  },
  rate: {
    type: Number,
    required: true,
    min: 0,
  },
  grossAmount: {
    type: Number,
    required: true,
  },
  discount: {
    type: Number,
    default: 0,
  },
  discountType: {
    type: String,
    enum: ['FIXED', 'PERCENT'],
    default: 'FIXED',
  },
  discountAmount: {
    type: Number,
    default: 0,
  },
  taxableAmount: {
    type: Number,
    required: true,
  },
  gstRate: {
    type: Number,
    required: true,
    default: 18,
  },
  cgstRate: { type: Number, default: 0 },
  sgstRate: { type: Number, default: 0 },
  igstRate: { type: Number, default: 0 },
  cgst: { type: Number, default: 0 },
  sgst: { type: Number, default: 0 },
  igst: { type: Number, default: 0 },
  totalTax: { type: Number, default: 0 },
  total: {
    type: Number,
    required: true,
  },
});

const InvoiceSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    invoiceNumber: {
      type: String,
      required: true,
      trim: true,
    },
    customerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Customer',
      required: true,
    },
    // Historical Customer Snapshot
    customerSnapshot: {
      name: { type: String, required: true },
      phone: { type: String, default: '' },
      email: { type: String, default: '' },
      billingAddress: { type: String, default: '' },
      shippingAddress: { type: String, default: '' },
      city: { type: String, default: '' },
      state: { type: String, required: true },
      stateCode: { type: String, default: '' },
      gstin: { type: String, default: '' },
      pan: { type: String, default: '' },
      customerType: { type: String, default: 'UNREGISTERED_B2C' },
    },
    // Historical Business Snapshot
    businessSnapshot: {
      businessName: { type: String, default: '' },
      logo: { type: String, default: '' },
      phone: { type: String, default: '' },
      email: { type: String, default: '' },
      address: { type: String, default: '' },
      city: { type: String, default: '' },
      state: { type: String, default: '' },
      stateCode: { type: String, default: '' },
      pincode: { type: String, default: '' },
      gstin: { type: String, default: '' },
      pan: { type: String, default: '' },
      bankDetails: {
        bankName: { type: String, default: '' },
        accountHolderName: { type: String, default: '' },
        accountNumber: { type: String, default: '' },
        ifscCode: { type: String, default: '' },
        branch: { type: String, default: '' },
        upiId: { type: String, default: '' },
      },
    },
    invoiceDate: {
      type: Date,
      default: Date.now,
    },
    dueDate: {
      type: Date,
      default: () => new Date(Date.now() + 15 * 24 * 60 * 60 * 1000), // 15 days default
    },
    items: [InvoiceItemSchema],
    isInterState: {
      type: Boolean,
      default: false,
    },
    subtotal: {
      type: Number,
      required: true,
      default: 0,
    },
    itemsDiscount: {
      type: Number,
      default: 0,
    },
    extraDiscount: {
      type: Number,
      default: 0,
    },
    totalDiscount: {
      type: Number,
      default: 0,
    },
    taxableAmount: {
      type: Number,
      required: true,
      default: 0,
    },
    cgst: {
      type: Number,
      default: 0,
    },
    sgst: {
      type: Number,
      default: 0,
    },
    igst: {
      type: Number,
      default: 0,
    },
    totalTax: {
      type: Number,
      default: 0,
    },
    otherCharges: {
      type: Number,
      default: 0,
    },
    roundOff: {
      type: Number,
      default: 0,
    },
    grandTotal: {
      type: Number,
      required: true,
      default: 0,
    },
    amountPaid: {
      type: Number,
      default: 0,
    },
    balanceDue: {
      type: Number,
      default: 0,
    },
    status: {
      type: String,
      enum: ['DRAFT', 'ISSUED', 'PAID', 'PARTIALLY_PAID', 'CANCELLED'],
      default: 'ISSUED',
    },
    paymentType: {
      type: String,
      default: 'Cash',
    },
    description: {
      type: String,
      default: '',
    },
    origin: {
      type: String,
      default: 'AP',
    },
    attachments: [
      {
        type: String,
      },
    ],
    excessAmount: {
      type: Number,
      default: 0,
    },
    notes: {
      type: String,
      default: 'Thank you for your business!',
    },
    termsAndConditions: {
      type: String,
      default: '',
    },
    amountInWords: {
      type: String,
      default: '',
    },
    pdfUrl: {
      type: String,
      default: '',
    },
  },
  { timestamps: true }
);

// Compound index for invoice number per user
InvoiceSchema.index({ userId: 1, invoiceNumber: 1 });

module.exports = mongoose.model('Invoice', InvoiceSchema);
