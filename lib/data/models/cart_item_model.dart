import 'package:equatable/equatable.dart';

import 'product_model.dart';
import 'product_unit_model.dart';

enum AppliedPriceType { normal, grosir, customerLevel }

/// Represents a single item in the POS shopping cart.
///
/// This is a local, in-memory model — it is not directly persisted to the
/// database. During checkout it is mapped to [TransactionItemModel] rows.
class CartItemModel extends Equatable {
  final ProductModel product;
  final ProductUnitModel unit;
  final double qty;

  /// System reference price = hargaJualMin × unit.conversionToBase.
  final double hargaAcuanSistem;

  /// Actual selling price (may differ from system price if overridden).
  final double hargaJualAktual;

  final bool isPriceOverridden;
  final String? priceOverrideReason;

  /// The type of tiered pricing currently applied.
  final AppliedPriceType appliedPriceType;

  const CartItemModel({
    required this.product,
    required this.unit,
    required this.qty,
    required this.hargaAcuanSistem,
    required this.hargaJualAktual,
    this.isPriceOverridden = false,
    this.priceOverrideReason,
    this.appliedPriceType = AppliedPriceType.normal,
  });

  /// Line total for this cart item.
  double get subtotal => qty * hargaJualAktual;

  /// Minimum allowed price for the currently selected unit.
  double get minPriceAllowed => product.hargaJualMin * unit.conversionToBase;

  CartItemModel copyWith({
    ProductModel? product,
    ProductUnitModel? unit,
    double? qty,
    double? hargaAcuanSistem,
    double? hargaJualAktual,
    bool? isPriceOverridden,
    String? priceOverrideReason,
    AppliedPriceType? appliedPriceType,
  }) {
    return CartItemModel(
      product: product ?? this.product,
      unit: unit ?? this.unit,
      qty: qty ?? this.qty,
      hargaAcuanSistem: hargaAcuanSistem ?? this.hargaAcuanSistem,
      hargaJualAktual: hargaJualAktual ?? this.hargaJualAktual,
      isPriceOverridden: isPriceOverridden ?? this.isPriceOverridden,
      priceOverrideReason: priceOverrideReason ?? this.priceOverrideReason,
      appliedPriceType: appliedPriceType ?? this.appliedPriceType,
    );
  }

  @override
  List<Object?> get props => [
        product,
        unit,
        qty,
        hargaAcuanSistem,
        hargaJualAktual,
        isPriceOverridden,
        priceOverrideReason,
        appliedPriceType,
      ];
}

