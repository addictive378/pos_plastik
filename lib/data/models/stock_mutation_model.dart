import 'package:equatable/equatable.dart';

class StockMutationModel extends Equatable {
  final String? id;
  final String? ownerId;
  final String productId;
  final String? unitId;
  final String mutationType;
  final double qtyInBase;
  final String unitNameSnapshot;
  final double qtyOriginal;
  final double? hargaModalLama;
  final double hargaModalBaru;
  final String? supplierName;
  final String? invoiceRef;
  final String? notes;
  final DateTime? createdAt;

  const StockMutationModel({
    this.id,
    this.ownerId,
    required this.productId,
    this.unitId,
    required this.mutationType,
    required this.qtyInBase,
    required this.unitNameSnapshot,
    required this.qtyOriginal,
    this.hargaModalLama,
    required this.hargaModalBaru,
    this.supplierName,
    this.invoiceRef,
    this.notes,
    this.createdAt,
  });

  /// Create from Supabase JSON row.
  factory StockMutationModel.fromJson(Map<String, dynamic> json) {
    return StockMutationModel(
      id: json['id'] as String?,
      ownerId: json['owner_id'] as String?,
      productId: json['product_id'] as String,
      unitId: json['unit_id'] as String?,
      mutationType: json['mutation_type'] as String,
      qtyInBase: (json['qty_in_base'] as num).toDouble(),
      unitNameSnapshot: json['unit_name_snapshot'] as String,
      qtyOriginal: (json['qty_original'] as num).toDouble(),
      hargaModalLama: (json['harga_modal_lama'] as num?)?.toDouble(),
      hargaModalBaru: (json['harga_modal_baru'] as num).toDouble(),
      supplierName: json['supplier_name'] as String?,
      invoiceRef: json['invoice_ref'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Convert to JSON for Supabase insert.
  Map<String, dynamic> toInsertJson() {
    return {
      'product_id': productId,
      if (unitId != null) 'unit_id': unitId,
      'mutation_type': mutationType,
      'qty_in_base': qtyInBase,
      'unit_name_snapshot': unitNameSnapshot,
      'qty_original': qtyOriginal,
      if (hargaModalLama != null) 'harga_modal_lama': hargaModalLama,
      'harga_modal_baru': hargaModalBaru,
      if (supplierName != null) 'supplier_name': supplierName,
      if (invoiceRef != null) 'invoice_ref': invoiceRef,
      if (notes != null) 'notes': notes,
    };
  }

  @override
  List<Object?> get props => [
        id,
        ownerId,
        productId,
        unitId,
        mutationType,
        qtyInBase,
        unitNameSnapshot,
        qtyOriginal,
        hargaModalLama,
        hargaModalBaru,
        supplierName,
        invoiceRef,
        notes,
        createdAt,
      ];
}
