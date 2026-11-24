import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/repository.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/icons.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'fund_editor_sheet.dart';
import 'fund_transfer_sheet.dart';

/// Quỹ: tiền đã dành sẵn cho những khoản biết trước.
///
/// Màn hình trả lời ba câu: mình có quỹ gì, mỗi quỹ được bao nhiêu, và tiền
/// đang nằm ở ví nào.
class FundScreen extends ConsumerWidget {
  const FundScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final funds = ref.watch(fundsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quỹ')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showFundEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Lập quỹ'),
      ),
      body: funds.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.savings_outlined,
              title: 'Chưa có quỹ nào',
              message: 'Quỹ là tiền để dành cho khoản đã biết trước: tiền nhà '
                  'tháng sau, tiền điện, trả nợ ví trả sau. Tiền quỹ không '
                  'tính vào phần tiêu hằng ngày.',
              action: FilledButton.icon(
                onPressed: () => showFundEditor(context),
                icon: const Icon(Icons.add),
                label: const Text('Lập quỹ'),
              ),
            );
          }

          final total = list.fold<int>(0, (sum, f) => sum + f.saved);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              _TotalCard(total: total, count: list.length),
              const SizedBox(height: 20),
              for (final f in list) ...[
                _FundCard(progress: f),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              Text(
                'Tiền quỹ vẫn nằm trong ví của bạn, chỉ là đã có chỗ đến nên '
                'không được tính vào phần tiêu được. Bấm vào thẻ tổng tài sản '
                'ở màn Tổng quan để xem cả hai con số.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total, required this.count});

  final int total;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(
              'Đang để dành',
              style: TextStyle(color: scheme.outline, fontSize: 13),
            ),
            const SizedBox(height: 6),
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
              count == 1 ? 'Trong 1 quỹ' : 'Trong $count quỹ',
              style: TextStyle(color: scheme.outline, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _FundCard extends ConsumerWidget {
  const _FundCard({required this.progress});

  final FundProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final fund = progress.fund;
    final color = fund.colorValue == null ? null : Color(fund.colorValue!);
    final due = fund.dueDayKey;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showFundEditor(context, editing: progress),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconAvatar(
                    icon: iconFor(fund.iconKey, fallback: Icons.savings),
                    color: color,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fund.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Icon(
                              iconFor(
                                progress.walletIconKey,
                                fallback: Icons.wallet,
                              ),
                              size: 13,
                              color: scheme.outline,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                progress.walletName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.outline,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (progress.isComplete)
                    Icon(
                      Icons.check_circle,
                      size: 20,
                      color: incomeColor(context),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (progress.hasTarget) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.ratio,
                    minHeight: 8,
                    backgroundColor:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.8),
                    valueColor: AlwaysStoppedAnimation(
                      progress.isComplete
                          ? incomeColor(context)
                          : (color ?? scheme.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Text(
                    formatVnd(progress.saved),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (progress.hasTarget)
                    Text(
                      ' / ${formatVnd(progress.target!)}',
                      style: TextStyle(fontSize: 13, color: scheme.outline),
                    ),
                  const Spacer(),
                  if (progress.isComplete)
                    Text(
                      'Đủ rồi',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: incomeColor(context),
                      ),
                    )
                  else if (progress.missing != null)
                    Text(
                      'Còn thiếu ${formatVndShort(progress.missing!)}',
                      style: TextStyle(fontSize: 12.5, color: scheme.outline),
                    ),
                ],
              ),
              if (due != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 14,
                      color: scheme.outline,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Cần dùng ${formatDate(dayKeyToDate(due))}',
                      style: TextStyle(fontSize: 12, color: scheme.outline),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () =>
                          showFundTransferSheet(context, progress: progress),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nạp thêm'),
                    ),
                  ),
                  if (progress.saved > 0) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => showFundTransferSheet(
                          context,
                          progress: progress,
                          withdraw: true,
                        ),
                        icon: const Icon(Icons.undo, size: 18),
                        label: const Text('Rút ra'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----- Nạp / rút quỹ -------------------------------------------------------

// ----- Lập / sửa quỹ -------------------------------------------------------
