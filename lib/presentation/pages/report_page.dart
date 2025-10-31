import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

import '../../data/entry_provider.dart';
import '../../data/category_provider.dart';
import '../../domain/entry.dart';

/// ReportPage: restores legend at right, tooltips, calendar picker, nicer axes and responsive layout.
class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  DateTime _selectedMonth = DateTime.now();
  int _monthsToShow = 6;
  int? _touchedPieIndex;

  @override
  Widget build(BuildContext context) {
    final asyncEntries = ref.watch(firestoreEntriesStreamProvider);
    final asyncCats = ref.watch(categoriesStreamProvider);

    return asyncEntries.when(
      data: (entries) {
        return asyncCats.when(
          data: (cats) {
            final idToName = <String, String>{};
            final idToColor = <String, int>{};
            for (final c in cats) {
              final id = c['id']?.toString() ?? '';
              final name = c['name']?.toString() ?? id;
              final colorInt = (c['color'] is int) ? (c['color'] as int) : 0;
              if (id.isNotEmpty) {
                idToName[id] = name;
                idToColor[id] = colorInt;
              }
            }

            // aggregate for selected month (category expenses)
            final monthExpenses = <String, int>{};
            for (final e in entries) {
              if (e.date.year == _selectedMonth.year && e.date.month == _selectedMonth.month) {
                if (e.type == EntryType.expense) {
                  final key = e.category;
                  monthExpenses[key] = (monthExpenses[key] ?? 0) + e.amount;
                }
              }
            }

            // nets for recent months
            final monthNets = <double>[];
            final monthLabels = <String>[];
            for (int i = _monthsToShow - 1; i >= 0; i--) {
              final dt = DateTime(_selectedMonth.year, _selectedMonth.month - i, 1);
              final y = dt.year;
              final m = dt.month;
              monthLabels.add('$m月');
              var net = 0;
              for (final e in entries) {
                if (e.date.year == y && e.date.month == m) net += (e.type == EntryType.income) ? e.amount : -e.amount;
              }
              monthNets.add(net.toDouble());
            }

            return SingleChildScrollView(
              child: Padding(
                // move up slightly (reduce top padding by 9px)
                padding: const EdgeInsets.fromLTRB(12, 3, 12, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Top controls: month selector and months-to-show
                Row(children: [
                  IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1))),
                  GestureDetector(
                    onTap: _pickYearMonth,
                    child: Text('${_selectedMonth.year}年 ${_selectedMonth.month}月', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _pickYearMonth),
                  IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1))),
                  const Spacer(),
                ]),

                const SizedBox(height: 12),

                // Charts area: pie + legend (legend ALWAYS on the right).
                // To avoid clipping on very narrow screens (iPhone SE), we render pie + legend
                // in a horizontal Row wrapped by a horizontal SingleChildScrollView so the
                // user can scroll sideways to see the full legend while keeping it on the right.
                LayoutBuilder(builder: (context, constraints) {
                  // compute a small pie size for narrow widths so the row looks reasonable
                  final pieSize = math.min(180.0, constraints.maxWidth * 0.38);

                  if (monthExpenses.isEmpty) {
                    return SizedBox(
                      height: pieSize,
                      child: Center(child: Text('当月の支出データがありません')),
                    );
                  }

                  final pie = SizedBox(
                    width: pieSize,
                    height: pieSize,
                    child: PieChart(
                      PieChartData(
                        sections: _pieSectionsFromMap(monthExpenses, idToName, idToColor, pieSize),
                        sectionsSpace: 2,
                        centerSpaceRadius: pieSize * 0.18,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, resp) {
                            setState(() {
                              final idx = resp?.touchedSection?.touchedSectionIndex;
                              _touchedPieIndex = idx;
                            });
                          },
                        ),
                      ),
                    ),
                  );

                  final legend = _buildLegend(monthExpenses, idToName, idToColor);

                  // width allocated to legend: try to use remaining space but allow it to expand
                  final legendWidth = math.max(140.0, constraints.maxWidth * 0.45);

                  // Ensure legend area has bounded height (pieSize) and scrolls vertically
                  final legendBox = SizedBox(
                    width: legendWidth,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: pieSize),
                      child: SingleChildScrollView(child: legend),
                    ),
                  );

                  // Keep horizontal scroll to avoid clipping on extremely narrow screens,
                  // but legend itself will not grow vertically beyond pieSize.
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      pie,
                      const SizedBox(width: 12),
                      legendBox,
                    ]),
                  );
                }),

                const SizedBox(height: 20),

                // Recent months bar chart
                Row(children: [
                  Text('直近 $_monthsToShow ヶ月の収支', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  const Text('表示月数:'),
                  const SizedBox(width: 6),
                  DropdownButton<int>(
                    value: _monthsToShow,
                    items: const [3, 6, 12].map((v) => DropdownMenuItem<int>(value: v, child: Text('$v'))).toList(),
                    onChanged: (v) => setState(() { if (v != null) _monthsToShow = v; }),
                  ),
                ]),
                const SizedBox(height: 8),
                SizedBox(
                  height: 240,
                  child: monthNets.every((v) => v == 0)
                      ? Center(child: Text('過去$_monthsToShowヶ月のデータがありません'))
                      : BarChart(_barChartData(monthNets, monthLabels)),
                ),
              ]),
            ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('カテゴリ取得エラー: $e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('エラー: $err')),
    );
  }

  // legend builder placed to the right on wide screens
  Widget _buildLegend(Map<String, int> monthExpenses, Map<String, String> idToName, Map<String, int> idToColor) {
    final fallback = Colors.primaries.map((c) => c.shade400).toList();
    final total = monthExpenses.values.fold<int>(0, (a, b) => a + b);
    final entries = monthExpenses.entries.toList();
    return Wrap(spacing: 8, runSpacing: 8, children: List.generate(entries.length, (i) {
      final e = entries[i];
      final key = e.key;
      final value = e.value;
      final name = idToName[key] ?? key;
      final percent = total == 0 ? 0 : ((value / total) * 100).round();
      final colorInt = idToColor[key] ?? 0;
      final color = colorInt == 0 ? fallback[i % fallback.length] : Color(colorInt);
      return SizedBox(
        width: 160,
        child: Row(children: [
          Container(width: 14, height: 14, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text('$name ($percent%)', style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
      );
    }));
  }

  List<PieChartSectionData> _pieSectionsFromMap(Map<String, int> map, Map<String, String> idToName, Map<String, int> idToColor, double pieSize) {
    final fallback = Colors.primaries.map((c) => c.shade400).toList();
    final entries = map.entries.toList();
    final total = map.values.fold<int>(0, (a, b) => a + b);
    return List.generate(entries.length, (i) {
      final e = entries[i];
      final value = e.value.toDouble();
      final name = idToName[e.key] ?? e.key;
      final isTouched = (_touchedPieIndex != null && _touchedPieIndex == i);
      final title = isTouched ? '$name\n${(total == 0 ? 0 : (value / total * 100).round())}%' : '';
      final colorInt = idToColor[e.key] ?? 0;
      final color = colorInt == 0 ? fallback[i % fallback.length] : Color(colorInt);
      return PieChartSectionData(
        color: color,
        value: value,
        title: title,
        radius: isTouched ? pieSize * 0.4 : pieSize * 0.33,
        titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
      );
    });
  }

  // Format with thousands separators (000 style)
  String _formatNumber(double v) {
    final vi = v.round().abs();
    final s = vi.toString();
    final reg = RegExp(r"\B(?=(\d{3})+(?!\d))");
    final withComma = s.replaceAllMapped(reg, (m) => ',');
    return (v < 0 ? '-' : '') + withComma;
  }

  // Nice ceil for axis
  double _niceCeil(double v) {
    if (v <= 0) return 1000.0;
    final p = v.abs();
    final exp = (p == 0) ? 0 : (math.log(p) / math.ln10).floor();
    final mag = math.pow(10, exp).toDouble();
    final norm = p / mag;
    double nice;
    if (norm <= 1) {
      nice = 1 * mag;
    } else if (norm <= 2) {
      nice = 2 * mag;
    } else if (norm <= 5) {
      nice = 5 * mag;
    } else {
      nice = 10 * mag;
    }
    return nice;
  }

  BarChartData _barChartData(List<double> nets, List<String> labels) {
    final maxAbs = nets.map((v) => v.abs()).fold<double>(0, (a, b) => a > b ? a : b);
    final top = _niceCeil(maxAbs);
    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: top,
      minY: -top,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final label = labels[group.x.toInt()];
            final value = rod.toY;
            return BarTooltipItem('$label\n${_formatNumber(value)}', const TextStyle(color: Colors.white, fontSize: 12));
          },
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 56,
          getTitlesWidget: (v, meta) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text(_formatNumber(v), style: const TextStyle(fontSize: 10)),
            );
          },
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) {
          final idx = v.toInt();
          if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
          return Text(labels[idx], style: const TextStyle(fontSize: 12));
        })),
      ),
      borderData: FlBorderData(show: false),
      barGroups: List.generate(nets.length, (i) {
        final v = nets[i];
        return BarChartGroupData(x: i, barRods: [BarChartRodData(toY: v, color: v >= 0 ? Colors.teal : Colors.redAccent, width: 18)]);
      }),
    );
  }

  // Year-Month picker dialog (returns when user confirms)
  Future<void> _pickYearMonth() async {
    final now = DateTime.now();
    final startYear = 2000;
    int selectedYear = _selectedMonth.year;
    int selectedMonth = _selectedMonth.month;
    final endYear = (now.year > selectedYear) ? now.year : selectedYear;
    final years = List<int>.generate(endYear - startYear + 1, (i) => startYear + i).reversed.toList();

    final res = await showDialog<bool>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('年月を選択'),
        content: StatefulBuilder(builder: (ctx2, setState) {
          return Row(children: [
            DropdownButton<int>(value: selectedYear, items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(), onChanged: (v) => setState(() => selectedYear = v ?? selectedYear)),
            const SizedBox(width: 12),
            DropdownButton<int>(value: selectedMonth, items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(value: m, child: Text('$m'))).toList(), onChanged: (v) => setState(() => selectedMonth = v ?? selectedMonth)),
          ]);
        }),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('キャンセル')), ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('OK'))],
      );
    });

    if (res == true) setState(() => _selectedMonth = DateTime(selectedYear, selectedMonth, 1));
  }
}
