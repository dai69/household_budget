import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/template.dart';
import '../domain/template_repository.dart';

class TemplateService {
  final FirebaseFirestore firestore;
  final TemplateRepository templateRepository;

  TemplateService({required this.firestore, required this.templateRepository});

  Future<ApplyResult> applyTemplate({
    required String userId,
    required Template template,
    required DateTime targetMonth,
    ApplyOptions? options,
    List<bool>? includeMask, // optional per-item include/skip
  }) async {
    includeMask ??= List<bool>.filled(template.items.length, true);
    final opts = options ?? ApplyOptions();
    final start = DateTime(targetMonth.year, targetMonth.month, 1);
    final end = DateTime(targetMonth.year, targetMonth.month + 1, 1);
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    final entriesRef = firestore.collection('users').doc(userId).collection('entries');

    // fetch existing entries in that month to do duplicate detection
    final existingSnap = await entriesRef.where('date', isGreaterThanOrEqualTo: startIso).where('date', isLessThan: endIso).get();
    final existingDocs = existingSnap.docs;

    final existingSet = <String>{};
    for (final d in existingDocs) {
      final data = d.data();
      final key = '${data['date'] ?? ''}|${data['title'] ?? ''}|${data['amount'] ?? ''}|${data['category'] ?? ''}';
      existingSet.add(key);
    }

    int created = 0;
    int skipped = 0;
    final createdIds = <String>[];
    final errors = <String>[];

    final batch = firestore.batch();

    final tempApplicationsRef = firestore.collection('users').doc(userId).collection('templates');
    final appDocRef = tempApplicationsRef.doc(template.id).collection('applications').doc();

    for (var i = 0; i < template.items.length; i++) {
      final item = template.items[i];
      try {
        if (includeMask.length <= i || includeMask[i] == false) {
          skipped++;
          continue;
        }
        final day = item.dayOfMonth ?? 1;
        final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
        final useDay = day <= lastDay ? day : lastDay;
        final entryDate = DateTime(targetMonth.year, targetMonth.month, useDay);
        final iso = entryDate.toIso8601String();

        final key = '$iso|${item.title}|${item.amount}|${item.categoryId ?? ''}';
        if (opts.duplicatePolicy == 'skip' && existingSet.contains(key)) {
          skipped++;
          continue;
        }

        final docRef = entriesRef.doc();
        final map = {
          'date': iso,
          'type': item.type == EntryTypeEnum.income ? 'income' : 'expense',
          'category': item.categoryId ?? '',
          'title': item.title,
          'amount': item.amount,
        };
        batch.set(docRef, map);
        createdIds.add(docRef.id);
        created++;
      } catch (e) {
        errors.add(e.toString());
      }
    }

    // commit batch
    try {
      await batch.commit();
      // record application
      final app = {
        'month': '${targetMonth.year.toString().padLeft(4,'0')}-${targetMonth.month.toString().padLeft(2,'0')}',
        'appliedAt': Timestamp.now(),
        'createdEntryIds': createdIds,
        'skippedCount': skipped,
        'errors': errors,
      };
      await appDocRef.set(app);
      // update template lastAppliedAt
      await firestore.collection('users').doc(userId).collection('templates').doc(template.id).update({'lastAppliedAt': Timestamp.now()});
    } catch (e) {
      errors.add('batch commit failed: $e');
    }

    return ApplyResult(createdCount: created, skippedCount: skipped, createdEntryIds: createdIds, errors: errors);
  }
}
