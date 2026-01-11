import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/category_provider.dart';
import '../../data/entry_provider.dart';
import '../../utils/global_keys.dart';

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  final _controller = TextEditingController();
  int? _selectedNewColor;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // A palette of visually-separated colors (ints with alpha)
  static const List<int> _paletteColors = [
    0xFF2196F3, // blue
    0xFFF44336, // red
    0xFFFFC107, // amber
    0xFF4CAF50, // green
    0xFF9C27B0, // purple
    0xFF795548, // brown
    0xFF009688, // teal
    0xFFFF5722, // deep orange
    0xFF3F51B5, // indigo
    0xFFE91E63, // pink
    0xFFCDDC39, // lime
    0xFF00BCD4, // cyan
  ];

  int _pickUnusedColorFromList(List<Map<String, dynamic>> cats) {
    // Prefer colors that maximize perceptual distance from already-used colors.
    final used = <int>[];
    for (final c in cats) {
      final col = c['color'] is int ? (c['color'] as int) : 0;
      if (col != 0) used.add(col);
    }
    if (used.isEmpty) return _paletteColors.first;

    // Convert used colors to LAB once
    final usedLab = used.map((c) => _rgbToLab(Color(c))).toList();

    double bestScore = -1;
    int bestColor = _paletteColors.first;
    for (final candidate in _paletteColors) {
      final candLab = _rgbToLab(Color(candidate));
      // compute minimum distance to any used color
      double minDist = double.infinity;
      for (final ul in usedLab) {
        final d = _labDistance(candLab, ul);
        if (d < minDist) minDist = d;
      }
      // we prefer candidates with larger minDist
      if (minDist > bestScore) {
        bestScore = minDist;
        bestColor = candidate;
      }
    }
    return bestColor;
  }

  // Convert Color (ARGB) to LAB triplet
  List<double> _rgbToLab(Color color) {
    // from sRGB to XYZ then to LAB
    // Use explicit channel extraction to avoid deprecated Color accessors.
    final v = color.toARGB32();
    double r = ((v >> 16) & 0xFF) / 255.0;
    double g = ((v >> 8) & 0xFF) / 255.0;
    double b = (v & 0xFF) / 255.0;
    // sRGB gamma expansion
    r = r > 0.04045 ? math.pow((r + 0.055) / 1.055, 2.4).toDouble() : r / 12.92;
    g = g > 0.04045 ? math.pow((g + 0.055) / 1.055, 2.4).toDouble() : g / 12.92;
    b = b > 0.04045 ? math.pow((b + 0.055) / 1.055, 2.4).toDouble() : b / 12.92;
    // Observer = 2°, Illuminant = D65
    double x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047;
    double y = (r * 0.2126 + g * 0.7152 + b * 0.0722) / 1.00000;
    double z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883;

    double fx = x > 0.008856 ? math.pow(x, 1.0 / 3.0).toDouble() : (7.787 * x) + (16.0 / 116.0);
    double fy = y > 0.008856 ? math.pow(y, 1.0 / 3.0).toDouble() : (7.787 * y) + (16.0 / 116.0);
    double fz = z > 0.008856 ? math.pow(z, 1.0 / 3.0).toDouble() : (7.787 * z) + (16.0 / 116.0);

    final l = (116.0 * fy) - 16.0;
    final a = 500.0 * (fx - fy);
    final bLab = 200.0 * (fy - fz);
    return [l, a, bLab];
  }

  double _labDistance(List<double> a, List<double> b) {
    final dl = a[0] - b[0];
    final da = a[1] - b[1];
    final db = a[2] - b[2];
    return math.sqrt(dl * dl + da * da + db * db);
  }

  // Rich color picker: palette + HSV sliders
  Future<int?> _pickRichColorDialog({int? initial}) async {
    // convert initial int to HSV
    final initColor = Color(initial ?? _paletteColors.first);
    double hue = 0, sat = 1, val = 1;
    // initialize HSV
    final hsl = HSLColor.fromColor(initColor);
    hue = hsl.hue;
    sat = hsl.saturation;
    val = hsl.lightness; // HSL lightness used as approximation

  int previewColor() => _hsvToColor(hue, sat, val).toARGB32();

    final res = await showDialog<int>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('色を選択'),
        content: StatefulBuilder(builder: (ctx2, setState) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 72, height: 72, decoration: BoxDecoration(color: Color(previewColor()), shape: BoxShape.circle)),
                const SizedBox(height: 12),
                // quick palette
                Wrap(spacing: 8, runSpacing: 8, children: _paletteColors.map((c) {
                  return GestureDetector(
                    onTap: () {
                      final hc = HSLColor.fromColor(Color(c));
                      setState(() {
                        hue = hc.hue;
                        sat = hc.saturation;
                        val = hc.lightness;
                      });
                    },
                    child: Container(width: 36, height: 36, decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: Border.all(width: 1, color: Colors.white))),
                  );
                }).toList()),
                const SizedBox(height: 12),
                // Hue slider
                Row(children: [const Text('色相'), Expanded(child: Slider(value: hue, min: 0, max: 360, onChanged: (v) => setState(() => hue = v)))]),
                // Saturation
                Row(children: [const Text('彩度'), Expanded(child: Slider(value: sat, min: 0, max: 1, onChanged: (v) => setState(() => sat = v)))]),
                // Lightness/Value
                Row(children: [const Text('明度'), Expanded(child: Slider(value: val, min: 0, max: 1, onChanged: (v) => setState(() => val = v)))]),
              ],
            ),
          );
        }),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('キャンセル')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(previewColor()), child: const Text('選択')),
        ],
      );
    });
    return res;
  }

  // Convert HSV (here using H,S,V where V approximated by HSL lightness) to Color
  Color _hsvToColor(double h, double s, double v) {
    // We'll convert via HSL for simplicity using Flutter's HSLColor
    final hsl = HSLColor.fromAHSL(1.0, h.clamp(0.0, 360.0), s.clamp(0.0, 1.0), v.clamp(0.0, 1.0));
    return hsl.toColor();
  }

  Future<void> _add() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final authState = ref.read(authStateProvider);
    final user = authState.asData?.value;
    if (user == null) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('未認証ユーザーです')));
      return;
    }
    final uid = user.uid;
    final repo = ref.read(categoryRepositoryProvider);
    try {
      // Determine next order value: append to end
      final cats = ref.read(categoriesStreamProvider).maybeWhen(data: (v) => v, orElse: () => []);
  final nextOrder = (cats.isEmpty) ? 0 : (cats.map((e) => (e['order'] is int ? e['order'] as int : 0)).fold<int>(0, (prev, e) => e > prev ? e : prev) + 1);
  // choose a color: use explicitly-selected new color if present, otherwise pick an unused one
  final catsList = List<Map<String, dynamic>>.from(cats);
  final chosenColor = _selectedNewColor ?? _pickUnusedColorFromList(catsList);
  await repo.addCategory(userId: uid, name: name, order: nextOrder, color: chosenColor);
      _controller.clear();
      // After adding, recompute suggested color for the next new-category preview
      try {
        final catsAfter = ref.read(categoriesStreamProvider).maybeWhen(data: (v) => v, orElse: () => []);
        final suggested = _pickUnusedColorFromList(List<Map<String, dynamic>>.from(catsAfter));
        if (mounted) setState(() => _selectedNewColor = suggested);
      } catch (_) {}
    } catch (e) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('追加に失敗しました: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncCats = ref.watch(categoriesStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('カテゴリ編集')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(labelText: 'カテゴリ名'))),
                const SizedBox(width: 8),
                // Color preview / chooser for new category
                GestureDetector(
                  onTap: () async {
                    final c = await _pickRichColorDialog(initial: _selectedNewColor);
                    if (c != null) setState(() => _selectedNewColor = c);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(_selectedNewColor ?? 0xFF2196F3),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _add, child: const Text('追加')),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: asyncCats.when(
                data: (cats) {
                  // ensure the new-category color preview has a suggested color before the user adds
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    try {
                      final suggested = _pickUnusedColorFromList(List<Map<String, dynamic>>.from(cats));
                      if (_selectedNewColor == null) setState(() => _selectedNewColor = suggested);
                    } catch (_) {}
                  });
                  if (cats.isEmpty) return const Center(child: Text('カテゴリがありません'));
                  return ReorderableListView.builder(
                    itemCount: cats.length,
                    onReorder: (oldIndex, newIndex) async {
                      // Adjust index when removing
                      if (newIndex > oldIndex) newIndex -= 1;
                      final moved = cats[oldIndex];
                      final mutable = List.of(cats);
                      mutable.removeAt(oldIndex);
                      mutable.insert(newIndex, moved);
                      // Build orders map
                      final orders = <String, int>{};
                      for (var i = 0; i < mutable.length; i++) {
                        final id = mutable[i]['id'] as String?;
                        if (id != null) orders[id] = i;
                      }
                      final authState = ref.read(authStateProvider);
                      final user = authState.asData?.value;
                      if (user == null) {
                        if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('未認証ユーザーです')));
                        return;
                      }
                      try {
                        await ref.read(categoryRepositoryProvider).updateCategoriesOrder(userId: user.uid, orders: orders);
                      } catch (e) {
                        // Use global scaffold messenger key to avoid BuildContext across async gaps
                        appScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('並び替えの保存に失敗しました: $e')));
                      }
                    },
                    itemBuilder: (context, index) {
                      final c = cats[index];
                      final colorInt = (c['color'] is int) ? (c['color'] as int) : 0xFF2196F3;
                      final tileColor = Color(colorInt == 0 ? 0xFF2196F3 : colorInt);
                      return ListTile(
                        key: ValueKey(c['id']),
                        leading: CircleAvatar(backgroundColor: tileColor, child: const Icon(Icons.category, color: Colors.white)),
                        title: Text(c['name'] ?? ''),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showEditDialog(c),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              final authState = ref.read(authStateProvider);
                              final user = authState.asData?.value;
                              if (user == null) {
                                if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('未認証ユーザーです')));
                                return;
                              }
                              try {
                                await ref.read(categoryRepositoryProvider).deleteCategory(userId: user.uid, categoryId: c['id']);
                              } catch (e) {
                                appScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
                              }
                            },
                          ),
                        ]),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('読み込みに失敗しました: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(Map<String, dynamic> category) async {
    final id = category['id'] as String?;
    if (id == null) return;
    final nameController = TextEditingController(text: category['name'] ?? '');
    int selectedColor = (category['color'] as int?) ?? 0;

    // Get current categories so we can choose a good unused color (exclude this category)
    final catsRaw = ref.read(categoriesStreamProvider).maybeWhen(data: (v) => v, orElse: () => []);
    final catsList = List<Map<String, dynamic>>.from(catsRaw);
    final catsExcludingThis = catsList.where((c) => (c['id'] as String?) != id).toList();

    final pickedColor = await showDialog<int?>(context: context, builder: (ctx) {
      int current = selectedColor == 0 ? _pickUnusedColorFromList(catsExcludingThis) : selectedColor;
      return AlertDialog(
        title: const Text('カテゴリ編集'),
        content: StatefulBuilder(builder: (context, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: '名称')),
              const SizedBox(height: 12),
              Row(children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: Color(current == 0 ? 0xFF2196F3 : current), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await _pickRichColorDialog(initial: current == 0 ? null : current);
                    if (picked != null) setState(() => current = picked);
                  },
                  child: const Text('色を選択'),
                ),
              ]),
            ],
          );
        }),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('キャンセル')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(current), child: const Text('保存')),
        ],
      );
    });

    if (pickedColor != null) {
      final authState = ref.read(authStateProvider);
      final user = authState.asData?.value;
      if (user == null) {
        if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('未認証ユーザーです')));
        return;
      }
      try {
  // If the pickedColor is 0 treat as null (no color). Otherwise store pickedColor.
  final colorToSave = (pickedColor == 0) ? null : pickedColor;
  await ref.read(categoryRepositoryProvider).updateCategory(userId: user.uid, categoryId: id, name: nameController.text.trim(), color: colorToSave);
  // After changing a category color, refresh suggested new color
  try {
    final catsAfter = ref.read(categoriesStreamProvider).maybeWhen(data: (v) => v, orElse: () => []);
    final suggested = _pickUnusedColorFromList(List<Map<String, dynamic>>.from(catsAfter));
    setState(() => _selectedNewColor = suggested);
  } catch (_) {}
      } catch (e) {
        appScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    }
  }
}
