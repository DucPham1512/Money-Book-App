import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons.dart';
import '../../../core/providers.dart';
import '../../categories/category_edit_screen.dart';

/// Chọn danh mục bằng lưới chip, kèm nút thêm mới ngay tại chỗ.
class CategoryPicker extends ConsumerWidget {
  const CategoryPicker({
    super.key,
    required this.flow,
    required this.value,
    required this.onChanged,
  });

  final String flow;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(
      flow == 'income' ? incomeCategoriesProvider : expenseCategoriesProvider,
    );

    return categories.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Lỗi: $e'),
      data: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Danh mục',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in list)
                ChoiceChip(
                  selected: value == c.id,
                  onSelected: (_) => onChanged(c.id),
                  showCheckmark: false,
                  avatar: Icon(
                    iconFor(c.iconKey, fallback: Icons.label_outline),
                    size: 18,
                    color: c.colorValue == null ? null : Color(c.colorValue!),
                  ),
                  label: Text(c.name),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Thêm'),
                onPressed: () async {
                  final id = await Navigator.push<int>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryEditScreen(flow: flow),
                    ),
                  );
                  if (id != null) onChanged(id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
