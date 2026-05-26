# Plan: Implement Supabase Authentication

**Branch:** `feature/#2-auth-and-rls`

Tolong implementasikan sistem Authentication lengkap menggunakan Supabase. Lakukan langkah-langkah berikut secara berurutan:

- [ ] **1. Setup Dependencies**
  - Tambahkan package `flutter_bloc` dan `shared_preferences` ke `pubspec.yaml`.
  - Jalankan `flutter pub get`.

- [ ] **2. Auth Repository**
  - Buat file `lib/data/repositories/auth_repository.dart`.
  - Isi dengan kelas `AuthRepository` yang memiliki fungsi `signIn`, `signUp`, dan `signOut`.
  - **PENTING UNTUK SIGN UP:** Fungsi `signUp` harus menerima parameter `email`, `password`, `fullName`, dan `storeName`. Saat memanggil `supabase.auth.signUp()`, masukkan `fullName` dan `storeName` ke dalam parameter `data` (sebagai metadata) agar trigger database dapat menangkapnya.

- [ ] **3. State Management (Auth Cubit)**
  - Buat file `lib/logic/auth/auth_cubit.dart` (beserta `auth_state.dart`) untuk me-manage state autentikasi.
  - Gunakan `SharedPreferences` untuk menyimpan token/status login lokal.

- [ ] **4. Auth UI Screens**
  - Buat 3 halaman UI di dalam folder `lib/presentation/auth/`:
    - `login_screen.dart`
    - `register_screen.dart`
    - `forgot_password_screen.dart`
  - **PENTING:** Pada `register_screen.dart`, tambahkan `TextField` wajib untuk **'Nama Lengkap'** dan **'Nama Toko'** selain email dan password.

- [ ] **5. Dependency Injection**
  - Daftarkan `AuthRepository` dan `AuthCubit` di `lib/main.dart` menggunakan `MultiRepositoryProvider` dan `MultiBlocProvider`.
