import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';

import 'backup_codec.dart';

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
const driveBackupScopes = <String>[
  'https://www.googleapis.com/auth/drive.appdata',
];

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

final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) {
  final service = GoogleDriveService();
  ref.onDispose(service.close);
  return service;
});

class DriveBackupFile {
  DriveBackupFile({
    required this.id,
    required this.name,
    required this.createdTime,
    this.size,
  });

  final String id;
  final String name;
  final DateTime createdTime;
  final int? size;

  factory DriveBackupFile.fromJson(Map<String, dynamic> json) {
    return DriveBackupFile(
      id: json['id'] as String,
      name: json['name'] as String,
      createdTime:
          (DateTime.tryParse(json['createdTime'] as String? ?? '') ??
                  DateTime.now())
              .toLocal(),
      size: json['size'] != null ? int.tryParse(json['size'].toString()) : null,
    );
  }
}

class GoogleDriveService {
  GoogleDriveService({
    http.Client? client,
    Future<Map<String, String>> Function(GoogleSignInAccount)? authorize,
    Future<void> Function(int)? retryDelay,
  }) : _client = client ?? http.Client(),
       _authorize = authorize,
       _retryDelay = retryDelay;
  final Future<Map<String, String>> Function(GoogleSignInAccount)? _authorize;
  final Future<void> Function(int)? _retryDelay;

  /// Shows the Google account picker / sign-in UI. Throws if the platform
  /// doesn't support it (shouldn't happen on Android).
  Future<GoogleSignInAccount> signIn(GoogleSignIn signIn) async {
    if (!signIn.supportsAuthenticate()) {
      throw Exception('Google Sign-In is not supported on this device.');
    }
    return signIn.authenticate();
  }

  Future<void> signOut(GoogleSignIn signIn) => signIn.signOut();

  /// Gets (requesting if necessary) HTTP headers authorized for the
  /// drive.appdata scope. The first time this runs for an account, it will
  /// prompt the user to grant access.
  Future<Map<String, String>> _authHeaders(GoogleSignInAccount account) async {
    if (_authorize != null) return _authorize(account);
    var headers = await account.authorizationClient.authorizationHeaders(
      driveBackupScopes,
    );
    if (headers == null) {
      await account.authorizationClient.authorizeScopes(driveBackupScopes);
      headers = await account.authorizationClient.authorizationHeaders(
        driveBackupScopes,
      );
    }
    if (headers == null) {
      throw Exception('Google Drive access was not granted.');
    }
    return headers;
  }

  final http.Client _client;
  void close() => _client.close();
  static const _timeout = Duration(seconds: 45);

  bool _retryable(http.Response response) {
    if (response.statusCode == 429 || response.statusCode >= 500) return true;
    if (response.statusCode == 403) {
      return response.body.contains('rateLimitExceeded') ||
          response.body.contains('userRateLimitExceeded');
    }
    return false;
  }

  Future<void> _backoff(int attempt) => _retryDelay != null
      ? _retryDelay(attempt)
      : Future<void>.delayed(
          Duration(
            milliseconds: (1 << attempt) * 1000 + Random().nextInt(1000),
          ),
        );

  Future<http.Response> _get(Uri uri, Map<String, String> headers) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final result = await _client
            .get(uri, headers: headers)
            .timeout(_timeout);
        if (!_retryable(result) || attempt == 4) return result;
      } on TimeoutException {
        if (attempt == 4) rethrow;
      } on http.ClientException {
        if (attempt == 4) rethrow;
      } on SocketException {
        if (attempt == 4) rethrow;
      }
      await _backoff(attempt);
    }
  }

  Never _failure(String action, int status) {
    if (status == 401)
      throw StateError(
        'Google session expired. Reconnect your account and try again.',
      );
    if (status == 403 || status == 429)
      throw StateError(
        'Drive access or quota limit. Please try later or reconnect your account.',
      );
    throw StateError(
      '$action failed (HTTP $status). Your local records are unchanged.',
    );
  }

  /// Resumable session: retry by querying the acknowledged byte offset, never
  /// blindly creating another backup after an ambiguous upload response.
  Future<void> uploadBackup({
    required GoogleSignInAccount account,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    if (fileBytes.isEmpty || fileBytes.length > BackupCodec.maxBytes) {
      throw const FormatException('Invalid backup size (maximum 64 MB).');
    }
    final headers = await _authHeaders(account);
    final start = await _client
        .post(
          Uri.parse(
            'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable',
          ),
          headers: {
            ...headers,
            'Content-Type': 'application/json; charset=UTF-8',
            'X-Upload-Content-Type': 'application/octet-stream',
            'X-Upload-Content-Length': '${fileBytes.length}',
          },
          body: jsonEncode({
            'name': fileName,
            'parents': ['appDataFolder'],
          }),
        )
        .timeout(_timeout);
    if (start.statusCode != 200) _failure('Start backup', start.statusCode);
    final location = start.headers['location'];
    if (location == null)
      throw StateError('Drive did not return an upload session.');
    final session = Uri.parse(location);
    if (session.scheme != 'https' || session.host != 'www.googleapis.com') {
      throw StateError('Unexpected Drive upload session.');
    }
    var offset = 0;
    var failures = 0;
    while (offset < fileBytes.length) {
      final end = min(offset + 1024 * 1024, fileBytes.length);
      http.Response? response;
      try {
        response = await _client
            .put(
              session,
              headers: {
                ...headers,
                'Content-Type': 'application/octet-stream',
                'Content-Range': 'bytes $offset-${end - 1}/${fileBytes.length}',
              },
              body: Uint8List.sublistView(fileBytes, offset, end),
            )
            .timeout(_timeout);
      } on TimeoutException {
        /* Probe below. */
      } on http.ClientException {
        /* Probe below. */
      } on SocketException {
        /* Probe below. */
      }
      if (response != null &&
          (response.statusCode == 200 || response.statusCode == 201))
        return;
      if (response != null && response.statusCode == 308) {
        final last = int.tryParse(
          response.headers['range']?.split('-').last ?? '',
        );
        final next = last == null ? 0 : last + 1;
        if (next > offset && next <= fileBytes.length) {
          offset = next;
          failures = 0;
          continue;
        }
      } else if (response != null && !_retryable(response)) {
        _failure('Upload backup', response.statusCode);
      }
      if (failures >= 4)
        throw StateError(
          'Backup upload interrupted. Try again when your connection is stable.',
        );
      await _backoff(failures++);
      final probe = await _client
          .put(
            session,
            headers: {
              ...headers,
              'Content-Range': 'bytes */${fileBytes.length}',
              'Content-Length': '0',
            },
          )
          .timeout(_timeout);
      if (probe.statusCode == 200 || probe.statusCode == 201) return;
      if (probe.statusCode != 308) _failure('Resume backup', probe.statusCode);
      offset =
          (int.tryParse(probe.headers['range']?.split('-').last ?? '') ?? -1) +
          1;
      if (offset < 0 || offset >= fileBytes.length)
        throw StateError('Unexpected upload progress. Please try again.');
    }
    throw StateError('Drive did not confirm this backup.');
  }

  Future<List<DriveBackupFile>> listBackups(GoogleSignInAccount account) async {
    final headers = await _authHeaders(account);
    final files = <DriveBackupFile>[];
    String? token;
    do {
      final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
        'q': "'appDataFolder' in parents and (name contains 'shophisab_backup' or name contains 'businessos_backup') and trashed = false",
        'fields': 'nextPageToken,files(id,name,createdTime,size)',
        'orderBy': 'createdTime desc',
        'spaces': 'appDataFolder',
        'pageSize': '100',
        if (token != null) 'pageToken': token,
      });
      final response = await _get(uri, headers);
      if (response.statusCode != 200)
        _failure('List backups', response.statusCode);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      files.addAll(
        (data['files'] as List<dynamic>? ?? []).map(
          (f) => DriveBackupFile.fromJson(f as Map<String, dynamic>),
        ),
      );
      token = data['nextPageToken'] as String?;
    } while (token != null && token.isNotEmpty);
    return files;
  }

  Future<Uint8List> downloadBackup({
    required GoogleSignInAccount account,
    required String fileId,
  }) async {
    final headers = await _authHeaders(account);
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files/$fileId', {
      'alt': 'media',
    });
    // Stream and enforce the cap before buffering the entire response.
    for (var attempt = 0; ; attempt++) {
      try {
        final request = http.Request('GET', uri)..headers.addAll(headers);
        final response = await _client.send(request).timeout(_timeout);
        if (response.statusCode != 200) {
          final status = response.statusCode;
          await response.stream.drain<void>().timeout(_timeout);
          if ((status == 429 || status >= 500) && attempt < 4) {
            await _backoff(attempt);
            continue;
          }
          _failure('Download backup', status);
        }
        if ((response.contentLength ?? 0) > BackupCodec.maxBytes) {
          await response.stream.listen(null).cancel();
          throw const FormatException(
            'Backup exceeds the supported 64 MB limit.',
          );
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream.timeout(_timeout)) {
          if (bytes.length + chunk.length > BackupCodec.maxBytes) {
            throw const FormatException(
              'Backup exceeds the supported 64 MB limit.',
            );
          }
          bytes.add(chunk);
        }
        return bytes.takeBytes();
      } on TimeoutException {
        if (attempt >= 4) rethrow;
      } on http.ClientException {
        if (attempt >= 4) rethrow;
      } on SocketException {
        if (attempt >= 4) rethrow;
      }
      await _backoff(attempt);
    }
  }
}
