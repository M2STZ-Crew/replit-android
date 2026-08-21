import 'package:hive/hive.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/hive_service.dart';
import '../../domain/entities/app_user.dart';

class AuthLocalDataSource {
  Box<Map> get _box => HiveService.getBox(HiveBoxes.userSession);

  static const _userKey = 'current_user';

  Future<void> cacheUser(AppUser user) async {
    await _box.put(_userKey, user.toMap());
  }

  AppUser? getCachedUser() {
    final data = _box.get(_userKey);
    if (data == null) return null;
    return AppUser.fromMap(Map<String, dynamic>.from(data));
  }

  Future<void> clearCache() async {
    await _box.clear();
  }
}
