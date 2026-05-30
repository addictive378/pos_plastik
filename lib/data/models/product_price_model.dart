import 'package:equatable/equatable.dart';

/// Represents a row in the `product_prices` table.
///
/// Supports two pricing strategies:
/// - `qty_based`       — tiered pricing based on minimum quantity thresholds.
/// - `customer_level`  — special pricing for a specific customer tier.
class ProductPriceModel extends Equatable {
  final String? id;
  final String productId;
  final String unitId;
  final String priceType; // 'qty_based' or 'customer_level'
  final int minQty;
  final String? customerLevel; // 'ecer', 'grosir', 'agen', 'vip'
  final double hargaJual;
  final bool isActive;

  const ProductPriceModel({
    this.id,
    required this.productId,
    required this.unitId,
    required this.priceType,
    this.minQty = 1,
    this.customerLevel,
    required this.hargaJual,
    this.isActive = true,
  });

  factory ProductPriceModel.fromJson(Map<String, dynamic> json) {
    return ProductPriceModel(
      id: json['id'] as String?,
      productId: json['product_id'] as String,
      unitId: json['unit_id'] as String,
      priceType: json['price_type'] as String,
      minQty: json['min_qty'] as int? ?? 1,
      customerLevel: json['customer_level'] as String?,
      hargaJual: (json['harga_jual'] as num).toDouble(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'product_id': productId,
      'unit_id': unitId,
      'price_type': priceType,
      'min_qty': minQty,
      if (customerLevel != null) 'customer_level': customerLevel,
      'harga_jual': hargaJual,
      'is_active': isActive,
    };
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        unitId,
        priceType,
        minQty,
        customerLevel,
        hargaJual,
        isActive,
      ];
}
