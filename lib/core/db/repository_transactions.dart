part of 'repository.dart';

// ----- Giao dịch ------------------------------------------------------

extension TransactionQueries on Repository {
  /// Danh sách giao dịch, đã ghép sẵn tên ví / danh mục / người.
  ///
  /// Dùng một câu SQL với các phép join trái, để Drift chỉ phải theo dõi một
  /// truy vấn duy nhất và phát lại đúng một lần khi có thay đổi.
  Stream<List<TxView>> watchTransactions({
    int? limit,
    int? walletId,
    int? personId,
    int? categoryId,
    bool uncategorized = false,
    int? monthKey,
    TxKind? kind,
  }) {
    final where = <String>['t.deleted_at IS NULL'];
    final vars = <Variable>[];

    if (walletId != null) {
      where.add('(t.wallet_from_id = ? OR t.wallet_to_id = ?)');
      vars
        ..add(Variable.withInt(walletId))
        ..add(Variable.withInt(walletId));
    }
    if (personId != null) {
      where.add('t.person_id = ?');
      vars.add(Variable.withInt(personId));
    }
    if (categoryId != null) {
      where.add('t.category_id = ?');
      vars.add(Variable.withInt(categoryId));
    }
    if (uncategorized) {
      where.add('t.category_id IS NULL');
    }
    if (monthKey != null) {
      where.add('t.month_key = ?');
      vars.add(Variable.withInt(monthKey));
    }
    if (kind != null) {
      where.add('t.kind = ?');
      vars.add(Variable.withString(kind.name));
    }

    final sql =
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
      WHERE ${where.join(' AND ')}
      ORDER BY t.occurred_at DESC, t.id DESC
      ${limit != null ? 'LIMIT $limit' : ''}
    ''';

    return db
        .customSelect(
          sql,
          variables: vars,
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

  Future<TxView?> getTransaction(int id) async {
    final list = await watchTransactionById(id).first;
    return list;
  }

  Stream<TxView?> watchTransactionById(int id) {
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
          WHERE t.id = ?
          ''',
          variables: [Variable.withInt(id)],
          readsFrom: {
            db.transactions,
            db.wallets,
            db.categories,
            db.people,
            db.billItems,
          },
        )
        .watch()
        .map((rows) => rows.isEmpty ? null : _rowToTxView(rows.first));
  }

  /// Thêm giao dịch.
  ///
  /// `debtDelta`, `fundDelta` và các khoá ngày tháng được suy ra tự động từ
  /// [kind], chân ví và [occurredAt], để không nơi nào khác trong app phải tự
  /// tính dấu. [intoFund] chỉ cần khi cả hai chân là ví giữ quỹ — xem
  /// [fundDeltaOf].
  Future<int> addTransaction({
    required TxKind kind,
    required int amount,
    required DateTime occurredAt,
    int? walletFromId,
    int? walletToId,
    int? categoryId,
    int? personId,
    int? fundId,
    bool? intoFund,
    String? note,
    String? groupId,
    int? recurringId,
    bool isWriteoff = false,
    List<BillLine> bill = const [],
  }) async {
    assert(amount > 0, 'amount phải dương, dấu suy ra từ kind');
    checkBill(amount, bill);
    checkPaidByOther(kind, personId, walletFromId, walletToId, fundId);
    final now = _now();
    final fundDelta = await _fundDeltaFor(
      fundId: fundId,
      amount: amount,
      walletFromId: walletFromId,
      walletToId: walletToId,
      intoFund: intoFund,
    );
    return db.transaction(() async {
      final id = await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              kind: kind,
              amount: amount,
              occurredAt: occurredAt.millisecondsSinceEpoch,
              dayKey: dayKeyOf(occurredAt),
              monthKey: monthKeyOf(occurredAt),
              walletFromId: Value(walletFromId),
              walletToId: Value(walletToId),
              categoryId: Value(categoryId),
              personId: Value(personId),
              fundId: Value(fundId),
              fundDelta: Value(fundDelta),
              debtDelta: Value(
                kind.debtDelta(amount, hasPerson: personId != null),
              ),
              note: Value(note),
              groupId: Value(groupId),
              recurringId: Value(recurringId),
              isWriteoff: Value(isWriteoff),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _writeBill(id, bill);
      return id;
    });
  }

  /// [bill] null thì giữ nguyên hoá đơn đang có; danh sách rỗng là bỏ hoá
  /// đơn.
  Future<void> updateTransaction({
    required int id,
    required TxKind kind,
    required int amount,
    required DateTime occurredAt,
    int? walletFromId,
    int? walletToId,
    int? categoryId,
    int? personId,
    int? fundId,
    String? note,
    List<BillLine>? bill,
  }) async {
    assert(amount > 0);
    if (bill != null) checkBill(amount, bill);
    checkPaidByOther(kind, personId, walletFromId, walletToId, fundId);
    // Nạp / rút ngay trong ví giữ quỹ không suy được chiều từ chân ví, nên giữ
    // chiều cũ của chính giao dịch này.
    final old = await (db.select(db.transactions)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    final fundDelta = await _fundDeltaFor(
      fundId: fundId,
      amount: amount,
      walletFromId: walletFromId,
      walletToId: walletToId,
      intoFund: old == null || old.fundDelta == 0 ? null : old.fundDelta > 0,
    );
    await db.transaction(() async {
      await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(
          kind: Value(kind),
          amount: Value(amount),
          occurredAt: Value(occurredAt.millisecondsSinceEpoch),
          dayKey: Value(dayKeyOf(occurredAt)),
          monthKey: Value(monthKeyOf(occurredAt)),
          walletFromId: Value(walletFromId),
          walletToId: Value(walletToId),
          categoryId: Value(categoryId),
          personId: Value(personId),
          fundId: Value(fundId),
          fundDelta: Value(fundDelta),
          debtDelta: Value(kind.debtDelta(amount, hasPerson: personId != null)),
          note: Value(note),
          updatedAt: Value(_now()),
        ),
      );
      if (bill != null) await _writeBill(id, bill);
    });
  }

  /// Xoá mềm, để còn hoàn tác được.
  Future<void> softDeleteTransaction(int id) =>
      (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(deletedAt: Value(_now())),
      );

  Future<void> restoreTransaction(int id) =>
      (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
        const TransactionsCompanion(deletedAt: Value(null)),
      );

  /// Xoá cả nhóm giao dịch sinh cùng lúc (ví dụ cặp giao dịch của trả dùm).
  /// Trả về danh sách id để hoàn tác.
  Future<List<int>> softDeleteGroup(String groupId) async {
    final rows = await (db.select(
      db.transactions,
    )..where((t) => t.groupId.equals(groupId) & t.deletedAt.isNull())).get();
    await (db.update(db.transactions)
          ..where((t) => t.groupId.equals(groupId) & t.deletedAt.isNull()))
        .write(TransactionsCompanion(deletedAt: Value(_now())));
    return rows.map((r) => r.id).toList();
  }

  Future<void> restoreMany(List<int> ids) =>
      (db.update(db.transactions)..where((t) => t.id.isIn(ids))).write(
        const TransactionsCompanion(deletedAt: Value(null)),
      );

  Future<int> countInGroup(String groupId) async {
    final t = db.transactions;
    final countExp = t.id.count();
    final q = db.selectOnly(t)
      ..addColumns([countExp])
      ..where(t.groupId.equals(groupId) & t.deletedAt.isNull());
    return (await q.getSingle()).read(countExp) ?? 0;
  }

  /// Ghi một bữa trả dùm: mình trả trước toàn bộ, những người khác nợ lại
  /// phần của họ.
  ///
  /// Sinh ra nhiều giao dịch cùng một [groupId]:
  ///   * một khoản chi đúng bằng phần của mình — chỉ phần này mới vào thống kê
  ///     và ngân sách, nên một bữa 200k chia bốn chỉ tính 50k tiền ăn;
  ///   * mỗi người một khoản cho mượn bằng phần của họ, vào sổ nợ.
  ///
  /// Tổng tiền rời ví vẫn đúng bằng số đã trả. Bỏ qua phần của tôi nếu bằng 0
  /// (trường hợp trả hộ hoàn toàn, mình không ăn).
  ///
  /// Trả về id của các giao dịch đã tạo.
  Future<List<int>> addSplitBill({
    required int walletFromId,
    required int myShare,
    required Map<int, int> sharesByPerson,
    required DateTime occurredAt,
    int? categoryId,
    String? note,
  }) async {
    assert(myShare >= 0);
    assert(sharesByPerson.values.every((v) => v > 0));

    final groupId = _uuid();
    final ids = <int>[];

    await db.transaction(() async {
      if (myShare > 0) {
        ids.add(
          await addTransaction(
            kind: TxKind.expense,
            amount: myShare,
            occurredAt: occurredAt,
            walletFromId: walletFromId,
            categoryId: categoryId,
            note: note,
            groupId: groupId,
          ),
        );
      }
      for (final entry in sharesByPerson.entries) {
        ids.add(
          await addTransaction(
            kind: TxKind.lend,
            amount: entry.value,
            occurredAt: occurredAt,
            walletFromId: walletFromId,
            personId: entry.key,
            note: note == null ? 'Trả dùm' : '$note (trả dùm)',
            groupId: groupId,
          ),
        );
      }
    });

    return ids;
  }

  /// Các giao dịch cùng một nhóm với giao dịch đã cho (kể cả chính nó).
  Future<List<TxView>> transactionsInGroup(String groupId) async {
    final rows = await db
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
      WHERE t.group_id = ? AND t.deleted_at IS NULL
      ORDER BY t.kind DESC, t.id
      ''',
          variables: [Variable.withString(groupId)],
          readsFrom: {
            db.transactions,
            db.wallets,
            db.categories,
            db.people,
            db.billItems,
          },
        )
        .get();
    return rows.map(_rowToTxView).toList();
  }

  /// Điều chỉnh số dư ví cho khớp thực tế.
  ///
  /// Không sửa thẳng số dư ban đầu mà ghi một giao dịch chênh lệch, để lịch sử
  /// vẫn giải thích được vì sao số dư nhảy. Trả về null nếu không có chênh
  /// lệch nào.
  Future<int?> adjustWalletBalance({
    required int walletId,
    required int newBalance,
    String? note,
  }) async {
    final current = await balanceOf(walletId);
    final delta = newBalance - current;
    if (delta == 0) return null;

    return addTransaction(
      kind: TxKind.adjust,
      amount: delta.abs(),
      occurredAt: DateTime.now(),
      walletFromId: delta < 0 ? walletId : null,
      walletToId: delta > 0 ? walletId : null,
      note: note ?? 'Điều chỉnh số dư',
    );
  }
}
