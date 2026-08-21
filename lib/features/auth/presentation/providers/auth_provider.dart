import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState, AuthChangeEvent;
import '../../../../core/errors/app_exception.dart';
import '../../data/datasources/auth_local_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/entities/app_user.dart';

// Repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = Supabase.instance.client;
  return AuthRepository(
    remoteDataSource: AuthRemoteDataSource(supabase),
    localDataSource: AuthLocalDataSource(),
  );
});

// Auth state
enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState2 {
  const AuthState2({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  final AuthStatus status;
  final AppUser? user;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isLoading => status == AuthStatus.loading;

  AuthState2 copyWith({
    AuthStatus? status,
    AppUser? user,
    String? errorMessage,
  }) {
    return AuthState2(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

// Auth notifier
class AuthNotifier extends StateNotifier<AuthState2> {
  AuthNotifier(this._repository) : super(const AuthState2()) {
    _init();
  }

  final AuthRepository _repository;
  StreamSubscription<AuthState>? _authSub;

  void _init() {
    _authSub = _repository.authStateChanges.listen((event) {
      if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.tokenRefreshed) {
        _loadCurrentUser();
      } else if (event.event == AuthChangeEvent.signedOut) {
        state = const AuthState2(status: AuthStatus.unauthenticated);
      }
    });
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    if (!_repository.isAuthenticated) {
      state = const AuthState2(status: AuthStatus.unauthenticated);
      return;
    }

    state = state.copyWith(status: AuthStatus.loading);
    final result = await _repository.getCurrentUser();
    result.when(
      success: (user) {
        state = AuthState2(status: AuthStatus.authenticated, user: user);
      },
      failure: (e) {
        state = const AuthState2(status: AuthStatus.unauthenticated);
      },
    );
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    final result = await _repository.signUp(
      email: email,
      password: password,
      fullName: fullName,
    );
    result.when(
      success: (user) {
        state = AuthState2(status: AuthStatus.authenticated, user: user);
      },
      failure: (e) {
        state = AuthState2(
          status: AuthStatus.unauthenticated,
          errorMessage: e.message,
        );
      },
    );
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    final result = await _repository.signIn(email: email, password: password);
    result.when(
      success: (user) {
        state = AuthState2(status: AuthStatus.authenticated, user: user);
      },
      failure: (e) {
        state = AuthState2(
          status: AuthStatus.unauthenticated,
          errorMessage: e.message,
        );
      },
    );
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AuthState2(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState2>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

// Convenience providers
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authProvider).user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});
