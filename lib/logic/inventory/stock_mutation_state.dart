import 'package:equatable/equatable.dart';

import '../../data/models/product_model.dart';
import '../../data/models/product_unit_model.dart';

enum StockMutationStatus { initial, loading, success, error }

class StockMutationState extends Equatable {
  final StockMutationStatus status;
  final List<ProductModel> products;
  final ProductModel? selectedProduct;
  final ProductUnitModel? selectedUnit;
  final String? errorMessage;

  const StockMutationState({
    this.status = StockMutationStatus.initial,
    this.products = const [],
    this.selectedProduct,
    this.selectedUnit,
    this.errorMessage,
  });

  /// Purchasable units for the currently selected product.
  List<ProductUnitModel> get purchasableUnits {
    if (selectedProduct == null) return [];
    return selectedProduct!.units
        .where((u) => u.isPurchasable)
        .toList();
  }

  StockMutationState copyWith({
    StockMutationStatus? status,
    List<ProductModel>? products,
    ProductModel? selectedProduct,
    ProductUnitModel? selectedUnit,
    String? errorMessage,
    bool clearSelectedProduct = false,
    bool clearSelectedUnit = false,
  }) {
    return StockMutationState(
      status: status ?? this.status,
      products: products ?? this.products,
      selectedProduct: clearSelectedProduct
          ? null
          : (selectedProduct ?? this.selectedProduct),
      selectedUnit: clearSelectedUnit
          ? null
          : (selectedUnit ?? this.selectedUnit),
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        products,
        selectedProduct,
        selectedUnit,
        errorMessage,
      ];
}
