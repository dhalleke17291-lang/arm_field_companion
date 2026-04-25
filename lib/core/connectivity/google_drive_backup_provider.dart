import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'cloud_backup_provider.dart';

class GoogleDriveBackupProvider extends CloudBackupProvider {
  static const _scope = 'https://www.googleapis.com/auth/drive.file';
  static const _iosClientId =
      '378868358691-mc68o474i376tbkpckgldn2rtd6ohtrj.apps.googleusercontent.com';

  static final GoogleDriveBackupProvider instance =
      GoogleDriveBackupProvider._();

  GoogleDriveBackupProvider._();

  final _signIn = GoogleSignIn(
    clientId: _iosClientId,
    scopes: [_scope],
  );

  @override
  String get displayName => 'Google Drive';

  @override
  String get providerId => 'google_drive';

  @override
  Future<bool> get isAuthenticated async {
    if (_signIn.currentUser != null) return true;
    return _signIn.isSignedIn();
  }

  GoogleSignInAccount? get currentAccount => _signIn.currentUser;

  String? get connectedEmail => _signIn.currentUser?.email;

  Future<bool> signInSilently() async {
    try {
      final account = await _signIn.signInSilently();
      return account != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate() async {
    try {
      final account = await _signIn.signIn();
      return account != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> signOut() async {
    await _signIn.signOut();
  }

  static const _kTimeout = Duration(seconds: 30);

  Future<Map<String, String>> _authHeaders() async {
    var account = _signIn.currentUser;
    if (account == null) {
      try {
        account = await _signIn
            .signInSilently()
            .timeout(_kTimeout, onTimeout: () => null);
      } catch (_) {}
    }
    if (account == null) throw Exception('Not signed in to Google Drive');
    final auth = await account.authentication.timeout(
      _kTimeout,
      onTimeout: () => throw Exception('Auth token refresh timed out'),
    );
    final token = auth.accessToken;
    if (token == null) throw Exception('Failed to obtain access token');
    return {'Authorization': 'Bearer $token'};
  }

  @override
  Future<String> uploadBackup(File localFile) async {
    final headers = await _authHeaders();
    final fileName = localFile.uri.pathSegments.last;
    final bytes = await localFile.readAsBytes();
    final boundary = 'agnexis_${DateTime.now().millisecondsSinceEpoch}';
    final metadata =
        jsonEncode({'name': fileName, 'mimeType': 'application/octet-stream'});

    final body = BytesBuilder();
    void w(String s) => body.add(utf8.encode(s));
    w('--$boundary\r\n');
    w('Content-Type: application/json; charset=UTF-8\r\n\r\n');
    w('$metadata\r\n');
    w('--$boundary\r\n');
    w('Content-Type: application/octet-stream\r\n\r\n');
    body.add(bytes);
    w('\r\n--$boundary--');

    final response = await http.post(
      Uri.parse(
        'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
      ),
      headers: {
        ...headers,
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body.toBytes(),
    ).timeout(_kTimeout);

    if (response.statusCode != 200) {
      throw Exception(
          'Upload failed (${response.statusCode}): ${response.body}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['id'] as String;
  }

  @override
  Future<List<CloudBackupFile>> listBackups() async {
    final headers = await _authHeaders();
    final q = Uri.encodeComponent(
      "name contains '.agnexis' and trashed = false",
    );
    final response = await http.get(
      Uri.parse(
        'https://www.googleapis.com/drive/v3/files'
        '?q=$q'
        '&fields=files(id,name,size,modifiedTime)'
        '&orderBy=modifiedTime+desc',
      ),
      headers: headers,
    ).timeout(_kTimeout);

    if (response.statusCode != 200) {
      throw Exception('List failed (${response.statusCode}): ${response.body}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final files = (json['files'] as List).cast<Map<String, dynamic>>();
    return files
        .map(
          (f) => CloudBackupFile(
            remoteId: f['id'] as String,
            name: f['name'] as String,
            sizeBytes: int.tryParse(f['size'] as String? ?? '0') ?? 0,
            modifiedAt: DateTime.parse(f['modifiedTime'] as String),
          ),
        )
        .toList();
  }

  @override
  Future<File> downloadBackup(String remoteId, String localPath) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse(
          'https://www.googleapis.com/drive/v3/files/$remoteId?alt=media'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Download failed (${response.statusCode})');
    }
    final file = File(localPath);
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  @override
  Future<void> deleteBackup(String remoteId) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('https://www.googleapis.com/drive/v3/files/$remoteId'),
      headers: headers,
    );
    if (response.statusCode != 204) {
      throw Exception('Delete failed (${response.statusCode})');
    }
  }
}
