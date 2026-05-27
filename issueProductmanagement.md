# Issue: Fitur Manajemen Produk (CRUD) & Multi-Satuan

## Deskripsi
Implementasi fitur Manajemen Produk (CRUD) beserta dukungan Multi-Satuan (Product Units). Fitur ini akan menggunakan `supabase_flutter` untuk integrasi backend dan arsitektur BLoC/Cubit untuk state management.

## Langkah-langkah Implementasi

### 1. Buat Model
- Buat `ProductModel` berdasarkan skema tabel `products`.
- Buat `ProductUnitModel` berdasarkan skema tabel `product_units`.
- *(Referensi skema database dapat dilihat di `.agents/rules/supabase_schema.md`)*

### 2. Buat Repository (`lib/data/repositories/product_repository.dart`)
Buat class `ProductRepository` dengan fungsi-fungsi berikut:
- `getProducts`: Mengambil daftar produk (beserta satuannya jika diperlukan).
- `createProduct`: Menambah produk baru.
  - **PENTING**: Saat melakukan `createProduct`, lakukan insert terlebih dahulu ke tabel `products` (pastikan menyertakan `owner_id` dari user auth yang sedang aktif). Ambil `id` produk yang baru terbuat dari response, lalu gunakan `id` tersebut untuk melakukan insert data ke tabel `product_units` secara batch.
- `updateProduct`: Memperbarui data produk dan/atau satuannya.
- `deleteProduct`: Menghapus data produk.

### 3. Buat State Management
- Buat `ProductCubit` untuk me-manage state halaman daftar produk.
- State harus mencakup: `Loading`, `Loaded`, dan `Error`.
- Tambahkan logika untuk mengakomodasi fitur search dan filter (misalnya filter status aktif/non-aktif).

### 4. Buat UI List (`lib/presentation/product/product_list_screen.dart`)
- Tampilkan daftar produk yang ada.
- Sediakan elemen Search Bar.
- Sediakan elemen Filter.
- Pastikan tampilan UI responsif dan clean.

### 5. Buat UI Form Kompleks (`lib/presentation/product/add_product_screen.dart`)
- **Field Utama**: Nama, SKU, `harga_modal_terakhir`, dan `harga_jual_min`.
- **Sub-form Dinamis**: Form untuk input satuan (Product Units). Pengguna harus bisa menambah atau menghapus input satuan secara dinamis sebelum form disubmit.
- **Validasi Wajib**: Minimal harus ada 1 satuan yang diset sebagai Base Unit (di mana `is_base_unit = true` dan `conversion_to_base = 1`).

## Kriteria Penerimaan (Acceptance Criteria)
- [ ] Model berhasil dibuat dan sesuai dengan skema Supabase.
- [ ] CRUD melalui `ProductRepository` berjalan lancar tanpa error, khususnya proses insert relasional (produk -> satuan).
- [ ] State Management (`ProductCubit`) berjalan dengan baik untuk list, loading, error, search, dan filter.
- [ ] Layar `product_list_screen` menampilkan UI yang clean dan responsif.
- [ ] Layar `add_product_screen` dapat menampung input dinamis untuk satuan.
- [ ] Validasi base unit berjalan dan mencegah submit jika tidak ada base unit.
