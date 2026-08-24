const express = require('express');
const router = express.Router();
const { upload, cloudinary } = require('../config/cloudinary');
const { protect } = require('../middleware/authMiddleware');

// @desc    Upload file to Cloudinary
// @route   POST /api/upload
// @access  Private
router.post('/', protect, (req, res) => {
  upload.single('file')(req, res, (err) => {
    if (err) {
      return res.status(400).json({
        success: false,
        message: err.message || 'File upload failed',
      });
    }

    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'Please provide a file to upload',
      });
    }

    // Return the secure Cloudinary URL or file path
    const fileUrl = req.file.path || req.file.secure_url || req.file.url;
    res.json({
      success: true,
      url: fileUrl,
      publicId: req.file.filename,
    });
  });
});

module.exports = router;
