import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/template_repository.dart';
import 'firestore_template_repository.dart';
import '../domain/template.dart';

import 'entry_provider.dart';

final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  return FirestoreTemplateRepository(firestore: FirebaseFirestore.instance);
});

final templatesStreamProvider = StreamProvider<List<Template>>((ref) {
  final repo = ref.watch(templateRepositoryProvider);
  final auth = ref.watch(authStateProvider);
  return auth.when(
    data: (user) {
      if (user == null) return const Stream<List<Template>>.empty();
      return repo.watchTemplates(userId: user.uid);
    },
    loading: () => const Stream<List<Template>>.empty(),
    error: (_, __) => const Stream<List<Template>>.empty(),
  );
});
