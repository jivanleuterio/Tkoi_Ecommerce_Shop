import 'product.dart';

class CartItem {
  final String id;
  final int quantity;
  final Product product;

  const CartItem({
    required this.id,
    required this.quantity,
    required this.product,
  });

  double get subtotal => product.price * quantity;

  factory CartItem.fromMap(Map<String, dynamic> map) => CartItem(
    id: map['id'] as String,
    quantity: (map['quantity'] as num? ?? 1).toInt(),
    product: Product.fromMap(map['products'] as Map<String, dynamic>),
  );
}
