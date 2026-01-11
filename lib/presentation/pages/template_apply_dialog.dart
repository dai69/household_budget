import 'package:flutter/material.dart';
import '../../domain/template.dart';

class TemplateApplyDialog extends StatefulWidget {
  final Template template;
  const TemplateApplyDialog({super.key, required this.template});

  @override
  State<TemplateApplyDialog> createState() => _TemplateApplyDialogState();
}

class _TemplateApplyDialogState extends State<TemplateApplyDialog> {
  DateTime _selected = DateTime.now();
  List<bool> _include = [];
  final Set<int> _duplicates = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _include = List<bool>.filled(widget.template.items.length, true);
    _computeDuplicates();
  }

  String _formatNumber(int v) {
    final vi = v.abs();
    final s = vi.toString();
    final reg = RegExp(r"\B(?=(\d{3})+(?!\d))");
    final withComma = s.replaceAllMapped(reg, (m) => ',');
    return (v < 0 ? '-' : '') + withComma;
  }

  Future<void> _computeDuplicates() async {
    setState(() => _loading = true);
    // Duplication check is performed at apply time in the service; keep UI responsive.
    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('テンプレート適用'),
      content: SizedBox(
        width: 640,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Text('対象月:'),
            const SizedBox(width: 8),
            TextButton(onPressed: () async {
              final picked = await showDatePicker(context: context, initialDate: _selected, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (picked != null) setState(() => _selected = picked);
            }, child: Text('${_selected.year}年 ${_selected.month}月')),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: _loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
              shrinkWrap: true,
              itemCount: widget.template.items.length,
              itemBuilder: (context, index) {
                final it = widget.template.items[index];
                final isDup = _duplicates.contains(index);
                return ListTile(
                  tileColor: isDup ? const Color(0xFFFFF7E6) : null,
                  title: Text('${it.dayOfMonth ?? 1}日 • ${it.title} • ${it.type == EntryTypeEnum.income ? '収入' : '支出'}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${it.type == EntryTypeEnum.income ? '+' : '-'}¥${_formatNumber(it.amount)}', style: TextStyle(color: it.type == EntryTypeEnum.income ? Colors.teal : Colors.redAccent)),
                    const SizedBox(width: 8),
                    Switch(value: _include[index], onChanged: (v) => setState(() => _include[index] = v)),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('キャンセル')),
        TextButton(onPressed: () => Navigator.of(context).pop({'date': _selected, 'include': _include}), child: const Text('適用')),
      ],
    );
  }
}
