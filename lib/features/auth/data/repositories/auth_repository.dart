import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/app_user.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepository {
  AuthRepository({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
  })  : _remote = remoteDataSource,
        _local = localDataSource;

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;

  Stream<AuthState> get authStateChanges => _remote.authStateChanges;
  bool get isAuthenticated => _remote.currentAuthUser != null;

  Future<Result<AppUser>> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final result = await _remote.signUp(
      email: email,
      password: password,
      fullName: fullName,
    );
    if (result.isSuccess) {
      await _local.cacheUser(result.value);
    }
    return result;
  }

  Future<Result<AppUser>> signIn({
    required String email,
    required String password,
  }) async {
    final result = await _remote.signIn(email: email, password: password);
    if (result.isSuccess) {
      await _local.cacheUser(result.value);
    }
    return result;
  }

  Future<void> signOut() async {
    await _remote.signOut();
    await _local.clearCache();
  }

  Future<Result<AppUser>> getCurrentUser() async {
    final cached = _local.getCachedUser();
    if (cached != null && _remote.currentAuthUser != null) {
      // Refresh in background but return cached immediately
      _remote.getCurrentUser().then((result) {
        if (result.isSuccess) _local.cacheUser(result.value);
      });
      return Success(cached);
    }

    final result = await _remote.getCurrentUser();
    if (result.isSuccess) {
      await _local.cacheUser(result.value);
    }
    return result;
  }

  AppUser? getCachedUser() => _local.getCachedUser();
}
