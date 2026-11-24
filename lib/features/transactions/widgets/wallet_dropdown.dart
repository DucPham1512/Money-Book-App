import 'package:flutter/material.dart';

import '../../../core/db/repository.dart';
import '../../../core/format/money.dart';
import '../../../core/icons.dart';

class WalletDropdown extends StatelessWidget {
  const WalletDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.wallets,
    required this.value,
    required this.onChanged,
    this.excludeId,
  });

  final String label;
  final IconData icon;
  final List<WalletWithBalance> wallets;
  final int? value;
  final int? excludeId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items =
        wallets.where((w) => excludeId == null || w.id != excludeId).toList();
    // Nếu ví đang chọn vừa bị loại khỏi danh sách (do trùng với ví bên kia),
    // phải bỏ chọn, nếu không DropdownButton sẽ ném lỗi.
    final safeValue = items.any((w) => w.id == value) ? value : null;

    return DropdownButtonFormField<int>(
      initialValue: safeValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: [
        for (final w in items)
          DropdownMenuItem(
            value: w.id,
            child: Row(
              children: [
                Icon(
                  iconFor(w.wallet.iconKey, fallback: Icons.wallet),
                  size: 18,
                  color: w.wallet.colorValue == null
                      ? null
                      : Color(w.wallet.colorValue!),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(w.name, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text(
                  formatVndShort(w.balance),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
