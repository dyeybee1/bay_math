import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/failure_mapper.dart';
import '../models/school_year.dart';

/// Reads/writes `school_years` rows. Admin-only in practice —
/// `school_years_admin_write` (0015) is the only policy permitting insert/
/// update/delete; Teachers only get `school_years_select`.
class SchoolYearsRepository {
  const SchoolYearsRepository(this._client);

  final SupabaseClient _client;

  /// All school years, most recently started first.
  Future<List<SchoolYear>> fetchAll() async {
    try {
      final List<Map<String, dynamic>> data =
          await _client.from('school_years').select().order('start_date', ascending: false);
      return data.map(SchoolYear.fromJson).toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  Future<void> create({
    required String schoolId,
    required String label,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      await _client.from('school_years').insert({
        'school_id': schoolId,
        'label': label,
        'start_date': _dateOnly(startDate),
        'end_date': _dateOnly(endDate),
      });
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Makes [yearId] the current year for [schoolId]. Two sequential
  /// single-row updates — never a single bulk statement — so the
  /// `school_years_one_current_per_school` partial unique index (0003) is
  /// never violated mid-operation: the old current row is demoted before
  /// the new one is promoted, not the other way around.
  Future<void> setCurrent({required String schoolId, required String yearId}) async {
    try {
      await _client
          .from('school_years')
          .update({'is_current': false})
          .eq('school_id', schoolId)
          .eq('is_current', true);

      await _client.from('school_years').update({'is_current': true}).eq('id', yearId);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Closes a school year. A closed year is never current, so this also
  /// clears [SchoolYear.isCurrent] rather than leaving a closed-but-current
  /// row an Admin would then have to fix separately.
  Future<void> close(String yearId) async {
    try {
      await _client
          .from('school_years')
          .update({'status': 'closed', 'is_current': false})
          .eq('id', yearId);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
