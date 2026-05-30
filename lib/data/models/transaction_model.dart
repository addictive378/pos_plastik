import 'package:equatable/equatable.dart';

/// Maps to the `transactions` table in Supabase.
class TransactionModel extends Equatable {
  final String? id;
  final String? ownerId;
  final String? customerId;
  final String invoiceNo;
  final double totalAmount;
  final double discountAmount;
  final double amountPaid;
  final double changeAmount;
  final String paymentMethod; // cash, transfer, qris, credit
  final String status; // completed, voided, pending
  final String? notes;
  final DateTime? createdAt;

  const TransactionModel({
    this.id,
    this.ownerId,
    this.customerId,
    required this.invoiceNo,
    required this.totalAmount,
    this.discountAmount = 0.0,
    required this.amountPaid,
    required this.changeAmount,
    this.paymentMethod = 'cash',
    this.status = 'completed',
    this.notes,
    this.createdAt,
  });

  /// Create from Supabase JSON row.
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String?,
      ownerId: json['owner_id'] as String?,
      customerId: json['customer_id'] as String?,
      invoiceNo: json['invoice_no'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      amountPaid: (json['amount_paid'] as num).toDouble(),
      changeAmount: (json['change_amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      status: json['status'] as String? ?? 'completed',
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Convert to JSON for Supabase insert.
  Map<String, dynamic> toInsertJson() {
    return {
      if (customerId != null) 'customer_id': customerId,
      'invoice_no': invoiceNo,
      'total_amount': totalAmount,
      'discount_amount': discountAmount,
      'amount_paid': amountPaid,
      'change_amount': changeAmount,
      'payment_method': paymentMethod,
      'status': status,
      if (notes != null) 'notes': notes,
    };
  }

  @override
  List<Object?> get props => [
        id,
        ownerId,
        customerId,
        invoiceNo,
        totalAmount,
        discountAmount,
        amountPaid,
        changeAmount,
        paymentMethod,
        status,
        notes,
        createdAt,
      ];
}
