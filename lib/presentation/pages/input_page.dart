import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entry.dart';
import '../../data/entry_provider.dart';
import '../../data/category_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InputPage extends ConsumerStatefulWidget {
  const InputPage({super.key});

  @override
  ConsumerState<InputPage> createState() => _InputPageState();
}

class _InputPageState extends ConsumerState<InputPage> {
  DateTime _selectedDate = DateTime.now();
  EntryType _type = EntryType.expense;
  String _category = '食費';
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      if (!mounted) return;
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amountController.text) ?? 0;
    if (_titleController.text.isEmpty || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('項目名と金額を正しく入力してください')),
        );
      }
      return;
    }

    // persist to Firestore via repository
    final repo = ref.read(entryRepositoryProvider);
    final entry = Entry(
      id: '', // Firestore will assign
      date: _selectedDate,
      type: _type,
      category: _category, // stores category id when available
      title: _titleController.text,
      amount: amount,
    );
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('未認証ユーザーです');
      await repo.addEntry(userId: uid, entry: entry);
      _titleController.clear();
      _amountController.clear();
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Firestoreに保存しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncCats = ref.watch(categoriesStreamProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          ListTile(
            title: const Text('日付'),
            subtitle: Text('${_selectedDate.toLocal()}'.split(' ')[0]),
            trailing: TextButton(onPressed: _pickDate, child: const Text('選択')),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<EntryType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: '入出金'),
            items: const [
              DropdownMenuItem(value: EntryType.income, child: Text('収入')),
              DropdownMenuItem(value: EntryType.expense, child: Text('支出')),
            ],
            onChanged: (v) => setState(() => _type = v ?? EntryType.expense),
          ),
          const SizedBox(height: 8),
          asyncCats.when(
            data: (cats) {
                if (cats.isNotEmpty) {
                // convert to id->name items
                final items = cats.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] as String))).toList();
                // if current _category is a name (legacy), try to resolve to id
                if (!cats.any((c) => c['id'] == _category)) {
                  final found = cats.firstWhere((c) => (c['name'] ?? '') == _category, orElse: () => <String, dynamic>{});
                  if (found.isNotEmpty) {
                    _category = found['id'] as String;
                  } else {
                    _category = cats.first['id'] as String;
                  }
                }
                return DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'カテゴリ'),
                  items: items,
                  onChanged: (v) => setState(() => _category = v ?? ''),
                );
              }
              // fallback to legacy names if no categories
              final items = const [
                DropdownMenuItem(value: '食費', child: Text('食費')),
                DropdownMenuItem(value: '交通', child: Text('交通')),
                DropdownMenuItem(value: '光熱費', child: Text('光熱費')),
                DropdownMenuItem(value: 'その他', child: Text('その他')),
              ];
              return DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'カテゴリ'),
                items: items,
                onChanged: (v) => setState(() => _category = v ?? 'その他'),
              );
            },
            loading: () => const CircularProgressIndicator(),
                error: (e, st) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('カテゴリの読み込みに失敗しました'),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'カテゴリ'),
                  items: const [
                    DropdownMenuItem(value: '食費', child: Text('食費')),
                    DropdownMenuItem(value: '交通', child: Text('交通')),
                    DropdownMenuItem(value: '光熱費', child: Text('光熱費')),
                    DropdownMenuItem(value: 'その他', child: Text('その他')),
                  ],
                  onChanged: (v) => setState(() => _category = v ?? 'その他'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: '項目名'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '金額'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }
}
