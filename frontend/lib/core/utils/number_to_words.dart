class NumberToWords {
  static const List<String> _ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen',
  ];

  static const List<String> _tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety',
  ];

  static String _convertLessThanOneThousand(int num) {
    String result = '';
    if (num >= 100) {
      result += '${_ones[num ~/ 100]} Hundred ';
      num %= 100;
    }
    if (num >= 20) {
      result += '${_tens[num ~/ 10]} ';
      num %= 10;
    }
    if (num > 0) {
      result += '${_ones[num]} ';
    }
    return result.trim();
  }

  static String convertToIndianWords(double amount) {
    if (amount <= 0) return 'Zero Rupees Only';

    final numStr = amount.abs().toStringAsFixed(2);
    final parts = numStr.split('.');
    int num = int.tryParse(parts[0]) ?? 0;
    final int paise = int.tryParse(parts[1]) ?? 0;

    String words = '';

    final int crore = num ~/ 10000000;
    num %= 10000000;

    final int lakh = num ~/ 100000;
    num %= 100000;

    final int thousand = num ~/ 1000;
    num %= 1000;

    final int remainder = num;

    if (crore > 0) {
      words += '${_convertLessThanOneThousand(crore)} Crore ';
    }
    if (lakh > 0) {
      words += '${_convertLessThanOneThousand(lakh)} Lakh ';
    }
    if (thousand > 0) {
      words += '${_convertLessThanOneThousand(thousand)} Thousand ';
    }
    if (remainder > 0) {
      words += '${_convertLessThanOneThousand(remainder)} ';
    }

    words = words.trim();
    if (words.isEmpty) {
      words = 'Zero';
    }

    String finalStr = '$words Rupees';

    if (paise > 0) {
      finalStr += ' and ${_convertLessThanOneThousand(paise)} Paise';
    }

    finalStr += ' Only';
    return finalStr;
  }
}
