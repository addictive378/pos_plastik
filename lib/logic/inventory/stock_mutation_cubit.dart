import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/product_model.dart';
import '../../data/models/product_unit_model.dart';
import '../../data/models/stock_mutation_model.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/stock_mutation_repository.dart';
import 'stock_mutation_state.dart';

class StockMutationCubit extends Cubit<StockMutationState> {
  final ProductRepository _productRepository;
  final StockMutationRepository _stockMutationRepository;

  StockMutationCubit({
    required ProductRepository productRepository,
    required StockMutationRepository stockMutationRepository,
  })  : _productRepository = productRepository,
        _stockMutationRepository = stockMutationRepository,
        super(const StockMutationState());

  /// Load all active products for the product picker dropdown.
  Future<void> loadProducts() async {
    emit(state.copyWith(status: StockMutationStatus.loading));
    try {
      final products = await _productRepository.getProducts(isActive: true);
      emit(state.copyWith(
        status: StockMutationStatus.initial,
        products: products,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: StockMutationStatus.error,
        errorMessage: 'Gagal memuat data produk: ${e.toString()}',
      ));
    }
  }

  /// Select a product and auto-select its first purchasable unit.
  void selectProduct(ProductModel product) {
    final purchasableUnits =
        product.units.where((u) => u.isPurchasable).toList();
    final defaultUnit =
        purchasableUnits.isNotEmpty ? purchasableUnits.first : null;

    emit(state.copyWith(
      selectedProduct: product,
      selectedUnit: defaultUnit,
    ));
  }

  /// Select a specific unit from the product's purchasable units.
  void selectUnit(ProductUnitModel unit) {
    emit(state.copyWith(selectedUnit: unit));
  }

  /// Submit a purchase stock mutation.
  ///
  /// The caller is responsible for form validation before calling this.
  /// [qtyOriginal] and [hargaModalBaru] come from the form text controllers.
  Future<void> submitPurchase({
    required double qtyOriginal,
    required double hargaModalBaru,
    String? supplierName,
    String? invoiceRef,
    String? notes,
  }) async {
    final product = state.selectedProduct;
    final unit = state.selectedUnit;

    if (product == null || unit == null) {
      emit(state.copyWith(
        status: StockMutationStatus.error,
        errorMessage: 'Pilih produk dan satuan terlebih dahulu.',
      ));
      return;
    }

    emit(state.copyWith(status: StockMutationStatus.loading));
    try {
      // ── Calculation logic before insert ──
      final qtyInBase = qtyOriginal * unit.conversionToBase;

      final mutation = StockMutationModel(
        productId: product.id!,
        unitId: unit.id,
        mutationType: 'purchase',
        qtyInBase: qtyInBase,
        unitNameSnapshot: unit.unitName,
        qtyOriginal: qtyOriginal,
        hargaModalLama: product.hargaModalTerakhir,
        hargaModalBaru: hargaModalBaru,
        supplierName:
            (supplierName != null && supplierName.trim().isNotEmpty)
                ? supplierName.trim()
                : null,
        invoiceRef: (invoiceRef != null && invoiceRef.trim().isNotEmpty)
            ? invoiceRef.trim()
            : null,
        notes: (notes != null && notes.trim().isNotEmpty)
            ? notes.trim()
            : null,
      );

      await _stockMutationRepository.createPurchaseMutation(mutation);
      emit(state.copyWith(status: StockMutationStatus.success));
    } catch (e) {
      emit(state.copyWith(
        status: StockMutationStatus.error,
        errorMessage: 'Gagal mencatat stok masuk: ${e.toString()}',
      ));
    }
  }
}
