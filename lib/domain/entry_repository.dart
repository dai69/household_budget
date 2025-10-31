import '../domain/entry.dart';

abstract class EntryRepository {
  Stream<List<Entry>> entriesStream({required String userId});
  Future<void> addEntry({required String userId, required Entry entry});
  Future<void> updateEntry({required String userId, required Entry entry});
  Future<void> deleteEntry({required String userId, required String entryId});
}
