/**
 * GST Calculation Engine for Billing App
 */

function calculateItemGST({
  quantity = 1,
  rate = 0,
  discount = 0,
  discountType = 'FIXED', // 'FIXED' or 'PERCENT'
  gstRate = 18,
  isInterState = false,
}) {
  const qty = Number(quantity) || 0;
  const unitRate = Number(rate) || 0;
  const taxPercent = Number(gstRate) || 0;

  const grossAmount = Number((qty * unitRate).toFixed(2));
  
  let discountAmount = 0;
  if (discountType === 'PERCENT') {
    discountAmount = Number(((grossAmount * (Number(discount) || 0)) / 100).toFixed(2));
  } else {
    discountAmount = Number((Number(discount) || 0).toFixed(2));
  }
  discountAmount = Math.min(grossAmount, Math.max(0, discountAmount));

  const taxableAmount = Number((grossAmount - discountAmount).toFixed(2));

  let cgstRate = 0;
  let sgstRate = 0;
  let igstRate = 0;
  let cgst = 0;
  let sgst = 0;
  let igst = 0;

  if (isInterState) {
    igstRate = taxPercent;
    igst = Number(((taxableAmount * igstRate) / 100).toFixed(2));
  } else {
    cgstRate = Number((taxPercent / 2).toFixed(2));
    sgstRate = Number((taxPercent / 2).toFixed(2));
    cgst = Number(((taxableAmount * cgstRate) / 100).toFixed(2));
    sgst = Number(((taxableAmount * sgstRate) / 100).toFixed(2));
  }

  const totalTax = Number((cgst + sgst + igst).toFixed(2));
  const total = Number((taxableAmount + totalTax).toFixed(2));

  return {
    quantity: qty,
    rate: unitRate,
    grossAmount,
    discount: Number(discount) || 0,
    discountType,
    discountAmount,
    taxableAmount,
    gstRate: taxPercent,
    cgstRate,
    sgstRate,
    igstRate,
    cgst,
    sgst,
    igst,
    totalTax,
    total,
  };
}

function calculateInvoiceTotals({
  items = [],
  sellerState = '',
  buyerState = '',
  invoiceDiscount = 0,
  invoiceDiscountType = 'FIXED',
  otherCharges = 0,
}) {
  const isInterState =
    sellerState.trim().toLowerCase() !== '' &&
    buyerState.trim().toLowerCase() !== '' &&
    sellerState.trim().toLowerCase() !== buyerState.trim().toLowerCase();

  const processedItems = items.map((item) => {
    return {
      ...item,
      ...calculateItemGST({
        quantity: item.quantity,
        rate: item.rate,
        discount: item.discount,
        discountType: item.discountType || 'FIXED',
        gstRate: item.gstRate,
        isInterState,
      }),
    };
  });

  const subtotal = Number(
    processedItems.reduce((acc, it) => acc + it.grossAmount, 0).toFixed(2)
  );

  const itemsDiscount = Number(
    processedItems.reduce((acc, it) => acc + it.discountAmount, 0).toFixed(2)
  );

  let extraDiscount = 0;
  if (invoiceDiscountType === 'PERCENT') {
    extraDiscount = Number(((subtotal * (Number(invoiceDiscount) || 0)) / 100).toFixed(2));
  } else {
    extraDiscount = Number((Number(invoiceDiscount) || 0).toFixed(2));
  }

  const totalDiscount = Number((itemsDiscount + extraDiscount).toFixed(2));

  const taxableAmount = Number(
    processedItems.reduce((acc, it) => acc + it.taxableAmount, 0).toFixed(2)
  );

  const cgst = Number(
    processedItems.reduce((acc, it) => acc + it.cgst, 0).toFixed(2)
  );
  const sgst = Number(
    processedItems.reduce((acc, it) => acc + it.sgst, 0).toFixed(2)
  );
  const igst = Number(
    processedItems.reduce((acc, it) => acc + it.igst, 0).toFixed(2)
  );

  const totalTax = Number((cgst + sgst + igst).toFixed(2));
  const charges = Number((Number(otherCharges) || 0).toFixed(2));

  const rawTotal = Number((taxableAmount + totalTax + charges - extraDiscount).toFixed(2));
  const grandTotal = Math.round(rawTotal);
  const roundOff = Number((grandTotal - rawTotal).toFixed(2));

  return {
    isInterState,
    items: processedItems,
    subtotal,
    itemsDiscount,
    extraDiscount,
    totalDiscount,
    taxableAmount,
    cgst,
    sgst,
    igst,
    totalTax,
    otherCharges: charges,
    roundOff,
    grandTotal,
  };
}

module.exports = {
  calculateItemGST,
  calculateInvoiceTotals,
};
