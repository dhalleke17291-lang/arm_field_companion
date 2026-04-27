import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:msal_auth/msal_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_backup_provider.dart';

class OneDriveBackupProvider extends CloudBackupProvider {
  static const _clientId = '4897f7fb-2010-4759-b585-9f95e1814ca4';
  static const _scopes = [
    'Files.ReadWrite.AppFolder',
  ];
  static const _authority =
      'https://login.microsoftonline.com/common';
  // MSAL Android redirect URI: msauth://<package>/<base64-signature-hash>
  // Hash is the URL-encoded base64 of the SHA-1 of the signing keystore.
  // Debug keystore hash for com.parminder.agnexis below; release keystore
  // would need its own hash registered in Azure as a second platform entry.
  static const _androidRedirectUri =
      'msauth://com.parminder.agnexis/Ivq1rIbgRxI8665rljj1XMmR2Hg%3D';
  static const _kTimeout = Duration(seconds: 30);
  static const _kPrefsKey = 'onedrive_account_id';
  static const _kEmailKey = 'onedrive_account_email';

  static final OneDriveBackupProvider instance =
      OneDriveBackupProvider._();

  OneDriveBackupProvider._();

  SingleAccountPca? _pca;
  String? _accessToken;
  DateTime? _tokenExpiry;
  String? _connectedEmail;
  String? _lastAuthError;

  @override
  String get displayName => 'OneDrive';

  @override
  String get providerId => 'onedrive';

  String? get connectedEmail => _connectedEmail;
  String? get lastAuthError => _lastAuthError;

  @override
  Future<bool> get isAuthenticated async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kPrefsKey);
  }

  Future<SingleAccountPca> _ensurePca() async {
    if (_pca != null) return _pca!;
    _pca = await SingleAccountPca.create(
      clientId: _clientId,
      androidConfig: AndroidConfig(
        configFilePath: 'assets/msal_config.json',
        redirectUri: _androidRedirectUri,
      ),
      appleConfig: AppleConfig(
        authority: _authority,
        authorityType: AuthorityType.aad,
        broker: Broker.webView,
      ),
    );
    return _pca!;
  }

  @override
  Future<bool> authenticate() async {
    _lastAuthError = null;
    try {
      final pca = await _ensurePca();
      final result = await pca.acquireToken(
        scopes: _scopes,
        prompt: Prompt.selectAccount,
      );
      _accessToken = result.accessToken;
      _tokenExpiry = result.expiresOn;
      _connectedEmail = result.account.username;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsKey, result.account.id);
      if (_connectedEmail != null) {
        await prefs.setString(_kEmailKey, _connectedEmail!);
      }
      return true;
    } catch (e) {
      _lastAuthError = e.toString();
      if (kDebugMode) {
        debugPrint('OneDrive auth failed: $e');
      }
      return false;
    }
  }

  @override
  Future<void> signOut() async {
    _accessToken = null;
    _tokenExpiry = null;
    _connectedEmail = null;
    try {
      final pca = await _ensurePca();
      await pca.signOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefsKey);
    await prefs.remove(_kEmailKey);
  }

  Future<String> _getAccessToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now()
            .isBefore(_tokenExpiry!.subtract(const Duration(minutes: 2)))) {
      return _accessToken!;
    }
    final pca = await _ensurePca();
    try {
      final result = await pca.acquireTokenSilent(scopes: _scopes);
      _accessToken = result.accessToken;
      _tokenExpiry = result.expiresOn;
      _connectedEmail = result.account.username;
      return _accessToken!;
    } catch (_) {
      final result = await pca.acquireToken(scopes: _scopes);
      _accessToken = result.accessToken;
      _tokenExpiry = result.expiresOn;
      _connectedEmail = result.account.username;
      return _accessToken!;
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getAccessToken();
    return {'Authorization': 'Bearer $token'};
  }

  Future<void> hydrateConnectedEmail() async {
    if (_connectedEmail != null) return;
    final prefs = await SharedPreferences.getInstance();
    _connectedEmail = prefs.getString(_kEmailKey);
  }

  Future<void> _ensureAppFolder(Map<String, String> headers) async {
    final response = await http.get(
      Uri.parse('https://graph.microsoft.com/v1.0/me/drive/special/approot'),
      headers: headers,
    ).timeout(_kTimeout);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'Could not access OneDrive app folder (${response.statusCode}): '
          '${response.body}');
    }
  }

  @override
  Future<String> uploadBackup(File localFile) async {
    final headers = await _authHeaders();
    await _ensureAppFolder(headers);
    final fileName = localFile.uri.pathSegments.last;
    final bytes = await localFile.readAsBytes();

    final response = await http.put(
      Uri.parse(
        'https://graph.microsoft.com/v1.0/me/drive/special/approot:/$fileName:/content',
      ),
      headers: {
        ...headers,
        'Content-Type': 'application/octet-stream',
      },
      body: bytes,
    ).timeout(_kTimeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'Upload failed (${response.statusCode}): ${response.body}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['id'] as String;
  }

  @override
  Future<List<CloudBackupFile>> listBackups() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse(
        'https://graph.microsoft.com/v1.0/me/drive/special/approot/children'
        '?\$select=id,name,size,lastModifiedDateTime'
        '&\$orderby=lastModifiedDateTime+desc',
      ),
      headers: headers,
    ).timeout(_kTimeout);

    if (response.statusCode != 200) {
      throw Exception('List failed (${response.statusCode}): ${response.body}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (json['value'] as List).cast<Map<String, dynamic>>();
    return items
        .where((f) => (f['name'] as String).endsWith('.agnexis'))
        .map(
          (f) => CloudBackupFile(
            remoteId: f['id'] as String,
            name: f['name'] as String,
            sizeBytes: (f['size'] as int?) ?? 0,
            modifiedAt: DateTime.parse(
                f['lastModifiedDateTime'] as String),
          ),
        )
        .toList();
  }

  @override
  Future<File> downloadBackup(String remoteId, String localPath) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse(
        'https://graph.microsoft.com/v1.0/me/drive/items/$remoteId/content',
      ),
      headers: headers,
    ).timeout(_kTimeout);

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
      Uri.parse(
        'https://graph.microsoft.com/v1.0/me/drive/items/$remoteId',
      ),
      headers: headers,
    ).timeout(_kTimeout);
    if (response.statusCode != 204) {
      throw Exception('Delete failed (${response.statusCode})');
    }
  }
}
