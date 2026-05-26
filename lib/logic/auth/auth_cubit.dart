import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../data/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final SharedPreferences _prefs;
  StreamSubscription<supabase.AuthState>? _authSubscription;

  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserId = 'user_id';
  static const String _keyEmail = 'user_email';

  AuthCubit({
    required AuthRepository authRepository,
    required SharedPreferences sharedPreferences,
  })  : _authRepository = authRepository,
        _prefs = sharedPreferences,
        super(const AuthState()) {
    _init();
  }

  void _init() {
    // Check local persisted login status first
    final isLoggedIn = _prefs.getBool(_keyIsLoggedIn) ?? false;
    final userId = _prefs.getString(_keyUserId);
    final email = _prefs.getString(_keyEmail);

    if (isLoggedIn && _authRepository.currentSession != null) {
      emit(AuthState(
        status: AuthStatus.authenticated,
        userId: userId,
        email: email,
      ));
    } else {
      emit(const AuthState(status: AuthStatus.unauthenticated));
      _clearLocalSession();
    }

    // Listen to auth state changes from Supabase
    _authSubscription = _authRepository.onAuthStateChange.listen((authState) {
      final session = authState.session;
      if (session != null) {
        _saveLocalSession(session.user.id, session.user.email ?? '');
        emit(AuthState(
          status: AuthStatus.authenticated,
          userId: session.user.id,
          email: session.user.email,
        ));
      } else {
        _clearLocalSession();
        emit(const AuthState(status: AuthStatus.unauthenticated));
      }
    });
  }

  /// Sign in with email and password.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final response = await _authRepository.signIn(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user != null) {
        await _saveLocalSession(user.id, user.email ?? '');
        emit(AuthState(
          status: AuthStatus.authenticated,
          userId: user.id,
          email: user.email,
        ));
      } else {
        emit(state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Login gagal. Silakan coba lagi.',
        ));
      }
    } on supabase.AuthException catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Terjadi kesalahan: ${e.toString()}',
      ));
    }
  }

  /// Sign up with email, password, fullName, and storeName.
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String storeName,
  }) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final response = await _authRepository.signUp(
        email: email,
        password: password,
        fullName: fullName,
        storeName: storeName,
      );
      final user = response.user;
      if (user != null) {
        await _saveLocalSession(user.id, user.email ?? '');
        emit(AuthState(
          status: AuthStatus.authenticated,
          userId: user.id,
          email: user.email,
        ));
      } else {
        emit(state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Registrasi gagal. Silakan coba lagi.',
        ));
      }
    } on supabase.AuthException catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Terjadi kesalahan: ${e.toString()}',
      ));
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      await _authRepository.signOut();
      await _clearLocalSession();
      emit(const AuthState(status: AuthStatus.unauthenticated));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Gagal logout: ${e.toString()}',
      ));
    }
  }

  /// Send password reset email.
  Future<void> resetPassword({required String email}) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      await _authRepository.resetPassword(email: email);
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    } on supabase.AuthException catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Terjadi kesalahan: ${e.toString()}',
      ));
    }
  }

  Future<void> _saveLocalSession(String userId, String email) async {
    await _prefs.setBool(_keyIsLoggedIn, true);
    await _prefs.setString(_keyUserId, userId);
    await _prefs.setString(_keyEmail, email);
  }

  Future<void> _clearLocalSession() async {
    await _prefs.remove(_keyIsLoggedIn);
    await _prefs.remove(_keyUserId);
    await _prefs.remove(_keyEmail);
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
