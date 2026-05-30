import 'package:equatable/equatable.dart';

import '../../data/models/cart_item_model.dart';
import '../../data/models/transaction_model.dart';

enum CartStatus { initial, loading, success, error }

class CartState extends Equatable {
  final CartStatus status;
  final List<CartItemModel> cartItems;
  final double discountAmount;
  final double amountPaid;
  final String paymentMethod; // cash, transfer, qris, credit
  final String? customerId;
  final String? customerLevel; // ecer, grosir, agen, vip
  final String? notes;
  final TransactionModel? successTransaction;
  final String? errorMessage;

  const CartState({
    this.status = CartStatus.initial,
    this.cartItems = const [],
    this.discountAmount = 0.0,
    this.amountPaid = 0.0,
    this.paymentMethod = 'cash',
    this.customerId,
    this.customerLevel = 'ecer',
    this.notes,
    this.successTransaction,
    this.errorMessage,
  });

  /// Total before discount.
  double get totalAmount {
    return cartItems.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  /// Total after discount.
  double get grandTotal {
    final total = totalAmount - discountAmount;
    return total < 0 ? 0.0 : total;
  }

  /// Change to return.
  double get changeAmount {
    final change = amountPaid - grandTotal;
    return change < 0 ? 0.0 : change;
  }

  /// Total number of items (sum of all quantities).
  int get totalItems {
    return cartItems.fold(0, (sum, item) => sum + item.qty.toInt());
  }

  CartState copyWith({
    CartStatus? status,
    List<CartItemModel>? cartItems,
    double? discountAmount,
    double? amountPaid,
    String? paymentMethod,
    String? customerId,
    String? customerLevel,
    String? notes,
    TransactionModel? successTransaction,
    String? errorMessage,
    bool clearCustomerId = false,
    bool clearCustomerLevel = false,
    bool clearNotes = false,
    bool clearSuccessTransaction = false,
    bool clearErrorMessage = false,
  }) {
    return CartState(
      status: status ?? this.status,
      cartItems: cartItems ?? this.cartItems,
      discountAmount: discountAmount ?? this.discountAmount,
      amountPaid: amountPaid ?? this.amountPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerId: clearCustomerId ? null : (customerId ?? this.customerId),
      customerLevel: clearCustomerLevel ? 'ecer' : (customerLevel ?? this.customerLevel),
      notes: clearNotes ? null : (notes ?? this.notes),
      successTransaction: clearSuccessTransaction
          ? null
          : (successTransaction ?? this.successTransaction),
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        cartItems,
        discountAmount,
        amountPaid,
        paymentMethod,
        customerId,
        customerLevel,
        notes,
        successTransaction,
        errorMessage,
      ];
}

