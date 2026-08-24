const Customer = require('../models/Customer');
const Invoice = require('../models/Invoice');

// @desc    Get all customers for current user with balance calculation
// @route   GET /api/customers
// @access  Private
const getCustomers = async (req, res) => {
  try {
    const { search, customerType } = req.query;
    let query = { userId: req.user._id };

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

    // Aggregate balances and last transaction date from Invoices
    const customerIds = customers.map((c) => c._id);
    const invoiceAgg = await Invoice.aggregate([
      { $match: { customerId: { $in: customerIds } } },
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

    const enrichedCustomers = customers.map((cust) => {
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
    const customer = await Customer.findOne({
      _id: req.params.id,
      userId: req.user._id,
    }).lean();

    if (!customer) {
      return res.status(404).json({ success: false, message: 'Customer not found' });
    }

    // Fetch transactions for this customer
    const invoices = await Invoice.find({
      customerId: customer._id,
      userId: req.user._id,
    }).sort({ invoiceDate: -1, createdAt: -1 });

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
    } = req.body;

    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: 'Customer name is required' });
    }

    const customer = await Customer.create({
      userId: req.user._id,
      name: name.trim(),
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
      billingName: billingName || name.trim(),
      openingBalance: Number(openingBalance) || 0,
      partyType: partyType || 'CUSTOMER',
      customerType: customerType || (gstin ? 'REGISTERED_B2B' : 'UNREGISTERED_B2C'),
    });

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
      'name',
      'phone',
      'email',
      'billingAddress',
      'shippingAddress',
      'city',
      'state',
      'stateCode',
      'pincode',
      'gstin',
      'pan',
      'customerType',
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

// @desc    Delete customer
// @route   DELETE /api/customers/:id
// @access  Private
const deleteCustomer = async (req, res) => {
  try {
    const customer = await Customer.findOneAndDelete({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!customer) {
      return res.status(404).json({ success: false, message: 'Customer not found' });
    }

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
