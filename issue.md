# Planning: Setup Awal Supabase Backend

## Konteks
Task ini dikerjakan pada branch `feature/setup-supabase` dan bertujuan untuk melakukan setup serta inisialisasi awal backend menggunakan Supabase di dalam aplikasi Flutter. Mengacu pada `.agents/rules/supabase_schema.md`, proyek ini adalah aplikasi Point of Sales (POS) yang akan memiliki berbagai tabel seperti `products`, `customers`, dan `transactions`. Setup awal klien Supabase merupakan pondasi agar aplikasi dapat mulai berinteraksi dengan database tersebut.

## Langkah-langkah Implementasi

### 1. Penambahan Dependensi
- Modifikasi file `pubspec.yaml`.
- Tambahkan library `supabase_flutter` versi terbaru di bawah bagian `dependencies:`.

### 2. Instalasi Dependensi
- Melalui terminal terintegrasi di dalam proyek, jalankan perintah:
  ```bash
  flutter pub get
  ```
- Pastikan proses pengambilan dependensi berjalan dengan sukses dan tidak ada konflik versi.

### 3. Pembuatan Klien Supabase (`lib/core/supabase_client.dart`)
- Buat direktori baru `core` di dalam folder `lib/` jika belum ada.
- Buat file `supabase_client.dart` di dalam `lib/core/`.
- Buat fungsi/kelas inisialisasi yang memanggil `Supabase.initialize(...)`.
- Gunakan placeholder untuk kredensial Supabase. Contoh:
  ```dart
  import 'package:supabase_flutter/supabase_flutter.dart';

  class SupabaseConfig {
    // TODO: Ganti dengan URL dan Anon Key dari dashboard Supabase
    static const String supabaseUrl = 'https://pjimlzfwfeqlgilcnqlg.supabase.co';
    static const String supabaseAnonKey = 'sb_publishable_Y9-e3MXPw3IdvTgMf2EO7A_j3LD73ys';

    static Future<void> init() async {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
    }
  }
  ```

### 4. Modifikasi `main.dart`
- Buka `lib/main.dart`.
- Ubah fungsi `main()` agar mendukung eksekusi asynchronous:
  ```dart
  void main() async {
    // Diperlukan agar binding framework flutter siap sebelum memanggil async function
    WidgetsFlutterBinding.ensureInitialized();
    
    // Inisialisasi Supabase
    await SupabaseConfig.init();
    
    runApp(const MyApp()); // Sesuaikan dengan nama root widget
  }
  ```

## Kriteria Penerimaan (Acceptance Criteria)
- [ ] Dependensi `supabase_flutter` terdaftar di `pubspec.yaml`.
- [ ] Instalasi paket (`flutter pub get`) berhasil tanpa error.
- [ ] File `lib/core/supabase_client.dart` berisi kode inisialisasi Supabase dengan placeholder `SUPABASE_URL` dan `SUPABASE_ANON_KEY`.
- [ ] Fungsi `main()` di `lib/main.dart` telah dijadikan asynchronous, memanggil `WidgetsFlutterBinding.ensureInitialized()`, dan menjalankan inisialisasi Supabase sebelum `runApp`.
- [ ] Source code tidak memiliki error kompilasi/analisa statik (dapat dijalankan dengan lancar).
