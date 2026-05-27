import 'package:equatable/equatable.dart';

class ProductUnitModel extends Equatable {
  final String? id;
  final String? productId;
  final String unitName;
  final double conversionToBase;
  final bool isBaseUnit;
  final bool isPurchasable;
  final bool isSellable;
  final DateTime? createdAt;

  const ProductUnitModel({
    this.id,
    this.productId,
    required this.unitName,
    this.conversionToBase = 1,
    this.isBaseUnit = false,
    this.isPurchasable = true,
    this.isSellable = true,
    this.createdAt,
  });

  /// Create from Supabase JSON row.
  factory ProductUnitModel.fromJson(Map<String, dynamic> json) {
    return ProductUnitModel(
      id: json['id'] as String?,
      productId: json['product_id'] as String?,
      unitName: json['unit_name'] as String,
      conversionToBase:
          (json['conversion_to_base'] as num?)?.toDouble() ?? 1,
      isBaseUnit: json['is_base_unit'] as bool? ?? false,
      isPurchasable: json['is_purchasable'] as bool? ?? true,
      isSellable: json['is_sellable'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Convert to JSON for Supabase insert/update.
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      'unit_name': unitName,
      'conversion_to_base': conversionToBase,
      'is_base_unit': isBaseUnit,
      'is_purchasable': isPurchasable,
      'is_sellable': isSellable,
    };
  }

  /// JSON payload for creating a new unit (excludes id).
  Map<String, dynamic> toInsertJson(String productId) {
    return {
      'product_id': productId,
      'unit_name': unitName,
      'conversion_to_base': conversionToBase,
      'is_base_unit': isBaseUnit,
      'is_purchasable': isPurchasable,
      'is_sellable': isSellable,
    };
  }

  ProductUnitModel copyWith({
    String? id,
    String? productId,
    String? unitName,
    double? conversionToBase,
    bool? isBaseUnit,
    bool? isPurchasable,
    bool? isSellable,
    DateTime? createdAt,
  }) {
    return ProductUnitModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      unitName: unitName ?? this.unitName,
      conversionToBase: conversionToBase ?? this.conversionToBase,
      isBaseUnit: isBaseUnit ?? this.isBaseUnit,
      isPurchasable: isPurchasable ?? this.isPurchasable,
      isSellable: isSellable ?? this.isSellable,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        unitName,
        conversionToBase,
        isBaseUnit,
        isPurchasable,
        isSellable,
        createdAt,
      ];
}
