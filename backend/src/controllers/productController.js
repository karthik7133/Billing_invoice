const Product = require('../models/Product');

// @desc    Get all products/services
// @route   GET /api/products
// @access  Private
const getProducts = async (req, res) => {
  try {
    const { search, itemType } = req.query;
    let query = { userId: req.user._id };

    if (search) {
      query.$or = [
        { name: { $regex: search, $options: 'i' } },
        { hsnSac: { $regex: search, $options: 'i' } },
        { description: { $regex: search, $options: 'i' } },
      ];
    }

    if (itemType) {
      query.itemType = itemType;
    }

    const products = await Product.find(query).sort({ createdAt: -1 });
    res.json({ success: true, count: products.length, products });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get product by ID
// @route   GET /api/products/:id
// @access  Private
const getProductById = async (req, res) => {
  try {
    const product = await Product.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found' });
    }

    res.json({ success: true, product });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Create new product
// @route   POST /api/products
// @access  Private
const createProduct = async (req, res) => {
  try {
    const { name, description, hsnSac, itemType, unit, price, gstRate, imageUrl } = req.body;

    if (!name || price === undefined || gstRate === undefined) {
      return res.status(400).json({ success: false, message: 'Name, price, and GST rate are required' });
    }

    const product = await Product.create({
      userId: req.user._id,
      name,
      description: description || '',
      hsnSac: hsnSac || '',
      itemType: itemType || 'PRODUCT',
      unit: unit || 'PCS',
      price: Number(price),
      gstRate: Number(gstRate),
      imageUrl: imageUrl || '',
    });

    res.status(201).json({ success: true, product });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update product
// @route   PUT /api/products/:id
// @access  Private
const updateProduct = async (req, res) => {
  try {
    let product = await Product.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found' });
    }

    const fields = ['name', 'description', 'hsnSac', 'itemType', 'unit', 'price', 'gstRate', 'imageUrl'];
    fields.forEach((f) => {
      if (req.body[f] !== undefined) {
        product[f] = req.body[f];
      }
    });

    await product.save();
    res.json({ success: true, product });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Delete product
// @route   DELETE /api/products/:id
// @access  Private
const deleteProduct = async (req, res) => {
  try {
    const product = await Product.findOneAndDelete({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found' });
    }

    res.json({ success: true, message: 'Product deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  getProducts,
  getProductById,
  createProduct,
  updateProduct,
  deleteProduct,
};
