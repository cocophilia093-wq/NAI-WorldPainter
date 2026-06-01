import 'package:equatable/equatable.dart';

class NaiModel extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? type;

  const NaiModel({
    required this.id,
    required this.name,
    this.description,
    this.type,
  });

  @override
  List<Object?> get props => [id];
}
