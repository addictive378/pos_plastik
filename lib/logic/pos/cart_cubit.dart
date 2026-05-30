import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/cart_item_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/product_unit_model.dart';
import '../../data/models/transaction_item_model.dart';
import '../../data/repositories/transaction_repository.dart';
import 'cart_state.dart';

/// Manages the POS shopping cart and checkout lifecycle.
class CartCubit extends Cubit<CartState> {
  final TransactionRepository _transactionRepository;

  CartCubit({
    required TransactionRepository transactionRepository,
  })  : _transactionRepository = transactionRepository,
        super(const CartState());

  // ── Cart manipulation ──────────────────────────────────────────────────

  /// Add a product to the cart (qty +1 if already present).
  void addToCart(ProductModel product) {
    final existingIndex =
        state.cartItems.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      // Already in cart → increment qty
      final existing = state.cartItems[existingIndex];
      final updated = existing.copyWith(qty: existing.qty + 1);
      final list = List<CartItemModel>.from(state.cartItems)
        ..[existingIndex] = updated;
      emit(state.copyWith(cartItems: list));
      return;
    }

    // New product → pick default sellable unit
    final sellableUnits =
        product.units.where((u) => u.isSellable).toList();
    if (sellableUnits.isEmpty) return; // nothing to sell

    final defaultUnit = sellableUnits.firstWhere(
      (u) => u.isBaseUnit,
      orElse: () => sellableUnits.first,
    );

    final systemPrice = product.hargaJualMin * defaultUnit.conversionToBase;

    final newItem = CartItemModel(
      product: product,
      unit: defaultUnit,
      qty: 1.0,
      hargaAcuanSistem: systemPrice,
      hargaJualAktual: systemPrice,
    );

    emit(state.copyWith(
      cartItems: List<CartItemModel>.from(state.cartItems)..add(newItem),
    ));
  }

  /// Remove an item from the cart entirely.
  void removeFromCart(int index) {
    if (index < 0 || index >= state.cartItems.length) return;
    final list = List<CartItemModel>.from(state.cartItems)..removeAt(index);
    emit(state.copyWith(cartItems: list));
  }

  /// Update the quantity for a cart item.
  void updateQty(int index, double newQty) {
    if (index < 0 || index >= state.cartItems.length || newQty <= 0) return;
    final updated = state.cartItems[index].copyWith(qty: newQty);
    final list = List<CartItemModel>.from(state.cartItems)..[index] = updated;
    emit(state.copyWith(cartItems: list));
  }

  /// Change the selling unit and recalculate the system reference price.
  void changeUnit(int index, ProductUnitModel newUnit) {
    if (index < 0 || index >= state.cartItems.length) return;
    final item = state.cartItems[index];

    final newSystemPrice =
        item.product.hargaJualMin * newUnit.conversionToBase;

    // If price was overridden, keep it unless it is now below the new minimum.
    double newActualPrice = newSystemPrice;
    bool overridden = false;
    String? reason;

    if (item.isPriceOverridden) {
      if (item.hargaJualAktual >= newSystemPrice) {
        newActualPrice = item.hargaJualAktual;
        overridden = true;
        reason = item.priceOverrideReason;
      }
      // else: old override is invalid → fall back to system price
    }

    final updated = item.copyWith(
      unit: newUnit,
      hargaAcuanSistem: newSystemPrice,
      hargaJualAktual: newActualPrice,
      isPriceOverridden: overridden,
      priceOverrideReason: reason,
    );

    final list = List<CartItemModel>.from(state.cartItems)..[index] = updated;
    emit(state.copyWith(cartItems: list));
  }

  /// Override the selling price for a cart item.
  ///
  /// Returns `true` if the override was accepted, `false` if [newPrice]
  /// is below the minimum allowed price.
  bool overridePrice(int index, double newPrice, String? reason) {
    if (index < 0 || index >= state.cartItems.length) return false;
    final item = state.cartItems[index];

    final minAllowed = item.product.hargaJualMin * item.unit.conversionToBase;
    if (newPrice < minAllowed) {
      emit(state.copyWith(
        status: CartStatus.error,
        errorMessage:
            'Harga tidak boleh di bawah minimum (Rp ${minAllowed.toStringAsFixed(0)})',
      ));
      // Reset to initial so the error doesn't stick
      emit(state.copyWith(
        status: CartStatus.initial,
        clearErrorMessage: true,
      ));
      return false;
    }

    final updated = item.copyWith(
      hargaJualAktual: newPrice,
      isPriceOverridden: true,
      priceOverrideReason:
          (reason == null || reason.trim().isEmpty) ? 'Penyesuaian Kasir' : reason.trim(),
    );

    final list = List<CartItemModel>.from(state.cartItems)..[index] = updated;
    emit(state.copyWith(cartItems: list));
    return true;
  }

  // ── Payment fields ─────────────────────────────────────────────────────

  void setDiscount(double discount) {
    emit(state.copyWith(discountAmount: discount < 0 ? 0 : discount));
  }

  void setAmountPaid(double amount) {
    emit(state.copyWith(amountPaid: amount));
  }

  void setPaymentMethod(String method) {
    emit(state.copyWith(paymentMethod: method));
  }

  void setNotes(String? notes) {
    if (notes == null || notes.trim().isEmpty) {
      emit(state.copyWith(clearNotes: true));
    } else {
      emit(state.copyWith(notes: notes.trim()));
    }
  }

  /// Reset the cart to its initial empty state.
  void clearCart() {
    emit(const CartState());
  }

  // ── Checkout ───────────────────────────────────────────────────────────

  /// Validate and execute the checkout.
  Future<void> checkout() async {
    if (state.cartItems.isEmpty) {
      emit(state.copyWith(
        status: CartStatus.error,
        errorMessage: 'Keranjang belanja masih kosong.',
      ));
      return;
    }

    if (state.amountPaid < state.grandTotal) {
      emit(state.copyWith(
        status: CartStatus.error,
        errorMessage: 'Jumlah bayar tidak mencukupi total transaksi.',
      ));
      return;
    }

    emit(state.copyWith(status: CartStatus.loading));

    try {
      // Map cart items → transaction items
      final transactionItems = state.cartItems.map((cartItem) {
        final qtyInBase = cartItem.qty * cartItem.unit.conversionToBase;
        final subtotal = cartItem.qty * cartItem.hargaJualAktual;
        final totalModal = qtyInBase * cartItem.product.hargaModalTerakhir;
        final profitSubtotal = subtotal - totalModal;

        return TransactionItemModel(
          productId: cartItem.product.id!,
          unitId: cartItem.unit.id,
          productNameSnapshot: cartItem.product.name,
          unitNameSnapshot: cartItem.unit.unitName,
          qty: cartItem.qty,
          qtyInBase: qtyInBase,
          hargaModalAktual: cartItem.product.hargaModalTerakhir,
          hargaJualAktual: cartItem.hargaJualAktual,
          hargaAcuanSistem: cartItem.hargaAcuanSistem,
          isPriceOverridden: cartItem.isPriceOverridden,
          priceOverrideReason: cartItem.priceOverrideReason,
          subtotal: subtotal,
          profitSubtotal: profitSubtotal,
        );
      }).toList();

      final result = await _transactionRepository.checkout(
        items: transactionItems,
        totalAmount: state.totalAmount,
        discountAmount: state.discountAmount,
        amountPaid: state.amountPaid,
        changeAmount: state.changeAmount,
        paymentMethod: state.paymentMethod,
        notes: state.notes,
      );

      emit(state.copyWith(
        status: CartStatus.success,
        successTransaction: result,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CartStatus.error,
        errorMessage: 'Checkout gagal: ${e.toString()}',
      ));
    }
  }
}
