const mongoose = require('mongoose');
const Invoice = require('../models/Invoice');
const Business = require('../models/Business');
const Customer = require('../models/Customer');
const { calculateInvoiceTotals } = require('../utils/gstCalculator');
const { numberToWordsIndian } = require('../utils/numberToWords');

// ── In-memory TTL cache for company filter lookups ────────────────────────────────
// Avoids a Business.findOne() DB hit on every single invoice request.
// TTL of 30s is safe because business ID / company scope rarely changes.
const _companyFilterCache = new Map(); // key: userId|companyId -> { filter, expiresAt }
const COMPANY_FILTER_TTL_MS = 30_000; // 30 seconds

// Helper to format invoice number
const formatInvoiceNumber = (prefix = 'INV', num = 1) => {
  return `${prefix}-${String(num).padStart(4, '0')}`;
};

// Helper to build isolated company filter (with in-memory TTL cache)
const buildCompanyFilter = async (userId, companyId) => {
  const cacheKey = `${userId}|${(companyId || '').trim()}`;
  const cached = _companyFilterCache.get(cacheKey);
  if (cached && cached.expiresAt > Date.now()) {
    return cached.filter;
  }

  const primaryBusiness = await Business.findOne({ userId }).lean();
  const primaryId = primaryBusiness ? primaryBusiness._id.toString() : null;

  const cid = (companyId || '').trim();
  const isPrimary = !cid || cid === 'comp_1' || cid === 'primary' || (primaryId && cid === primaryId);

  let filter;
  if (isPrimary) {
    const orList = [
      { companyId: 'comp_1' },
      { companyId: '' },
      { companyId: null },
      { companyId: { $exists: false } },
    ];
    if (primaryId) {
      orList.push({ companyId: primaryId });
    }
    filter = { $or: orList };
  } else {
    filter = { companyId: cid };
  }

  _companyFilterCache.set(cacheKey, { filter, expiresAt: Date.now() + COMPANY_FILTER_TTL_MS });
  return filter;
};

// @desc    Get next invoice number preview
// @route   GET /api/invoices/next-number
// @access  Private
const getNextInvoiceNumber = async (req, res) => {
  try {
    const business = await Business.findOne({ userId: req.user._id });
    const prefix = business ? business.invoicePrefix || 'INV' : 'INV';
    const nextNum = business ? business.nextInvoiceNumber || 1 : 1;
    const formatted = formatInvoiceNumber(prefix, nextNum);

    res.json({
      success: true,
      prefix,
      nextNumber: nextNum,
      formattedInvoiceNumber: formatted,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get all invoices with filtering & search
// @route   GET /api/invoices
// @access  Private
const getInvoices = async (req, res) => {
  try {
    const { status, search, startDate, endDate, period, companyId } = req.query;
    const andConditions = [{ userId: req.user._id, isDeleted: { $ne: true } }];

    // Company isolation filter
    const companyFilter = await buildCompanyFilter(req.user._id, companyId);
    andConditions.push(companyFilter);

    // Status filter
    if (status && status !== 'ALL') {
      if (status === 'UNPAID') {
        andConditions.push({ status: { $in: ['ISSUED', 'PARTIALLY_PAID'] } });
      } else {
        andConditions.push({ status: status });
      }
    }

    // Date range filter
    if (period) {
      const now = new Date();
      if (period === 'today') {
        const start = new Date(now.setHours(0, 0, 0, 0));
        const end = new Date(now.setHours(23, 59, 59, 999));
        andConditions.push({ invoiceDate: { $gte: start, $lte: end } });
      } else if (period === 'week') {
        const firstDay = new Date(now.setDate(now.getDate() - now.getDay()));
        firstDay.setHours(0, 0, 0, 0);
        andConditions.push({ invoiceDate: { $gte: firstDay } });
      } else if (period === 'month') {
        const firstDay = new Date(now.getFullYear(), now.getMonth(), 1);
        andConditions.push({ invoiceDate: { $gte: firstDay } });
      }
    } else if (startDate || endDate) {
      const dateFilter = {};
      if (startDate) dateFilter.$gte = new Date(startDate);
      if (endDate) {
        const end = new Date(endDate);
        end.setHours(23, 59, 59, 999);
        dateFilter.$lte = end;
      }
      andConditions.push({ invoiceDate: dateFilter });
    }

    // Search query
    if (search) {
      andConditions.push({
        $or: [
          { invoiceNumber: { $regex: search, $options: 'i' } },
          { 'customerSnapshot.name': { $regex: search, $options: 'i' } },
          { 'customerSnapshot.phone': { $regex: search, $options: 'i' } },
        ],
      });
    }

    const query = andConditions.length > 1 ? { $and: andConditions } : andConditions[0];

    // .lean() returns plain JS objects (~30-40% faster serialization).
    // Projection excludes heavy fields not needed for the list view
    // (full item details, terms, etc. are only needed on single-invoice fetch).
    const listProjection = {
      userId: 0,
      'businessSnapshot.bankDetails': 0,
      termsAndConditions: 0,
      __v: 0,
    };

    const invoices = await Invoice.find(query, listProjection)
      .sort({ invoiceDate: -1, createdAt: -1 })
      .lean();

    // Aggregate summary for the filtered results
    const summary = invoices.reduce(
      (acc, inv) => {
        acc.totalAmount += inv.grandTotal || 0;
        acc.totalPaid += inv.amountPaid || 0;
        acc.totalDue += inv.balanceDue || 0;
        return acc;
      },
      { totalAmount: 0, totalPaid: 0, totalDue: 0 }
    );

    res.json({
      success: true,
      count: invoices.length,
      summary: {
        totalAmount: Number(summary.totalAmount.toFixed(2)),
        totalPaid: Number(summary.totalPaid.toFixed(2)),
        totalDue: Number(summary.totalDue.toFixed(2)),
      },
      invoices,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get single invoice by ID
// @route   GET /api/invoices/:id
// @access  Private
const getInvoiceById = async (req, res) => {
  try {
    const invoice = await Invoice.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!invoice) {
      return res.status(404).json({ success: false, message: 'Invoice not found' });
    }

    res.json({ success: true, invoice });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Create new invoice with GST calculation and snapshots
// @route   POST /api/invoices
// @access  Private
const createInvoice = async (req, res) => {
  try {
    const {
      customerId,
      invoiceNumber: customInvoiceNumber,
      invoiceDate,
      dueDate,
      items,
      invoiceDiscount,
      invoiceDiscountType,
      otherCharges,
      status = 'ISSUED',
      amountPaid = 0,
      notes,
      termsAndConditions,
      companyId,
    } = req.body;

    if (!customerId) {
      return res.status(400).json({ success: false, message: 'Customer is required' });
    }

    if (!items || !items.length) {
      return res.status(400).json({ success: false, message: 'At least one item is required' });
    }

    const companyScope = (companyId || '').trim() || 'comp_1';
    const companyFilter = await buildCompanyFilter(req.user._id, companyScope);

    // Fetch or resolve Customer
    let customer;
    if (customerId) {
      customer = await Customer.findOne({
        _id: customerId,
        userId: req.user._id,
      });
    }

    // If not found by ID, attempt lookup by name (within same company scope)
    if (!customer && req.body.customerName) {
      customer = await Customer.findOne({
        userId: req.user._id,
        name: { $regex: new RegExp(`^${req.body.customerName.trim()}$`, 'i') },
        ...companyFilter,
      });

      if (!customer) {
        customer = await Customer.create({
          userId: req.user._id,
          companyId: companyScope,
          name: req.body.customerName.trim(),
          phone: req.body.customerPhone || '',
          state: req.body.customerState || 'Andhra Pradesh',
          billingName: req.body.billingName || req.body.customerName.trim(),
        });
      }
    }

    if (!customer) {
      return res.status(404).json({ success: false, message: 'Customer not found' });
    }

    // Fetch Business Profile
    let business = await Business.findOne({ userId: req.user._id });
    if (!business) {
      business = await Business.create({
        userId: req.user._id,
        businessName: `${req.user.name}'s Business`,
        email: req.user.email,
        state: 'Andhra Pradesh',
        stateCode: '37',
      });
    }

    // Determine invoice number
    let finalInvoiceNumber = customInvoiceNumber;
    if (!finalInvoiceNumber) {
      const prefix = business.invoicePrefix || 'INV';
      const nextNum = business.nextInvoiceNumber || 1;
      finalInvoiceNumber = formatInvoiceNumber(prefix, nextNum);
      // Increment business invoice counter
      business.nextInvoiceNumber = nextNum + 1;
      await business.save();
    }

    // ── Duplicate invoice number check per customer ───────────────────────
    const existingInvoice = await Invoice.findOne({
      userId: req.user._id,
      customerId: customer._id,
      invoiceNumber: finalInvoiceNumber,
    });
    if (existingInvoice) {
      return res.status(409).json({
        success: false,
        message: `Invoice #${finalInvoiceNumber} already exists for customer "${customer.name}". Please use a different invoice number.`,
      });
    }
    // ─────────────────────────────────────────────────────────────────────

    // Run Calculation Engine
    const calculated = calculateInvoiceTotals({
      items,
      sellerState: business.state,
      buyerState: customer.state,
      invoiceDiscount,
      invoiceDiscountType,
      otherCharges,
    });

    const grandTotal = calculated.grandTotal;

    // Parse payments list or synthesize from amountPaid
    let parsedPayments = [];
    if (Array.isArray(req.body.payments) && req.body.payments.length > 0) {
      parsedPayments = req.body.payments.map((p) => ({
        amount: Number(p.amount) || 0,
        type: p.type || req.body.paymentType || 'Cash',
        date: p.date ? new Date(p.date) : (invoiceDate ? new Date(invoiceDate) : new Date()),
        notes: p.notes || '',
      }));
    } else if (Number(amountPaid) > 0) {
      parsedPayments = [
        {
          amount: Number(amountPaid),
          type: req.body.paymentType || 'Cash',
          date: invoiceDate ? new Date(invoiceDate) : new Date(),
          notes: '',
        },
      ];
    }

    const paid = parsedPayments.length > 0
      ? Number(parsedPayments.reduce((sum, p) => sum + (Number(p.amount) || 0), 0).toFixed(2))
      : (Number(amountPaid) || 0);

    const balanceDue = Number(Math.max(0, grandTotal - paid).toFixed(2));
    const excessAmount = paid > grandTotal ? Number((paid - grandTotal).toFixed(2)) : 0;

    let finalStatus = status;
    if (paid >= grandTotal && grandTotal > 0) {
      finalStatus = 'PAID';
    } else if (paid > 0 && paid < grandTotal) {
      finalStatus = 'PARTIALLY_PAID';
    }

    const amountInWords = numberToWordsIndian(grandTotal);

    // Create Invoice with Immutable Snapshots
    const invoice = await Invoice.create({
      userId: req.user._id,
      companyId: companyScope,
      invoiceNumber: finalInvoiceNumber,
      customerId: customer._id,
      customerSnapshot: {
        name: customer.name,
        phone: customer.phone || '',
        email: customer.email || '',
        billingAddress: customer.billingAddress || '',
        shippingAddress: customer.shippingAddress || customer.billingAddress || '',
        city: customer.city || '',
        state: customer.state,
        stateCode: customer.stateCode || '',
        gstin: customer.gstin || '',
        pan: customer.pan || '',
        customerType: customer.customerType || 'UNREGISTERED_B2C',
      },
      businessSnapshot: {
        businessName: business.businessName,
        logo: business.logo || '',
        phone: business.phone || '',
        email: business.email || '',
        address: business.address || '',
        city: business.city || '',
        state: business.state || '',
        stateCode: business.stateCode || '',
        pincode: business.pincode || '',
        gstin: business.gstin || '',
        pan: business.pan || '',
        bankDetails: business.bankDetails || {},
      },
      invoiceDate: invoiceDate ? new Date(invoiceDate) : new Date(),
      dueDate: dueDate ? new Date(dueDate) : new Date(Date.now() + 15 * 24 * 60 * 60 * 1000),
      items: calculated.items,
      isInterState: calculated.isInterState,
      subtotal: calculated.subtotal,
      itemsDiscount: calculated.itemsDiscount,
      extraDiscount: calculated.extraDiscount,
      totalDiscount: calculated.totalDiscount,
      taxableAmount: calculated.taxableAmount,
      cgst: calculated.cgst,
      sgst: calculated.sgst,
      igst: calculated.igst,
      totalTax: calculated.totalTax,
      otherCharges: calculated.otherCharges,
      roundOff: calculated.roundOff,
      grandTotal: calculated.grandTotal,
      amountPaid: paid,
      balanceDue: balanceDue,
      excessAmount: excessAmount,
      payments: parsedPayments,
      paymentType: req.body.paymentType || (parsedPayments.length > 0 ? parsedPayments[0].type : 'Cash'),
      description: req.body.description || notes || '',
      origin: req.body.origin || 'AP',
      attachments: Array.isArray(req.body.attachments) ? req.body.attachments : [],
      status: finalStatus,
      notes: notes || req.body.description || 'Thank you for your business!',
      termsAndConditions: termsAndConditions || business.termsAndConditions || '',
      amountInWords: amountInWords,
    });

    res.status(201).json({ success: true, invoice });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update invoice status / Mark as Paid
// @route   PUT /api/invoices/:id/status
// @access  Private
const updateInvoiceStatus = async (req, res) => {
  try {
    const { status, amountPaid } = req.body;

    let invoice = await Invoice.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!invoice) {
      return res.status(404).json({ success: false, message: 'Invoice not found' });
    }

    if (status) invoice.status = status;
    if (amountPaid !== undefined) {
      invoice.amountPaid = Number(amountPaid);
      invoice.balanceDue = Number(Math.max(0, invoice.grandTotal - invoice.amountPaid).toFixed(2));
      invoice.excessAmount = invoice.amountPaid > invoice.grandTotal ? Number((invoice.amountPaid - invoice.grandTotal).toFixed(2)) : 0;
      if (invoice.amountPaid >= invoice.grandTotal) {
        invoice.status = 'PAID';
      } else if (invoice.amountPaid > 0) {
        invoice.status = 'PARTIALLY_PAID';
      }
    }

    await invoice.save();
    res.json({ success: true, invoice });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Mark invoice as fully paid
// @route   POST /api/invoices/:id/mark-paid
// @access  Private
const markInvoiceAsPaid = async (req, res) => {
  try {
    let invoice = await Invoice.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!invoice) {
      return res.status(404).json({ success: false, message: 'Invoice not found' });
    }

    invoice.amountPaid = invoice.grandTotal;
    invoice.balanceDue = 0;
    invoice.status = 'PAID';

    await invoice.save();
    res.json({ success: true, invoice });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update invoice (e.g. invoiceNumber, notes, items, status, etc.)
// @route   PUT /api/invoices/:id
// @access  Private
const updateInvoice = async (req, res) => {
  try {
    const { id } = req.params;
    let query = { userId: req.user._id };

    if (mongoose.Types.ObjectId.isValid(id)) {
      query._id = id;
    } else {
      query.$or = [{ _id: id }, { invoiceNumber: id }];
    }

    let invoice = await Invoice.findOne(query);

    if (!invoice) {
      return res.status(404).json({ success: false, message: 'Invoice not found' });
    }

    if (req.body.invoiceNumber !== undefined && req.body.invoiceNumber !== null) {
      const newNum = String(req.body.invoiceNumber).trim();
      if (newNum !== invoice.invoiceNumber) {
        // Check uniqueness for the same customer
        const existing = await Invoice.findOne({
          userId: req.user._id,
          customerId: invoice.customerId,
          invoiceNumber: newNum,
          _id: { $ne: invoice._id },
        });
        if (existing) {
          return res.status(409).json({
            success: false,
            message: `Invoice #${newNum} already exists for this customer. Please use a different number.`,
          });
        }
      }
      invoice.invoiceNumber = newNum;
    }

    // Recalculate totals if items are updated
    if (req.body.items && Array.isArray(req.body.items) && req.body.items.length > 0) {
      const business = await Business.findOne({ userId: req.user._id });
      const sellerState = business ? business.state : 'Andhra Pradesh';
      const buyerState = invoice.customerSnapshot ? invoice.customerSnapshot.state : sellerState;

      const calculated = calculateInvoiceTotals({
        items: req.body.items,
        sellerState,
        buyerState,
        invoiceDiscount: req.body.invoiceDiscount !== undefined ? req.body.invoiceDiscount : invoice.extraDiscount,
        invoiceDiscountType: req.body.invoiceDiscountType || 'FIXED',
        otherCharges: req.body.otherCharges !== undefined ? req.body.otherCharges : invoice.otherCharges,
      });

      invoice.items = calculated.items;
      invoice.isInterState = calculated.isInterState;
      invoice.subtotal = calculated.subtotal;
      invoice.itemsDiscount = calculated.itemsDiscount;
      invoice.extraDiscount = calculated.extraDiscount;
      invoice.totalDiscount = calculated.totalDiscount;
      invoice.taxableAmount = calculated.taxableAmount;
      invoice.cgst = calculated.cgst;
      invoice.sgst = calculated.sgst;
      invoice.igst = calculated.igst;
      invoice.totalTax = calculated.totalTax;
      invoice.otherCharges = calculated.otherCharges;
      invoice.roundOff = calculated.roundOff;
      invoice.grandTotal = calculated.grandTotal;
      invoice.amountInWords = numberToWordsIndian(calculated.grandTotal);
    }

    const simpleFields = [
      'invoiceDate',
      'dueDate',
      'origin',
      'attachments',
      'paymentType',
      'description',
      'notes',
      'termsAndConditions',
      'companyId',
    ];

    simpleFields.forEach((field) => {
      if (req.body[field] !== undefined) {
        if (field === 'invoiceDate' || field === 'dueDate') {
          invoice[field] = new Date(req.body[field]);
        } else {
          invoice[field] = req.body[field];
        }
      }
    });

    if (Array.isArray(req.body.payments)) {
      invoice.payments = req.body.payments.map((p) => ({
        amount: Number(p.amount) || 0,
        type: p.type || invoice.paymentType || 'Cash',
        date: p.date ? new Date(p.date) : new Date(),
        notes: p.notes || '',
      }));
      invoice.amountPaid = Number(invoice.payments.reduce((sum, p) => sum + (p.amount || 0), 0).toFixed(2));
      invoice.balanceDue = Number(Math.max(0, invoice.grandTotal - invoice.amountPaid).toFixed(2));
      invoice.excessAmount = invoice.amountPaid > invoice.grandTotal ? Number((invoice.amountPaid - invoice.grandTotal).toFixed(2)) : 0;
      if (invoice.amountPaid >= invoice.grandTotal && invoice.grandTotal > 0) {
        invoice.status = 'PAID';
      } else if (invoice.amountPaid > 0) {
        invoice.status = 'PARTIALLY_PAID';
      } else {
        invoice.status = 'ISSUED';
      }
    } else if (req.body.amountPaid !== undefined) {
      invoice.amountPaid = Number(req.body.amountPaid);
      invoice.balanceDue = Number(Math.max(0, invoice.grandTotal - invoice.amountPaid).toFixed(2));
      invoice.excessAmount = invoice.amountPaid > invoice.grandTotal ? Number((invoice.amountPaid - invoice.grandTotal).toFixed(2)) : 0;
      if (invoice.amountPaid >= invoice.grandTotal && invoice.grandTotal > 0) {
        invoice.status = 'PAID';
      } else if (invoice.amountPaid > 0) {
        invoice.status = 'PARTIALLY_PAID';
      }
    }

    if (req.body.status !== undefined) {
      invoice.status = req.body.status;
    }

    await invoice.save();
    res.json({ success: true, invoice });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Delete invoice (soft delete by default, retained in recycle bin for 30 days)
// @route   DELETE /api/invoices/:id
// @access  Private
const deleteInvoice = async (req, res) => {
  try {
    const { permanent } = req.query;
    const { id } = req.params;
    let query = { userId: req.user._id };
    if (mongoose.Types.ObjectId.isValid(id)) {
      query._id = id;
    } else {
      query.$or = [{ _id: id }, { invoiceNumber: id }];
    }

    if (permanent === 'true') {
      const invoice = await Invoice.findOneAndDelete(query);

      if (!invoice) {
        return res.status(404).json({ success: false, message: 'Invoice not found' });
      }

      return res.json({ success: true, message: 'Invoice permanently deleted' });
    }

    // Soft delete: keep for 30 days in recycle bin
    const invoice = await Invoice.findOneAndUpdate(
      query,
      { isDeleted: true, deletedAt: new Date() },
      { new: true }
    );

    if (!invoice) {
      return res.status(404).json({ success: false, message: 'Invoice not found' });
    }

    res.json({ success: true, message: 'Invoice moved to recycle bin (retained for 30 days)', invoice });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get recycle bin items (invoices deleted within 30 days)
// @route   GET /api/invoices/recycle-bin
// @access  Private
const getRecycleBin = async (req, res) => {
  try {
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    // Auto-purge items older than 30 days
    await Invoice.deleteMany({
      userId: req.user._id,
      isDeleted: true,
      deletedAt: { $lt: thirtyDaysAgo },
    });

    const invoices = await Invoice.find({
      userId: req.user._id,
      isDeleted: true,
    }).sort({ deletedAt: -1 });

    res.json({ success: true, count: invoices.length, invoices });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Restore invoice from recycle bin
// @route   POST /api/invoices/:id/restore
// @access  Private
const restoreInvoice = async (req, res) => {
  try {
    const { id } = req.params;
    let query = { userId: req.user._id };
    if (mongoose.Types.ObjectId.isValid(id)) {
      query._id = id;
    } else {
      query.$or = [{ _id: id }, { invoiceNumber: id }];
    }

    const invoice = await Invoice.findOneAndUpdate(
      query,
      { isDeleted: false, deletedAt: null },
      { new: true }
    );

    if (!invoice) {
      return res.status(404).json({ success: false, message: 'Invoice not found in recycle bin' });
    }

    res.json({ success: true, message: 'Invoice restored successfully', invoice });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Empty recycle bin
// @route   DELETE /api/invoices/recycle-bin/empty
// @access  Private
const emptyRecycleBin = async (req, res) => {
  try {
    await Invoice.deleteMany({
      userId: req.user._id,
      isDeleted: true,
    });

    res.json({ success: true, message: 'Recycle bin emptied' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  getNextInvoiceNumber,
  getInvoices,
  getInvoiceById,
  createInvoice,
  updateInvoice,
  updateInvoiceStatus,
  markInvoiceAsPaid,
  deleteInvoice,
  getRecycleBin,
  restoreInvoice,
  emptyRecycleBin,
};
