const User = require('../models/User');
const Business = require('../models/Business');
const jwt = require('jsonwebtoken');

const generateToken = (id) => {
  return jwt.sign(
    { id },
    process.env.JWT_SECRET || 'gst_billing_jwt_secret_key_123456',
    { expiresIn: '30d' }
  );
};

// @desc    Register a new user and auto-create default business profile
// @route   POST /api/auth/register
// @access  Public
const registerUser = async (req, res) => {
  try {
    const { name, email, password, phone, businessName, state, gstin } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ success: false, message: 'Please provide name, email, and password' });
    }

    const userExists = await User.findOne({ email });
    if (userExists) {
      return res.status(400).json({ success: false, message: 'User already exists with this email' });
    }

    const user = await User.create({
      name,
      email,
      password,
      phone: phone || '',
    });

    // Create corresponding Business entity
    const business = await Business.create({
      userId: user._id,
      businessName: businessName || `${name}'s Business`,
      email: email,
      phone: phone || '',
      state: state || 'Andhra Pradesh',
      stateCode: '37',
      gstin: gstin || '',
    });

    res.status(201).json({
      success: true,
      token: generateToken(user._id),
      user: {
        _id: user._id,
        name: user.name,
        email: user.email,
        phone: user.phone,
      },
      business,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Auth user & get token
// @route   POST /api/auth/login
// @access  Public
const loginUser = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Please provide email and password' });
    }

    const user = await User.findOne({ email }).select('+password');
    if (!user || !(await user.matchPassword(password))) {
      return res.status(401).json({ success: false, message: 'Invalid email or password' });
    }

    let business = await Business.findOne({ userId: user._id });
    if (!business) {
      business = await Business.create({
        userId: user._id,
        businessName: `${user.name}'s Business`,
        email: user.email,
        state: 'Andhra Pradesh',
        stateCode: '37',
      });
    }

    res.json({
      success: true,
      token: generateToken(user._id),
      user: {
        _id: user._id,
        name: user.name,
        email: user.email,
        phone: user.phone,
      },
      business,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get current user profile & business
// @route   GET /api/auth/me
// @access  Private
const getMe = async (req, res) => {
  try {
    const user = await User.findById(req.user._id);
    const business = await Business.findOne({ userId: req.user._id });
    res.json({
      success: true,
      user,
      business,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  registerUser,
  loginUser,
  getMe,
};
