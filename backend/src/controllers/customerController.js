const Customer = require('../models/Customer');

// @desc    Get all customers for current user
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

    const customers = await Customer.find(query).sort({ createdAt: -1 });
    res.json({ success: true, count: customers.length, customers });
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
    });

    if (!customer) {
      return res.status(404).json({ success: false, message: 'Customer not found' });
    }

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
      customerType,
    } = req.body;

    if (!name || !state) {
      return res.status(400).json({ success: false, message: 'Customer name and state are required' });
    }

    const customer = await Customer.create({
      userId: req.user._id,
      name,
      phone: phone || '',
      email: email || '',
      billingAddress: billingAddress || '',
      shippingAddress: shippingAddress || billingAddress || '',
      city: city || '',
      state,
      stateCode: stateCode || '',
      pincode: pincode || '',
      gstin: gstin ? gstin.toUpperCase() : '',
      pan: pan ? pan.toUpperCase() : '',
      customerType: customerType || (gstin ? 'REGISTERED_B2B' : 'UNREGISTERED_B2C'),
    });

    res.status(201).json({ success: true, customer });
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
