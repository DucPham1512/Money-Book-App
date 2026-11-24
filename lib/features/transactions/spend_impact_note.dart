import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/free_money.dart';
import '../../core/format/money.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

/// Nói trước khi bấm Ghi: khoản chi này lấy tiền từ đâu.
///
/// Nằm gọn trong hạn mức, lấy từ tiền tự do, hay đang lấn vào tiền đã giữ cho
/// ngân sách — cái cuối là lúc nên nhịn, và phải biết TRƯỚC khi tiêu chứ không
/// phải sau khi đã ghi.
class SpendImpactNote extends ConsumerWidget {
  const SpendImpactNote({
    super.key,
    required this.amount,
    required this.categoryId,
    this.outside = 0,
  });

  /// Phần tính vào danh mục [categoryId].
  final int amount;
  final int? categoryId;

  /// Phần nằm ngoài ngân sách, như tiền trả dùm hoặc cho mượn.
  final int outside;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (amount + outside <= 0) return const SizedBox.shrink();
    final money = ref.watch(freeMoneyProvider).valueOrNull;
    final budgets = ref.watch(currentBudgetsProvider).valueOrNull;
    if (money == null || budgets == null) return const SizedBox.shrink();

    final budget = categoryId == null
        ? null
        : budgets.where((b) => b.categoryId == categoryId).firstOrNull;
    final impact = money.preview(
      amount: amount,
      budget: budget,
      outside: outside,
    );

    final scheme = Theme.of(context).colorScheme;
    final warn = const Color(0xFFEF6C00);
    final (icon, color, text) = _describe(context, money, impact, warn);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (color ?? scheme.primary).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color ?? scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: color == null ? null : FontWeight.w500,
                color: color ?? scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color?, String) _describe(
    BuildContext context,
    FreeMoney money,
    SpendImpact i,
    Color warn,
  ) {
    // Một dòng, con số đi trước.
    final inBudget = i.fromBudget > 0 && i.budgetName != null
        ? '${formatVnd(i.fromBudget)} trong hạn mức ${i.budgetName} · '
        : '';

    if (i.fromReserve > 0) {
      final protected = money.reserves.map((r) => r.name).join(', ');
      return (
        Icons.warning_amber_rounded,
        expenseColor(context),
        '$inBudget${money.isExhausted ? 'Hết tiền tự do · ' : ''}'
            'Lấn ${formatVnd(i.fromReserve)} vào tiền giữ cho '
            '${protected.isEmpty ? 'nợ phải trả' : protected}',
      );
    }

    if (i.fromFree > 0) {
      final text =
          '$inBudget${formatVnd(i.fromFree)} từ tiền tự do · '
          'còn ${formatVnd(i.freeAfter)}';
      if (i.overToday) {
        return (Icons.trending_up, warn, '$text · quá mốc hôm nay');
      }
      return (Icons.bolt, null, text);
    }

    return (
      Icons.check_circle_outline,
      null,
      'Trong hạn mức ${i.budgetName} · còn '
          '${formatVnd(i.budgetLeftAfter ?? 0)}',
    );
  }
}
