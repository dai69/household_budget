import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/template.dart';
import '../../data/template_provider.dart';import '../../data/category_provider.dart';
import '../../utils/global_keys.dart';
class TemplateEditPage extends ConsumerStatefulWidget {
  final Template? template;
  const TemplateEditPage({super.key, this.template});

  @override
  ConsumerState<TemplateEditPage> createState() => _TemplateEditPageState();
}

class _TemplateEditPageState extends ConsumerState<TemplateEditPage> {
  final _nameCtl = TextEditingController();
  final _descCtl = TextEditingController();
  List<TemplateItem> _items = [];

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    if (t != null) {
      _nameCtl.text = t.name;
      _descCtl.text = t.description ?? '';
      _items = List<TemplateItem>.from(t.items);
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _descCtl.dispose();
    super.dispose();
  }

  String _formatNumber(int v) {
    final vi = v.abs();
    final s = vi.toString();
    final reg = RegExp(r"\B(?=(\d{3})+(?!\d))");
    final withComma = s.replaceAllMapped(reg, (m) => ',');
    return (v < 0 ? '-' : '') + withComma;
  }

  Future<void> _editItem({TemplateItem? item, required int index}) async {
    final titleCtl = TextEditingController(text: item?.title ?? '');
    final amountCtl = TextEditingController(text: item?.amount.toString() ?? '0');
    final dayCtl = TextEditingController(text: item?.dayOfMonth?.toString() ?? '1');
    String? selectedCategoryId = item?.categoryId;
    var type = item?.type ?? EntryTypeEnum.expense;

    final cats = ref.read(categoriesStreamProvider).maybeWhen(data: (v) => v, orElse: () => []);

    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(item == null ? '項目追加' : '項目編集'),
      content: StatefulBuilder(builder: (ctx2, setInner) {
        return Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: type == EntryTypeEnum.income ? 'income' : 'expense',
            decoration: const InputDecoration(labelText: '種類'),
            items: const [
              DropdownMenuItem(value: 'expense', child: Text('支出')),
              DropdownMenuItem(value: 'income', child: Text('収入')),
            ],
            onChanged: (v) {
              setInner(() {
                type = (v == 'income') ? EntryTypeEnum.income : EntryTypeEnum.expense;
              });
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: selectedCategoryId,
            decoration: const InputDecoration(labelText: 'カテゴリ（マスターから選択）'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('- 選択しない -')),
              ...cats.map((c) {
                final id = c['id'] as String?;
                final name = (c['name'] ?? '').toString();
                return DropdownMenuItem<String?>(value: id, child: Text(name));
              }),
            ],
            onChanged: (v) {
              setInner(() {
                selectedCategoryId = v;
              });
            },
          ),
          const SizedBox(height: 8),
          TextField(controller: titleCtl, decoration: const InputDecoration(labelText: 'タイトル')),
          const SizedBox(height: 8),
          TextField(controller: amountCtl, decoration: const InputDecoration(labelText: '金額'), keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          TextField(controller: dayCtl, decoration: const InputDecoration(labelText: '日（1-31）'), keyboardType: TextInputType.number),
        ]);
      }),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('キャンセル')), TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('保存'))],
    ));

    if (ok != true) { return; }
    final newItem = TemplateItem(
      id: item?.id ?? Uuid().v4(),
      title: titleCtl.text.trim(),
      type: type,
      amount: int.tryParse(amountCtl.text.replaceAll(',', '')) ?? 0,
      categoryId: selectedCategoryId,
      dayOfMonth: int.tryParse(dayCtl.text) ?? 1,
      order: index,
    );

    setState(() {
      if (item == null) {
        _items.add(newItem);
      } else {
        _items[index] = newItem;
      }
    });
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final repo = ref.read(templateRepositoryProvider);
    final now = Timestamp.now();
    final id = widget.template?.id ?? Uuid().v4();
    final template = Template(id: id, name: _nameCtl.text.trim(), description: _descCtl.text.trim().isEmpty ? null : _descCtl.text.trim(), items: _items, createdAt: now, updatedAt: now, createdBy: user.uid, lastAppliedAt: null);
    try {
      if (widget.template == null) {
        await repo.createTemplate(userId: user.uid, template: template);
      } else {
        await repo.updateTemplate(userId: user.uid, template: template);
      }
      if (mounted) { Navigator.of(context).pop(); }
    } catch (e) {
      appScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('テンプレート保存エラー: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.template == null ? '新規テンプレート' : 'テンプレート編集')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: _nameCtl, decoration: const InputDecoration(labelText: 'テンプレート名')),
          const SizedBox(height: 8),
          TextField(controller: _descCtl, decoration: const InputDecoration(labelText: '説明（任意）')),
          const SizedBox(height: 16),
          const Text('項目'),
          const SizedBox(height: 8),
          Expanded(child: ListView.builder(itemCount: _items.length, itemBuilder: (context, index) {
            final it = _items[index];
            final cats = ref.read(categoriesStreamProvider).maybeWhen(data: (v) => v, orElse: () => []);
            final sel = cats.firstWhere((c) => (c['id'] as String?) == it.categoryId, orElse: () => <String,dynamic>{});
            final catName = sel is Map ? (sel['name'] ?? '').toString() : (it.categoryId ?? '');
            return ListTile(
              title: Text(it.title),
              subtitle: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: it.type == EntryTypeEnum.income ? Colors.teal : Colors.redAccent, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(it.type == EntryTypeEnum.income ? '収入' : '支出', style: TextStyle(color: it.type == EntryTypeEnum.income ? Colors.teal : Colors.redAccent)),
                const SizedBox(width: 12),
                Expanded(child: Text('$catName • 日: ${it.dayOfMonth ?? 1}')),
                const SizedBox(width: 8),
                Text('${it.type == EntryTypeEnum.income ? '+' : '-'}¥${_formatNumber(it.amount)}', style: TextStyle(color: it.type == EntryTypeEnum.income ? Colors.teal : Colors.redAccent)),
              ]),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit), onPressed: () => _editItem(item: it, index: index)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () { setState(() => _items.removeAt(index)); }),
              ]),
            );
          })),

          const SizedBox(height: 12),
          Row(children: [
            ElevatedButton(onPressed: () => _editItem(item: null, index: _items.length), child: const Text('+ 項目を追加')),
            const SizedBox(width: 12),
            const Spacer(),
            OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('キャンセル')),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _save, child: const Text('保存')),
          ])
        ]),
      ),
    );
  }
}
