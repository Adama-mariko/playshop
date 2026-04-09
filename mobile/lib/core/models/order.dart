class OrderItem {
  final int id;
  final int quantity;
  final double unitPrice;
  final Map<String, dynamic>? product;

  const OrderItem({
    required this.id,
    required this.quantity,
    required this.unitPrice,
    this.product,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: json['id'],
        quantity: json['quantity'],
        // L'API retourne unit_price en snake_case
        unitPrice: double.parse(
          (json['unit_price'] ?? json['unitPrice'] ?? 0).toString(),
        ),
        product: json['product'],
      );
}

class Order {
  final int id;
  final String status;
  final double totalAmount;
  final String? paymentMethod;
  final String paymentStatus;
  final String createdAt;
  final List<OrderItem> items;

  const Order({
    required this.id,
    required this.status,
    required this.totalAmount,
    this.paymentMethod,
    required this.paymentStatus,
    required this.createdAt,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'],
        status: json['status'],
        totalAmount: double.parse(
          (json['total_amount'] ?? json['totalAmount'] ?? 0).toString(),
        ),
        paymentMethod: json['payment_method'] ?? json['paymentMethod'],
        paymentStatus: json['payment_status'] ?? json['paymentStatus'] ?? 'pending',
        createdAt: json['created_at'] ?? json['createdAt'] ?? '',
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => OrderItem.fromJson(e))
            .toList(),
      );
}
