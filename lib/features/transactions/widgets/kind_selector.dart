import 'package:flutter/material.dart';

import '../../../core/domain/tx_kind.dart';

/// Hàng chip chọn loại giao dịch. Ba loại hay dùng luôn hiện; bốn loại vay
/// mượn nằm sau chip "Vay mượn" để màn ghi mới không bị ba hàng chip chiếm
/// chỗ. Đang ở loại vay mượn (kể cả khi sửa) thì nhóm đó tự mở.
class KindSelector extends StatefulWidget {
  const KindSelector({super.key, required this.selected, required this.onChanged});

  final TxKind selected;
  final ValueChanged<TxKind> onChanged;

  @override
  State<KindSelector> createState() => _KindSelectorState();
}

class _KindSelectorState extends State<KindSelector> {
  late bool _debtOpen = kDebtTxKinds.contains(widget.selected);

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final isDebt = kDebtTxKinds.contains(selected);
    final open = _debtOpen || isDebt;
    final scheme = Theme.of(context).colorScheme;

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
                onTap: () {
                  setState(() => _debtOpen = false);
                  widget.onChanged(kind);
                },
              ),
            FilterChip(
              selected: open,
              showCheckmark: false,
              avatar: Icon(
                Icons.handshake_outlined,
                size: 18,
                color: open ? scheme.onSecondaryContainer : null,
              ),
              label: const Text('Vay mượn'),
              onSelected: (v) {
                setState(() => _debtOpen = v);
                if (v && !isDebt) widget.onChanged(kDebtTxKinds.first);
              },
            ),
          ],
        ),
        if (open) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in kDebtTxKinds)
                _KindChip(
                  kind: kind,
                  selected: selected == kind,
                  onTap: () => widget.onChanged(kind),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            selected.hint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.outline,
                ),
          ),
        ],
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
