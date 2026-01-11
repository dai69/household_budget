import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../utils/global_keys.dart';
// conditional import for web file IO
import '../../utils/file_io_stub.dart' if (dart.library.html) '../../utils/file_io_web.dart';

import '../../data/entry_provider.dart';
import '../../data/category_provider.dart';
import '../../domain/entry.dart';
import '../../domain/template.dart';
import '../../data/template_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// selection mode providers (move selection state to Riverpod for AppBar coordination)
final listSelectionModeProvider = StateProvider<bool>((ref) => false);
final listSelectedEntryIdsProvider = StateProvider<Set<String>>((ref) => <String>{});
// visible IDs provider (so AppBar can perform full-select on visible entries)
final listVisibleEntryIdsProvider = StateProvider<List<String>>((ref) => <String>[]);

// small helper provider to check if a specific entry is selected (limits rebuild scope)
final isEntrySelectedProvider = Provider.family<bool, String>((ref, id) => ref.watch(listSelectedEntryIdsProvider).contains(id));

class ListPageClean extends ConsumerStatefulWidget {
  const ListPageClean({super.key});

  @override
  ConsumerState<ListPageClean> createState() => _ListPageCleanState();
}

class _ListPageCleanState extends ConsumerState<ListPageClean> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  // Filter / sort state
  final TextEditingController _filterTitleController = TextEditingController();
  final TextEditingController _filterMinController = TextEditingController();
  final TextEditingController _filterMaxController = TextEditingController();
  final Set<EntryType> _filterTypes = <EntryType>{};
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  // support multiple selected categories
  final Set<String> _filterCategoryIds = <String>{};
  String _sortField = 'date';
  bool _sortAsc = false;


  String formatNumber(int v) {
    final vi = v.abs();
    final s = vi.toString();
    final reg = RegExp(r"\B(?=(\d{3})+(?!\d))");
    final withComma = s.replaceAllMapped(reg, (m) => ',');
    return (v < 0 ? '-' : '') + withComma;
  }

  // Edit dialog for an entry
  Future<void> _showEditDialog(Entry entry, List<dynamic> cats, Map<String, String> idToName) async {
    final authState = ref.read(authStateProvider);
    final user = authState.asData?.value;
    if (user == null) return;
    final uid = user.uid;

    DateTime selectedDate = entry.date;
    EntryType selectedType = entry.type;
    String selectedCategory = entry.category;
    final titleController = TextEditingController(text: entry.title);
    final amountController = TextEditingController(text: entry.amount.toString());

    // Show dialog to collect edited values. Do not perform async repo update inside dialog to
    // avoid using BuildContext across async gaps. Return the updated Entry from the dialog
    // then perform the update after the dialog completes.
    final updatedEntry = await showDialog<Entry?>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('項目を編集'),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            TextButton.icon(onPressed: () { showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100)).then((d) { if (d != null) selectedDate = d; }); }, icon: const Icon(Icons.date_range), label: Text(formatDate(selectedDate))),
            const SizedBox(height: 8),
            DropdownButton<EntryType>(value: selectedType, items: const [DropdownMenuItem(value: EntryType.income, child: Text('収入')), DropdownMenuItem(value: EntryType.expense, child: Text('支出'))], onChanged: (v) { if (v != null) selectedType = v; }),
            const SizedBox(height: 8),
            DropdownButton<String>(value: selectedCategory, items: cats.map<DropdownMenuItem<String>>((c) { final id = c['id'] as String? ?? ''; final name = (c['name'] ?? '') as String; return DropdownMenuItem(value: id, child: Text(name)); }).toList(), onChanged: (v) { if (v != null) selectedCategory = v; }),
            const SizedBox(height: 8),
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'タイトル')),
            const SizedBox(height: 8),
            TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '金額')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('キャンセル')),
          ElevatedButton(onPressed: () {
            // validate and return updated entry (do not call repos here)
            final t = titleController.text.trim();
            final a = int.tryParse(amountController.text.replaceAll(',', '').trim());
            if (t.isEmpty || a == null) {
              ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(const SnackBar(content: Text('タイトルと金額を正しく入力してください')));
              return;
            }
            final updated = entry.copyWith(date: selectedDate, type: selectedType, category: selectedCategory, title: t, amount: a);
            Navigator.of(ctx).pop(updated);
          }, child: const Text('保存')),
        ],
      );
    });

    if (updatedEntry != null) {
      // perform update outside the dialog (async) and then show snackbar using this widget's context
      try {
        final repo = ref.read(entryRepositoryProvider);
        await repo.updateEntry(userId: uid, entry: updatedEntry);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('更新しました')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新エラー: $e')));
      }
    }
  }

  String formatDate(DateTime dt) {
    final d = dt.toLocal();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y/$m/$day';
  }

  @override
  void dispose() {
    _filterTitleController.dispose();
    _filterMinController.dispose();
    _filterMaxController.dispose();
    super.dispose();
  }

  Future<void> _exportCsv(List<Entry> rows, Map<String, String> idToName) async {
    final sb = StringBuffer();
    sb.writeln('date,type,category,title,amount');
    for (final e in rows) {
      final dt = e.date.toLocal();
      final yyyy = dt.year.toString().padLeft(4, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final dd = dt.day.toString().padLeft(2, '0');
      final dateStr = '$yyyy/$mm/$dd';
      final typeStr = e.type == EntryType.income ? '収入' : '支出';
      final catName = (idToName[e.category] ?? e.category).toString().replaceAll(',', '，');
      final title = e.title.replaceAll(',', '，');
      final amount = e.amount.toString();
      sb.writeln('$dateStr,$typeStr,$catName,$title,$amount');
    }
    final csv = sb.toString();
  await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('CSV 出力'), content: SingleChildScrollView(child: SelectableText(csv)), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('閉じる')), TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: csv)); Navigator.of(ctx).pop(); }, child: const Text('コピー'))]));
  }

  // Export all entries to a file (web download) or clipboard fallback
  Future<void> _exportAllCsv(List<Entry> allEntries, Map<String, String> idToName) async {
    final sb = StringBuffer();
    sb.writeln('date,type,category,title,amount');
    for (final e in allEntries) {
      final dt = e.date.toLocal();
      final yyyy = dt.year.toString().padLeft(4, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final dd = dt.day.toString().padLeft(2, '0');
      final dateStr = '$yyyy/$mm/$dd';
      final typeStr = e.type == EntryType.income ? '収入' : '支出';
      final catName = (idToName[e.category] ?? e.category).toString().replaceAll(',', '，');
      final title = e.title.replaceAll(',', '，');
      final amount = e.amount.toString();
      sb.writeln('$dateStr,$typeStr,$catName,$title,$amount');
    }
    final csv = sb.toString();
    final filename = 'household_export_${DateTime.now().toIso8601String().split('T').first}.csv';
    try {
      await exportFile(filename, csv);
      if (!mounted) return;
      appScaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('全件エクスポートを開始しました')));
    } catch (e) {
      // fallback: copy to clipboard
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      appScaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('クリップボードにCSVをコピーしました')));
    }
  }

  Future<void> _importFromFileOrPaste() async {
    try {
      final content = await pickFileAndRead();
      if (content == null) {
        final controller = TextEditingController();
        // ignore: use_build_context_synchronously
        final res = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('CSV 読み込み（貼り付け）'), content: SizedBox(width: 560, child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('ヘッダ: date,type,category,title,amount\n日付は yyyy/MM/dd 書式、type は 収入/支出'), TextField(controller: controller, maxLines: 12)])), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('キャンセル')), ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('読み込み'))]));
        if (!context.mounted) return;
        if (res == true) {
          final text = controller.text.trim();
          if (text.isNotEmpty) {
            if (!mounted) return;
            await _processImportedCsv(text);
          }
        }
        return;
      }
      await _processImportedCsv(content);
    } catch (e) {
      // fallback to paste dialog
      final controller = TextEditingController();
      // ignore: use_build_context_synchronously
      final res = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('CSV 読み込み（貼り付け）'), content: SizedBox(width: 560, child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('ヘッダ: date,type,category,title,amount\n日付は yyyy/MM/dd 書式、type は 収入/支出'), TextField(controller: controller, maxLines: 12)])), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('キャンセル')), ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('読み込み'))]));
      if (!context.mounted) return;
      if (res == true) {
        final text = controller.text.trim();
        if (text.isNotEmpty) {
          if (!mounted) return;
          await _processImportedCsv(text);
        }
      }
    }
  }

  Future<void> _saveAsTemplateForMonth(DateTime month, List<Entry> rows) async {
    final nameController = TextEditingController(text: '${month.year}-${month.month} のテンプレート');
    final descController = TextEditingController(text: 'Saved from ${month.year}/${month.month}');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('テンプレートとして保存'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameController, decoration: const InputDecoration(labelText: 'テンプレート名')),
        const SizedBox(height: 8),
        TextField(controller: descController, decoration: const InputDecoration(labelText: '説明（任意）')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('キャンセル')), ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('保存'))],
    ));
    if (!context.mounted) return;
    if (ok == true) {
      final auth = ref.read(authStateProvider);
      final user = auth.asData?.value;
      if (user == null) return;
      final uid = user.uid;
      final items = rows.map((e) => TemplateItem(id: DateTime.now().microsecondsSinceEpoch.toString(), title: e.title, type: e.type == EntryType.income ? EntryTypeEnum.income : EntryTypeEnum.expense, amount: e.amount, categoryId: e.category, dayOfMonth: e.date.day, order: 0)).toList();
      final t = Template(id: '', name: nameController.text.trim(), description: descController.text.trim().isEmpty ? 'Saved from ${month.year}/${month.month}' : descController.text.trim(), items: items, createdAt: Timestamp.now(), updatedAt: Timestamp.now(), createdBy: uid, lastAppliedAt: null);
      await ref.read(templateRepositoryProvider).createTemplate(userId: uid, template: t);
      if (!mounted) return;
      appScaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('テンプレートを保存しました')));
    }
  }

  Future<void> _processImportedCsv(String text) async {
    List<List<String>> parseCsv(String src) {
      final lines = <List<String>>[];
      final rows = src.split(RegExp(r'\r?\n'));
      for (var row in rows) {
        if (row.trim().isEmpty) continue;
        final fields = <String>[];
        final sb = StringBuffer();
        bool inQuotes = false;
        for (int i = 0; i < row.length; i++) {
          final ch = row[i];
          if (ch == '"') {
            if (inQuotes && i + 1 < row.length && row[i + 1] == '"') { sb.write('"'); i++; } else { inQuotes = !inQuotes; }
          } else if (ch == ',' && !inQuotes) { fields.add(sb.toString()); sb.clear(); } else { sb.write(ch); }
        }
        fields.add(sb.toString());
        lines.add(fields);
      }
      return lines;
    }

    final rows = parseCsv(text);
    if (rows.isEmpty) return;
    final first = rows.first.map((s) => s.trim().toLowerCase()).toList();
    if (first.length >= 5 && first[0] == 'date' && first[1] == 'type') rows.removeAt(0);

    final errors = <String>[];
    final authState = ref.read(authStateProvider);
    final user = authState.asData?.value;
    if (user == null) return;
    final uid = user.uid;
    final categoryRepo = ref.read(categoryRepositoryProvider);
    final entryRepo = ref.read(entryRepositoryProvider);

    final catsRaw = ref.read(categoriesStreamProvider).maybeWhen(data: (v) => v, orElse: () => []);
    final catsList = List<Map<String, dynamic>>.from(catsRaw);
    final nameToId = <String, String>{};
    for (final c in catsList) { final id = c['id']?.toString() ?? ''; final name = (c['name'] ?? '').toString(); if (id.isNotEmpty) nameToId[name] = id; }

    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      try {
        if (r.length < 5) throw Exception('列数不足: ${r.length}');
        final dateStr = r[0].trim();
        final typeStr = r[1].trim();
        final categoryName = r[2].trim();
        final title = r[3].trim();
        final amountStr = r[4].trim();

        final parts = dateStr.split('/');
        if (parts.length != 3) throw Exception('日付書式エラー: $dateStr');
        final y = int.tryParse(parts[0]); final m = int.tryParse(parts[1]); final d = int.tryParse(parts[2]);
        if (y == null || m == null || d == null) throw Exception('日付解析失敗: $dateStr');
        final date = DateTime(y, m, d);

        final type = (typeStr == '収入') ? EntryType.income : EntryType.expense;

        String? categoryId = nameToId[categoryName];
        if (categoryId == null) {
          final nextOrder = (catsList.isEmpty) ? 0 : (catsList.map((e) => (e['order'] is int ? e['order'] as int : 0)).fold<int>(0, (prev, e) => e > prev ? e : prev) + 1);
          final palette = [0xFF2196F3,0xFFF44336,0xFFFFC107,0xFF4CAF50,0xFF9C27B0,0xFF795548,0xFF009688,0xFFFF5722,0xFF3F51B5,0xFFE91E63,0xFFCDDC39,0xFF00BCD4];
          final used = <int>{}; for (final c in catsList) { final col = c['color'] is int ? (c['color'] as int) : 0; if (col != 0) used.add(col); }
          int chosen = palette.firstWhere((p) => !used.contains(p), orElse: () => palette[catsList.length % palette.length]);
          final newId = await categoryRepo.addCategory(userId: uid, name: categoryName, order: nextOrder, color: chosen);
          categoryId = newId; nameToId[categoryName] = newId; catsList.add({'id': newId, 'name': categoryName, 'order': nextOrder, 'color': chosen});
        }

        final amount = int.tryParse(amountStr.replaceAll(',', '')) ?? (throw Exception('金額解析失敗: $amountStr'));
        final entry = Entry(id: '', date: date, type: type, category: categoryId, title: title, amount: amount);
        await entryRepo.addEntry(userId: uid, entry: entry);
      } catch (e) {
        errors.add('行 ${i + 1}: ${e.toString()}');
      }
    }

    if (errors.isNotEmpty) {
      final joined = errors.join('\n');
      // ignore: use_build_context_synchronously
      await showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text('読み込みエラー'),
        content: SizedBox(width: 560, child: SingleChildScrollView(child: SelectableText(joined))),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('閉じる')),
          TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: joined)); Navigator.of(ctx).pop(); }, child: const Text('エラーをコピー')),
        ],
      ));
    } else {
      if (!mounted) return;
      appScaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('CSV の読み込みが完了しました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncEntries = ref.watch(firestoreEntriesStreamProvider);
    return asyncEntries.when(
      data: (entries) {
        final month = _selectedMonth;
        final visible = entries.where((e) => e.date.year == month.year && e.date.month == month.month).toList();

        final catsAsync = ref.watch(categoriesStreamProvider);
        return catsAsync.when(
          data: (cats) {
            final idToName = <String, String>{};
            for (final c in cats) { final id = c['id'] as String?; final name = (c['name'] ?? '') as String; if (id != null) idToName[id] = name; }

            // Apply current filters immediately so the header '合計' reflects the filtered list
            final titleFilterTop = _filterTitleController.text.trim().toLowerCase();
            final minTop = int.tryParse(_filterMinController.text);
            final maxTop = int.tryParse(_filterMaxController.text);

            final filtered2 = visible.where((e) {
              if (titleFilterTop.isNotEmpty && !e.title.toLowerCase().contains(titleFilterTop)) return false;
              final signed = e.type == EntryType.income ? e.amount : -e.amount;
              if (minTop != null && signed < minTop) return false;
              if (maxTop != null && signed > maxTop) return false;
              if (_filterTypes.isNotEmpty && !_filterTypes.contains(e.type)) return false;
              if (_filterStartDate != null) { final d = DateTime(e.date.year, e.date.month, e.date.day); if (d.isBefore(DateTime(_filterStartDate!.year, _filterStartDate!.month, _filterStartDate!.day))) return false; }
              if (_filterEndDate != null) { final d = DateTime(e.date.year, e.date.month, e.date.day); if (d.isAfter(DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day))) return false; }
              if (_filterCategoryIds.isNotEmpty) { if (!_filterCategoryIds.contains(e.category)) return false; }
              return true;
            }).toList();

            // sort filtered list according to sort state
            filtered2.sort((a, b) {
              int cmp = 0;
              switch (_sortField) {
                case 'title': cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase()); break;
                case 'amount': final va = (a.type == EntryType.income ? a.amount : -a.amount); final vb = (b.type == EntryType.income ? b.amount : -b.amount); cmp = va.compareTo(vb); break;
                case 'category': final na = idToName[a.category] ?? a.category; final nb = idToName[b.category] ?? b.category; cmp = na.toLowerCase().compareTo(nb.toLowerCase()); break;
                case 'date': default: cmp = a.date.compareTo(b.date);
              }
              return _sortAsc ? cmp : -cmp;
            });

            // publish visible ids for AppBar actions
            // Delay updating the provider until after the current build frame to avoid modifying providers while building.
            WidgetsBinding.instance.addPostFrameCallback((_) { ref.read(listVisibleEntryIdsProvider.notifier).state = filtered2.map((e) => e.id).toList(); });

            final filteredTotal = filtered2.fold<int>(0, (prev, e) => prev + (e.type == EntryType.income ? e.amount : -e.amount));

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  // left group: selection toggle + previous month chevron (no extra spacing)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      icon: Icon(ref.watch(listSelectionModeProvider) ? Icons.check_box : Icons.check_box_outline_blank),
                      tooltip: ref.watch(listSelectionModeProvider) ? '選択モードを終了' : '選択モードを開始',
                      onPressed: () {
                        final mode = ref.read(listSelectionModeProvider);
                        if (mode) {
                          ref.read(listSelectionModeProvider.notifier).state = false;
                          ref.read(listSelectedEntryIdsProvider.notifier).state = <String>{};
                        } else {
                          ref.read(listSelectionModeProvider.notifier).state = true;
                        }
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(onPressed: () => setState(() => _selectedMonth = DateTime(month.year, month.month - 1, 1)), icon: const Icon(Icons.chevron_left)),
                  ],),

                  // center: month title
                  Expanded(child: Column(children: [Text('${month.year}年 ${month.month}月', style: Theme.of(context).textTheme.titleLarge), Text('合計: ¥${formatNumber(filteredTotal)}', style: TextStyle(color: filteredTotal >= 0 ? Colors.teal : Colors.redAccent))],),),

                  // right-side controls
                  Row(children: [
                    IconButton(onPressed: () { showDatePicker(context: context, initialDate: _selectedMonth, firstDate: DateTime(2000), lastDate: DateTime(2100)).then((picked) { if (picked != null) setState(() => _selectedMonth = DateTime(picked.year, picked.month, 1)); }); }, icon: const Icon(Icons.calendar_today)),
                    IconButton(onPressed: () => setState(() => _selectedMonth = DateTime(month.year, month.month + 1, 1)), icon: const Icon(Icons.chevron_right)),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (v) async {
                        switch (v) {
                          case 'export_month':
                            await _exportCsv(visible, idToName);
                            break;
                          case 'export_all':
                            await _exportAllCsv(entries, idToName);
                            break;
                          case 'import':
                            await _importFromFileOrPaste();
                            break;
                          case 'save_template':
                            await _saveAsTemplateForMonth(month, filtered2);
                            break;
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(value: 'export_month', child: Row(children: const [Icon(Icons.file_download), SizedBox(width: 8), Text('該当月をCSV出力')])),
                        PopupMenuItem(value: 'export_all', child: Row(children: const [Icon(Icons.cloud_download), SizedBox(width: 8), Text('全件エクスポート')])),
                        PopupMenuItem(value: 'import', child: Row(children: const [Icon(Icons.file_upload), SizedBox(width: 8), Text('CSV読み込み')])),
                        const PopupMenuDivider(),
                        PopupMenuItem(value: 'save_template', child: Row(children: const [Icon(Icons.save_alt), SizedBox(width: 8), Text('この月をテンプレートとして保存')])),
                      ],
                    ),
                    // bulk selection toggle (moved to left side)
                    // NOTE: the per-page inline bulk controls were removed; AppBar handles selection actions now.
                    
                  ]),
                ]),
                const SizedBox(height: 8),
                // Filter / Sort UI
                ExpansionTile(
                  title: const Text('フィルター・ソート'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(controller: _filterTitleController, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'タイトル（部分一致）')),
                          const SizedBox(height: 8),
                          Row(children: [
                            SizedBox(width: 120, child: TextField(controller: _filterMinController, onChanged: (_) => setState(() {}), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '金額（最小）'))),
                            const SizedBox(width: 12),
                            SizedBox(width: 120, child: TextField(controller: _filterMaxController, onChanged: (_) => setState(() {}), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '金額（最大）'))),
                          ]),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, children: [
                            FilterChip(label: const Text('収入'), selected: _filterTypes.contains(EntryType.income), onSelected: (s) => setState(() => s ? _filterTypes.add(EntryType.income) : _filterTypes.remove(EntryType.income))),
                            FilterChip(label: const Text('支出'), selected: _filterTypes.contains(EntryType.expense), onSelected: (s) => setState(() => s ? _filterTypes.add(EntryType.expense) : _filterTypes.remove(EntryType.expense))),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            TextButton.icon(onPressed: () { showDatePicker(context: context, initialDate: _filterStartDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100)).then((d) { if (d != null && mounted) setState(() => _filterStartDate = d); }); }, icon: const Icon(Icons.date_range), label: Text(_filterStartDate == null ? '開始日を選択' : formatDate(_filterStartDate!))),
                            const SizedBox(width: 8),
                            TextButton.icon(onPressed: () { showDatePicker(context: context, initialDate: _filterEndDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100)).then((d) { if (d != null && mounted) setState(() => _filterEndDate = d); }); }, icon: const Icon(Icons.date_range), label: Text(_filterEndDate == null ? '終了日を選択' : formatDate(_filterEndDate!))),
                            const SizedBox(width: 8),
                            TextButton(onPressed: () => setState(() { _filterStartDate = null; _filterEndDate = null; }), child: const Text('日付クリア')),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            const Text('カテゴリ:'),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () async {
                                await showDialog(context: context, builder: (ctx) {
                                  return StatefulBuilder(builder: (ctx2, setInner) {
                                    return AlertDialog(
                                      title: const Text('カテゴリで絞り込む'),
                                      content: SingleChildScrollView(
                                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                                          for (final c in cats)
                                            CheckboxListTile(
                                              value: _filterCategoryIds.contains(c['id']),
                                              title: Text((c['name'] ?? '').toString()),
                                              controlAffinity: ListTileControlAffinity.leading,
                                              onChanged: (v) {
                                                setInner(() {
                                                  final id = c['id'] as String?;
                                                  if (id == null) return;
                                                  if (v == true) {
                                                    _filterCategoryIds.add(id);
                                                  } else {
                                                    _filterCategoryIds.remove(id);
                                                  }
                                                  // also rebuild parent list UI
                                                  setState(() {});
                                                });
                                              },
                                            ),
                                        ]),
                                      ),
                                      actions: [
                                        TextButton(onPressed: () {
                                          // 全選択
                                          setInner(() {
                                            for (final c in cats) {
                                              final id = c['id'] as String?;
                                              if (id != null) _filterCategoryIds.add(id);
                                            }
                                            setState(() {});
                                          });
                                        }, child: const Text('全選択')),
                                        TextButton(onPressed: () {
                                          // 全解除
                                          setInner(() { _filterCategoryIds.clear(); setState(() {}); });
                                        }, child: const Text('全解除')),
                                        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('閉じる')),
                                      ],
                                    );
                                  });
                                });
                              },
                              child: Text(_filterCategoryIds.isEmpty ? 'カテゴリ: すべて' : 'カテゴリ: ${_filterCategoryIds.length} 個選択'),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            const Text('ソート:'),
                            const SizedBox(width: 8),
                            DropdownButton<String>(value: _sortField, items: const [DropdownMenuItem(value: 'date', child: Text('日付')), DropdownMenuItem(value: 'title', child: Text('タイトル')), DropdownMenuItem(value: 'amount', child: Text('金額')), DropdownMenuItem(value: 'category', child: Text('カテゴリ'))], onChanged: (v) => setState(() => _sortField = v ?? 'date')),
                            IconButton(onPressed: () => setState(() => _sortAsc = !_sortAsc), icon: Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward)),
                            const Spacer(),
                            TextButton(onPressed: () { setState(() { _filterTitleController.clear(); _filterMinController.clear(); _filterMaxController.clear(); _filterTypes.clear(); _filterStartDate = null; _filterEndDate = null; _filterCategoryIds.clear(); _sortField = 'date'; _sortAsc = false; }); }, child: const Text('クリア')),
                          ]),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                Expanded(
                  child: filtered2.isEmpty
                      ? const Center(child: Text('該当月のデータはありません'))
                      : ListView.builder(
                          itemCount: filtered2.length,
                          itemBuilder: (context, index) {
                            final e = filtered2[index];
                            final cat = idToName[e.category] ?? '';
                            final signed = e.type == EntryType.income ? e.amount : -e.amount;
                            return ListTile(
                              leading: ref.watch(listSelectionModeProvider)
                                  ? AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 180),
                                      transitionBuilder: (child, anim) => SizeTransition(sizeFactor: anim, axis: Axis.horizontal, child: child),
                                      child: Consumer(
                                        key: ValueKey('checkbox-${e.id}'),
                                        builder: (context, localRef, _) {
                                          final selected = localRef.watch(isEntrySelectedProvider(e.id));
                                          return Checkbox(value: selected, onChanged: (v) {
                                            final current = Set<String>.from(localRef.read(listSelectedEntryIdsProvider));
                                            if (v == true) {
                                              current.add(e.id);
                                            } else {
                                              current.remove(e.id);
                                            }
                                            localRef.read(listSelectedEntryIdsProvider.notifier).state = current;
                                          });
                                        },
                                      ),
                                    )
                                  : null,
                              onLongPress: () {
                                if (!ref.read(listSelectionModeProvider)) { ref.read(listSelectionModeProvider.notifier).state = true; }
                                final cur = Set<String>.from(ref.read(listSelectedEntryIdsProvider));
                                if (cur.contains(e.id)) { cur.remove(e.id); } else { cur.add(e.id); }
                                ref.read(listSelectedEntryIdsProvider.notifier).state = cur;
                              },
                              title: Text(e.title),
                              subtitle: Text('${cat.isNotEmpty ? '$cat • ' : ''}${formatDate(e.date)}'),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text('${signed >= 0 ? '+' : '-'}¥${formatNumber(signed.abs())}', style: TextStyle(color: signed >= 0 ? Colors.teal : Colors.redAccent)),
                                if (!ref.watch(listSelectionModeProvider)) IconButton(icon: const Icon(Icons.edit), onPressed: () async { await _showEditDialog(e, cats, idToName); }),
                                if (!ref.watch(listSelectionModeProvider)) IconButton(icon: const Icon(Icons.delete), onPressed: () async {
                                  final uid = ref.read(authStateProvider).asData?.value?.uid;
                                  if (uid == null) {
                                    if (!mounted) return;
                                    appScaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('未認証ユーザーです')));
                                    return;
                                  }
                                  final ok = await showDialog<bool>(context: context, builder: (dctx) => AlertDialog(title: const Text('削除確認'), content: const Text('この項目を削除してもよいですか？'), actions: [TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: Text('キャンセル')), TextButton(onPressed: () => Navigator.of(dctx).pop(true), child: Text('削除'))]));
                                  if (!context.mounted) return;
                                  if (ok == true) {
                                    try {
                                      final repo = ref.read(entryRepositoryProvider);
                                      await repo.deleteEntry(userId: uid, entryId: e.id);
                                    } catch (ex) {
                                      if (!mounted) return;
                                      appScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('削除エラー: $ex')));
                                    }
                                  }
                                }),
                              ]),
                            );
                          },
                        ),
                ),
              ]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Center(child: Text('カテゴリ取得エラー: $err')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('エラー: $err')),
    );
  }
}
