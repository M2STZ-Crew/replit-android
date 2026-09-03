import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
// Supabase's gotrue exports its own AuthException, which is what the auth calls
// below throw. Ours is prefixed so `on AuthException` still catches Supabase's
// while `app.AuthException` constructs the domain error we hand back.
import '../../../../core/errors/app_exception.dart' as app;
import '../../../../core/errors/result.dart';
import '../../domain/entities/app_user.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._supabase);

  final SupabaseClient _supabase;

  User? get currentAuthUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<Result<AppUser>> signUp({
    required String email,
    required String password,
    required String fullName,
    String role = UserRole.generalUser,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'role': role},
      );

      if (response.user == null) {
        return const Failure(app.AuthException('Sign up failed. Please try again.'));
      }

      final profile = await _fetchUserProfile(response.user!.id);
      return Success(profile);
    } on AuthException catch (e) {
      return Failure(app.AuthException(_sanitizeAuthError(e.message)));
    } catch (e) {
      return Failure(app.AuthException('An unexpected error occurred.', e));
    }
  }

  Future<Result<AppUser>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        return const Failure(app.AuthException('Invalid credentials.'));
      }

      final profile = await _fetchUserProfile(response.user!.id);
      return Success(profile);
    } on AuthException catch (e) {
      return Failure(app.AuthException(_sanitizeAuthError(e.message)));
    } catch (e) {
      return Failure(app.AuthException('An unexpected error occurred.', e));
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<Result<AppUser>> getCurrentUser() async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        return const Failure(app.AuthException('Not authenticated.'));
      }
      final profile = await _fetchUserProfile(authUser.id);
      return Success(profile);
    } catch (e) {
      return Failure(app.AuthException('Failed to fetch user profile.', e));
    }
  }

  Future<AppUser> _fetchUserProfile(String userId) async {
    final response = await _supabase
        .from(SupabaseTables.users)
        .select()
        .eq('id', userId)
        .single();
    return AppUser.fromMap(response);
  }

  String _sanitizeAuthError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Invalid email or password.';
    }
    if (message.contains('Email not confirmed')) {
      return 'Please verify your email address.';
    }
    if (message.contains('User already registered')) {
      return 'An account with this email already exists.';
    }
    return 'Authentication failed. Please try again.';
  }
}
