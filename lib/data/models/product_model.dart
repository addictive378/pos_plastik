import 'package:equatable/equatable.dart';

import 'product_unit_model.dart';

class ProductModel extends Equatable {
  final String? id;
  final String ownerId;
  final String name;
  final String? sku;
  final String? barcode;
  final String baseUnit;
  final double currentStock;
  final double? stockAlertQty;
  final double hargaModalTerakhir;
  final double hargaJualMin;
  final bool isActive;
  final String? imageUrl;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Related product units (populated via join or separate query).
  final List<ProductUnitModel> units;

  const ProductModel({
    this.id,
    required this.ownerId,
    required this.name,
    this.sku,
    this.barcode,
    required this.baseUnit,
    this.currentStock = 0,
    this.stockAlertQty,
    this.hargaModalTerakhir = 0,
    this.hargaJualMin = 0,
    this.isActive = true,
    this.imageUrl,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.units = const [],
  });

  /// Create from Supabase JSON row.
  /// Expects the row to optionally include a `product_units` key
  /// containing a list of unit JSON objects.
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final unitsList = json['product_units'] as List<dynamic>?;
    return ProductModel(
      id: json['id'] as String?,
      ownerId: json['owner_id'] as String,
      name: json['name'] as String,
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      baseUnit: json['base_unit'] as String,
      currentStock:
          (json['current_stock'] as num?)?.toDouble() ?? 0,
      stockAlertQty:
          (json['stock_alert_qty'] as num?)?.toDouble(),
      hargaModalTerakhir:
          (json['harga_modal_terakhir'] as num?)?.toDouble() ?? 0,
      hargaJualMin:
          (json['harga_jual_min'] as num?)?.toDouble() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      imageUrl: json['image_url'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      units: unitsList != null
          ? unitsList
              .map((e) =>
                  ProductUnitModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  /// Convert to JSON for Supabase insert.
  Map<String, dynamic> toInsertJson() {
    return {
      'owner_id': ownerId,
      'name': name,
      if (sku != null) 'sku': sku,
      if (barcode != null) 'barcode': barcode,
      'base_unit': baseUnit,
      'current_stock': currentStock,
      if (stockAlertQty != null) 'stock_alert_qty': stockAlertQty,
      'harga_modal_terakhir': hargaModalTerakhir,
      'harga_jual_min': hargaJualMin,
      'is_active': isActive,
      if (imageUrl != null) 'image_url': imageUrl,
      if (notes != null) 'notes': notes,
    };
  }

  /// Convert to JSON for Supabase update (excludes owner_id).
  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'base_unit': baseUnit,
      'stock_alert_qty': stockAlertQty,
      'harga_modal_terakhir': hargaModalTerakhir,
      'harga_jual_min': hargaJualMin,
      'is_active': isActive,
      'image_url': imageUrl,
      'notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  ProductModel copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? sku,
    String? barcode,
    String? baseUnit,
    double? currentStock,
    double? stockAlertQty,
    double? hargaModalTerakhir,
    double? hargaJualMin,
    bool? isActive,
    String? imageUrl,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ProductUnitModel>? units,
  }) {
    return ProductModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      baseUnit: baseUnit ?? this.baseUnit,
      currentStock: currentStock ?? this.currentStock,
      stockAlertQty: stockAlertQty ?? this.stockAlertQty,
      hargaModalTerakhir: hargaModalTerakhir ?? this.hargaModalTerakhir,
      hargaJualMin: hargaJualMin ?? this.hargaJualMin,
      isActive: isActive ?? this.isActive,
      imageUrl: imageUrl ?? this.imageUrl,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      units: units ?? this.units,
    );
  }

  @override
  List<Object?> get props => [
        id,
        ownerId,
        name,
        sku,
        barcode,
        baseUnit,
        currentStock,
        stockAlertQty,
        hargaModalTerakhir,
        hargaJualMin,
        isActive,
        imageUrl,
        notes,
        createdAt,
        updatedAt,
        units,
      ];
}
