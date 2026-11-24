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
    String flow = 'expense',
  }) {
    final kind = flow == 'income' ? TxKind.income : TxKind.expense;
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
          SELECT t.*,
                 wf.name AS wf_name, wf.color_value AS wf_color, wf.icon_key AS wf_icon,
                 wt.name AS wt_name, wt.color_value AS wt_color, wt.icon_key AS wt_icon,
                 c.name  AS c_name,  c.color_value  AS c_color,  c.icon_key  AS c_icon,
                 p.name  AS p_name,  p.avatar_color AS p_color,
                 ${Repository._billCountExpr} AS bill_count
          FROM transactions t
          LEFT JOIN wallets    wf ON wf.id = t.wallet_from_id
          LEFT JOIN wallets    wt ON wt.id = t.wallet_to_id
          LEFT JOIN categories c  ON c.id  = t.category_id
          LEFT JOIN people     p  ON p.id  = t.person_id
          WHERE t.deleted_at IS NULL AND t.month_key = ? AND t.kind = 'expense'
          ORDER BY t.amount DESC
          LIMIT $limit
          ''',
          variables: [Variable.withInt(monthKey)],
          readsFrom: {
            db.transactions,
            db.wallets,
            db.categories,
            db.people,
            db.billItems,
          },
        )
        .watch()
        .map((rows) => rows.map(_rowToTxView).toList());
  }
}
