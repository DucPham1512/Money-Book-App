import 'package:flutter/material.dart';

import 'person_picker.dart';

/// Công tắc "người khác trả dùm", bật lên thì chọn người mình nợ. Nằm cạnh
/// công tắc chia tiền vì cả hai đều trả lời câu "ai đã trả hoá đơn này".
class PaidByOtherSection extends StatelessWidget {
  const PaidByOtherSection({
    super.key,
    required this.value,
    required this.onChanged,
    required this.personId,
    required this.onPersonChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final int? personId;
  final ValueChanged<int?> onPersonChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: value,
          onChanged: onChanged,
          title: const Text('Người khác trả dùm'),
          subtitle: const Text(
            'Ví không bị trừ, bạn nợ lại người đó. Chỉ ghi phần của bạn',
          ),
        ),
        if (value) ...[
          const SizedBox(height: 4),
          PersonPicker(
            label: 'Ai trả dùm',
            value: personId,
            onChanged: onPersonChanged,
          ),
        ],
      ],
    );
  }
}
