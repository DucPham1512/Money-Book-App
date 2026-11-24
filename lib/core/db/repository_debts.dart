part of 'repository.dart';

// ----- Sổ nợ ----------------------------------------------------------

extension DebtQueries on Repository {
  /// Công nợ theo từng người. Chỉ là một phép SUM nhờ cột debt_delta đã lưu
  /// sẵn dấu lúc ghi giao dịch.
  ///
  /// Điều kiện lưu trữ trông như bị đảo nhưng là cố ý: mặc định (chỉ người
  /// còn nợ) thì KHÔNG lọc người đã lưu trữ, vì người bị ẩn mà còn nợ vẫn
  /// phải hiện ra; khi [includeSettled] thì liệt kê cả người hết nợ, nên mới
  /// bỏ những người đã lưu trữ.
  Stream<List<DebtSummary>> watchDebts({bool includeSettled = false}) {
    final sql =
        '''
      SELECT p.*, COALESCE((
        SELECT SUM(t.debt_delta) FROM transactions t
        WHERE t.person_id = p.id AND t.deleted_at IS NULL
      ), 0) AS net
      FROM people p
      ${includeSettled ? 'WHERE p.is_archived = 0' : ''}
      ORDER BY p.sort_order, p.name
    ''';
    return db
        .customSelect(sql, readsFrom: {db.people, db.transactions})
        .watch()
        .map((rows) {
          final list = rows
              .map(
                (row) =>
                    DebtSummary(db.people.map(row.data), row.read<int>('net')),
              )
              .where((d) => includeSettled || d.net != 0)
              .toList();
          list.sort((a, b) => b.absAmount.compareTo(a.absAmount));
          return list;
        });
  }

  Stream<int> watchNetDebt(int personId) {
    final t = db.transactions;
    final sumExp = t.debtDelta.sum();
    final q = db.selectOnly(t)
      ..addColumns([sumExp])
      ..where(t.deletedAt.isNull() & t.personId.equals(personId));
    return q.watchSingle().map((row) => row.read(sumExp) ?? 0);
  }

  Future<int> netDebtOf(int personId) async {
    final t = db.transactions;
    final sumExp = t.debtDelta.sum();
    final q = db.selectOnly(t)
      ..addColumns([sumExp])
      ..where(t.deletedAt.isNull() & t.personId.equals(personId));
    return (await q.getSingle()).read(sumExp) ?? 0;
  }
}
