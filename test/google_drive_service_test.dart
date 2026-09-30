import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:businessos/services/google_drive_service.dart';

class _Account extends Fake implements GoogleSignInAccount {}

void main() {
  GoogleDriveService service(http.Client client) => GoogleDriveService(
    client: client,
    authorize: (_) async => {'Authorization': 'Bearer test-only'},
    retryDelay: (_) async {},
  );
  test('Drive listing follows page tokens and handles 429', () async {
    var calls = 0;
    final drive = service(
      MockClient((request) async {
        calls++;
        if (calls == 1) return http.Response('', 429);
        if (request.url.queryParameters['pageToken'] == null) {
          return http.Response(
            jsonEncode({
              'nextPageToken': 'second',
              'files': [
                {
                  'id': 'one',
                  'name': 'shophisab_backup_1',
                  'createdTime': '2026-01-01T00:00:00Z',
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'files': [
              {
                'id': 'two',
                'name': 'businessos_backup_2',
                'createdTime': '2025-01-01T00:00:00Z',
              },
            ],
          }),
          200,
        );
      }),
    );
    addTearDown(drive.close);
    expect((await drive.listBackups(_Account())).map((f) => f.id), [
      'one',
      'two',
    ]);
    expect(calls, 3);
  });
  test(
    'unauthorized list fails immediately and 5xx retries are bounded',
    () async {
      var calls = 0;
      final denied = service(
        MockClient((_) async {
          calls++;
          return http.Response('', 401);
        }),
      );
      addTearDown(denied.close);
      await expectLater(denied.listBackups(_Account()), throwsStateError);
      expect(calls, 1);
      calls = 0;
      final down = service(
        MockClient((_) async {
          calls++;
          return http.Response('', 503);
        }),
      );
      addTearDown(down.close);
      await expectLater(down.listBackups(_Account()), throwsStateError);
      expect(calls, 5);
    },
  );
  test(
    'ambiguous upload probes existing session without another create',
    () async {
      var creates = 0;
      var puts = 0;
      final drive = service(
        MockClient((request) async {
          if (request.method == 'POST') {
            creates++;
            return http.Response(
              '',
              200,
              headers: {
                'location': 'https://www.googleapis.com/upload/session/test',
              },
            );
          }
          puts++;
          if (puts == 1) return http.Response('', 503);
          expect(request.headers['Content-Range'], 'bytes */3');
          return http.Response('{}', 200); // Server had already committed.
        }),
      );
      addTearDown(drive.close);
      await drive.uploadBackup(
        account: _Account(),
        fileBytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'shophisab_backup_test.bosb',
      );
      expect(creates, 1);
      expect(puts, 2);
    },
  );
}
