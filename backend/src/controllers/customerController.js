const Customer = require('../models/Customer');
const Invoice = require('../models/Invoice');

// @desc    Get all customers for current user with balance calculation
// @route   GET /api/customers
// @access  Private
const getCustomers = async (req, res) => {
  try {
    const { search, customerType, companyId } = req.query;
    let query = { userId: req.user._id };

    // ─── Company isolation ─────────────────────────────────────────────────────
    // If a companyId is provided, filter strictly to that company.
    // Existing records with no companyId (legacy) fall back to userId-only scope.
    if (companyId && companyId.trim()) {
      query.companyId = companyId.trim();
    }
    // ──────────────────────────────────────────────────────────────────────────

    if (search) {
      query.$or = [
        { name: { $regex: search, $options: 'i' } },
        { phone: { $regex: search, $options: 'i' } },
        { gstin: { $regex: search, $options: 'i' } },
      ];
    }

    if (customerType) {
      query.customerType = customerType;
    }

    const customers = await Customer.find(query).sort({ createdAt: -1 }).lean();

    // Deduplicate within the same company scope only
    const uniqueCustomers = [];
    const seenNames = new Set();
    const duplicateIds = [];

    for (const cust of customers) {
      const lowerName = (cust.name || '').trim().toLowerCase();
      if (!seenNames.has(lowerName)) {
        seenNames.add(lowerName);
        uniqueCustomers.push(cust);
      } else {
        duplicateIds.push(cust._id);
      }
    }

    if (duplicateIds.length > 0) {
      Customer.deleteMany({ _id: { $in: duplicateIds }, userId: req.user._id }).exec().catch(() => {});
    }

    // Aggregate balances from Invoices (scoped to same companyId if provided)
    const customerIds = uniqueCustomers.map((c) => c._id);
    const invoiceMatchQuery = { customerId: { $in: customerIds } };
    if (companyId && companyId.trim()) {
      invoiceMatchQuery.companyId = companyId.trim();
    }

    const invoiceAgg = await Invoice.aggregate([
      { $match: invoiceMatchQuery },
      {
        $group: {
          _id: '$customerId',
          totalInvoiced: { $sum: '$grandTotal' },
          totalPaid: { $sum: '$amountPaid' },
          totalBalanceDue: { $sum: '$balanceDue' },
          lastTransactionDate: { $max: '$invoiceDate' },
        },
      },
    ]);

    const aggMap = {};
    invoiceAgg.forEach((agg) => {
      aggMap[agg._id.toString()] = agg;
    });

    const enrichedCustomers = uniqueCustomers.map((cust) => {
      const agg = aggMap[cust._id.toString()];
      const openingBal = cust.openingBalance || 0;
      const invoiceDue = agg ? agg.totalBalanceDue : 0;
      const balance = openingBal + invoiceDue;

      return {
        ...cust,
        balance,
        lastTransactionDate: agg ? agg.lastTransactionDate : cust.updatedAt || cust.createdAt,
      };
    });

    res.json({ success: true, count: enrichedCustomers.length, customers: enrichedCustomers });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get single customer
// @route   GET /api/customers/:id
// @access  Private
const getCustomerById = async (req, res) => {
  try {
    const { companyId } = req.query;
    const customer = await Customer.findOne({
      _id: req.params.id,
      userId: req.user._id,
    }).lean();

    if (!customer) {
      return res.status(404).json({ success: false, message: 'Customer not found' });
    }

    // Fetch invoices scoped to the same company
    const invoiceQuery = { customerId: customer._id, userId: req.user._id };
    if (companyId && companyId.trim()) {
      invoiceQuery.companyId = companyId.trim();
    }

    const invoices = await Invoice.find(invoiceQuery).sort({ invoiceDate: -1, createdAt: -1 });

    const totalBalanceDue = invoices.reduce((sum, inv) => sum + (inv.balanceDue || 0), 0);
    customer.balance = (customer.openingBalance || 0) + totalBalanceDue;
    customer.invoices = invoices;

    res.json({ success: true, customer });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Create new customer
// @route   POST /api/customers
// @access  Private
const createCustomer = async (req, res) => {
  try {
    const {
      name,
      phone,
      email,
      billingAddress,
      shippingAddress,
      city,
      state,
      stateCode,
      pincode,
      gstin,
      pan,
      billingName,
      openingBalance,
      partyType,
      customerType,
      companyId,  // ← NEW
    } = req.body;

    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: 'Customer name is required' });
    }

    const trimmedName = name.trim();
    const companyScope = companyId ? companyId.trim() : '';

    // Check if customer exists within the same company scope
    const existingQuery = {
      userId: req.user._id,
      name: { $regex: new RegExp(`^${trimmedName.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')}$`, 'i') },
    };
    if (companyScope) {
      existingQuery.companyId = companyScope;
    }

    let customer = await Customer.findOne(existingQuery);

    if (customer) {
      if (phone && !customer.phone) customer.phone = phone;
      if (gstin && !customer.gstin) customer.gstin = gstin.toUpperCase();
      if (billingAddress && !customer.billingAddress) customer.billingAddress = billingAddress;
      if (billingName && !customer.billingName) customer.billingName = billingName;
      await customer.save();
    } else {
      customer = await Customer.create({
        userId: req.user._id,
        companyId: companyScope,
        name: trimmedName,
        phone: phone || '',
        email: email || '',
        billingAddress: billingAddress || '',
        shippingAddress: shippingAddress || billingAddress || '',
        city: city || '',
        state: state || 'Andhra Pradesh',
        stateCode: stateCode || '',
        pincode: pincode || '',
        gstin: gstin ? gstin.toUpperCase() : '',
        pan: pan ? pan.toUpperCase() : '',
        billingName: billingName || trimmedName,
        openingBalance: Number(openingBalance) || 0,
        partyType: partyType || 'CUSTOMER',
        customerType: customerType || (gstin ? 'REGISTERED_B2B' : 'UNREGISTERED_B2C'),
      });
    }

    const responseCust = customer.toObject();
    responseCust.balance = responseCust.openingBalance || 0;
    responseCust.lastTransactionDate = responseCust.createdAt;

    res.status(201).json({ success: true, customer: responseCust });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update customer
// @route   PUT /api/customers/:id
// @access  Private
const updateCustomer = async (req, res) => {
  try {
    let customer = await Customer.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!customer) {
      return res.status(404).json({ success: false, message: 'Customer not found' });
    }

    const fieldsToUpdate = [
      'name', 'phone', 'email', 'billingAddress', 'shippingAddress',
      'city', 'state', 'stateCode', 'pincode', 'gstin', 'pan', 'customerType', 'companyId',
    ];

    fieldsToUpdate.forEach((field) => {
      if (req.body[field] !== undefined) {
        if (field === 'gstin' || field === 'pan') {
          customer[field] = req.body[field].toUpperCase();
        } else {
          customer[field] = req.body[field];
        }
      }
    });

    await customer.save();
    res.json({ success: true, customer });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Delete customer and all duplicate records
// @route   DELETE /api/customers/:id
// @access  Private
const deleteCustomer = async (req, res) => {
  try {
    const customer = await Customer.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!customer) {
      await Customer.deleteOne({ _id: req.params.id, userId: req.user._id });
      return res.json({ success: true, message: 'Customer deleted successfully' });
    }

    const customerName = (customer.name || '').trim();
    const companyScope = customer.companyId || '';

    const deleteQuery = {
      userId: req.user._id,
      $or: [
        { _id: customer._id },
        { name: { $regex: new RegExp(`^${customerName.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')}$`, 'i') } },
      ],
    };
    if (companyScope) {
      deleteQuery.companyId = companyScope;
    }

    await Customer.deleteMany(deleteQuery);

    res.json({ success: true, message: 'Customer deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  getCustomers,
  getCustomerById,
  createCustomer,
  updateCustomer,
  deleteCustomer,
};
