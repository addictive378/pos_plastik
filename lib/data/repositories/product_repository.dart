import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_model.dart';
import '../models/product_price_model.dart';
import '../models/product_unit_model.dart';

class ProductRepository {
  final SupabaseClient _client;

  ProductRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Current authenticated user's ID.
  String get _ownerId => _client.auth.currentUser!.id;

  /// Fetch all products belonging to the current user,
  /// including their related product_units.
  Future<List<ProductModel>> getProducts({
    String? searchQuery,
    bool? isActive,
  }) async {
    // Build filter query first, then apply .order() last
    // because .order() returns PostgrestTransformBuilder which
    // no longer exposes filter methods like .eq() / .ilike().
    var query = _client
        .from('products')
        .select('*, product_units(*), product_prices(*)')
        .eq('owner_id', _ownerId);

    if (isActive != null) {
      query = query.eq('is_active', isActive);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('name', '%$searchQuery%');
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List<dynamic>)
        .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Create a new product and its associated units in two steps:
  /// 1. Insert into `products` → get back the new product id.
  /// 2. Batch-insert into `product_units` using the new product id.
  Future<ProductModel> createProduct({
    required ProductModel product,
    required List<ProductUnitModel> units,
  }) async {
    // Step 1: Insert product
    final productJson = product.toInsertJson();
    productJson['owner_id'] = _ownerId;

    final productResponse = await _client
        .from('products')
        .insert(productJson)
        .select('*, product_units(*), product_prices(*)')
        .single();

    final newProductId = productResponse['id'] as String;

    // Step 2: Batch insert product units
    if (units.isNotEmpty) {
      final unitsJson =
          units.map((u) => u.toInsertJson(newProductId)).toList();
      await _client.from('product_units').insert(unitsJson);
    }

    // Re-fetch the product with units to return the complete object
    final completeProduct = await _client
        .from('products')
        .select('*, product_units(*), product_prices(*)')
        .eq('id', newProductId)
        .single();

    return ProductModel.fromJson(completeProduct);
  }

  /// Update an existing product and replace its units.
  /// Deletes all old units, then inserts the new ones.
  Future<ProductModel> updateProduct({
    required String productId,
    required ProductModel product,
    required List<ProductUnitModel> units,
  }) async {
    // Step 1: Update product row
    await _client
        .from('products')
        .update(product.toUpdateJson())
        .eq('id', productId);

    // Step 2: Delete old units and insert new ones
    await _client.from('product_units').delete().eq('product_id', productId);

    if (units.isNotEmpty) {
      final unitsJson =
          units.map((u) => u.toInsertJson(productId)).toList();
      await _client.from('product_units').insert(unitsJson);
    }

    // Re-fetch the complete product
    final completeProduct = await _client
        .from('products')
        .select('*, product_units(*), product_prices(*)')
        .eq('id', productId)
        .single();

    return ProductModel.fromJson(completeProduct);
  }

  /// Delete a product by id.
  /// Related product_units will be deleted via CASCADE or manually.
  Future<void> deleteProduct(String productId) async {
    // Delete units first (in case no cascade)
    await _client.from('product_units').delete().eq('product_id', productId);
    await _client.from('products').delete().eq('id', productId);
  }

  /// Find the recommended price based on tiered pricing and customer level.
  double getRecommendedPrice(
    ProductModel product,
    String unitId,
    double qty,
    String? customerLevel,
  ) {
    // 1. Find conversion rate for the unit
    final unit = product.units.firstWhere(
      (u) => u.id == unitId,
      orElse: () => ProductUnitModel(
        id: unitId,
        unitName: product.baseUnit,
        conversionToBase: 1.0,
      ),
    );
    final conversionToBase = unit.conversionToBase;

    // 2. Normal retail price
    final normalPrice = product.hargaJualMin * conversionToBase;

    // Filter price tiers for this unit
    final activePrices = product.prices
        .where((p) => p.unitId == unitId && p.isActive)
        .toList();

    // 3. Wholesale price (qty_based): min_qty <= qty, take the largest min_qty
    ProductPriceModel? bestQtyPrice;
    for (final price in activePrices) {
      if (price.priceType == 'qty_based' && price.minQty <= qty) {
        if (bestQtyPrice == null || price.minQty > bestQtyPrice.minQty) {
          bestQtyPrice = price;
        }
      }
    }

    // 4. Customer-specific price (customer_level): matches customerLevel
    ProductPriceModel? bestCustomerPrice;
    if (customerLevel != null && customerLevel.isNotEmpty) {
      for (final price in activePrices) {
        if (price.priceType == 'customer_level' &&
            price.customerLevel == customerLevel) {
          bestCustomerPrice = price;
          break;
        }
      }
    }

    // Compare and return the cheapest price
    double recommendedPrice = normalPrice;
    if (bestQtyPrice != null && bestQtyPrice.hargaJual < recommendedPrice) {
      recommendedPrice = bestQtyPrice.hargaJual;
    }
    if (bestCustomerPrice != null && bestCustomerPrice.hargaJual < recommendedPrice) {
      recommendedPrice = bestCustomerPrice.hargaJual;
    }

    return recommendedPrice;
  }
}
