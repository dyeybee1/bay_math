import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/failure_mapper.dart';
import '../models/school.dart';

/// Reads `schools` rows. Phase 2 scope: Admin-only Read (schema §3.1 —
/// `schools_select` grants read to Admin and any approved Teacher;
/// `schools_admin_write` reserves writes to Admin). No write surface is
/// exposed yet — the app assumes a single, pre-seeded school row and has
/// no "create a school" UI in this phase.
class SchoolsRepository {
  const SchoolsRepository(this._client);

  final SupabaseClient _client;

  /// Returns the first (oldest) school row, or null if none exists yet.
  /// Deliberately named `fetchFirst`, not `fetchDefault`/`fetchCurrent` —
  /// there is no "the" school concept in the schema itself (schema §3.1),
  /// only "whichever row happens to exist" until multi-school support
  /// is added.
  Future<School?> fetchFirst() async {
    try {
      final Map<String, dynamic>? data = await _client
          .from('schools')
          .select()
          .order('created_at')
          .limit(1)
          .maybeSingle();

      if (data == null) return null;
      return School.fromJson(data);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }
}
