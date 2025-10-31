import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/category_repository.dart';
import 'firestore_category_repository.dart';
import 'entry_provider.dart' show authStateProvider; // watch auth state

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return FirestoreCategoryRepository();
});

final categoriesStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(categoryRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return const Stream<List<Map<String, dynamic>>>.empty();
      return repo.categoriesStream(userId: user.uid);
    },
    loading: () => const Stream<List<Map<String, dynamic>>>.empty(),
    error: (_, __) => const Stream<List<Map<String, dynamic>>>.empty(),
  );
});
