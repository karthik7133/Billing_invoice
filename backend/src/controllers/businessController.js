const Business = require('../models/Business');

// @desc    Get current business profile
// @route   GET /api/business
// @access  Private
const getBusinessProfile = async (req, res) => {
  try {
    let business = await Business.findOne({ userId: req.user._id });
    if (!business) {
      business = await Business.create({
        userId: req.user._id,
        businessName: `${req.user.name}'s Business`,
        email: req.user.email,
        phone: req.user.phone || '',
        state: 'Andhra Pradesh',
        stateCode: '37',
      });
    }
    res.json({ success: true, business });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update business profile
// @route   PUT /api/business
// @access  Private
const updateBusinessProfile = async (req, res) => {
  try {
    const {
      businessName,
      logo,
      phone,
      email,
      address,
      city,
      state,
      stateCode,
      pincode,
      gstin,
      pan,
      invoicePrefix,
      nextInvoiceNumber,
      bankDetails,
      termsAndConditions,
      signatureUrl,
    } = req.body;

    let business = await Business.findOne({ userId: req.user._id });

    if (!business) {
      business = new Business({ userId: req.user._id });
    }

    if (businessName !== undefined) business.businessName = businessName;
    if (logo !== undefined) business.logo = logo;
    if (phone !== undefined) business.phone = phone;
    if (email !== undefined) business.email = email;
    if (address !== undefined) business.address = address;
    if (city !== undefined) business.city = city;
    if (state !== undefined) business.state = state;
    if (stateCode !== undefined) business.stateCode = stateCode;
    if (pincode !== undefined) business.pincode = pincode;
    if (gstin !== undefined) business.gstin = gstin.toUpperCase();
    if (pan !== undefined) business.pan = pan.toUpperCase();
    if (invoicePrefix !== undefined) business.invoicePrefix = invoicePrefix;
    if (nextInvoiceNumber !== undefined) business.nextInvoiceNumber = nextInvoiceNumber;
    if (bankDetails !== undefined) business.bankDetails = bankDetails;
    if (termsAndConditions !== undefined) business.termsAndConditions = termsAndConditions;
    if (signatureUrl !== undefined) business.signatureUrl = signatureUrl;

    await business.save();
    res.json({ success: true, business });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  getBusinessProfile,
  updateBusinessProfile,
};
