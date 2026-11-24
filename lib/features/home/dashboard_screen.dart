import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/money.dart';
import '../../core/providers.dart';
import '../settings/settings_screen.dart';
import '../templates/template_editor_sheet.dart';
import '../templates/template_screen.dart';
import 'budget_today_section.dart';
import 'free_money_section.dart';
import 'month_summary_card.dart';
import 'recent_section.dart';
import 'wallets_section.dart';
import 'widgets/section_header.dart';

/// Màn hình đầu tiên: tổng tài sản, các ví, thu chi tháng này và vài giao dịch
/// gần nhất.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tổng quan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Cài đặt',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: const [
          _TotalAssetsCard(),
          SizedBox(height: 12),
          // Ngay dưới số tiền đang có là câu hỏi quan trọng hơn: trong đó bao
          // nhiêu được tiêu thoải mái mà không đụng tới tiền ăn.
          FreeMoneySection(),
          // Không có mẫu thì cụm này tự ẩn, kể cả khoảng cách.
          _TemplatesSection(),
          SizedBox(height: 20),
          // Ngân sách nằm ngay dưới tổng tài sản: đây là con số quyết định
          // bữa trưa hôm nay, không phải thứ phải đi tìm trong Cài đặt.
          BudgetTodaySection(),
          SizedBox(height: 20),
          MonthSummaryCard(),
          SizedBox(height: 20),
          WalletsSection(),
          SizedBox(height: 20),
          RecentSection(),
        ],
      ),
    );
  }
}

/// Tổng tài sản, mặc định chỉ tính phần thực sự tiêu được (đã trừ quỹ và nợ
/// phải trả).
///
/// Tiền quỹ đã có chỗ đến rồi nên gộp vào đây dễ làm mình tưởng còn nhiều tiền
/// hơn thực tế. Bấm con mắt thì mới hiện thêm phần quỹ.
class _TotalAssetsCard extends ConsumerWidget {
  const _TotalAssetsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spendable = ref.watch(spendableAssetsProvider);
    final inFunds = ref.watch(totalInFundsProvider).valueOrNull ?? 0;
    final owed = ref.watch(totalOwedProvider).valueOrNull ?? 0;
    final showFunds = ref.watch(showFundsInTotalProvider);
    final scheme = Theme.of(context).colorScheme;

    final value = spendable.valueOrNull;
    // Tổng tài sản là tiền thật trong ví nên cộng lại cả phần nợ đã trừ.
    final shown = value == null
        ? null
        : (showFunds ? value + inFunds + owed : value);

    return Card(
      color: scheme.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: inFunds == 0
            ? null
            : () => ref.read(showFundsInTotalProvider.notifier).state =
                !showFunds,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    showFunds && inFunds > 0
                        ? 'Tổng tài sản, tính cả quỹ'
                        : 'Tiền tiêu được',
                    style: TextStyle(
                      color:
                          scheme.onPrimaryContainer.withValues(alpha: 0.75),
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (inFunds > 0) ...[
                    const SizedBox(width: 6),
                    Icon(
                      showFunds
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 16,
                      color:
                          scheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              if (shown == null)
                const SizedBox(
                  height: 40,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Text(
                  formatVnd(shown),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              if (owed > 0 && !(showFunds && inFunds > 0)) ...[
                const SizedBox(height: 8),
                Text(
                  'Đã trừ ${formatVnd(owed)} nợ phải trả',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
                    fontSize: 12.5,
                  ),
                ),
              ],
              // Khi mắt nhắm thì không hé lộ phần để dành — chỉ con số tiêu
              // được. Muốn biết thì bấm con mắt.
              if (inFunds > 0 && showFunds) ...[
                const SizedBox(height: 8),
                Text(
                  'Trong đó ${formatVnd(inFunds)} đã dành cho quỹ',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Nút ghi nhanh theo mẫu: bấm là ghi, giữ để sửa mẫu.
class _TemplatesSection extends ConsumerWidget {
  const _TemplatesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templatesProvider).valueOrNull ?? const [];
    if (templates.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Ghi nhanh',
            actionLabel: 'Quản lý',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TemplateScreen()),
            ),
          ),
          const SizedBox(height: 4),
          TemplateChips(
            templates: templates,
            onTap: (t) => useTemplate(context, ref, t),
            onLongPress: (t) => showTemplateEditor(context, editing: t),
          ),
        ],
      ),
    );
  }
}
