import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../transactions/tx_editor_screen.dart';
import '../transactions/tx_tile.dart';
import 'widgets/section_header.dart';

class RecentSection extends ConsumerWidget {
  const RecentSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(recentTransactionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Gần đây'),
        const SizedBox(height: 8),
        txs.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Lỗi: $e'),
          data: (list) {
            if (list.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 40,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 12),
                      const Text('Chưa có giao dịch nào'),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () => openTxEditor(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Ghi khoản đầu tiên'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final shown = list.take(8).toList();
            return Card(
              child: Column(
                children: [
                  for (var i = 0; i < shown.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 68),
                    TxTile(
                      view: shown[i],
                      onTap: () => openTxEditor(context, editing: shown[i]),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
