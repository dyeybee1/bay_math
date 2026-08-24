// Riverpod 3.x moved StateProvider out of the main barrel file — it still
// works the same, just needs this separate import now (see sections_screen.dart
// for the same note).
import 'package:flutter_riverpod/legacy.dart';

import '../models/student_session.dart';

/// The signed-in student, if any. Deliberately a bare [StateProvider], not
/// an [AsyncNotifier] like [sessionProvider] — there is no restoration
/// logic to speak of yet (in-memory only, per the "keep this part minimal"
/// scope for this phase). Null means no student is currently signed in.
final StateProvider<StudentSession?> studentSessionProvider =
    StateProvider<StudentSession?>((ref) => null);
