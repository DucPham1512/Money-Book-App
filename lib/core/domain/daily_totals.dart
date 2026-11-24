
import '../db/repository.dart';

/// Tổng chi từng ngày của tháng, phần tử `i` là ngày `i + 1`.
///
/// Trả về đủ [days] phần tử kể cả những ngày không tiêu gì, để biểu đồ không
/// nhảy cóc qua ngày trống — ngày không tiêu cũng là thông tin.
List<int> dailyTotals(Iterable<TxView> txs, int monthKey, int days) {
  final totals = List<int>.filled(days, 0);
  for (final v in txs) {
    if (v.tx.monthKey != monthKey) continue;
    final day = v.tx.dayKey % 100;
    if (day >= 1 && day <= days) totals[day - 1] += v.tx.amount;
  }
  return totals;
}
