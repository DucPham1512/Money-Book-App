part of 'repository.dart';

// ----- Ví -------------------------------------------------------------

extension WalletQueries on Repository {
  /// Số dư mọi ví, tính bằng đúng một công thức cho mọi loại giao dịch:
  ///
  ///   số dư = số dư ban đầu + (tổng tiền vào ví) - (tổng tiền ra khỏi ví)
  ///
  /// Viết bằng SQL thô vì phải cộng gộp hai chân ví khác nhau của cùng một
  /// bảng; diễn đạt bằng API dựng truy vấn sẽ dài dòng hơn nhiều mà không rõ
  /// ràng hơn.
  Stream<List<WalletWithBalance>> watchWalletsWithBalance({
    bool includeArchived = false,
  }) {
    final sql =
        '''
      SELECT w.*, (
        w.initial_balance
        + COALESCE((SELECT SUM(t.amount) FROM transactions t
                    WHERE t.wallet_to_id = w.id AND t.deleted_at IS NULL), 0)
        - COALESCE((SELECT SUM(t.amount) FROM transactions t
                    WHERE t.wallet_from_id = w.id AND t.deleted_at IS NULL), 0)
      ) AS balance
      FROM wallets w
      ${includeArchived ? '' : 'WHERE w.is_archived = 0'}
      ORDER BY w.sort_order, w.id
    ''';

    return db
        .customSelect(sql, readsFrom: {db.wallets, db.transactions})
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => WalletWithBalance(
                  db.wallets.map(row.data),
                  row.read<int>('balance'),
                ),
              )
              .toList(),
        );
  }

  Stream<int> watchTotalAssets() {
    const sql = 'SELECT ${Repository._totalAssetsExpr} AS total';
    return db
        .customSelect(sql, readsFrom: {db.wallets, db.transactions})
        .watchSingle()
        .map((row) => row.read<int>('total'));
  }

  Future<int> balanceOf(int walletId) async {
    final row = await db
        .customSelect(
          '''
      SELECT (
        w.initial_balance
        + COALESCE((SELECT SUM(t.amount) FROM transactions t
                    WHERE t.wallet_to_id = w.id AND t.deleted_at IS NULL), 0)
        - COALESCE((SELECT SUM(t.amount) FROM transactions t
                    WHERE t.wallet_from_id = w.id AND t.deleted_at IS NULL), 0)
      ) AS balance
      FROM wallets w WHERE w.id = ?
      ''',
          variables: [Variable.withInt(walletId)],
          readsFrom: {db.wallets, db.transactions},
        )
        .getSingleOrNull();
    return row?.read<int>('balance') ?? 0;
  }

  Future<int> countTransactionsOfWallet(int walletId) async {
    final t = db.transactions;
    final countExp = t.id.count();
    final q = db.selectOnly(t)
      ..addColumns([countExp])
      ..where(
        t.deletedAt.isNull() &
            (t.walletFromId.equals(walletId) | t.walletToId.equals(walletId)),
      );
    return (await q.getSingle()).read(countExp) ?? 0;
  }

  Future<int> insertWallet(WalletsCompanion w) => db.into(db.wallets).insert(w);

  Future<bool> updateWallet(Wallet w) => db.update(db.wallets).replace(w);

  /// Ví đang giữ quỹ thì không lưu trữ được: ví lưu trữ rời khỏi tổng tài
  /// sản, còn quỹ vẫn bị trừ khỏi tiền tiêu được, thành ra tiền quỹ bị trừ
  /// vào những ví chưa bao giờ giữ nó. Màn hình hỏi [countFundsOfWallet]
  /// trước để báo cho người dùng.
  Future<void> archiveWallet(int id, {required bool archived}) async {
    if (archived && await countFundsOfWallet(id) > 0) {
      throw ArgumentError('Ví đang giữ quỹ, không lưu trữ được');
    }
    await (db.update(db.wallets)..where((w) => w.id.equals(id))).write(
      WalletsCompanion(isArchived: Value(archived), updatedAt: Value(_now())),
    );
  }

  /// Chỉ nên gọi khi ví không còn giao dịch nào — ví đã dùng thì lưu trữ,
  /// nếu không lịch sử sẽ thủng một lỗ.
  ///
  /// Mẫu chi tiêu trỏ tới ví này thì chỉ mất ví, lần bấm sau sẽ hỏi lại.
  ///
  /// Giao dịch đã xoá mềm thì xoá hẳn: chúng không được đếm là "có giao dịch"
  /// nhưng vẫn giữ khoá ngoại tới ví, để lại thì SQLite chặn lệnh xoá. Ví đang
  /// giữ quỹ vẫn bị chặn — xem [countFundsOfWallet].
  Future<void> deleteWallet(int id) async {
    await db.transaction(() async {
      await (db.delete(db.transactions)
            ..where((t) =>
                t.deletedAt.isNotNull() &
                (t.walletFromId.equals(id) | t.walletToId.equals(id))))
          .go();
      await (db.update(db.expenseTemplates)
            ..where((t) => t.walletId.equals(id)))
          .write(const ExpenseTemplatesCompanion(walletId: Value(null)));
      await (db.delete(db.wallets)..where((w) => w.id.equals(id))).go();
    });
  }

  /// Số quỹ (kể cả đã lưu trữ) đang neo vào ví này. Khác 0 thì không xoá
  /// được ví: quỹ sẽ mất chỗ neo.
  Future<int> countFundsOfWallet(int walletId) async {
    final f = db.funds;
    final countExp = f.id.count();
    final q = db.selectOnly(f)
      ..addColumns([countExp])
      ..where(f.walletId.equals(walletId));
    return (await q.getSingle()).read(countExp) ?? 0;
  }

  Future<int> nextWalletSortOrder() async {
    final w = db.wallets;
    final maxExp = w.sortOrder.max();
    final q = db.selectOnly(w)..addColumns([maxExp]);
    return ((await q.getSingle()).read(maxExp) ?? -1) + 1;
  }
}
