import 'template.dart';

abstract class TemplateRepository {
  Stream<List<Template>> watchTemplates({required String userId});
  Future<String> createTemplate({required String userId, required Template template});
  Future<void> updateTemplate({required String userId, required Template template});
  Future<void> deleteTemplate({required String userId, required String templateId});
  Future<Template?> getTemplate({required String userId, required String templateId});
}
