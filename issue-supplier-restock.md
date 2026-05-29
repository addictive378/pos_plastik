# Issue: Fitur Stok Masuk dari Supplier (Purchase)

## Deskripsi
Implementasi fitur **Stok Masuk dari Supplier (Purchase)** menggunakan `flutter_bloc` (Cubit) untuk mencatat penambahan stok barang. Fitur ini akan menyimpan mutasi stok ke tabel `stock_mutations` di Supabase. Perubahan stok aktual (`current_stock`) dan update harga modal (`harga_modal_terakhir`) pada tabel `products` sudah di-handle secara otomatis oleh trigger database, sehingga repositori Flutter tidak perlu melakukan update manual ke tabel `products`.

---

## Langkah-langkah Implementasi

### 1. Model & Repository

#### **StockMutationModel**
Buat model `StockMutationModel` di [stock_mutation_model.dart](file:///home/adi/Projects/pos_toko_plastik/lib/data/models/stock_mutation_model.dart) untuk merepresentasikan baris pada tabel `stock_mutations`.

```dart
import 'package:equatable/equatable.dart';

class StockMutationModel extends Equatable {
  final String? id;
  final String? ownerId;
  final String productId;
  final String? unitId;
  final String mutationType; // Nilai default: 'purchase'
  final double qtyInBase;
  final String unitNameSnapshot;
  final double qtyOriginal;
  final double? hargaModalLama;
  final double hargaModalBaru;
  final String? supplierName;
  final String? invoiceRef;
  final String? notes;
  final DateTime? createdAt;

  const StockMutationModel({
    this.id,
    this.ownerId,
    required this.productId,
    this.unitId,
    required this.mutationType,
    required this.qtyInBase,
    required this.unitNameSnapshot,
    required this.qtyOriginal,
    this.hargaModalLama,
    required this.hargaModalBaru,
    this.supplierName,
    this.invoiceRef,
    this.notes,
    this.createdAt,
  });

  factory StockMutationModel.fromJson(Map<String, dynamic> json) {
    return StockMutationModel(
      id: json['id'] as String?,
      ownerId: json['owner_id'] as String?,
      productId: json['product_id'] as String,
      unitId: json['unit_id'] as String?,
      mutationType: json['mutation_type'] as String,
      qtyInBase: (json['qty_in_base'] as num).toDouble(),
      unitNameSnapshot: json['unit_name_snapshot'] as String,
      qtyOriginal: (json['qty_original'] as num).toDouble(),
      hargaModalLama: (json['harga_modal_lama'] as num?)?.toDouble(),
      hargaModalBaru: (json['harga_modal_baru'] as num).toDouble(),
      supplierName: json['supplier_name'] as String?,
      invoiceRef: json['invoice_ref'] as String?,
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
      'product_id': productId,
      if (unitId != null) 'unit_id': unitId,
      'mutation_type': mutationType,
      'qty_in_base': qtyInBase,
      'unit_name_snapshot': unitNameSnapshot,
      'qty_original': qtyOriginal,
      if (hargaModalLama != null) 'harga_modal_lama': hargaModalLama,
      'harga_modal_baru': hargaModalBaru,
      if (supplierName != null) 'supplier_name': supplierName,
      if (invoiceRef != null) 'invoice_ref': invoiceRef,
      if (notes != null) 'notes': notes,
    };
  }

  @override
  List<Object?> get props => [
        id,
        ownerId,
        productId,
        unitId,
        mutationType,
        qtyInBase,
        unitNameSnapshot,
        qtyOriginal,
        hargaModalLama,
        hargaModalBaru,
        supplierName,
        invoiceRef,
        notes,
        createdAt,
      ];
}
```

#### **StockMutationRepository**
Buat class `StockMutationRepository` di [stock_mutation_repository.dart](file:///home/adi/Projects/pos_toko_plastik/lib/data/repositories/stock_mutation_repository.dart) dengan satu fungsi `createPurchaseMutation()`.

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/stock_mutation_model.dart';

class StockMutationRepository {
  final SupabaseClient _client;

  StockMutationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String get _ownerId => _client.auth.currentUser!.id;

  /// Memasukkan data mutasi pembelian baru ke tabel `stock_mutations`
  Future<StockMutationModel> createPurchaseMutation(StockMutationModel mutation) async {
    final json = mutation.toJson();
    json['owner_id'] = _ownerId;

    final response = await _client
        .from('stock_mutations')
        .insert(json)
        .select()
        .single();

    return StockMutationModel.fromJson(response);
  }
}
```

---

## 2. State Management (BLoC / Cubit)

Buat folder `lib/logic/inventory/` dan tambahkan `StockMutationCubit` beserta State-nya.

#### **StockMutationState**
Definisikan status form, data produk untuk dropdown, produk terpilih, unit terpilih, input quantitas, dan input harga di [stock_mutation_state.dart](file:///home/adi/Projects/pos_toko_plastik/lib/logic/inventory/stock_mutation_state.dart).

```dart
import 'package:equatable/equatable.dart';
import '../../data/models/product_model.dart';
import '../../data/models/product_unit_model.dart';

enum StockMutationStatus { initial, loading, success, error }

class StockMutationState extends Equatable {
  final StockMutationStatus status;
  final List<ProductModel> products;
  final ProductModel? selectedProduct;
  final ProductUnitModel? selectedUnit;
  final double? qtyOriginal;
  final double? hargaModalBaru;
  final String? supplierName;
  final String? invoiceRef;
  final String? notes;
  final String? errorMessage;

  const StockMutationState({
    this.status = StockMutationStatus.initial,
    this.products = const [],
    this.selectedProduct,
    this.selectedUnit,
    this.qtyOriginal,
    this.hargaModalBaru,
    this.supplierName,
    this.invoiceRef,
    this.notes,
    this.errorMessage,
  });

  StockMutationState copyWith({
    StockMutationStatus? status,
    List<ProductModel>? products,
    ProductModel? selectedProduct,
    ProductUnitModel? selectedUnit,
    double? qtyOriginal,
    double? hargaModalBaru,
    String? supplierName,
    String? invoiceRef,
    String? notes,
    String? errorMessage,
  }) {
    return StockMutationState(
      status: status ?? this.status,
      products: products ?? this.products,
      selectedProduct: selectedProduct ?? this.selectedProduct,
      selectedUnit: selectedUnit ?? this.selectedUnit,
      qtyOriginal: qtyOriginal ?? this.qtyOriginal,
      hargaModalBaru: hargaModalBaru ?? this.hargaModalBaru,
      supplierName: supplierName ?? this.supplierName,
      invoiceRef: invoiceRef ?? this.invoiceRef,
      notes: notes ?? this.notes,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        products,
        selectedProduct,
        selectedUnit,
        qtyOriginal,
        hargaModalBaru,
        supplierName,
        invoiceRef,
        notes,
        errorMessage,
      ];
}
```

#### **StockMutationCubit**
Definisikan cubit di [stock_mutation_cubit.dart](file:///home/adi/Projects/pos_toko_plastik/lib/logic/inventory/stock_mutation_cubit.dart). Cubit ini bertanggung jawab mengambil daftar produk aktif, memanipulasi state input form, dan melakukan eksekusi simpan.

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/stock_mutation_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/product_unit_model.dart';
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

  /// Mengambil daftar semua produk untuk kebutuhan dropdown pilihan
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
        errorMessage: 'Gagal mengambil data produk: ${e.toString()}',
      ));
    }
  }

  void selectProduct(ProductModel product) {
    // Cari unit yang bisa dibeli (isPurchasable == true). 
    // Jika tidak ada, default ke unit pertama atau null.
    final purchasableUnits = product.units.where((u) => u.isPurchasable).toList();
    final defaultUnit = purchasableUnits.isNotEmpty ? purchasableUnits.first : null;

    emit(state.copyWith(
      selectedProduct: product,
      selectedUnit: defaultUnit,
      // Default harga beli saat ini menggunakan harga modal terakhir dari produk
      hargaModalBaru: product.hargaModalTerakhir,
    ));
  }

  void selectUnit(ProductUnitModel unit) {
    emit(state.copyWith(selectedUnit: unit));
  }

  void setQtyOriginal(double qty) {
    emit(state.copyWith(qtyOriginal: qty));
  }

  void setHargaModalBaru(double harga) {
    emit(state.copyWith(hargaModalBaru: harga));
  }

  void setSupplierName(String name) {
    emit(state.copyWith(supplierName: name));
  }

  void setInvoiceRef(String ref) {
    emit(state.copyWith(invoiceRef: ref));
  }

  void setNotes(String notes) {
    emit(state.copyWith(notes: notes));
  }

  /// Eksekusi insert data pembelian ke stock mutations
  Future<void> submitPurchase() async {
    if (state.selectedProduct == null ||
        state.selectedUnit == null ||
        state.qtyOriginal == null ||
        state.qtyOriginal! <= 0 ||
        state.hargaModalBaru == null ||
        state.hargaModalBaru! < 0) {
      emit(state.copyWith(
        status: StockMutationStatus.error,
        errorMessage: 'Mohon lengkapi semua field input dengan benar.',
      ));
      return;
    }

    emit(state.copyWith(status: StockMutationStatus.loading));
    try {
      final product = state.selectedProduct!;
      final unit = state.selectedUnit!;
      
      // Logika Kalkulasi Sebelum Insert
      final qtyInBase = state.qtyOriginal! * unit.conversionToBase;
      const mutationType = 'purchase';
      final unitNameSnapshot = unit.unitName;
      final hargaModalLama = product.hargaModalTerakhir;

      final mutation = StockMutationModel(
        productId: product.id!,
        unitId: unit.id,
        mutationType: mutationType,
        qtyInBase: qtyInBase,
        unitNameSnapshot: unitNameSnapshot,
        qtyOriginal: state.qtyOriginal!,
        hargaModalLama: hargaModalLama,
        hargaModalBaru: state.hargaModalBaru!,
        supplierName: state.supplierName?.trim().isEmpty == true ? null : state.supplierName,
        invoiceRef: state.invoiceRef?.trim().isEmpty == true ? null : state.invoiceRef,
        notes: state.notes?.trim().isEmpty == true ? null : state.notes,
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
```

---

## 3. UI Form (`lib/presentation/inventory/restock_screen.dart`)

Buat file baru di [restock_screen.dart](file:///home/adi/Projects/pos_toko_plastik/lib/presentation/inventory/restock_screen.dart). Screen ini akan menggunakan `StockMutationCubit` untuk berinteraksi dengan state.

#### **Form Layout & Input Fields**
* **Produk (Product) Dropdown/Search**: Pilihan untuk memilih Produk dari state (`state.products`). Dapat menggunakan widget `Autocomplete` atau `DropdownButtonFormField` yang dipercantik agar mudah mencari produk berdasarkan nama atau SKU.
* **Informasi Produk (Read-Only)**: Tampilkan detail harga modal terakhir dan stok saat ini milik produk terpilih.
  * *Harga Modal Terakhir:* `Rp ${hargaModalTerakhir}`
  * *Stok Saat Ini:* `${currentStock} ${baseUnit}`
* **Satuan (ProductUnit) Dropdown**: Filter satuan dari `selectedProduct.units` yang bertanda `isPurchasable == true`.
* **Input `qty_original`**:
  * Widget: `TextFormField` WITH `keyboardType: TextInputType.number`
  * Validasi: Harus berupa angka positif (lebih besar dari 0).
* **Input `harga_modal_baru`**:
  * Widget: `TextFormField` WITH `keyboardType: TextInputType.number`
  * Validasi: Harus berupa angka >= 0.

#### **Logika UX Pop-up Harga (PENTING)**
Saat tombol Submit ditekan, jalankan pemeriksaan perbandingan harga berikut di UI sebelum memanggil API insert:
```dart
void _onSubmitPressed(BuildContext context, StockMutationState state) {
  if (!_formKey.currentState!.validate()) return;

  final product = state.selectedProduct;
  final newPrice = double.tryParse(_hargaBaruCtrl.text) ?? 0.0;

  if (product != null && newPrice > product.hargaModalTerakhir) {
    // Tampilkan Pop-up dialog peringatan kenaikan harga modal
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Harga Modal Naik!'),
        content: const Text(
          'Stok akan ditambahkan, namun apakah Anda ingin meninjau ulang Harga Jual sekarang?'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx); // Tutup dialog
              _executeSubmit(context, navigateToEdit: true);
            },
            child: const Text('Ya'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx); // Tutup dialog
              _executeSubmit(context, navigateToEdit: false);
            },
            child: const Text('Tidak'),
          ),
        ],
      ),
    );
  } else {
    // Jika tidak naik, langsung submit
    _executeSubmit(context, navigateToEdit: false);
  }
}
```

#### **Logika Navigasi Pasca-Submit**
* Jika `navigateToEdit` bernilai `true`:
  1. Tunggu proses insert mutasi selesai (`StockMutationStatus.success`).
  2. Buka halaman Edit Produk menggunakan `Navigator.pushReplacement` ke halaman [AddProductScreen](file:///home/adi/Projects/pos_toko_plastik/lib/presentation/product/add_product_screen.dart) dengan parameter `product: selectedProduct`.
* Jika `navigateToEdit` bernilai `false`:
  1. Tunggu proses insert selesai.
  2. Tutup layar Restock menggunakan `Navigator.pop(context)`.

---

## 4. Integrasi ke System (`lib/main.dart` & Routing)

Daftarkan `StockMutationRepository` dan `StockMutationCubit` di [main.dart](file:///home/adi/Projects/pos_toko_plastik/lib/main.dart) pada bagian Provider agar dapat digunakan di seluruh aplikasi:

```dart
// Di MultiRepositoryProvider
RepositoryProvider<StockMutationRepository>(
  create: (_) => StockMutationRepository(),
),

// Di MultiBlocProvider
BlocProvider<StockMutationCubit>(
  create: (context) => StockMutationCubit(
    productRepository: context.read<ProductRepository>(),
    stockMutationRepository: context.read<StockMutationRepository>(),
  )..loadProducts(),
),
```

---

## Kriteria Penerimaan (Acceptance Criteria)

- [ ] Model `StockMutationModel` berhasil dibuat sesuai skema kolom tabel `stock_mutations`.
- [ ] Repositori `StockMutationRepository` berhasil didefinisikan dengan method `createPurchaseMutation()`.
- [ ] BLoC State Management `StockMutationCubit` mengontrol input form dengan baik (load produk, select produk, select unit, set quantity, dll).
- [ ] Layar `restock_screen.dart` menampilkan:
  - Dropdown/Search produk.
  - Field Read-Only harga modal terakhir dan stok saat ini.
  - Dropdown satuan yang valid.
  - Input quantity (validasi positif).
  - Input harga modal baru.
- [ ] Perhitungan `qty_in_base = qty_original * conversion_to_base` dihitung dengan benar sebelum data disubmit.
- [ ] Logika Dialog Pop-up bekerja dengan benar saat harga modal baru > harga modal terakhir.
  - Pilihan **"Ya"**: Melakukan insert, lalu mengarahkan ke halaman Edit Produk (`AddProductScreen`).
  - Pilihan **"Tidak"**: Melakukan insert, lalu menutup halaman Restock.
- [ ] Desain antarmuka rapi, responsif, dan menangani error form kosong atau error API dengan memadai.
