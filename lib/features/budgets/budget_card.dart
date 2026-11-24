import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/repository.dart';
import '../../core/format/money.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'budget_editor_sheet.dart';
import 'widgets/pace_widgets.dart';

class BudgetCard extends ConsumerWidget {
  const BudgetCard({super.key, required this.progress});

  final BudgetProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final color =
        progress.colorValue == null ? null : Color(progress.colorValue!);
    final barColor = progress.isOver
        ? expenseColor(context)
        : progress.isNearLimit
            ? const Color(0xFFEF6C00)
            : (color ?? scheme.primary);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showBudgetEditor(context, editing: progress),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconAvatar(
                    icon: iconFor(
                      progress.iconKey,
                      fallback: Icons.label_outline,
                    ),
                    color: color,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          progress.categoryName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          progress.isRecurring
                              ? 'Mọi tháng'
                              : 'Riêng tháng này',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(progress.ratio * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: barColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              PaceMarkerBar(progress: progress, color: barColor),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    formatVnd(progress.spent),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    ' / ${formatVnd(progress.limitAmount)}',
                    style: TextStyle(fontSize: 13, color: scheme.outline),
                  ),
                  const Spacer(),
                  if (progress.isOver)
                    _StatusChip(
                      label: 'Vượt ${formatVndShort(-progress.remaining)}',
                      color: expenseColor(context),
                      icon: Icons.error_outline,
                    )
                  else if (progress.isNearLimit)
                    _StatusChip(
                      label: 'Sắp hết',
                      color: const Color(0xFFEF6C00),
                      icon: Icons.warning_amber_outlined,
                    )
                  else
                    Text(
                      'Còn ${formatVndShort(progress.remaining)}',
                      style: TextStyle(fontSize: 12.5, color: scheme.outline),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              BudgetPaceRow(progress: progress),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nhãn trạng thái, luôn kèm biểu tượng để không chỉ dựa vào màu.
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
