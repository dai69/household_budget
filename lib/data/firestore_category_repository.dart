import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/category_repository.dart';

class FirestoreCategoryRepository implements CategoryRepository {
  final FirebaseFirestore _firestore;

  FirestoreCategoryRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _categoriesRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('categories');

  @override
  Stream<List<Map<String, dynamic>>> categoriesStream({required String userId}) {
    // Order by 'order' server-side to avoid requiring a composite index;
    // then sort by name client-side for a stable secondary sort.
    return _categoriesRef(userId).orderBy('order').snapshots().map((snap) {
      final list = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();

      list.sort((a, b) {
        int oa = 0;
        int ob = 0;
        final ao = a['order'];
        final bo = b['order'];
        if (ao is int) {
          oa = ao;
        } else if (ao is Timestamp) {
          oa = ao.millisecondsSinceEpoch;
        }
        if (bo is int) {
          ob = bo;
        } else if (bo is Timestamp) {
          ob = bo.millisecondsSinceEpoch;
        }
        if (oa != ob) return oa.compareTo(ob);
        final an = (a['name'] ?? '').toString();
        final bn = (b['name'] ?? '').toString();
        return an.compareTo(bn);
      });

      return list;
    });
  }

  @override
  Future<String> addCategory({required String userId, required String name, int? color, int? order}) async {
    try {
  final map = <String, dynamic>{'name': name, 'color': color ?? 0};
  // Use provided integer order when available, otherwise default to 0
  if (order != null) {
    map['order'] = order;
  } else {
    map['order'] = 0;
  }
      final ref = await _categoriesRef(userId).add(map);
  // store id inside document for easier queries/inspection
  await _categoriesRef(userId).doc(ref.id).update({'id': ref.id});
      return ref.id;
    } catch (e) {
      throw Exception('addCategory failed: $e');
    }
  }

  @override
  Future<void> updateCategory({required String userId, required String categoryId, String? name, int? color, int? order}) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (color != null) data['color'] = color;
      if (order != null) data['order'] = order;
      if (data.isEmpty) return;
      await _categoriesRef(userId).doc(categoryId).update(data);
    } catch (e) {
      throw Exception('updateCategory failed: $e');
    }
  }

  @override
  Future<void> updateCategoriesOrder({required String userId, required Map<String, int> orders}) async {
    final batch = _firestore.batch();
    try {
      orders.forEach((categoryId, ord) {
        final docRef = _categoriesRef(userId).doc(categoryId);
        batch.update(docRef, {'order': ord});
      });
      await batch.commit();
    } catch (e) {
      throw Exception('updateCategoriesOrder failed: $e');
    }
  }

  @override
  Future<void> deleteCategory({required String userId, required String categoryId}) async {
    try {
      await _categoriesRef(userId).doc(categoryId).delete();
    } catch (e) {
      throw Exception('deleteCategory failed: $e');
    }
  }
}
