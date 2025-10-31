import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/entry.dart';
import '../domain/entry_repository.dart';
import 'firestore_entry_repository.dart';

// Repository provider - default to Firestore implementation
final entryRepositoryProvider = Provider<EntryRepository>((ref) {
  return FirestoreEntryRepository(firestore: FirebaseFirestore.instance);
});

// Provide auth state as a StreamProvider so other providers react to sign-in/out
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Stream provider to listen to Firestore entries for the current authenticated user
final firestoreEntriesStreamProvider = StreamProvider<List<Entry>>((ref) {
  final repo = ref.watch(entryRepositoryProvider);
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) {
        return const Stream<List<Entry>>.empty();
      }
      return repo.entriesStream(userId: user.uid);
    },
    loading: () => const Stream<List<Entry>>.empty(),
    error: (_, __) => const Stream<List<Entry>>.empty(),
  );
});

// Keep in-memory provider for quick testing or offline mode
final entryListProvider = StateNotifierProvider<EntryListNotifier, List<Entry>>(
  (ref) => EntryListNotifier(),
);

class EntryListNotifier extends StateNotifier<List<Entry>> {
  EntryListNotifier() : super([]);

  void addEntry({
    required DateTime date,
    required EntryType type,
    required String category,
    required String title,
    required int amount,
  }) {
    final entry = Entry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: date,
      type: type,
      category: category,
      title: title,
      amount: amount,
    );
    state = [entry, ...state];
  }

  void removeEntry(String id) {
    state = state.where((e) => e.id != id).toList();
  }
}
