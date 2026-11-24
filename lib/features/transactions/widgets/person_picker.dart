import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets.dart';
import '../../people/person_edit_screen.dart';

/// Chọn người từ danh bạ. Thêm một lần, những lần sau chỉ việc chọn.
class PersonPicker extends ConsumerWidget {
  const PersonPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Với ai',
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(peopleProvider);

    return people.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Lỗi: $e'),
      data: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          if (list.isEmpty)
            Text(
              'Danh bạ đang trống. Thêm một người để bắt đầu ghi nợ.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in list)
                ChoiceChip(
                  selected: value == p.id,
                  onSelected: (_) => onChanged(p.id),
                  showCheckmark: false,
                  avatar: InitialAvatar(
                    name: p.name,
                    size: 24,
                    color:
                        p.avatarColor == null ? null : Color(p.avatarColor!),
                  ),
                  label: Text(p.name),
                ),
              ActionChip(
                avatar: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Thêm người'),
                onPressed: () async {
                  final id = await Navigator.push<int>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PersonEditScreen(),
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
