import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/tx_kind.dart';
import '../../../core/format/dates.dart';
import '../../../core/providers.dart';
import '../spend_impact_note.dart';
import '../tx_form_rules.dart';

/// Khoản chi này lấy tiền từ đâu. Chỉ hiện khi ghi mới một khoản làm tiền
/// ra khỏi ví trong tháng này — sửa khoản cũ thì số tự do đã tính nó rồi, còn
/// chi từ quỹ thì không đụng tới tiền tự do.
class ImpactNoteSection extends ConsumerWidget {
  const ImpactNoteSection({
    super.key,
    required this.form,
    required this.occurredAt,
    required this.total,
    required this.myShareFor,
  });

  final TxForm form;
  final DateTime occurredAt;

  /// Số tiền sẽ ghi (tổng hoá đơn nếu chia tiền).
  final int total;

  /// Phần của mình khi chia tiền, tính theo [total].
  final int Function(int total) myShareFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const none = SizedBox.shrink();
    if (form.isEditing) return none;
    final today = ref.watch(todayProvider);
    if (monthKeyOf(occurredAt) != monthKeyOf(today)) return none;

    final kind = form.kind;
    final Widget note;
    if (kind.isFreeMoneyOutflow) {
      note = SpendImpactNote(amount: 0, categoryId: null, outside: total);
    } else if (!kind.countsInBudgets ||
        (form.fundId != null && !form.isPaidByOther)) {
      return none;
    } else if (form.usesSplit) {
      final mine = myShareFor(total);
      note = SpendImpactNote(
        amount: mine,
        categoryId: form.categoryId,
        outside: total - mine,
      );
    } else {
      note = SpendImpactNote(amount: total, categoryId: form.categoryId);
    }
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: note);
  }
}
