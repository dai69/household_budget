import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../domain/template.dart';
import '../domain/template_repository.dart';

class FirestoreTemplateRepository implements TemplateRepository {
  final FirebaseFirestore firestore;
  FirestoreTemplateRepository({required this.firestore});

  CollectionReference<Map<String, dynamic>> _templatesRef(String userId) {
    return firestore.collection('users').doc(userId).collection('templates');
  }

  @override
  Stream<List<Template>> watchTemplates({required String userId}) {
    return _templatesRef(userId).orderBy('updatedAt', descending: true).snapshots().map((snap) {
      return snap.docs.map((d) => Template.fromJson({...d.data(), 'id': d.id})).toList();
    });
  }

  @override
  Future<String> createTemplate({required String userId, required Template template}) async {
    final id = Uuid().v4();
    final now = Timestamp.now();
    final data = template.toJson();
    // sanitize items to ensure categoryId is a String (avoid storing nested maps accidentally)
    if (data['items'] is List) {
      final items = data['items'] as List;
      for (final it in items) {
        if (it is Map) {
          final cid = it['categoryId'];
          if (cid != null && cid is! String) {
            // try to extract id field or fallback to toString()
            if (cid is Map && cid.containsKey('id')) {
              it['categoryId'] = cid['id']?.toString();
            } else {
              it['categoryId'] = cid.toString();
            }
          }
        }
      }
    }
    data['createdAt'] = now;
    data['updatedAt'] = now;
    data['createdBy'] = template.createdBy;
    await _templatesRef(userId).doc(id).set(data);
    return id;
  }

  @override
  Future<void> deleteTemplate({required String userId, required String templateId}) async {
    await _templatesRef(userId).doc(templateId).delete();
  }

  @override
  Future<Template?> getTemplate({required String userId, required String templateId}) async {
    final doc = await _templatesRef(userId).doc(templateId).get();
    if (!doc.exists) return null;
    return Template.fromJson({...doc.data()!, 'id': doc.id});
  }

  @override
  Future<void> updateTemplate({required String userId, required Template template}) async {
    final data = template.toJson();
    // sanitize similarly
    if (data['items'] is List) {
      final items = data['items'] as List;
      for (final it in items) {
        if (it is Map) {
          final cid = it['categoryId'];
          if (cid != null && cid is! String) {
            if (cid is Map && cid.containsKey('id')) {
              it['categoryId'] = cid['id']?.toString();
            } else {
              it['categoryId'] = cid.toString();
            }
          }
        }
      }
    }
    data['updatedAt'] = Timestamp.now();
    await _templatesRef(userId).doc(template.id).update(data);
  }
}
