import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pos_toko_plastik/data/models/product_model.dart';
import 'package:pos_toko_plastik/data/models/product_price_model.dart';
import 'package:pos_toko_plastik/data/models/product_unit_model.dart';
import 'package:pos_toko_plastik/data/repositories/product_repository.dart';

class FakeSupabaseClient extends Fake implements SupabaseClient {}

void main() {
  late ProductRepository repository;

  setUp(() {
    repository = ProductRepository(client: FakeSupabaseClient());
  });

  group('getRecommendedPrice Tests', () {
    // Shared constants
    const productId = 'prod-123';
    const unitId = 'unit-pack';
    
    final baseUnit = ProductUnitModel(
      id: 'unit-pcs',
      productId: productId,
      unitName: 'pcs',
      conversionToBase: 1.0,
      isBaseUnit: true,
    );

    final packUnit = ProductUnitModel(
      id: unitId,
      productId: productId,
      unitName: 'pack',
      conversionToBase: 10.0,
      isBaseUnit: false,
    );

    // Create a product with specific pricing setup
    ProductModel createTestProduct({List<ProductPriceModel> prices = const []}) {
      return ProductModel(
        id: productId,
        ownerId: 'owner-123',
        name: 'Plastik HD Kantong',
        baseUnit: 'pcs',
        hargaJualMin: 100.0, // base unit retail price: Rp 100/pcs
        units: [baseUnit, packUnit],
        prices: prices,
      );
    }

    test('should return normal retail price when no progressive pricing exists', () {
      final product = createTestProduct();

      // For base unit (pcs): 100 * 1.0 = 100
      final pricePcs = repository.getRecommendedPrice(product, 'unit-pcs', 5.0, 'ecer');
      expect(pricePcs, 100.0);

      // For pack unit (pack): 100 * 10.0 = 1000
      final pricePack = repository.getRecommendedPrice(product, unitId, 2.0, 'ecer');
      expect(pricePack, 1000.0);
    });

    test('should apply qty-based wholesale price when minimum quantity is reached', () {
      final product = createTestProduct(
        prices: [
          // Tier 1: purchase >= 5 packs -> Rp 950 each (normal: 1000)
          ProductPriceModel(
            id: 'price-1',
            productId: productId,
            unitId: unitId,
            priceType: 'qty_based',
            minQty: 5,
            hargaJual: 950.0,
            isActive: true,
          ),
          // Tier 2: purchase >= 10 packs -> Rp 900 each (normal: 1000)
          ProductPriceModel(
            id: 'price-2',
            productId: productId,
            unitId: unitId,
            priceType: 'qty_based',
            minQty: 10,
            hargaJual: 900.0,
            isActive: true,
          ),
        ],
      );

      // 4 packs (below minimum) -> Rp 1000 (normal)
      expect(repository.getRecommendedPrice(product, unitId, 4.0, 'ecer'), 1000.0);

      // 5 packs (meets tier 1) -> Rp 950
      expect(repository.getRecommendedPrice(product, unitId, 5.0, 'ecer'), 950.0);

      // 9 packs (meets tier 1, below tier 2) -> Rp 950
      expect(repository.getRecommendedPrice(product, unitId, 9.0, 'ecer'), 950.0);

      // 10 packs (meets tier 2) -> Rp 900
      expect(repository.getRecommendedPrice(product, unitId, 10.0, 'ecer'), 900.0);

      // 15 packs (meets tier 2) -> Rp 900
      expect(repository.getRecommendedPrice(product, unitId, 15.0, 'ecer'), 900.0);
    });

    test('should apply customer level price when customer level matches', () {
      final product = createTestProduct(
        prices: [
          // Member VIP price for pack: Rp 880 (normal: 1000)
          ProductPriceModel(
            id: 'price-vip',
            productId: productId,
            unitId: unitId,
            priceType: 'customer_level',
            customerLevel: 'vip',
            hargaJual: 880.0,
            isActive: true,
          ),
          // Member Agen price for pack: Rp 910 (normal: 1000)
          ProductPriceModel(
            id: 'price-agen',
            productId: productId,
            unitId: unitId,
            priceType: 'customer_level',
            customerLevel: 'agen',
            hargaJual: 910.0,
            isActive: true,
          ),
        ],
      );

      // customerLevel = ecer (normal) -> Rp 1000
      expect(repository.getRecommendedPrice(product, unitId, 1.0, 'ecer'), 1000.0);

      // customerLevel = vip -> Rp 880
      expect(repository.getRecommendedPrice(product, unitId, 1.0, 'vip'), 880.0);

      // customerLevel = agen -> Rp 910
      expect(repository.getRecommendedPrice(product, unitId, 1.0, 'agen'), 910.0);
    });

    test('should compare and return the cheapest price if both wholesale and member pricing apply', () {
      final product = createTestProduct(
        prices: [
          // Wholesale: qty >= 5 -> Rp 920
          ProductPriceModel(
            id: 'price-qty-5',
            productId: productId,
            unitId: unitId,
            priceType: 'qty_based',
            minQty: 5,
            hargaJual: 920.0,
            isActive: true,
          ),
          // Customer VIP level: Rp 900
          ProductPriceModel(
            id: 'price-vip',
            productId: productId,
            unitId: unitId,
            priceType: 'customer_level',
            customerLevel: 'vip',
            hargaJual: 900.0,
            isActive: true,
          ),
        ],
      );

      // Case A: qty = 5, level = vip
      // Wholesale price = Rp 920, Member VIP price = Rp 900.
      // Member price (900) is cheaper -> should return 900.
      expect(repository.getRecommendedPrice(product, unitId, 5.0, 'vip'), 900.0);

      // Now add a wholesale tier for qty >= 10 -> Rp 850
      final productWithTier2 = createTestProduct(
        prices: [
          ...product.prices,
          ProductPriceModel(
            id: 'price-qty-10',
            productId: productId,
            unitId: unitId,
            priceType: 'qty_based',
            minQty: 10,
            hargaJual: 850.0,
            isActive: true,
          ),
        ],
      );

      // Case B: qty = 10, level = vip
      // Wholesale price = Rp 850, Member VIP price = Rp 900.
      // Wholesale price (850) is cheaper -> should return 850.
      expect(repository.getRecommendedPrice(productWithTier2, unitId, 10.0, 'vip'), 850.0);
    });

    test('should ignore inactive prices', () {
      final product = createTestProduct(
        prices: [
          // Inactive price: qty >= 5 -> Rp 800
          ProductPriceModel(
            id: 'price-inactive',
            productId: productId,
            unitId: unitId,
            priceType: 'qty_based',
            minQty: 5,
            hargaJual: 800.0,
            isActive: false,
          ),
        ],
      );

      // Because the wholesale price is inactive, it should return normal price (1000)
      expect(repository.getRecommendedPrice(product, unitId, 5.0, 'ecer'), 1000.0);
    });
  });
}
