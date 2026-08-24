class DashboardMetrics {
  final double todaySales;
  final double monthSales;
  final double totalSales;
  final double totalUnpaid;
  final int totalInvoices;
  final int paidCount;
  final int unpaidCount;
  final int draftCount;
  final int customerCount;
  final int productCount;

  DashboardMetrics({
    this.todaySales = 0,
    this.monthSales = 0,
    this.totalSales = 0,
    this.totalUnpaid = 0,
    this.totalInvoices = 0,
    this.paidCount = 0,
    this.unpaidCount = 0,
    this.draftCount = 0,
    this.customerCount = 0,
    this.productCount = 0,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic>? json) {
    if (json == null) return DashboardMetrics();
    return DashboardMetrics(
      todaySales: (json['todaySales'] as num?)?.toDouble() ?? 0.0,
      monthSales: (json['monthSales'] as num?)?.toDouble() ?? 0.0,
      totalSales: (json['totalSales'] as num?)?.toDouble() ?? 0.0,
      totalUnpaid: (json['totalUnpaid'] as num?)?.toDouble() ?? 0.0,
      totalInvoices: (json['totalInvoices'] as num?)?.toInt() ?? 0,
      paidCount: (json['paidCount'] as num?)?.toInt() ?? 0,
      unpaidCount: (json['unpaidCount'] as num?)?.toInt() ?? 0,
      draftCount: (json['draftCount'] as num?)?.toInt() ?? 0,
      customerCount: (json['customerCount'] as num?)?.toInt() ?? 0,
      productCount: (json['productCount'] as num?)?.toInt() ?? 0,
    );
  }
}
