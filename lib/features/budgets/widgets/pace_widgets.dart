import 'package:flutter/material.dart';

import '../../../core/db/repository.dart';
import '../../../core/format/money.dart';
import '../../../core/theme.dart';

/// Thanh tiến độ kèm một vạch đánh dấu vị trí "đáng lẽ đang ở đây".
///
/// Vạch nằm ở chỗ tương ứng với phần tháng đã trôi qua. Phần tô vượt qua vạch
/// nghĩa là đang tiêu nhanh hơn nhịp — nhìn một cái là thấy, không cần đọc số.
class PaceMarkerBar extends StatelessWidget {
  const PaceMarkerBar({
    super.key,
    required this.progress,
    required this.color,
    this.height = 8,
  });

  final BudgetProgress progress;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showMarker = !progress.isPastMonth &&
        progress.daysElapsed > 0 &&
        progress.daysElapsed < progress.daysInMonth;
    final markerAt = progress.daysInMonth == 0
        ? 0.0
        : progress.daysElapsed / progress.daysInMonth;

    return SizedBox(
      height: height + 6,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.ratio.clamp(0.0, 1.0),
              minHeight: height,
              backgroundColor:
                  scheme.surfaceContainerHighest.withValues(alpha: 0.8),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          if (showMarker)
            LayoutBuilder(
              builder: (context, constraints) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: (constraints.maxWidth * markerAt)
                        .clamp(0.0, constraints.maxWidth - 2),
                  ),
                  child: Container(
                    width: 2,
                    height: height + 6,
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Màu và biểu tượng ứng với từng tình trạng nhịp độ.
///
/// Luôn đi kèm biểu tượng và chữ, không bao giờ chỉ dựa vào màu.
/// Cảnh báo tiền thật trong ví không còn đủ cho phần còn lại của hạn mức.
///
/// Hạn mức chỉ đếm chi tiêu của đúng danh mục đó, nên tiêu lố ở chỗ khác thì
/// hạn mức vẫn báo "còn nhiều" trong khi ví đã cạn. Dòng này nói thẳng ra.
class CashLimitNote extends StatelessWidget {
  const CashLimitNote({super.key, required this.progress});

  final BudgetProgress progress;

  @override
  Widget build(BuildContext context) {
    if (!progress.isLimitedByCash) return const SizedBox.shrink();
    final style = paceStyle(context, BudgetPace.fast);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            Icons.account_balance_wallet_outlined,
            size: 14,
            color: style.color,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Tiền trong ví chỉ còn đủ ${formatVnd(progress.spendable)} cho '
            'mục này, ít hơn ${formatVnd(progress.reserved)} hạn mức còn '
            'giữ — phần chênh đã tiêu sang khoản khác.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: style.color,
            ),
          ),
        ),
      ],
    );
  }
}

({Color color, IconData icon, String label}) paceStyle(
  BuildContext context,
  BudgetPace pace,
) {
  return switch (pace) {
    BudgetPace.over => (
        color: expenseColor(context),
        icon: Icons.error_outline,
        label: 'Đã vượt',
      ),
    BudgetPace.fast => (
        color: const Color(0xFFEF6C00),
        icon: Icons.trending_up,
        label: 'Tiêu nhanh',
      ),
    BudgetPace.onTrack => (
        color: Theme.of(context).colorScheme.primary,
        icon: Icons.check_circle_outline,
        label: 'Đúng nhịp',
      ),
    BudgetPace.slow => (
        color: incomeColor(context),
        icon: Icons.trending_down,
        label: 'Đang dư dả',
      ),
  };
}

/// Phần nói về nhịp độ tiêu tiền của một hạn mức.
///
/// Trả lời hai câu hỏi mà con số "đã tiêu bao nhiêu" không trả lời được:
/// tiêu như vậy có nhanh quá so với thời điểm này của tháng không, và những
/// ngày còn lại được tiêu bao nhiêu mỗi ngày thì vừa đủ.
class BudgetPaceRow extends StatelessWidget {
  const BudgetPaceRow({super.key, required this.progress});

  final BudgetProgress progress;

  @override
  Widget build(BuildContext context) {
    if (progress.isPastMonth) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final style = paceStyle(context, progress.pace);
    final canStillSpend = progress.daysRemaining > 0 && progress.spendable > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(style.icon, size: 16, color: style.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _headline(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: style.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            canStillSpend
                ? 'Còn ${progress.daysRemaining} ngày, tiêu dưới '
                    '${formatVnd(progress.remainingDailyAllowance)} mỗi ngày '
                    'thì vừa đủ.'
                : _fallbackDetail(),
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          if (progress.isLimitedByCash) ...[
            const SizedBox(height: 6),
            CashLimitNote(progress: progress),
          ],
          if (progress.pace == BudgetPace.fast &&
              progress.daysUntilRunOut != null) ...[
            const SizedBox(height: 4),
            Text(
              // Nói số ngày còn cầm cự được, vì "hết tiền vào ngày 10" nghe
              // như còn xa trong khi thực ra chỉ còn vài hôm nữa.
              progress.daysUntilRunOut == 0
                  ? 'Giữ nhịp này thì hôm nay là hết tiền.'
                  : 'Giữ nhịp này thì khoảng ${progress.daysUntilRunOut} ngày '
                      'nữa là hết, tức ngày ${progress.projectedRunOutDay}.',
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
          ],
        ],
      ),
    );
  }

  String _headline() {
    final avg = formatVndShort(progress.dailyAverage);
    final allowance = formatVndShort(progress.dailyAllowance);

    return switch (progress.pace) {
      BudgetPace.over =>
        'Đã vượt hạn mức ${formatVnd(-progress.remaining)}',
      BudgetPace.fast =>
        'Đang tiêu $avg mỗi ngày, cao hơn mức $allowance',
      BudgetPace.onTrack => 'Đúng nhịp — khoảng $avg mỗi ngày',
      BudgetPace.slow => 'Đang tiết kiệm — mới $avg mỗi ngày',
    };
  }

  String _fallbackDetail() {
    if (progress.remaining <= 0) {
      return 'Hạn mức tháng này đã dùng hết.';
    }
    if (progress.daysRemaining > 0) {
      return 'Ví đã hết tiền tiêu được dù hạn mức vẫn còn.';
    }
    return 'Hết tháng rồi, còn dư ${formatVnd(progress.remaining)}.';
  }
}
