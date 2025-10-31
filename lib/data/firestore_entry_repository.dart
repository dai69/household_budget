import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/entry.dart';
import '../domain/entry_repository.dart';

class FirestoreEntryRepository implements EntryRepository {
  final FirebaseFirestore _firestore;

  FirestoreEntryRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _entriesRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('entries');

  @override
  Stream<List<Entry>> entriesStream({required String userId}) {
    return _entriesRef(userId).orderBy('date', descending: true).snapshots().map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id; // ensure id
        return Entry.fromMap(data);
      }).toList();
    });
  }

  @override
  Future<void> addEntry({required String userId, required Entry entry}) async {
    try {
      final map = entry.toMap();
      // remove id to let Firestore assign one
      map.remove('id');
      await _entriesRef(userId).add(map);
    } catch (e) {
      // rethrow for upper layers to handle
      throw Exception('Firestore addEntry failed: $e');
    }
  }

  @override
  Future<void> deleteEntry({required String userId, required String entryId}) async {
    try {
      await _entriesRef(userId).doc(entryId).delete();
    } catch (e) {
      throw Exception('Firestore deleteEntry failed: $e');
    }
  }

  @override
  Future<void> updateEntry({required String userId, required Entry entry}) async {
    try {
      final map = entry.toMap();
      final id = map.remove('id');
      if (id == null) throw Exception('entry.id is null');
      await _entriesRef(userId).doc(id.toString()).update(map);
    } catch (e) {
      throw Exception('Firestore updateEntry failed: $e');
    }
  }
}
