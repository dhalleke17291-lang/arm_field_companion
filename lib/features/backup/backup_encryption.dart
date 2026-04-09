import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'backup_models.dart';

/// AES-256-GCM + PBKDF2 for `.agnexis` payload.
///
/// V1: [encrypt] / [decrypt] load the full ZIP in memory (see class doc on [BackupMeta]).
class BackupEncryption {
  BackupEncryption._();

  static const int saltLength = 32;
  static const int ivLength = 12;
  static const int pbkdf2Iterations = 100000;
  static const int keyLengthBytes = 32;
  static const int gcmTagLengthBits = 128;
  static const int headerLength =
      8 + 1 + saltLength + ivLength; // magic + version + salt + iv

  /// ASCII "AGNEXIS" + NUL.
  static final Uint8List magicBytes =
      Uint8List.fromList(utf8.encode('AGNEXIS\u0000'));

  static const int formatVersion = 0x01;

  static Uint8List _randomBytes(int length) {
    final r = FortunaRandom();
    final seed = Uint8List(32);
    final sr = Random.secure();
    for (var i = 0; i < 32; i++) {
      seed[i] = sr.nextInt(256);
    }
    r.seed(KeyParameter(seed));
    return r.nextBytes(length);
  }

  static Uint8List _deriveKey(Uint8List salt, String password) {
    final d = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, pbkdf2Iterations, keyLengthBytes));
    return d.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Encrypts ZIP bytes. Returns full `.agnexis` file bytes (header + ciphertext + tag).
  static Uint8List encrypt(Uint8List zipBytes, String password) {
    final salt = _randomBytes(saltLength);
    final iv = _randomBytes(ivLength);
    final key = _deriveKey(salt, password);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          gcmTagLengthBits,
          iv,
          Uint8List(0),
        ),
      );
    final encrypted = cipher.process(zipBytes);
    final out = BytesBuilder(copy: false);
    out.add(magicBytes);
    out.addByte(formatVersion);
    out.add(salt);
    out.add(iv);
    out.add(encrypted);
    return out.toBytes();
  }

  /// Decrypts `.agnexis` file bytes to ZIP bytes.
  static Uint8List decrypt(Uint8List agnexisBytes, String password) {
    if (agnexisBytes.length < headerLength + 16) {
      throw BackupException('Backup file is too small or corrupted');
    }
    if (!isValidAgnexisHeader(
        Uint8List.sublistView(agnexisBytes, 0, headerLength))) {
      throw BackupException('Not a valid Agnexis backup file');
    }
    final salt = agnexisBytes.sublist(9, 9 + saltLength);
    final iv = agnexisBytes.sublist(9 + saltLength, headerLength);
    final cipherBytes =
        agnexisBytes.sublist(headerLength, agnexisBytes.length);
    final key = _deriveKey(salt, password);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(key),
          gcmTagLengthBits,
          iv,
          Uint8List(0),
        ),
      );
    try {
      return cipher.process(cipherBytes);
    } on InvalidCipherTextException {
      throw BackupException('Wrong password or corrupted backup file');
    }
  }

  /// True if [headerBytes] is at least [headerLength] and magic + version match.
  static bool isValidAgnexisHeader(Uint8List headerBytes) {
    if (headerBytes.length < headerLength) return false;
    for (var i = 0; i < magicBytes.length; i++) {
      if (headerBytes[i] != magicBytes[i]) return false;
    }
    return headerBytes[8] == formatVersion;
  }

  static bool isValidAgnexisFile(Uint8List bytes) {
    if (bytes.length < headerLength) return false;
    return isValidAgnexisHeader(
        Uint8List.sublistView(bytes, 0, headerLength));
  }
}
