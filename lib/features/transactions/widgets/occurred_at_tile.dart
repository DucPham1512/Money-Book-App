import 'package:flutter/material.dart';

import '../../../core/format/dates.dart';

/// Dòng "Thời điểm" của màn ghi giao dịch; bấm vào để chọn ngày và giờ.
class OccurredAtTile extends StatelessWidget {
  const OccurredAtTile({
    super.key,
    required this.occurredAt,
    required this.onTap,
  });

  final DateTime occurredAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      tileColor: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.4),
      leading: const Icon(Icons.event),
      title: const Text('Thời điểm'),
      subtitle: Text(formatDateTime(occurredAt)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Hỏi ngày rồi giờ cho một giao dịch, bắt đầu từ [current].
///
/// Null nếu người dùng huỷ ở bước chọn ngày, hoặc màn hình đã đóng giữa chừng.
/// Huỷ ở bước chọn giờ thì vẫn lấy ngày mới, giữ giờ cũ.
Future<DateTime?> pickOccurredAt(BuildContext context, DateTime current) async {
  final date = await showDatePicker(
    context: context,
    initialDate: current,
    firstDate: DateTime(2000),
    lastDate: DateTime.now().add(const Duration(days: 365)),
    helpText: 'Chọn ngày giao dịch',
  );
  if (date == null || !context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(current),
    helpText: 'Chọn giờ',
  );
  if (!context.mounted) return null;

  return DateTime(
    date.year,
    date.month,
    date.day,
    time?.hour ?? current.hour,
    time?.minute ?? current.minute,
  );
}
