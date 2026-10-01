import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:instructional_math_app/core/models/profile.dart';
import 'package:instructional_math_app/core/repositories/profiles_repository.dart';

void main() {
  test(
    'processed Teachers use the valid self-FK hint and server-side filters',
    () async {
      late http.Request capturedRequest;
      final MockClient httpClient = MockClient((http.Request request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode(<Map<String, Object?>>[
            _profileJson(
              id: 'approved',
              status: 'approved',
              approvedBy: 'admin',
              approvedAt: '2026-09-15T01:00:00Z',
              updatedAt: '2026-09-17T01:00:00Z',
              approvedByProfile: <String, Object?>{
                'full_name': 'BayMath Admin',
              },
            ),
            _profileJson(id: 'rejected', status: 'rejected'),
            _profileJson(
              id: 'approved-missing-approver',
              status: 'approved',
              approvedAt: '2026-09-14T01:00:00Z',
            ),
            // Defensive repository filtering protects the UI contract even
            // if a stale proxy/cache unexpectedly returns extra statuses.
            _profileJson(id: 'pending', status: 'pending'),
            _profileJson(id: 'archived', status: 'archived'),
          ]),
          200,
          headers: <String, String>{'content-type': 'application/json'},
          request: request,
        );
      });
      final SupabaseClient client = SupabaseClient(
        'http://localhost',
        'test-anon-key',
        httpClient: httpClient,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);

      final List<Profile> result =
          await ProfilesRepository(client).fetchProcessedTeachers();

      expect(
        capturedRequest.url.queryParameters['select'],
        '*,approved_by_profile:approved_by(full_name)',
      );
      expect(capturedRequest.url.queryParameters['role'], 'eq.teacher');
      expect(
        capturedRequest.url.queryParameters['status'],
        'in.("approved","rejected")',
      );
      expect(
        capturedRequest.url.queryParameters['order'],
        'updated_at.desc.nullslast',
      );
      expect(result.map((Profile profile) => profile.id), <String>[
        'rejected',
        'approved',
        'approved-missing-approver',
      ]);
      expect(
        result
            .singleWhere((Profile profile) => profile.id == 'approved')
            .approvedByName,
        'BayMath Admin',
      );
      expect(
        result
            .singleWhere((Profile profile) => profile.id == 'rejected')
            .approvedAt,
        isNull,
      );
      expect(
        result
            .singleWhere(
              (Profile profile) => profile.id == 'approved-missing-approver',
            )
            .approvedByName,
        isNull,
      );
    },
  );

  test('nullable approval metadata cannot break profile parsing', () {
    final Map<String, Object?> json = _profileJson(
      id: 'rejected',
      status: 'rejected',
      approvedAt: 'not-a-timestamp',
      approvedByProfile: const <Object?>[],
    );
    json['approved_by'] = 42;

    final Profile profile = Profile.fromJson(json);

    expect(profile.approvedBy, isNull);
    expect(profile.approvedByName, isNull);
    expect(profile.approvedAt, isNull);
  });
}

Map<String, Object?> _profileJson({
  required String id,
  required String status,
  Object? approvedBy,
  Object? approvedAt,
  Object? approvedByProfile,
  String updatedAt = '2026-09-16T01:00:00Z',
}) {
  return <String, Object?>{
    'id': id,
    'role': 'teacher',
    'status': status,
    'full_name': '$status Teacher',
    'email': '$id@baymath.test',
    'approved_by': approvedBy,
    'approved_at': approvedAt,
    'approved_by_profile': approvedByProfile,
    'created_at': '2026-09-01T01:00:00Z',
    'updated_at': updatedAt,
  };
}
