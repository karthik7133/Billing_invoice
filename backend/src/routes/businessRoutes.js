const express = require('express');
const router = express.Router();
const { getBusinessProfile, updateBusinessProfile } = require('../controllers/businessController');
const { protect } = require('../middleware/authMiddleware');

router.get('/', protect, getBusinessProfile);
router.put('/', protect, updateBusinessProfile);

module.exports = router;
