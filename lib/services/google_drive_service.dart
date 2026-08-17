import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../core/google_config.dart';

/// Deliberately the narrowest possible Drive scope: the app can only see
/// and manage files it creates itself, never anything else in the user's
/// Drive. This also matters practically - broader scopes require Google's
/// full app-verification review process (weeks, needs a hosted privacy
/// policy, a review video, etc.), which nobody can complete on your behalf.
/// drive.appdata is the app-specific, non-sensitive Drive scope.
const driveBackupScopes = <String>['https://www.googleapis.com/auth/drive.appdata'];

/// Initializes GoogleSignIn.instance exactly once (the plugin requires
/// this and errors if you call initialize() more than once) - wrapping it
/// in a FutureProvider gives us that for free via Riverpod's memoization.
final googleSignInProvider = FutureProvider<GoogleSignIn>((ref) async {
  if (!isGoogleServerClientIdConfigured) {
    throw Exception(
      'Google Drive is not set up yet. Create a "Web application" OAuth '
      'client ID in Google Cloud Console and paste it into '
      'lib/core/google_config.dart (see the comment there for exact steps).',
    );
  }
  final signIn = GoogleSignIn.instance;
  await signIn.initialize(serverClientId: googleServerClientId);
  return signIn;
});

final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) => GoogleDriveService());

class DriveBackupFile {
  DriveBackupFile({required this.id, required this.name, required this.createdTime, this.size});

  final String id;
  final String name;
  final DateTime createdTime;
  final int? size;

  factory DriveBackupFile.fromJson(Map<String, dynamic> json) {
    return DriveBackupFile(
      id: json['id'] as String,
      name: json['name'] as String,
      createdTime: DateTime.tryParse(json['createdTime'] as String? ?? '') ?? DateTime.now(),
      size: json['size'] != null ? int.tryParse(json['size'].toString()) : null,
    );
  }
}

class GoogleDriveService {
  /// Shows the Google account picker / sign-in UI. Throws if the platform
  /// doesn't support it (shouldn't happen on Android).
  Future<GoogleSignInAccount> signIn(GoogleSignIn signIn) async {
    if (!signIn.supportsAuthenticate()) {
      throw Exception('Google Sign-In is not supported on this device.');
    }
    return signIn.authenticate();
  }

  Future<void> signOut(GoogleSignIn signIn) => signIn.disconnect();

  /// Gets (requesting if necessary) HTTP headers authorized for the
  /// drive.appdata scope. The first time this runs for an account, it will
  /// prompt the user to grant access.
  Future<Map<String, String>> _authHeaders(GoogleSignInAccount account) async {
    var headers = await account.authorizationClient.authorizationHeaders(driveBackupScopes);
    if (headers == null) {
      await account.authorizationClient.authorizeScopes(driveBackupScopes);
      headers = await account.authorizationClient.authorizationHeaders(driveBackupScopes);
    }
    if (headers == null) {
      throw Exception('Google Drive access was not granted.');
    }
    return headers;
  }

  Future<void> uploadBackup({
    required GoogleSignInAccount account,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final headers = await _authHeaders(account);
    final boundary = 'shophisab-${DateTime.now().microsecondsSinceEpoch}';
    final metadata = jsonEncode({
      'name': fileName,
      'parents': ['appDataFolder'],
    });

    final body = BytesBuilder()
      ..add(utf8.encode('--$boundary\r\n'))
      ..add(utf8.encode('Content-Type: application/json; charset=UTF-8\r\n\r\n'))
      ..add(utf8.encode(metadata))
      ..add(utf8.encode('\r\n--$boundary\r\n'))
      ..add(utf8.encode('Content-Type: application/octet-stream\r\n\r\n'))
      ..add(fileBytes)
      ..add(utf8.encode('\r\n--$boundary--'));

    final response = await http.post(
      Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart'),
      headers: {...headers, 'Content-Type': 'multipart/related; boundary=$boundary'},
      body: body.takeBytes(),
    );

    if (response.statusCode != 200) {
      throw Exception('Drive upload failed (${response.statusCode}): ${response.body}');
    }
  }

  Future<List<DriveBackupFile>> listBackups(GoogleSignInAccount account) async {
    final headers = await _authHeaders(account);
    final query =
        "'appDataFolder' in parents and name contains 'shophisab_backup' and trashed = false";
    final uri = Uri.parse('https://www.googleapis.com/drive/v3/files').replace(
      queryParameters: {
        'q': query,
        'fields': 'files(id,name,createdTime,size)',
        'orderBy': 'createdTime desc',
        'spaces': 'appDataFolder',
      },
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Could not list Drive backups (${response.statusCode}): ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final files = data['files'] as List<dynamic>? ?? [];
    return files.map((f) => DriveBackupFile.fromJson(f as Map<String, dynamic>)).toList();
  }

  Future<Uint8List> downloadBackup({
    required GoogleSignInAccount account,
    required String fileId,
  }) async {
    final headers = await _authHeaders(account);
    final response = await http.get(
      Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?alt=media'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Drive download failed (${response.statusCode}): ${response.body}');
    }
    return response.bodyBytes;
  }
}
