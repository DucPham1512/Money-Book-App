part of 'repository.dart';

// ----- Thống kê -------------------------------------------------------

extension StatsQueries on Repository {
  /// Tổng thu / chi trong tháng. Chỉ tính thu nhập và chi tiêu — chuyển ví,
  /// vay mượn và điều chỉnh số dư không phải tiêu dùng.
  Stream<MonthTotals> watchMonthTotals(int monthKey) {
    return db
        .customSelect(
          '''
      SELECT
        COALESCE(SUM(CASE WHEN kind = 'income'  THEN amount END), 0) AS income,
        COALESCE(SUM(CASE WHEN kind = 'expense' THEN amount END), 0) AS expense
      FROM transactions
      WHERE deleted_at IS NULL AND month_key = ?
      ''',
          variables: [Variable.withInt(monthKey)],
          readsFrom: {db.transactions},
        )
        .watchSingle()
        .map(
          (row) => MonthTotals(
            income: row.read<int>('income'),
            expense: row.read<int>('expense'),
          ),
        );
  }

  /// Chi tiêu (hoặc thu nhập) trong tháng, gom theo danh mục, nhiều nhất
  /// trước. Danh mục đã bị xoá gom chung vào "Chưa phân loại".
  Stream<List<CategoryTotal>> watchCategoryTotals(
    int monthKey, {
    CategoryFlow flow = CategoryFlow.expense,
  }) {
    final kind = flow.txKind;
    return db
        .customSelect(
          '''
      SELECT t.category_id AS cid,
             c.name        AS cname,
             c.color_value AS ccolor,
             c.icon_key    AS cicon,
             SUM(t.amount) AS total
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.deleted_at IS NULL AND t.month_key = ? AND t.kind = ?
      GROUP BY t.category_id
      ORDER BY total DESC
      ''',
          variables: [
            Variable.withInt(monthKey),
            Variable.withString(kind.name),
          ],
          readsFrom: {db.transactions, db.categories},
        )
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => CategoryTotal(
                  categoryId: row.read<int?>('cid'),
                  name: row.read<String?>('cname') ?? 'Chưa phân loại',
                  colorValue: row.read<int?>('ccolor'),
                  iconKey: row.read<String?>('cicon'),
                  total: row.read<int>('total'),
                ),
              )
              .toList(),
        );
  }

  /// Vài khoản chi lớn nhất trong tháng.
  Stream<List<TxView>> watchTopExpenses(int monthKey, {int limit = 5}) {
    return db
        .customSelect(
          '''
          ${Repository._txViewSelect}
          WHERE t.deleted_at IS NULL AND t.month_key = ? AND t.kind = 'expense'
          ORDER BY t.amount DESC
          LIMIT $limit
          ''',
          variables: [Variable.withInt(monthKey)],
          readsFrom: _txViewTables,
        )
        .watch()
        .map((rows) => rows.map(_rowToTxView).toList());
  }
}
