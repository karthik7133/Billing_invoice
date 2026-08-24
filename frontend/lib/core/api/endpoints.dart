class Endpoints {
  // Production backend on Render
  static const String baseUrl = 'https://billing-invoice-rpt0.onrender.com/api';

  // Auth
  static const String register = '$baseUrl/auth/register';
  static const String login = '$baseUrl/auth/login';
  static const String me = '$baseUrl/auth/me';

  // Business
  static const String business = '$baseUrl/business';

  // Customers
  static const String customers = '$baseUrl/customers';

  // Products
  static const String products = '$baseUrl/products';

  // Invoices
  static const String invoices = '$baseUrl/invoices';
  static const String nextInvoiceNumber = '$baseUrl/invoices/next-number';

  // Dashboard
  static const String dashboard = '$baseUrl/dashboard';

  // Upload
  static const String upload = '$baseUrl/upload';
}
