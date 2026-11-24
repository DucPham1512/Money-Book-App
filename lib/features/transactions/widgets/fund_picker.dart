import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/repository.dart';
import '../../../core/format/money.dart';
import '../../../core/icons.dart';
import '../../../core/providers.dart';

/// Chọn quỹ để lấy tiền ra chi.
///
/// Chỉ hiện khi có quỹ. Chọn quỹ nào thì khoản chi vừa trừ ví vừa trừ quỹ đó —
/// đúng như thực tế: tiền quỹ vốn đã nằm trong ví, giờ mới thực sự tiêu.
class FundPicker extends ConsumerWidget {
  const FundPicker({super.key, required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final funds = ref.watch(fundsProvider).valueOrNull ?? const <FundProgress>[];
    if (funds.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final selected = funds.where((f) => f.id == value).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lấy từ quỹ', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              selected: value == null,
              onSelected: (_) => onChanged(null),
              showCheckmark: false,
              label: const Text('Không'),
            ),
            for (final f in funds)
              ChoiceChip(
                selected: value == f.id,
                onSelected: (_) => onChanged(f.id),
                showCheckmark: false,
                avatar: Icon(
                  iconFor(f.fund.iconKey, fallback: Icons.savings),
                  size: 18,
                  color: f.fund.colorValue == null
                      ? null
                      : Color(f.fund.colorValue!),
                ),
                label: Text('${f.name} · ${formatVndShort(f.saved)}'),
              ),
          ],
        ),
        if (selected != null) ...[
          const SizedBox(height: 8),
          Text(
            'Trừ vào quỹ ${selected.name}, đang có '
            '${formatVnd(selected.saved)} ở ${selected.walletName}.',
            style: TextStyle(fontSize: 12, color: scheme.outline),
          ),
        ],
      ],
    );
  }
}
