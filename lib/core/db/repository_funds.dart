part of 'repository.dart';

// ----- Quỹ ------------------------------------------------------------

extension FundQueries on Repository {
  Stream<int> watchTotalInFunds() {
    const sql = 'SELECT ${Repository._totalInFundsExpr} AS total';
    return db
        .customSelect(sql, readsFrom: {db.funds, db.transactions})
        .watchSingle()
        .map((row) => row.read<int>('total'));
  }

  Stream<int> watchTotalOwed() {
    const sql = 'SELECT ${Repository._totalOwedExpr} AS total';
    return db
        .customSelect(sql, readsFrom: {db.transactions})
        .watchSingle()
        .map((row) => row.read<int>('total'));
  }

  /// Tiền thực sự tiêu được: tổng ví trừ đi phần đã hứa cho các quỹ và nợ
  /// mình phải trả.
  ///
  /// Tiền mượn nằm trong ví nhưng không phải của mình, nên vay hay trả nợ đều
  /// không làm con số này nhảy. Người khác nợ mình thì không cộng vào: tiền
  /// đó chưa về tay. Âm nghĩa là có trong tay không đủ trả nợ.
  ///
  /// Một truy vấn duy nhất theo dõi cả ví, giao dịch lẫn quỹ: đổi riêng bảng
  /// quỹ (ví dụ quỹ lưu trữ) cũng phải phát lại con số mới.
  Stream<int> watchSpendableAssets() {
    const sql =
        'SELECT ${Repository._totalAssetsExpr} - ${Repository._totalInFundsExpr} - ${Repository._totalOwedExpr} '
        'AS total';
    return db
        .customSelect(
          sql,
          readsFrom: {db.wallets, db.transactions, db.funds},
        )
        .watchSingle()
        .map((row) => row.read<int>('total'));
  }

  /// Danh sách quỹ kèm số đã để dành và ví đang giữ tiền.
  Stream<List<FundProgress>> watchFunds({bool includeArchived = false}) {
    final sql =
        '''
      SELECT f.*,
             w.name        AS wallet_name,
             w.icon_key    AS wallet_icon,
             w.color_value AS wallet_color,
             ${Repository._fundSavedExpr} AS saved
      FROM funds f
      JOIN wallets w ON w.id = f.wallet_id
      ${includeArchived ? '' : 'WHERE f.is_archived = 0'}
      ORDER BY f.sort_order, f.id
    ''';

    return db
        .customSelect(sql, readsFrom: {db.funds, db.wallets, db.transactions})
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => FundProgress(
                  fund: db.funds.map(row.data),
                  saved: row.read<int>('saved'),
                  walletName: row.read<String>('wallet_name'),
                  walletIconKey: row.read<String?>('wallet_icon'),
                  walletColorValue: row.read<int?>('wallet_color'),
                ),
              )
              .toList(),
        );
  }

  Future<int> savedInFund(int fundId) async {
    final row = await db
        .customSelect(
          '''
      SELECT ${Repository._fundSavedExpr} AS saved
      FROM funds f WHERE f.id = ?
      ''',
          variables: [Variable.withInt(fundId)],
          readsFrom: {db.funds, db.transactions},
        )
        .getSingleOrNull();
    return row?.read<int>('saved') ?? 0;
  }

  Future<int> insertFund(FundsCompanion f) => db.into(db.funds).insert(f);

  Future<bool> updateFund(Fund f) => db.update(db.funds).replace(f);

  /// Xoá quỹ. Các giao dịch từng gắn quỹ vẫn còn nguyên, chỉ mất nhãn quỹ —
  /// tiền chưa bao giờ rời ví nên số dư không đổi.
  Future<void> deleteFund(int id) async {
    await db.transaction(() async {
      await (db.update(db.transactions)..where((t) => t.fundId.equals(id)))
          .write(
            const TransactionsCompanion(
              fundId: Value(null),
              fundDelta: Value(0),
            ),
          );
      await (db.delete(db.funds)..where((f) => f.id.equals(id))).go();
    });
  }

  Future<int> nextFundSortOrder() async {
    final f = db.funds;
    final maxExp = f.sortOrder.max();
    final q = db.selectOnly(f)..addColumns([maxExp]);
    return ((await q.getSingle()).read(maxExp) ?? -1) + 1;
  }

  /// Nạp tiền vào quỹ: chuyển từ ví chi tiêu sang ví đang giữ quỹ.
  ///
  /// Đây đúng là một lần chuyển ví thật, nên ghi bằng [TxKind.transfer] chứ
  /// không đẻ thêm loại giao dịch mới. Gắn thêm quỹ để biết khoản chuyển này
  /// dành cho việc gì.
  ///
  /// Nếu ví nguồn và ví giữ quỹ là một thì không có tiền nào di chuyển, nhưng
  /// vẫn cần ghi để đánh dấu phần tiền đã được hứa — lúc đó dùng chính ví đó
  /// làm cả hai chân. Số dư ví không đổi (vào bao nhiêu ra bấy nhiêu), còn
  /// chiều của quỹ nằm ở `fund_delta`.
  Future<int> depositToFund({
    required int fundId,
    required int walletFromId,
    required int walletToId,
    required int amount,
    required DateTime occurredAt,
    String? note,
  }) {
    assert(amount > 0);
    return addTransaction(
      kind: TxKind.transfer,
      amount: amount,
      occurredAt: occurredAt,
      walletFromId: walletFromId,
      walletToId: walletToId,
      fundId: fundId,
      intoFund: true,
      note: note,
    );
  }

  /// Rút tiền khỏi quỹ mà chưa tiêu: trả lại về ví chi tiêu.
  ///
  /// Rút về chính ví giữ quỹ thì tiền đứng yên, chỉ gỡ nhãn quỹ — số đó quay
  /// lại phần tiêu được.
  Future<int> withdrawFromFund({
    required int fundId,
    required int walletFromId,
    required int walletToId,
    required int amount,
    required DateTime occurredAt,
    String? note,
  }) {
    assert(amount > 0);
    return addTransaction(
      kind: TxKind.transfer,
      amount: amount,
      occurredAt: occurredAt,
      walletFromId: walletFromId,
      walletToId: walletToId,
      fundId: fundId,
      intoFund: false,
      note: note,
    );
  }
}
