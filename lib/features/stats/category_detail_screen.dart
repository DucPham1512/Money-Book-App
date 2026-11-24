import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/repository.dart';
import '../../core/domain/daily_totals.dart';
import '../../core/domain/tx_kind.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/icons.dart';
import '../../core/providers.dart';
import '../transactions/tx_editor_screen.dart';
import '../transactions/tx_tile.dart';
import 'daily_chart_card.dart';

/// Khoá của một danh mục trong một tháng. `categoryId` null là "Chưa phân loại".
typedef _CategoryMonth = ({int? categoryId, int monthKey});

final _categoryExpensesProvider =
    StreamProvider.family<List<TxView>, _CategoryMonth>((ref, key) {
      return ref
          .watch(repositoryProvider)
          .watchTransactions(
            categoryId: key.categoryId,
            uncategorized: key.categoryId == null,
            monthKey: key.monthKey,
            kind: TxKind.expense,
          );
    });

/// Toàn bộ khoản chi của một danh mục trong tháng, kèm biểu đồ theo ngày.
class CategoryDetailScreen extends ConsumerStatefulWidget {
  const CategoryDetailScreen({
    super.key,
    required this.categoryId,
    required this.name,
    required this.monthKey,
    this.iconKey,
    this.colorValue,
  });

  final int? categoryId;
  final String name;
  final int monthKey;
  final String? iconKey;
  final int? colorValue;

  @override
  ConsumerState<CategoryDetailScreen> createState() =>
      _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends ConsumerState<CategoryDetailScreen> {
  bool _cumulative = false;

  /// Ngày đang chọn trên biểu đồ (1-based), null là ngày cuối cùng.
  int? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final key = (categoryId: widget.categoryId, monthKey: widget.monthKey);
    final txs = ref.watch(_categoryExpensesProvider(key));
    final today = ref.watch(todayProvider);
    final budgets =
        ref.watch(budgetsProvider(widget.monthKey)).valueOrNull ?? const [];
    final budget = widget.categoryId == null
        ? null
        : budgets.where((b) => b.categoryId == widget.categoryId).firstOrNull;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              iconFor(widget.iconKey, fallback: Icons.label_outline),
              size: 20,
              color: widget.colorValue == null
                  ? scheme.onSurfaceVariant
                  : Color(widget.colorValue!),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: txs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (list) {
          final monthDays = daysInMonth(widget.monthKey);
          final elapsed = daysElapsedIn(widget.monthKey, now: today);
          // Khoản ghi trước cho ngày sau hôm nay vẫn phải hiện ra được.
          final lastDataDay = list.fold<int>(
            0,
            (m, v) => math.max(m, v.tx.dayKey % 100),
          );
          final shownDays = math.max(
            1,
            math.min(monthDays, math.max(elapsed, lastDataDay)),
          );
          final daily = dailyTotals(list, widget.monthKey, shownDays);
          final total = daily.fold<int>(0, (s, v) => s + v);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                monthKeyLabel(widget.monthKey),
                style: TextStyle(color: scheme.outline, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                formatVnd(total),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _summaryLine(list.length, total, elapsed, budget),
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ChartCard(
                daily: daily,
                monthDays: monthDays,
                budget: budget,
                cumulative: _cumulative,
                selectedDay: _selectedDay,
                onModeChanged: (v) => setState(() => _cumulative = v),
                onSelectDay: (d) => setState(() => _selectedDay = d),
              ),
              const SizedBox(height: 20),
              Text(
                'Các khoản chi',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              if (list.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        'Tháng này chưa có khoản chi nào',
                        style: TextStyle(color: scheme.outline),
                      ),
                    ),
                  ),
                )
              else
                ..._dayGroups(context, list),
            ],
          );
        },
      ),
    );
  }

  String _summaryLine(
    int count,
    int total,
    int elapsed,
    BudgetProgress? budget,
  ) {
    final parts = <String>['$count khoản'];
    if (elapsed > 0) {
      parts.add('trung bình ${formatVndShort(total ~/ elapsed)}/ngày');
    }
    if (budget != null) {
      parts.add(
        budget.isOver
            ? 'vượt hạn mức ${formatVndShort(-budget.remaining)}'
            : 'còn ${formatVndShort(budget.remaining)} / '
                  '${formatVndShort(budget.limitAmount)}',
      );
    }
    return parts.join(' · ');
  }

  /// Danh sách gom theo ngày, mới nhất lên đầu, mỗi nhóm có tổng của ngày.
  List<Widget> _dayGroups(BuildContext context, List<TxView> list) {
    final scheme = Theme.of(context).colorScheme;
    final groups = <int, List<TxView>>{};
    for (final v in list) {
      groups.putIfAbsent(v.tx.dayKey, () => []).add(v);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return [
      for (final day in days) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  dayHeaderLabel(day),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                formatVnd(groups[day]!.fold<int>(0, (s, v) => s + v.tx.amount)),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < groups[day]!.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 68),
                TxTile(
                  view: groups[day]![i],
                  onTap: () => openTxEditor(context, editing: groups[day]![i]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }
}
