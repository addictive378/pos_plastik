import 'package:equatable/equatable.dart';

import '../../data/models/product_model.dart';

enum ProductStatus { initial, loading, loaded, error }

/// Filter for product active status.
enum ProductActiveFilter { all, active, inactive }

class ProductState extends Equatable {
  final ProductStatus status;
  final List<ProductModel> products;
  final String? errorMessage;
  final String searchQuery;
  final ProductActiveFilter activeFilter;

  const ProductState({
    this.status = ProductStatus.initial,
    this.products = const [],
    this.errorMessage,
    this.searchQuery = '',
    this.activeFilter = ProductActiveFilter.all,
  });

  /// Filtered products based on current search query and active filter.
  List<ProductModel> get filteredProducts {
    var result = products;

    // Apply active filter
    if (activeFilter == ProductActiveFilter.active) {
      result = result.where((p) => p.isActive).toList();
    } else if (activeFilter == ProductActiveFilter.inactive) {
      result = result.where((p) => !p.isActive).toList();
    }

    // Apply search filter (client-side for instant feedback)
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      result = result.where((p) {
        return p.name.toLowerCase().contains(query) ||
            (p.sku?.toLowerCase().contains(query) ?? false) ||
            (p.barcode?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return result;
  }

  ProductState copyWith({
    ProductStatus? status,
    List<ProductModel>? products,
    String? errorMessage,
    String? searchQuery,
    ProductActiveFilter? activeFilter,
  }) {
    return ProductState(
      status: status ?? this.status,
      products: products ?? this.products,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }

  @override
  List<Object?> get props => [
        status,
        products,
        errorMessage,
        searchQuery,
        activeFilter,
      ];
}
