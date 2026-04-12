import 'dart:convert';
import 'dart:typed_data';

import 'package:arm_field_companion/features/backup/backup_encryption.dart';
import 'package:arm_field_companion/features/backup/backup_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackupEncryption', () {
    test('encrypt then decrypt round-trip', () {
      const password = 'secret12';
      final plain = Uint8List.fromList(utf8.encode('hello zip payload'));
      final file = BackupEncryption.encrypt(plain, password);
      final out = BackupEncryption.decrypt(file, password);
      expect(out, plain);
    });

    test('wrong password throws BackupException', () {
      final file =
          BackupEncryption.encrypt(Uint8List.fromList([1, 2, 3]), 'goodpass12');
      expect(
        () => BackupEncryption.decrypt(file, 'wrongpw12'),
        throwsA(isA<BackupException>()),
      );
    });

    test('different salts produce different ciphertext for same input', () {
      const password = 'samepass12';
      final plain = Uint8List.fromList([0, 1, 2, 3]);
      final a = BackupEncryption.encrypt(plain, password);
      final b = BackupEncryption.encrypt(plain, password);
      expect(a, isNot(equals(b)));
    });

    test('empty plaintext round-trip', () {
      const password = 'secret12';
      final plain = Uint8List(0);
      final enc = BackupEncryption.encrypt(plain, password);
      expect(BackupEncryption.decrypt(enc, password), plain);
    });

    test('isValidAgnexisFile false for random bytes', () {
      expect(BackupEncryption.isValidAgnexisFile(Uint8List(100)), isFalse);
    });

    test('isValidAgnexisFile true for valid header prefix', () {
      const password = 'secret12';
      final full = BackupEncryption.encrypt(Uint8List.fromList([0]), password);
      expect(BackupEncryption.isValidAgnexisFile(full), isTrue);
    });

    test('header layout: magic 8 + version 1 + salt 32 + iv 12', () {
      const password = 'secret12';
      final full =
          BackupEncryption.encrypt(Uint8List.fromList([9, 9]), password);
      expect(full.length, greaterThan(BackupEncryption.headerLength + 16));
      expect(full.sublist(0, 8), BackupEncryption.magicBytes);
      expect(full[8], BackupEncryption.formatVersion);
      expect(full.sublist(9, 41).length, BackupEncryption.saltLength);
      expect(full.sublist(41, 53).length, BackupEncryption.ivLength);
    });
  });
}
