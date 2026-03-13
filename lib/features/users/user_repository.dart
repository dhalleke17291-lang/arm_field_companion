import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';

class UserRepository {
  final AppDatabase _db;
  UserRepository(this._db);

  Future<User> createUser({
    required String displayName,
    String? initials,
    String roleKey = 'technician',
  }) async {
    final id = await _db.into(_db.users).insert(
          UsersCompanion.insert(
            displayName: displayName.trim(),
            initials: Value(
                initials?.trim().isNotEmpty == true ? initials!.trim() : null),
            roleKey: Value(roleKey),
          ),
        );
    final user = await getUserById(id);
    if (user == null) throw UserNotFoundException(id);
    return user;
  }

  Future<User?> getUserById(int id) {
    return (_db.select(_db.users)..where((u) => u.id.equals(id)))
        .getSingleOrNull();
  }

  Stream<List<User>> watchActiveUsers() {
    return (_db.select(_db.users)
          ..where((u) => u.isActive.equals(true))
          ..orderBy([(u) => OrderingTerm.asc(u.displayName)]))
        .watch();
  }

  Future<List<User>> getActiveUsers() {
    return (_db.select(_db.users)
          ..where((u) => u.isActive.equals(true))
          ..orderBy([(u) => OrderingTerm.asc(u.displayName)]))
        .get();
  }
}

class UserNotFoundException implements Exception {
  final int id;
  UserNotFoundException(this.id);
  @override
  String toString() => 'User with id $id not found.';
}
