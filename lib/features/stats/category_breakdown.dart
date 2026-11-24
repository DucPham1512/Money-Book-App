import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/repository.dart';
import '../../core/format/money.dart';
import '../../core/icons.dart';
import '../../core/providers.dart';
import 'category_detail_screen.dart';

final _categoryTotalsProvider =
    StreamProvider.family<List<CategoryTotal>, int>((ref, monthKey) {
  return ref.watch(repositoryProvider).watchCategoryTotals(monthKey);
});

/// Cơ cấu chi tiêu theo danh mục.
///
/// Dùng thanh ngang xếp hạng thay vì biểu đồ tròn: danh mục do người dùng tự
/// thêm nên số lượng không giới hạn, mà quá 3-4 màu thì các lát bánh không còn
/// phân biệt được với nhau, nhất là với người mù màu. Ở dạng thanh, danh tính
/// đến từ nhãn chữ, còn màu chỉ mã hoá độ lớn (một tông, đậm dần).
class CategoryBreakdown extends ConsumerWidget {
  const CategoryBreakdown({super.key, required this.monthKey});

  final int monthKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(_categoryTotalsProvider(monthKey));
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chi theo danh mục',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        totals.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Lỗi: $e'),
          data: (list) {
            if (list.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 28,
                  ),
                  child: Center(
                    child: Text(
                      'Tháng này chưa có khoản chi nào',
                      style: TextStyle(color: scheme.outline),
                    ),
                  ),
                ),
              );
            }

            final grand = list.fold<int>(0, (sum, c) => sum + c.total);
            final max = list.first.total;

            return Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    for (final item in list)
                      _CategoryBar(
                        item: item,
                        maxValue: max,
                        grandTotal: grand,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CategoryDetailScreen(
                              categoryId: item.categoryId,
                              name: item.name,
                              monthKey: monthKey,
                              iconKey: item.iconKey,
                              colorValue: item.colorValue,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.item,
    required this.maxValue,
    required this.grandTotal,
    required this.onTap,
  });

  final CategoryTotal item;
  final int maxValue;
  final int grandTotal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = maxValue == 0 ? 0.0 : item.total / maxValue;
    final share = grandTotal == 0 ? 0.0 : item.total / grandTotal * 100;

    // Một tông duy nhất, đậm dần theo giá trị: đây là so sánh độ lớn chứ không
    // phải phân biệt danh tính, nên không cần bảng màu nhiều sắc.
    final barColor = Color.lerp(
      scheme.primary.withValues(alpha: 0.35),
      scheme.primary,
      ratio,
    )!;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  iconFor(item.iconKey, fallback: Icons.label_outline),
                  size: 16,
                  color: item.colorValue == null
                      ? scheme.onSurfaceVariant
                      : Color(item.colorValue!),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${share.toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
                const SizedBox(width: 10),
                Text(
                  formatVnd(item.total),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, size: 18, color: scheme.outline),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest.withValues(
                  alpha: 0.7,
                ),
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
