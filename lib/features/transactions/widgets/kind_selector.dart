import 'package:flutter/material.dart';

import '../../../core/domain/tx_kind.dart';

/// Hàng chip chọn loại giao dịch, tách nhóm thường và nhóm nợ cho dễ nhìn.
class KindSelector extends StatelessWidget {
  const KindSelector({super.key, required this.selected, required this.onChanged});

  final TxKind selected;
  final ValueChanged<TxKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in kQuickTxKinds)
              _KindChip(
                kind: kind,
                selected: selected == kind,
                onTap: () => onChanged(kind),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Vay mượn',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in kDebtTxKinds)
              _KindChip(
                kind: kind,
                selected: selected == kind,
                onTap: () => onChanged(kind),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          selected.hint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final TxKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(
        kind.icon,
        size: 18,
        color: selected ? Theme.of(context).colorScheme.onSecondaryContainer : null,
      ),
      label: Text(kind.label),
      showCheckmark: false,
    );
  }
}
