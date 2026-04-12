import 'package:shared_preferences/shared_preferences.dart';

/// Key for persisting the current user id (identity only; no auth).
const String kCurrentUserIdKey = 'current_user_id';

Future<int?> getCurrentUserId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(kCurrentUserIdKey);
}

Future<void> setCurrentUserId(int userId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(kCurrentUserIdKey, userId);
}
