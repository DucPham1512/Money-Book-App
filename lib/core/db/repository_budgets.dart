part of 'repository.dart';

// ----- Ngân sách ------------------------------------------------------

extension BudgetQueries on Repository {
  /// Hạn mức từng danh mục kèm số đã tiêu trong tháng.
  ///
  /// Số đã tiêu chỉ đếm giao dịch `expense`, nên tiền trả dùm cho bạn bè —
  /// vốn được ghi thành các khoản `lend` — không làm vượt ngân sách oan.
  ///
  /// [now] là mốc "hôm nay" để tính số ngày đã qua; truyền vào để nơi gọi đổi
  /// được mốc khi qua nửa đêm mà không cần đợi dữ liệu thay đổi.
  Stream<List<BudgetProgress>> watchBudgets(int monthKey, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final isCurrentMonth = monthKeyOf(today) == monthKey;
    return db
        .customSelect(
          '''
      SELECT b.id            AS budget_id,
             b.limit_amount  AS limit_amount,
             b.month_key     AS budget_month,
             c.id            AS category_id,
             c.name          AS category_name,
             c.color_value   AS category_color,
             c.icon_key      AS category_icon,
             COALESCE((
               SELECT SUM(t.amount) FROM transactions t
               WHERE t.category_id = c.id
                 AND t.kind = 'expense'
                 AND t.month_key = ?
                 AND t.deleted_at IS NULL
             ), 0) AS spent,
             COALESCE((
               SELECT SUM(t.amount) FROM transactions t
               WHERE t.category_id = c.id
                 AND t.kind = 'expense'
                 AND t.day_key = ?
                 AND t.deleted_at IS NULL
             ), 0) AS spent_today
      FROM budgets b
      JOIN categories c ON c.id = b.category_id
      WHERE (b.month_key IS NULL OR b.month_key = ?)
        AND c.is_archived = 0
      ORDER BY c.sort_order, c.id
      ''',
          variables: [
            Variable.withInt(monthKey),
            Variable.withInt(dayKeyOf(today)),
            Variable.withInt(monthKey),
          ],
          readsFrom: {db.budgets, db.categories, db.transactions},
        )
        .watch()
        .map((rows) {
          // Tính một lần cho cả danh sách thay vì lặp lại ở từng dòng.
          final totalDays = daysInMonth(monthKey);
          final elapsed = daysElapsedIn(monthKey, now: now);

          return rows
              .map(
                (row) => BudgetProgress(
                  budgetId: row.read<int>('budget_id'),
                  categoryId: row.read<int>('category_id'),
                  categoryName: row.read<String>('category_name'),
                  colorValue: row.read<int?>('category_color'),
                  iconKey: row.read<String?>('category_icon'),
                  limitAmount: row.read<int>('limit_amount'),
                  spent: row.read<int>('spent'),
                  // Tháng khác tháng này thì không có "hôm nay", nên cũng
                  // không có tiền dư nào được nhả ra tiền tự do.
                  spentToday: isCurrentMonth
                      ? row.read<int>('spent_today')
                      : null,
                  isRecurring: row.read<int?>('budget_month') == null,
                  monthKey: monthKey,
                  daysInMonth: totalDays,
                  daysElapsed: elapsed,
                ),
              )
              .toList();
        });
  }

  /// Tổng chi tiêu trong một ngày, gom theo danh mục có đặt hạn mức.
  ///
  /// Dùng ở màn Tổng quan để trả lời câu "hôm nay mình đã tiêu bao nhiêu rồi",
  /// đối chiếu ngay với mức khuyến nghị mỗi ngày.
  Stream<Map<int, int>> watchSpentByCategoryOnDay(int dayKey) {
    return db
        .customSelect(
          '''
      SELECT category_id AS cid, SUM(amount) AS total
      FROM transactions
      WHERE deleted_at IS NULL
        AND kind = 'expense'
        AND day_key = ?
        AND category_id IS NOT NULL
      GROUP BY category_id
      ''',
          variables: [Variable.withInt(dayKey)],
          readsFrom: {db.transactions},
        )
        .watch()
        .map(
          (rows) => {
            for (final row in rows)
              row.read<int>('cid'): row.read<int>('total'),
          },
        );
  }

  /// Tiền đã ra khỏi ví trong một ngày cho những việc NGOÀI các ngân sách:
  /// chi vào danh mục không đặt hạn mức (kể cả chưa phân loại) và cho mượn —
  /// gồm cả phần trả dùm.
  ///
  /// Khoản chi lấy từ quỹ không tính: tiền đó đã được để dành sẵn, không lấy
  /// từ tiền tự do.
  Stream<int> watchSpentOutsideBudgetsOnDay(int dayKey, int monthKey) {
    return db
        .customSelect(
          '''
      SELECT COALESCE(SUM(t.amount), 0) AS total
      FROM transactions t
      WHERE t.deleted_at IS NULL
        AND t.day_key = ?
        AND t.fund_id IS NULL
        AND t.wallet_from_id IS NOT NULL
        AND (
          t.kind = 'lend'
          OR (t.kind = 'expense' AND (
            t.category_id IS NULL OR t.category_id NOT IN (
              SELECT b.category_id FROM budgets b
              JOIN categories c ON c.id = b.category_id
              WHERE (b.month_key IS NULL OR b.month_key = ?)
                AND c.is_archived = 0
            )
          ))
        )
      ''',
          variables: [Variable.withInt(dayKey), Variable.withInt(monthKey)],
          readsFrom: {db.transactions, db.budgets, db.categories},
        )
        .watchSingle()
        .map((row) => row.read<int>('total'));
  }

  /// Đặt hoặc cập nhật hạn mức cho một danh mục.
  ///
  /// [monthKey] null nghĩa là áp dụng cho mọi tháng.
  ///
  /// Tự tìm rồi cập nhật thay vì dựa vào `insertOnConflictUpdate`: SQLite coi
  /// hai giá trị NULL là khác nhau, nên chỉ mục duy nhất trên
  /// `(category_id, month_key)` không bắt được xung đột ở các hạn mức áp dụng
  /// cho mọi tháng, và mỗi lần đặt lại sẽ đẻ thêm một dòng mới.
  Future<void> setBudget({
    required int categoryId,
    required int limitAmount,
    int? monthKey,
  }) async {
    assert(limitAmount > 0);
    final now = _now();

    await db.transaction(() async {
      final query = db.select(db.budgets)
        ..where((b) => b.categoryId.equals(categoryId))
        ..where(
          (b) => monthKey == null
              ? b.monthKey.isNull()
              : b.monthKey.equals(monthKey),
        );
      final existing = await query.getSingleOrNull();

      if (existing == null) {
        await db
            .into(db.budgets)
            .insert(
              BudgetsCompanion.insert(
                categoryId: categoryId,
                monthKey: Value(monthKey),
                limitAmount: limitAmount,
                createdAt: now,
                updatedAt: now,
              ),
            );
      } else {
        await (db.update(
          db.budgets,
        )..where((b) => b.id.equals(existing.id))).write(
          BudgetsCompanion(
            limitAmount: Value(limitAmount),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  Future<void> deleteBudget(int id) =>
      (db.delete(db.budgets)..where((b) => b.id.equals(id))).go();
}
