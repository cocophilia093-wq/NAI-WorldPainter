import 'package:equatable/equatable.dart';

class LlmSession extends Equatable {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LlmSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  LlmSession copyWith({
    String? title,
    DateTime? updatedAt,
  }) {
    return LlmSession(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, title, createdAt, updatedAt];
}
