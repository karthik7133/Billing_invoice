class GstRates {
  static const List<double> standardRates = [0.0, 3.0, 5.0, 12.0, 18.0, 28.0];
  static const List<String> units = [
    'Kg',
    'PCS',
    'BOX',
    'LTR',
    'MTR',
    'NOS',
    'BAG',
    'DOZ',
    'SET',
    'SQFT',
    'SERVICE',
    'HRS',
    'DAY',
  ];
}

class GstConstants {
  static const List<double> gstRates = [0.0, 3.0, 5.0, 12.0, 18.0, 28.0];

  static const List<String> units = [
    'PCS',
    'BOX',
    'KG',
    'LTR',
    'MTR',
    'NOS',
    'BAG',
    'DOZ',
    'SET',
    'SQFT',
    'SERVICE',
    'HRS',
    'DAY',
  ];

  static const List<String> invoiceStatuses = [
    'ALL',
    'ISSUED',
    'PAID',
    'PARTIALLY_PAID',
    'DRAFT',
    'CANCELLED',
  ];

  static const List<String> customerTypes = [
    'REGISTERED_B2B',
    'UNREGISTERED_B2C',
  ];
}
