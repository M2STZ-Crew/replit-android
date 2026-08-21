import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_constants.dart';

class HiveService {
  static Future<void> init() async {
    await Hive.initFlutter();
    await _openBoxes();
  }

  static Future<void> _openBoxes() async {
    await Future.wait([
      Hive.openBox<Map>(HiveBoxes.incidents),
      Hive.openBox<Map>(HiveBoxes.userSession),
      Hive.openBox<Map>(HiveBoxes.weather),
      Hive.openBox<Map>(HiveBoxes.settings),
    ]);
  }

  static Box<Map> getBox(String name) => Hive.box<Map>(name);

  static Future<void> clearAll() async {
    try {
      await Future.wait([
        Hive.box<Map>(HiveBoxes.incidents).clear(),
        Hive.box<Map>(HiveBoxes.userSession).clear(),
        Hive.box<Map>(HiveBoxes.weather).clear(),
        Hive.box<Map>(HiveBoxes.settings).clear(),
      ]);
    } catch (e) {
      debugPrint('Error clearing Hive boxes: $e');
    }
  }
}
