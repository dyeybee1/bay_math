import 'content_source_type.dart';

/// A Dart-side mirror of one `public.question_bank` row — a reusable
/// question, used only by Internal Quizzes via `quiz_questions` (0008,
/// 0009). Choices live separately in `question_choices`
/// (see [QuestionChoice] / `QuestionBankRepository.fetchChoices`).
class QuestionBankItem {
  const QuestionBankItem({
    required this.id,
    required this.sourceType,
    this.createdBy,
    this.topic,
    required this.promptText,
    this.explanationText,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final ContentSourceType sourceType;

  /// Null for built-in questions (`question_bank_source_created_by_pairing`, 0008).
  final String? createdBy;

  /// Free text — supports the Highest/Lowest Performing Topics dashboard
  /// metrics (0008 comment). Not an enum.
  final String? topic;
  final String promptText;
  final String? explanationText;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory QuestionBankItem.fromJson(Map<String, dynamic> json) {
    return QuestionBankItem(
      id: json['id'] as String,
      sourceType: ContentSourceType.fromDb(json['source_type'] as String),
      createdBy: json['created_by'] as String?,
      topic: json['topic'] as String?,
      promptText: json['prompt_text'] as String,
      explanationText: json['explanation_text'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
