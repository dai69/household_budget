import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/template_provider.dart';
import '../../data/template_service.dart';
import '../pages/template_edit_page.dart';
import '../pages/template_apply_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/global_keys.dart';

class TemplatesPage extends ConsumerWidget {
  const TemplatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(templatesStreamProvider);
    final user = FirebaseAuth.instance.currentUser;

    return templatesAsync.when(
      data: (templates) {
        return Scaffold(
          appBar: AppBar(title: const Text('テンプレート')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView.builder(
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final t = templates[index];
                return Card(
                  child: ListTile(
                    title: Text(t.name),
                    subtitle: Text('${t.items.length} 件 • ${t.description ?? ''}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.play_arrow), tooltip: '適用', onPressed: () async {
                        final picked = await showDialog<Map<String, dynamic>?>(context: context, builder: (ctx) => TemplateApplyDialog(template: t));
                        if (picked != null && user != null) {
                          final svc = TemplateService(firestore: FirebaseFirestore.instance, templateRepository: ref.read(templateRepositoryProvider));
                          final date = picked['date'] as DateTime?;
                          final include = (picked['include'] as List?)?.cast<bool>();
                          final res = await svc.applyTemplate(userId: user.uid, template: t, targetMonth: date ?? DateTime.now(), includeMask: include);
                          if (res.errors.isEmpty) {
                            appScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('適用完了: 作成 ${res.createdCount} 件, スキップ ${res.skippedCount} 件')));
                          } else {
                            appScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('一部エラー: ${res.errors.join(', ')}')));
                          }
                        }
                      }),
                      IconButton(icon: const Icon(Icons.edit), tooltip: '編集', onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => TemplateEditPage(template: t)));
                      }),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), tooltip: '削除', onPressed: () async {
                        final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('削除確認'), content: Text('テンプレート「${t.name}」を削除してよいですか？'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('キャンセル')), TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('削除', style: TextStyle(color: Colors.red))),]));
                        if (ok == true && user != null) {
                          await ref.read(templateRepositoryProvider).deleteTemplate(userId: user.uid, templateId: t.id);
                        }
                      }),
                    ]),
                  ),
                );
              },
            ),
          ),
          floatingActionButton: FloatingActionButton(child: const Icon(Icons.add), onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TemplateEditPage()));
          }),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('テンプレート取得エラー: $err'), if (err.toString().contains('permission-denied')) ElevatedButton(onPressed: () {
            showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Firestore ルール例'), content: SingleChildScrollView(child: SelectableText(r'''rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}''')), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('閉じる'))]));
          }, child: const Text('ルールの例を表示'))])),
    );
  }
}
