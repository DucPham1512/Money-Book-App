import 'package:moneybook/core/db/repository.dart';

/// Một tiến độ ngân sách dựng tay, để kiểm tra phần tính toán mà không cần
/// cơ sở dữ liệu. Mặc định: danh mục 1 "Ăn uống", tháng 9/2026 có 30 ngày,
/// đã qua 10 ngày, không biết hôm nay tiêu bao nhiêu.
BudgetProgress makeProgress({
  int categoryId = 1,
  String name = 'Ăn uống',
  required int limit,
  required int spent,
  int daysElapsed = 10,
  int daysInMonth = 30,
  int? spentToday,
}) {
  return BudgetProgress(
    budgetId: categoryId,
    categoryId: categoryId,
    categoryName: name,
    limitAmount: limit,
    spent: spent,
    isRecurring: true,
    monthKey: 202609,
    daysInMonth: daysInMonth,
    daysElapsed: daysElapsed,
    spentToday: spentToday,
  );
}
