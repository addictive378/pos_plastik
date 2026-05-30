# Issue: Fitur Sistem Kasir (Point of Sale - POS)

## Deskripsi
Implementasi fitur **Sistem Kasir (Point of Sale)** menggunakan `flutter_bloc` (Cubit) untuk melayani transaksi retail dengan cepat, responsif, dan akurat. Fitur ini akan mencatat transaksi ke tabel `transactions` dan detail item ke `transaction_items`, serta merekam mutasi stok keluar bermutasi negatif ke tabel `stock_mutations`.

Proses checkout akan berjalan secara atomik melalui beberapa request Supabase (atau RPC jika didukung) untuk menyimpan data transaksi secara utuh. Pengurangan stok di tabel `products` akan dilakukan otomatis oleh trigger database saat baris baru dengan nilai negatif masuk ke tabel `stock_mutations`.

---

## Langkah-langkah Implementasi

### 1. Model Data

#### **CartItemModel**
Buat model `CartItemModel` di [cart_item_model.dart](file:///home/adi/Projects/pos_toko_plastik/lib/data/models/cart_item_model.dart). Model ini bersifat lokal untuk menampung state item belanja di dalam keranjang (tidak disimpan langsung ke database).

```dart
import 'package:equatable/equatable.dart';
import 'product_model.dart';
import 'product_unit_model.dart';

class CartItemModel extends Equatable {
  final ProductModel product;
  final ProductUnitModel unit;
  final double qty;
  final double hargaAcuanSistem; // Harga acuan (default: harga_jual_min * conversion_to_base)
  final double hargaJualAktual; // Harga final setelah override manual
  final bool isPriceOverridden;
  final String? priceOverrideReason;

  const CartItemModel({
    required this.product,
    required this.unit,
    required this.qty,
    required this.hargaAcuanSistem,
    required this.hargaJualAktual,
    this.isPriceOverridden = false,
    this.priceOverrideReason,
  });

  /// Subtotal belanja untuk item ini (qty * harga_jual_aktual)
  double get subtotal => qty * hargaJualAktual;

  /// Harga jual minimum yang diperbolehkan untuk satuan terpilih
  double get minPriceAllowed => product.hargaJualMin * unit.conversionToBase;

  CartItemModel copyWith({
    ProductModel? product,
    ProductUnitModel? unit,
    double? qty,
    double? hargaAcuanSistem,
    double? hargaJualAktual,
    bool? isPriceOverridden,
    String? priceOverrideReason,
  }) {
    return CartItemModel(
      product: product ?? this.product,
      unit: unit ?? this.unit,
      qty: qty ?? this.qty,
      hargaAcuanSistem: hargaAcuanSistem ?? this.hargaAcuanSistem,
      hargaJualAktual: hargaJualAktual ?? this.hargaJualAktual,
      isPriceOverridden: isPriceOverridden ?? this.isPriceOverridden,
      priceOverrideReason: priceOverrideReason ?? this.priceOverrideReason,
    );
  }

  @override
  List<Object?> get props => [
        product,
        unit,
        qty,
        hargaAcuanSistem,
        hargaJualAktual,
        isPriceOverridden,
        priceOverrideReason,
      ];
}
```

#### **TransactionModel**
Buat model `TransactionModel` di [transaction_model.dart](file:///home/adi/Projects/pos_toko_plastik/lib/data/models/transaction_model.dart) untuk memetakan tabel `transactions`.

```dart
import 'package:equatable/equatable.dart';

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
      paymentMethod: json['payment_method'] as String,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
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
```

#### **TransactionItemModel**
Buat model `TransactionItemModel` di [transaction_item_model.dart](file:///home/adi/Projects/pos_toko_plastik/lib/data/models/transaction_item_model.dart) untuk memetakan tabel `transaction_items`.

```dart
import 'package:equatable/equatable.dart';

class TransactionItemModel extends Equatable {
  final String? id;
  final String? transactionId;
  final String productId;
  final String? unitId;
  final String productNameSnapshot;
  final String unitNameSnapshot;
  final double qty;
  final double qtyInBase;
  final double hargaModalAktual;
  final double hargaJualAktual;
  final double hargaAcuanSistem;
  final bool isPriceOverridden;
  final String? priceOverrideReason;
  final double subtotal;
  final double profitSubtotal;

  const TransactionItemModel({
    this.id,
    this.transactionId,
    required this.productId,
    this.unitId,
    required this.productNameSnapshot,
    required this.unitNameSnapshot,
    required this.qty,
    required this.qtyInBase,
    required this.hargaModalAktual,
    required this.hargaJualAktual,
    required this.hargaAcuanSistem,
    this.isPriceOverridden = false,
    this.priceOverrideReason,
    required this.subtotal,
    required this.profitSubtotal,
  });

  factory TransactionItemModel.fromJson(Map<String, dynamic> json) {
    return TransactionItemModel(
      id: json['id'] as String?,
      transactionId: json['transaction_id'] as String?,
      productId: json['product_id'] as String,
      unitId: json['unit_id'] as String?,
      productNameSnapshot: json['product_name_snapshot'] as String,
      unitNameSnapshot: json['unit_name_snapshot'] as String,
      qty: (json['qty'] as num).toDouble(),
      qtyInBase: (json['qty_in_base'] as num).toDouble(),
      hargaModalAktual: (json['harga_modal_aktual'] as num).toDouble(),
      hargaJualAktual: (json['harga_jual_aktual'] as num).toDouble(),
      hargaAcuanSistem: (json['harga_acuan_sistem'] as num).toDouble(),
      isPriceOverridden: json['is_price_overridden'] as bool? ?? false,
      priceOverrideReason: json['price_override_reason'] as String?,
      subtotal: (json['subtotal'] as num).toDouble(),
      profitSubtotal: (json['profit_subtotal'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (transactionId != null) 'transaction_id': transactionId,
      'product_id': productId,
      if (unitId != null) 'unit_id': unitId,
      'product_name_snapshot': productNameSnapshot,
      'unit_name_snapshot': unitNameSnapshot,
      'qty': qty,
      'qty_in_base': qtyInBase,
      'harga_modal_aktual': hargaModalAktual,
      'harga_jual_aktual': hargaJualAktual,
      'harga_acuan_sistem': hargaAcuanSistem,
      'is_price_overridden': isPriceOverridden,
      if (priceOverrideReason != null) 'price_override_reason': priceOverrideReason,
      'subtotal': subtotal,
      'profit_subtotal': profitSubtotal,
    };
  }

  @override
  List<Object?> get props => [
        id,
        transactionId,
        productId,
        unitId,
        productNameSnapshot,
        unitNameSnapshot,
        qty,
        qtyInBase,
        hargaModalAktual,
        hargaJualAktual,
        hargaAcuanSistem,
        isPriceOverridden,
        priceOverrideReason,
        subtotal,
        profitSubtotal,
      ];
}
```

---

## 2. Repositori Transaksi (`TransactionRepository`)
Buat class `TransactionRepository` di [transaction_repository.dart](file:///home/adi/Projects/pos_toko_plastik/lib/data/repositories/transaction_repository.dart) untuk menyimpan transaksi ke database.

Repository harus menangani 3 operasi insert:
1. `transactions`: Membuat baris transaksi utama dan mendapatkan generated ID.
2. `transaction_items`: Memasukkan data detail barang belanjaan yang terikat pada transaksi di atas.
3. `stock_mutations`: Mencatat mutasi keluar barang dengan tipe `sale` dan volume qty bernilai **negatif** (`-qty_in_base` dan `-qty_original`), agar stock trigger di Supabase mendeteksi penjualan dan mengurangi `current_stock` master.

```dart
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction_model.dart';
import '../models/transaction_item_model.dart';

class TransactionRepository {
  final SupabaseClient _client;

  TransactionRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String get _ownerId => _client.auth.currentUser!.id;

  /// Membuat invoice no format INV-YYYYMMDD-XXXX (4 digit angka acak)
  String _generateInvoiceNo() {
    final now = DateTime.now();
    final yyyymmdd = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final randomDigits = Random().nextInt(9000) + 1000; // 1000 - 9999
    return 'INV-$yyyymmdd-$randomDigits';
  }

  /// Melakukan batch checkout ke Supabase
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

    // 1. Insert ke tabel transactions
    final transactionData = {
      'owner_id': _ownerId,
      'invoice_no': invoiceNo,
      'total_amount': totalAmount,
      'discount_amount': discountAmount,
      'amount_paid': amountPaid,
      'change_amount': changeAmount,
      'payment_method': paymentMethod,
      'status': 'completed',
      if (customerId != null) 'customer_id': customerId,
      if (notes != null) 'notes': notes,
    };

    final transResponse = await _client
        .from('transactions')
        .insert(transactionData)
        .select()
        .single();

    final transactionId = transResponse['id'] as String;

    // 2. Insert ke tabel transaction_items
    final itemsData = items.map((item) {
      final json = item.toJson();
      json['transaction_id'] = transactionId;
      return json;
    }).toList();

    await _client.from('transaction_items').insert(itemsData);

    // 3. Insert ke tabel stock_mutations (Penjualan / Stok Keluar)
    // PENTING: qty_in_base & qty_original harus NEGATIF agar stock trigger mendeteksi pengurangan
    final stockMutationsData = items.map((item) {
      return {
        'owner_id': _ownerId,
        'product_id': item.productId,
        'unit_id': item.unitId,
        'mutation_type': 'sale',
        'qty_in_base': -item.qtyInBase,
        'qty_original': -item.qty,
        'unit_name_snapshot': item.unitNameSnapshot,
        'harga_modal_lama': item.hargaModalAktual,
        'harga_modal_baru': item.hargaModalAktual, // Tidak ada perubahan harga modal saat penjualan
        'invoice_ref': invoiceNo,
        'notes': 'Penjualan Invoice $invoiceNo',
      };
    }).toList();

    await _client.from('stock_mutations').insert(stockMutationsData);

    return TransactionModel.fromJson(transResponse);
  }
}
```

---

## 3. State Management (`CartCubit` & `CartState`)

Buat folder `lib/logic/pos/` dan tambahkan `CartCubit` serta State pendukungnya.

#### **CartState**
Buat file [cart_state.dart](file:///home/adi/Projects/pos_toko_plastik/lib/logic/pos/cart_state.dart) untuk mendefinisikan state keranjang belanja dan status checkout.

```dart
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
  final String? customerId; // Opsional jika dikaitkan dengan customer
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
    this.notes,
    this.successTransaction,
    this.errorMessage,
  });

  /// Kalkulasi total belanja sebelum diskon
  double get totalAmount {
    return cartItems.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  /// Grand total belanja setelah dipotong diskon
  double get grandTotal {
    final total = totalAmount - discountAmount;
    return total < 0 ? 0.0 : total;
  }

  /// Jumlah kembalian uang bayar
  double get changeAmount {
    final change = amountPaid - grandTotal;
    return change < 0 ? 0.0 : change;
  }

  CartState copyWith({
    CartStatus? status,
    List<CartItemModel>? cartItems,
    double? discountAmount,
    double? amountPaid,
    String? paymentMethod,
    String? customerId,
    String? notes,
    TransactionModel? successTransaction,
    String? errorMessage,
  }) {
    return CartState(
      status: status ?? this.status,
      cartItems: cartItems ?? this.cartItems,
      discountAmount: discountAmount ?? this.discountAmount,
      amountPaid: amountPaid ?? this.amountPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerId: customerId ?? this.customerId,
      notes: notes ?? this.notes,
      successTransaction: successTransaction ?? this.successTransaction,
      errorMessage: errorMessage ?? this.errorMessage,
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
        notes,
        successTransaction,
        errorMessage,
      ];
}
```

#### **CartCubit**
Buat file [cart_cubit.dart](file:///home/adi/Projects/pos_toko_plastik/lib/logic/pos/cart_cubit.dart). Cubit ini melayani manipulasi data keranjang lokal, validasi harga manual, dan checkout.

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/product_unit_model.dart';
import '../../data/models/transaction_item_model.dart';
import '../../data/repositories/transaction_repository.dart';
import 'cart_state.dart';

class CartCubit extends Cubit<CartState> {
  final TransactionRepository _transactionRepository;

  CartCubit({
    required TransactionRepository transactionRepository,
  })  : _transactionRepository = transactionRepository,
        super(const CartState());

  /// Menambah produk ke keranjang belanja
  void addToCart(ProductModel product) {
    final existingIndex = state.cartItems.indexWhere((item) => item.product.id == product.id);

    if (existingIndex != null && existingIndex >= 0) {
      // Jika produk sudah ada, tambahkan quantity (+1)
      final existingItem = state.cartItems[existingIndex];
      final updatedItem = existingItem.copyWith(qty: existingItem.qty + 1);
      final updatedList = List<CartItemModel>.from(state.cartItems)..[existingIndex] = updatedItem;
      emit(state.copyWith(cartItems: updatedList));
    } else {
      // Jika produk baru, pilih unit default (base_unit atau unit yang sellable)
      final sellableUnits = product.units.where((u) => u.isSellable).toList();
      if (sellableUnits.isEmpty) return; // Tidak ada unit yang bisa dijual

      // Cari base unit yang bisa dijual, fallback ke unit pertama yang sellable
      final defaultUnit = sellableUnits.firstWhere(
        (u) => u.isBaseUnit,
        orElse: () => sellableUnits.first,
      );

      // Default harga menggunakan harga minimum untuk unit tersebut
      final basePrice = product.hargaJualMin * defaultUnit.conversionToBase;

      final newItem = CartItemModel(
        product: product,
        unit: defaultUnit,
        qty: 1.0,
        hargaAcuanSistem: basePrice,
        hargaJualAktual: basePrice,
        isPriceOverridden: false,
      );

      emit(state.copyWith(cartItems: List<CartItemModel>.from(state.cartItems)..add(newItem)));
    }
  }

  /// Menghapus item dari keranjang belanja
  void removeFromCart(CartItemModel item) {
    final updatedList = state.cartItems.where((i) => i != item).toList();
    emit(state.copyWith(cartItems: updatedList));
  }

  /// Mengubah quantity item
  void updateQty(CartItemModel item, double newQty) {
    if (newQty <= 0) return;
    final index = state.cartItems.indexOf(item);
    if (index == -1) return;

    final updatedItem = item.copyWith(qty: newQty);
    final updatedList = List<CartItemModel>.from(state.cartItems)..[index] = updatedItem;
    emit(state.copyWith(cartItems: updatedList));
  }

  /// Mengubah satuan (Unit) di keranjang dan otomatis kalkulasi ulang harga_acuan_sistem
  void changeUnit(CartItemModel item, ProductUnitModel newUnit) {
    final index = state.cartItems.indexOf(item);
    if (index == -1) return;

    // Kalkulasi harga acuan berdasarkan konversi satuan terpilih
    final newSystemPrice = item.product.hargaJualMin * newUnit.conversionToBase;
    
    // Jika harga tidak pernah di-override, ubah harga jual aktual mengikuti harga acuan baru
    // Jika sebelumnya di-override, periksa apakah di bawah harga minimum baru. 
    // Jika iya, paksa naikkan ke harga minimum baru.
    double newActualPrice = newSystemPrice;
    bool overridden = item.isPriceOverridden;
    String? reason = item.priceOverrideReason;

    if (item.isPriceOverridden) {
      if (item.hargaJualAktual < newSystemPrice) {
        newActualPrice = newSystemPrice;
        overridden = false;
        reason = null;
      } else {
        newActualPrice = item.hargaJualAktual;
      }
    }

    final updatedItem = item.copyWith(
      unit: newUnit,
      hargaAcuanSistem: newSystemPrice,
      hargaJualAktual: newActualPrice,
      isPriceOverridden: overridden,
      priceOverrideReason: reason,
    );

    final updatedList = List<CartItemModel>.from(state.cartItems)..[index] = updatedItem;
    emit(state.copyWith(cartItems: updatedList));
  }

  /// Mengubah harga manual (Override Harga) dengan validasi minimum
  bool overridePrice(CartItemModel item, double newPrice, String? reason) {
    final index = state.cartItems.indexOf(item);
    if (index == -1) return false;

    // Validasi: Tidak boleh di bawah harga_jual_min dari master produk terkonversi
    final minAllowed = item.product.hargaJualMin * item.unit.conversionToBase;
    if (newPrice < minAllowed) {
      emit(state.copyWith(
        status: CartStatus.error,
        errorMessage: 'Harga tidak boleh di bawah harga jual minimum (Rp ${minAllowed.toStringAsFixed(0)})',
      ));
      // Reset error status ke initial setelah emit
      emit(state.copyWith(status: CartStatus.initial, errorMessage: null));
      return false;
    }

    final updatedItem = item.copyWith(
      hargaJualAktual: newPrice,
      isPriceOverridden: true,
      priceOverrideReason: reason?.trim().isEmpty == true ? 'Penyesuaian Kasir' : reason,
    );

    final updatedList = List<CartItemModel>.from(state.cartItems)..[index] = updatedItem;
    emit(state.copyWith(cartItems: updatedList));
    return true;
  }

  void setDiscount(double discount) {
    emit(state.copyWith(discountAmount: discount));
  }

  void setAmountPaid(double amount) {
    emit(state.copyWith(amountPaid: amount));
  }

  void setPaymentMethod(String method) {
    emit(state.copyWith(paymentMethod: method));
  }

  void setCustomerId(String? id) {
    emit(state.copyWith(customerId: id));
  }

  void setNotes(String? notes) {
    emit(state.copyWith(notes: notes));
  }

  /// Membersihkan isi keranjang belanja
  void clearCart() {
    emit(const CartState());
  }

  /// Eksekusi checkout transaksi ke Supabase
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
      // Pemetaan CartItemModel -> TransactionItemModel
      final transactionItems = state.cartItems.map((cartItem) {
        final qtyInBase = cartItem.qty * cartItem.unit.conversionToBase;
        final subtotal = cartItem.qty * cartItem.hargaJualAktual;
        
        // Kalkulasi profit subtotal: (qty_in_base * (harga_jual_aktual_per_base - harga_modal_aktual))
        // Atau disederhanakan: subtotal_penjualan - (qty_in_base * harga_modal_terakhir)
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
        customerId: state.customerId,
        notes: state.notes,
      );

      emit(state.copyWith(
        status: CartStatus.success,
        successTransaction: result,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CartStatus.error,
        errorMessage: 'Checkout Gagal: ${e.toString()}',
      ));
    }
  }
}
```

---

### 4. UI Sistem Kasir (`lib/presentation/pos/pos_screen.dart`)

Buat file baru di [pos_screen.dart](file:///home/adi/Projects/pos_toko_plastik/lib/presentation/pos/pos_screen.dart). Menggunakan split layout di tablet/layar lebar (Daftar produk kiri 60%, Keranjang kanan 40%) dan modal bottom sheet/navigation tabs di mobile.

#### **Fitur Utama UI**
1. **Pencarian Real-Time (Left Panel)**:
   - Input search bar untuk memfilter produk berdasarkan nama atau barcode (real-time filtering).
   - Tampilkan produk aktif (`is_active = true`) dalam grid modern. Setiap card menampilkan informasi produk (nama, SKU, stok aktif) dan tombol cepat tambah ke keranjang.
2. **Detail Keranjang & Operasi Item (Right Panel)**:
   - Tampilkan list item belanja dengan scrollable area.
   - Pilihan Unit menggunakan dropdown dinamis yang difilter hanya menampilkan unit yang bisa dijual (`isSellable == true`).
   - Penambahan/pengurangan quantity menggunakan tombol `+` / `-` yang cepat atau ketikan input langsung.
   - Override harga manual dengan mengetuk area harga item belanja, memicu dialog input angka harga baru + catatan alasan override (opsional).
3. **Kalkulasi Pembayaran & Checkout (Bottom Bar / Card)**:
   - Ringkasan total belanja, nominal diskon.
   - Pilihan metode bayar: Cash, Transfer, QRIS, Credit.
   - Form input uang bayar dengan pintasan nominal uang (misal: Uang Pas, Rp 20.000, Rp 50.000, Rp 100.000).
   - Menampilkan kembalian secara real-time.
   - Tombol checkout "Bayar Sekarang" yang memicu validasi nominal bayar dan pemanggilan method checkout.

#### **Logika UX Dialog Override Harga**
```dart
void _showOverridePriceDialog(BuildContext context, CartItemModel item) {
  final controller = TextEditingController(text: item.hargaJualAktual.toStringAsFixed(0));
  final reasonController = TextEditingController(text: item.priceOverrideReason ?? '');
  final formKey = GlobalKey<FormState>();
  final minAllowed = item.product.hargaJualMin * item.unit.conversionToBase;

  showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text('Override Harga: ${item.product.name}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Min. Harga Satuan ${item.unit.unitName}: Rp ${minAllowed.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga Baru',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                  final price = double.tryParse(v.trim());
                  if (price == null || price < minAllowed) {
                    return 'Tidak boleh di bawah Rp ${minAllowed.toStringAsFixed(0)}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Alasan Ubah Harga',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final price = double.tryParse(controller.text) ?? 0.0;
                context.read<CartCubit>().overridePrice(
                      item,
                      price,
                      reasonController.text,
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      );
    },
  );
}
```

---

### 5. Registrasi ke System (`lib/main.dart` & Routing)

Daftarkan `TransactionRepository` dan `CartCubit` pada file [main.dart](file:///home/adi/Projects/pos_toko_plastik/lib/main.dart):

```dart
// Di dalam MultiRepositoryProvider
RepositoryProvider<TransactionRepository>(
  create: (_) => TransactionRepository(),
),

// Di dalam MultiBlocProvider
BlocProvider<CartCubit>(
  create: (context) => CartCubit(
    transactionRepository: context.read<TransactionRepository>(),
  ),
),
```

Tambahkan pula rute navigasi atau pintasan menu di dashboard utama untuk menuju ke halaman `PosScreen`.

---

## Kriteria Penerimaan (Acceptance Criteria)

- [ ] Model data `CartItemModel`, `TransactionModel`, dan `TransactionItemModel` sukses didefinisikan lengkap dengan adapter JSON dan Equatable.
- [ ] Repositori `TransactionRepository` memiliki fungsi `checkout()` yang meng-insert data secara berurutan ke tabel `transactions`, `transaction_items`, dan `stock_mutations`.
- [ ] Record stok keluar di `stock_mutations` dibuat dengan `mutation_type = 'sale'` dan quantity bernilai **negatif** (`-qty_in_base`).
- [ ] State Management `CartCubit` berjalan lancar dalam mengolah state keranjang belanja (tambah, kurangi, hapus item).
- [ ] Penggantian unit produk di dalam keranjang belanja memicu kalkulasi ulang `harga_acuan_sistem` secara otomatis.
- [ ] Fitur Override Harga Manual berjalan dengan validasi minimal tidak boleh kurang dari `harga_jual_min * conversion_to_base` dari produk master.
- [ ] UI Layar Kasir (`pos_screen.dart`) responsif:
  - Layar tablet terbagi dua (daftar produk kiri, keranjang belanja kanan).
  - Layar ponsel menyembunyikan keranjang dalam panel bottom sheet atau tab terpisah.
- [ ] Barcode / Name search bar bekerja real-time menyaring daftar produk aktif.
- [ ] Form nominal bayar mendeteksi jika uang bayar kurang dari total belanjaan dan memunculkan error handling yang memadai saat Checkout ditekan.
- [ ] Transaksi sukses memunculkan pop-up dialog ringkasan struk (Nominal Belanja, Nominal Bayar, Kembalian) dan membersihkan keranjang setelah dialog ditutup.
