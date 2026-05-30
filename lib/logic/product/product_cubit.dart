import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/product_model.dart';
import '../../data/models/product_unit_model.dart';
import '../../data/repositories/product_repository.dart';
import 'product_state.dart';

class ProductCubit extends Cubit<ProductState> {
  final ProductRepository _productRepository;

  ProductCubit({required ProductRepository productRepository})
      : _productRepository = productRepository,
        super(const ProductState());

  /// Load all products from Supabase.
  Future<void> loadProducts() async {
    emit(state.copyWith(status: ProductStatus.loading));
    try {
      final products = await _productRepository.getProducts();
      emit(state.copyWith(
        status: ProductStatus.loaded,
        products: products,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ProductStatus.error,
        errorMessage: 'Gagal memuat produk: ${e.toString()}',
      ));
    }
  }

  /// Update the search query (client-side filter).
  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  /// Update the active filter.
  void setActiveFilter(ProductActiveFilter filter) {
    emit(state.copyWith(activeFilter: filter));
  }

  /// Create a new product with its units and price rules.
  Future<void> createProduct({
    required ProductModel product,
    required List<ProductUnitModel> units,
    List<Map<String, dynamic>> priceRules = const [],
  }) async {
    emit(state.copyWith(status: ProductStatus.loading));
    try {
      final newProduct = await _productRepository.createProduct(
        product: product,
        units: units,
        priceRules: priceRules,
      );
      final updatedProducts = [newProduct, ...state.products];
      emit(state.copyWith(
        status: ProductStatus.loaded,
        products: updatedProducts,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ProductStatus.error,
        errorMessage: 'Gagal menambah produk: ${e.toString()}',
      ));
    }
  }

  /// Update an existing product and its units and price rules.
  Future<void> updateProduct({
    required String productId,
    required ProductModel product,
    required List<ProductUnitModel> units,
    List<Map<String, dynamic>> priceRules = const [],
  }) async {
    emit(state.copyWith(status: ProductStatus.loading));
    try {
      final updatedProduct = await _productRepository.updateProduct(
        productId: productId,
        product: product,
        units: units,
        priceRules: priceRules,
      );
      final updatedProducts = state.products.map((p) {
        return p.id == productId ? updatedProduct : p;
      }).toList();
      emit(state.copyWith(
        status: ProductStatus.loaded,
        products: updatedProducts,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ProductStatus.error,
        errorMessage: 'Gagal mengubah produk: ${e.toString()}',
      ));
    }
  }

  /// Delete a product.
  Future<void> deleteProduct(String productId) async {
    emit(state.copyWith(status: ProductStatus.loading));
    try {
      await _productRepository.deleteProduct(productId);
      final updatedProducts =
          state.products.where((p) => p.id != productId).toList();
      emit(state.copyWith(
        status: ProductStatus.loaded,
        products: updatedProducts,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ProductStatus.error,
        errorMessage: 'Gagal menghapus produk: ${e.toString()}',
      ));
    }
  }
}
