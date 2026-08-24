/**
 * Indian Numbering System to Words Converter (Rupees and Paise)
 */

const ones = [
  '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
  'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
  'Seventeen', 'Eighteen', 'Nineteen',
];

const tens = [
  '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety',
];

function convertLessThanOneThousand(num) {
  let result = '';
  if (num >= 100) {
    result += ones[Math.floor(num / 100)] + ' Hundred ';
    num %= 100;
  }
  if (num >= 20) {
    result += tens[Math.floor(num / 10)] + ' ';
    num %= 10;
  }
  if (num > 0) {
    result += ones[num] + ' ';
  }
  return result.trim();
}

function numberToWordsIndian(number) {
  if (number === 0) return 'Zero Rupees Only';

  const numStr = Math.abs(number).toFixed(2);
  const parts = numStr.split('.');
  let num = parseInt(parts[0], 10);
  const paise = parseInt(parts[1], 10);

  let words = '';

  const crore = Math.floor(num / 10000000);
  num %= 10000000;

  const lakh = Math.floor(num / 100000);
  num %= 100000;

  const thousand = Math.floor(num / 1000);
  num %= 1000;

  const remainder = num;

  if (crore > 0) {
    words += convertLessThanOneThousand(crore) + ' Crore ';
  }
  if (lakh > 0) {
    words += convertLessThanOneThousand(lakh) + ' Lakh ';
  }
  if (thousand > 0) {
    words += convertLessThanOneThousand(thousand) + ' Thousand ';
  }
  if (remainder > 0) {
    words += convertLessThanOneThousand(remainder) + ' ';
  }

  words = words.trim();
  if (words === '') {
    words = 'Zero';
  }

  let finalStr = words + ' Rupees';

  if (paise > 0) {
    finalStr += ' and ' + convertLessThanOneThousand(paise) + ' Paise';
  }

  finalStr += ' Only';
  return finalStr;
}

module.exports = {
  numberToWordsIndian,
};
