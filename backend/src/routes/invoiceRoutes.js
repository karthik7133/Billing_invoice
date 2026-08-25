const express = require('express');
const router = express.Router();
const {
  getNextInvoiceNumber,
  getInvoices,
  getInvoiceById,
  createInvoice,
  updateInvoice,
  updateInvoiceStatus,
  markInvoiceAsPaid,
  deleteInvoice,
} = require('../controllers/invoiceController');
const { protect } = require('../middleware/authMiddleware');

router.use(protect);

router.get('/next-number', getNextInvoiceNumber);
router.route('/').get(getInvoices).post(createInvoice);
router.route('/:id').get(getInvoiceById).put(updateInvoice).delete(deleteInvoice);
router.put('/:id/status', updateInvoiceStatus);
router.post('/:id/mark-paid', markInvoiceAsPaid);

module.exports = router;
