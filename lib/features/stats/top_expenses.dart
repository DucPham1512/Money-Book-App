import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/repository.dart';
import '../../core/providers.dart';
import '../transactions/tx_editor_screen.dart';
import '../transactions/tx_tile.dart';

final _topExpensesProvider =
    StreamProvider.family<List<TxView>, int>((ref, monthKey) {
  return ref.watch(repositoryProvider).watchTopExpenses(monthKey);
});

class TopExpenses extends ConsumerWidget {
  const TopExpenses({super.key, required this.monthKey});

  final int monthKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = ref.watch(_topExpensesProvider(monthKey));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chi nhiều nhất',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        top.when(
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
                  child: Center(
                    child: Text(
                      'Chưa có khoản chi nào',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              );
            }
            return Card(
              child: Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 68),
                    TxTile(
                      view: list[i],
                      onTap: () => openTxEditor(context, editing: list[i]),
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
