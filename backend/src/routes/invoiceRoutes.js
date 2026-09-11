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
  getRecycleBin,
  restoreInvoice,
  emptyRecycleBin,
} = require('../controllers/invoiceController');
const { protect } = require('../middleware/authMiddleware');

router.use(protect);

router.get('/next-number', getNextInvoiceNumber);
router.get('/recycle-bin', getRecycleBin);
router.delete('/recycle-bin/empty', emptyRecycleBin);
router.post('/:id/restore', restoreInvoice);

router.route('/').get(getInvoices).post(createInvoice);
router.route('/:id').get(getInvoiceById).put(updateInvoice).delete(deleteInvoice);
router.put('/:id/status', updateInvoiceStatus);
router.post('/:id/mark-paid', markInvoiceAsPaid);

module.exports = router;

