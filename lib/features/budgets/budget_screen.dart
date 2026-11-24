import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/repository.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'budget_card.dart';
import 'budget_editor_sheet.dart';
import 'widgets/pace_widgets.dart';

/// Hạn mức chi tiêu theo từng danh mục, kèm tiến độ trong tháng.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthKey = ref.watch(selectedMonthProvider);
    final budgets = ref.watch(budgetsProvider(monthKey));
    // Số dư ví hôm nay chỉ có nghĩa với tháng này.
    final isCurrent = monthKey == monthKeyOf(ref.watch(todayProvider));
    final cash = isCurrent
        ? ref.watch(spendableAssetsProvider).valueOrNull
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ngân sách'),
        actions: const [
          InfoButton(
            title: 'Ngân sách tính gì',
            points: [
              'Chỉ tính khoản chi của chính bạn.',
              'Tiền trả dùm người khác vào sổ nợ, không làm vượt hạn mức.',
              'Ví còn ít hơn hạn mức thì mức mỗi ngày tính theo tiền thật.',
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBudgetEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Đặt hạn mức'),
      ),
      body: budgets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.savings_outlined,
              title: 'Chưa đặt hạn mức nào',
              message: 'Biết sớm khi sắp tiêu quá tay',
              action: FilledButton.icon(
                onPressed: () => showBudgetEditor(context),
                icon: const Icon(Icons.add),
                label: const Text('Đặt hạn mức'),
              ),
            );
          }

          final totalLimit =
              list.fold<int>(0, (sum, b) => sum + b.limitAmount);
          final totalSpent = list.fold<int>(0, (sum, b) => sum + b.spent);
          final totalReserved = list.fold<int>(
            0,
            (sum, b) => sum + (b.reserved > 0 ? b.reserved : 0),
          );
          final totalAfterToday = list.fold<int>(
            0,
            (sum, b) =>
                sum + (b.spendableAfterToday > 0 ? b.spendableAfterToday : 0),
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              _MonthHeader(monthKey: monthKey),
              const SizedBox(height: 12),
              _OverallCard(
                limit: totalLimit,
                spent: totalSpent,
                reserved: totalReserved,
                afterToday: totalAfterToday,
                monthKey: monthKey,
                cash: cash,
              ),
              const SizedBox(height: 20),
              for (final b in list) ...[
                BudgetCard(progress: b),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MonthHeader extends ConsumerWidget {
  const _MonthHeader({required this.monthKey});

  final int monthKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrent = monthKey == monthKeyOf(ref.watch(todayProvider));

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Tháng trước',
          onPressed: () => ref.read(selectedMonthProvider.notifier).state =
              previousMonthKey(monthKey),
        ),
        Expanded(
          child: Center(
            child: Text(
              monthKeyLabel(monthKey),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Tháng sau',
          onPressed: isCurrent
              ? null
              : () => ref.read(selectedMonthProvider.notifier).state =
                  nextMonthKey(monthKey),
        ),
      ],
    );
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({
    required this.limit,
    required this.spent,
    required this.reserved,
    required this.afterToday,
    required this.monthKey,
    this.cash,
  });

  final int limit;
  final int spent;

  /// Tổng phần các hạn mức còn giữ. Cộng từ từng mục chứ không tính lại trên
  /// tổng, vì mục tiêu dư không bù được cho mục tiêu lố.
  final int reserved;

  /// Tổng phần để dành cho những ngày sau hôm nay, đã chặn bằng tiền thật.
  final int afterToday;
  final int monthKey;

  /// Tiền tiêu được trong ví, null nếu không xét (tháng đã qua).
  final int? cash;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remaining = limit - spent;
    final over = spent > limit;

    // Gộp mọi hạn mức lại thành một tiến độ chung để nói về nhịp tổng thể.
    // Chặn bằng tổng phần để dành của từng mục để mức mỗi ngày khớp các mục:
    // tiền dư đã sang tiền tự do, và từng mục đã được chặn bằng tiền thật.
    final limitedByCash = cash != null && reserved > 0 && cash! < reserved;
    final overall = BudgetProgress(
      budgetId: -1,
      categoryId: -1,
      categoryName: '',
      limitAmount: limit,
      spent: spent,
      isRecurring: true,
      monthKey: monthKey,
      daysInMonth: daysInMonth(monthKey),
      daysElapsed: daysElapsedIn(monthKey),
    ).withCashCap(afterToday);

    return Card(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(
              over ? 'Đã vượt tổng hạn mức' : 'Còn lại trong tháng',
              style: TextStyle(color: scheme.outline, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              formatVnd(remaining.abs()),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: over ? expenseColor(context) : scheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 14),
            PaceMarkerBar(
              progress: overall,
              color: over ? expenseColor(context) : scheme.primary,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Đã tiêu ${formatVnd(spent)}',
                  style: TextStyle(fontSize: 12.5, color: scheme.outline),
                ),
                Text(
                  'Hạn mức ${formatVnd(limit)}',
                  style: TextStyle(fontSize: 12.5, color: scheme.outline),
                ),
              ],
            ),
            if (!overall.isPastMonth && overall.daysRemaining > 0) ...[
              const SizedBox(height: 12),
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      overall.spendable > 0
                          ? 'Còn ${overall.daysRemaining} ngày · '
                                '${formatVnd(overall.remainingDailyAllowance)}'
                                '/ngày'
                          : overall.remaining > 0
                          ? 'Còn ${overall.daysRemaining} ngày · ví hết tiền'
                          : 'Còn ${overall.daysRemaining} ngày · hết hạn mức',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _PaceBadge(pace: overall.pace),
                ],
              ),
              if (limitedByCash) ...[
                const SizedBox(height: 10),
                Text(
                  'Ví chỉ còn ${formatVnd(cash!)}, ít hơn hạn mức còn lại',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: paceStyle(context, BudgetPace.fast).color,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Nhãn ngắn cho nhịp độ, dùng ở chỗ chật.
class _PaceBadge extends StatelessWidget {
  const _PaceBadge({required this.pace});

  final BudgetPace pace;

  @override
  Widget build(BuildContext context) {
    final style = paceStyle(context, pace);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 13, color: style.color),
          const SizedBox(width: 4),
          Text(
            style.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: style.color,
            ),
          ),
        ],
      ),
    );
  }
}
