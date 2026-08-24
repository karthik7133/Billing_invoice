const Invoice = require('../models/Invoice');
const Customer = require('../models/Customer');
const Product = require('../models/Product');

// @desc    Get dashboard metrics & summary
// @route   GET /api/dashboard
// @access  Private
const getDashboardMetrics = async (req, res) => {
  try {
    const userId = req.user._id;

    // Today's Date Boundaries
    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);
    const endOfToday = new Date();
    endOfToday.setHours(23, 59, 59, 999);

    // Month's Date Boundaries
    const startOfMonth = new Date(startOfToday.getFullYear(), startOfToday.getMonth(), 1);

    // Fetch all user invoices
    const allInvoices = await Invoice.find({ userId }).sort({ invoiceDate: -1, createdAt: -1 });

    let todaySales = 0;
    let monthSales = 0;
    let totalSales = 0;
    let totalUnpaid = 0;
    let paidCount = 0;
    let unpaidCount = 0;
    let draftCount = 0;

    allInvoices.forEach((inv) => {
      const invDate = new Date(inv.invoiceDate);

      // Today
      if (invDate >= startOfToday && invDate <= endOfToday && inv.status !== 'CANCELLED') {
        todaySales += inv.grandTotal || 0;
      }

      // This Month
      if (invDate >= startOfMonth && inv.status !== 'CANCELLED') {
        monthSales += inv.grandTotal || 0;
      }

      // All Time
      if (inv.status !== 'CANCELLED') {
        totalSales += inv.grandTotal || 0;
        totalUnpaid += inv.balanceDue || 0;
      }

      if (inv.status === 'PAID') paidCount++;
      if (inv.status === 'ISSUED' || inv.status === 'PARTIALLY_PAID') unpaidCount++;
      if (inv.status === 'DRAFT') draftCount++;
    });

    // Counts
    const customerCount = await Customer.countDocuments({ userId });
    const productCount = await Product.countDocuments({ userId });

    // Recent 5 invoices
    const recentInvoices = allInvoices.slice(0, 5);

    res.json({
      success: true,
      metrics: {
        todaySales: Number(todaySales.toFixed(2)),
        monthSales: Number(monthSales.toFixed(2)),
        totalSales: Number(totalSales.toFixed(2)),
        totalUnpaid: Number(totalUnpaid.toFixed(2)),
        totalInvoices: allInvoices.length,
        paidCount,
        unpaidCount,
        draftCount,
        customerCount,
        productCount,
      },
      recentInvoices,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  getDashboardMetrics,
};
