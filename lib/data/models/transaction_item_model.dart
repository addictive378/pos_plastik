import 'package:equatable/equatable.dart';

/// Maps to the `transaction_items` table in Supabase.
class TransactionItemModel extends Equatable {
  final String? id;
  final String? transactionId;
  final String productId;
  final String? unitId;
  final String productNameSnapshot;
  final String unitNameSnapshot;
  final double qty;
  final double qtyInBase;
  final double hargaModalAktual;
  final double hargaJualAktual;
  final double hargaAcuanSistem;
  final bool isPriceOverridden;
  final String? priceOverrideReason;
  final double subtotal;
  final double profitSubtotal;

  const TransactionItemModel({
    this.id,
    this.transactionId,
    required this.productId,
    this.unitId,
    required this.productNameSnapshot,
    required this.unitNameSnapshot,
    required this.qty,
    required this.qtyInBase,
    required this.hargaModalAktual,
    required this.hargaJualAktual,
    required this.hargaAcuanSistem,
    this.isPriceOverridden = false,
    this.priceOverrideReason,
    required this.subtotal,
    required this.profitSubtotal,
  });

  /// Create from Supabase JSON row.
  factory TransactionItemModel.fromJson(Map<String, dynamic> json) {
    return TransactionItemModel(
      id: json['id'] as String?,
      transactionId: json['transaction_id'] as String?,
      productId: json['product_id'] as String,
      unitId: json['unit_id'] as String?,
      productNameSnapshot: json['product_name_snapshot'] as String,
      unitNameSnapshot: json['unit_name_snapshot'] as String,
      qty: (json['qty'] as num).toDouble(),
      qtyInBase: (json['qty_in_base'] as num).toDouble(),
      hargaModalAktual: (json['harga_modal_aktual'] as num).toDouble(),
      hargaJualAktual: (json['harga_jual_aktual'] as num).toDouble(),
      hargaAcuanSistem: (json['harga_acuan_sistem'] as num).toDouble(),
      isPriceOverridden: json['is_price_overridden'] as bool? ?? false,
      priceOverrideReason: json['price_override_reason'] as String?,
      subtotal: (json['subtotal'] as num).toDouble(),
      profitSubtotal: (json['profit_subtotal'] as num).toDouble(),
    );
  }

  /// Convert to JSON for Supabase insert (excludes id and transaction_id).
  Map<String, dynamic> toInsertJson() {
    return {
      'product_id': productId,
      if (unitId != null) 'unit_id': unitId,
      'product_name_snapshot': productNameSnapshot,
      'unit_name_snapshot': unitNameSnapshot,
      'qty': qty,
      'qty_in_base': qtyInBase,
      'harga_modal_aktual': hargaModalAktual,
      'harga_jual_aktual': hargaJualAktual,
      'harga_acuan_sistem': hargaAcuanSistem,
      'is_price_overridden': isPriceOverridden,
      if (priceOverrideReason != null)
        'price_override_reason': priceOverrideReason,
      'subtotal': subtotal,
      'profit_subtotal': profitSubtotal,
    };
  }

  @override
  List<Object?> get props => [
        id,
        transactionId,
        productId,
        unitId,
        productNameSnapshot,
        unitNameSnapshot,
        qty,
        qtyInBase,
        hargaModalAktual,
        hargaJualAktual,
        hargaAcuanSistem,
        isPriceOverridden,
        priceOverrideReason,
        subtotal,
        profitSubtotal,
      ];
}
