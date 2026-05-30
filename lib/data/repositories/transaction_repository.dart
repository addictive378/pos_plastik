import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction_item_model.dart';
import '../models/transaction_model.dart';

/// Repository for POS checkout operations.
///
/// The [checkout] method performs a batch insert into three tables:
/// 1. `transactions` — the header row.
/// 2. `transaction_items` — one row per cart line.
/// 3. `stock_mutations` — one row per cart line (with **negative** qty to
///    trigger the database stock-decrement trigger).
class TransactionRepository {
  final SupabaseClient _client;

  TransactionRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Current authenticated user's ID.
  String get _ownerId => _client.auth.currentUser!.id;

  /// Generate invoice number: INV-YYYYMMDD-XXXX.
  String _generateInvoiceNo() {
    final now = DateTime.now();
    final yyyymmdd = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final randomDigits = Random().nextInt(9000) + 1000; // 1000–9999
    return 'INV-$yyyymmdd-$randomDigits';
  }

  /// Execute the full checkout flow.
  ///
  /// Returns the created [TransactionModel] on success.
  Future<TransactionModel> checkout({
    required List<TransactionItemModel> items,
    required double totalAmount,
    required double discountAmount,
    required double amountPaid,
    required double changeAmount,
    required String paymentMethod,
    String? customerId,
    String? notes,
  }) async {
    final invoiceNo = _generateInvoiceNo();

    // ── Step 1: Insert transaction header ──
    final transactionData = {
      'owner_id': _ownerId,
      'invoice_no': invoiceNo,
      'total_amount': totalAmount,
      'discount_amount': discountAmount,
      'amount_paid': amountPaid,
      'change_amount': changeAmount,
      'payment_method': paymentMethod,
      'status': 'completed',
      'customer_id': null,
      if (notes != null) 'notes': notes,
    };

    final transResponse = await _client
        .from('transactions')
        .insert(transactionData)
        .select()
        .single();

    final transactionId = transResponse['id'] as String;

    // ── Step 2: Insert transaction items ──
    final itemsData = items.map((item) {
      final json = item.toInsertJson();
      json['transaction_id'] = transactionId;
      return json;
    }).toList();

    await _client.from('transaction_items').insert(itemsData);

    // ── Step 3: Insert stock mutations (sale = negative qty) ──
    // The database trigger will subtract current_stock automatically.
    final stockMutationsData = items.map((item) {
      return <String, dynamic>{
        'owner_id': _ownerId,
        'product_id': item.productId,
        if (item.unitId != null) 'unit_id': item.unitId,
        'mutation_type': 'sale',
        'qty_in_base': -item.qtyInBase,
        'qty_original': -item.qty,
        'unit_name_snapshot': item.unitNameSnapshot,
        'harga_modal_lama': item.hargaModalAktual,
        'harga_modal_baru': item.hargaModalAktual,
        'invoice_ref': invoiceNo,
        'notes': 'Penjualan $invoiceNo',
      };
    }).toList();

    await _client.from('stock_mutations').insert(stockMutationsData);

    return TransactionModel.fromJson(transResponse);
  }
}
