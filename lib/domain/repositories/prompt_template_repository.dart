import 'package:nai_huishi/domain/entities/prompt_template.dart';

abstract class PromptTemplateRepository {
  Future<List<PromptTemplate>> getAllTemplates();
  Future<PromptTemplate?> getTemplate(int id);
  Future<PromptTemplate> createTemplate(PromptTemplate template);
  Future<PromptTemplate> updateTemplate(PromptTemplate template);
  Future<void> deleteTemplate(int id);
  Future<List<PromptTemplate>> getTemplatesByCategory(String category);
  Future<List<PromptTemplate>> searchTemplates(String query);
  Future<void> incrementUseCount(int id);
}
