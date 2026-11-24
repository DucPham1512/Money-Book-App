part of 'repository.dart';

// ----- Mẫu chi tiêu ---------------------------------------------------

extension TemplateQueries on Repository {
  static const _templateSql = '''
      SELECT et.*,
             w.name        AS w_name,
             w.is_archived AS w_archived,
             c.name        AS c_name,
             c.icon_key    AS c_icon,
             c.color_value AS c_color,
             c.is_archived AS c_archived
      FROM expense_templates et
      LEFT JOIN wallets    w ON w.id = et.wallet_id
      LEFT JOIN categories c ON c.id = et.category_id
  ''';

  TemplateView _rowToTemplateView(QueryRow row) => TemplateView(
    template: db.expenseTemplates.map(row.data),
    walletName: row.read<String?>('w_name'),
    walletArchived: (row.read<int?>('w_archived') ?? 0) != 0,
    categoryName: row.read<String?>('c_name'),
    categoryIconKey: row.read<String?>('c_icon'),
    categoryColorValue: row.read<int?>('c_color'),
    categoryArchived: (row.read<int?>('c_archived') ?? 0) != 0,
  );

  Stream<List<TemplateView>> watchTemplates() {
    return db
        .customSelect(
          '$_templateSql ORDER BY et.sort_order, et.id',
          readsFrom: {db.expenseTemplates, db.wallets, db.categories},
        )
        .watch()
        .map((rows) => rows.map(_rowToTemplateView).toList());
  }

  Future<TemplateView?> getTemplate(int id) async {
    final row = await db
        .customSelect(
          '$_templateSql WHERE et.id = ?',
          variables: [Variable.withInt(id)],
          readsFrom: {db.expenseTemplates, db.wallets, db.categories},
        )
        .getSingleOrNull();
    return row == null ? null : _rowToTemplateView(row);
  }

  Future<int> insertTemplate({
    String? note,
    int? amount,
    int? walletId,
    int? categoryId,
  }) async {
    assert(amount == null || amount > 0);
    final now = _now();
    return db
        .into(db.expenseTemplates)
        .insert(
          ExpenseTemplatesCompanion.insert(
            note: Value(note),
            amount: Value(amount),
            walletId: Value(walletId),
            categoryId: Value(categoryId),
            sortOrder: Value(await _nextTemplateSortOrder()),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> updateTemplate({
    required int id,
    String? note,
    int? amount,
    int? walletId,
    int? categoryId,
  }) {
    assert(amount == null || amount > 0);
    return (db.update(
      db.expenseTemplates,
    )..where((t) => t.id.equals(id))).write(
      ExpenseTemplatesCompanion(
        note: Value(note),
        amount: Value(amount),
        walletId: Value(walletId),
        categoryId: Value(categoryId),
        updatedAt: Value(_now()),
      ),
    );
  }

  Future<void> deleteTemplate(int id) =>
      (db.delete(db.expenseTemplates)..where((t) => t.id.equals(id))).go();

  /// Lưu thứ tự mới sau khi kéo thả: mẫu đứng đầu [ids] lên đầu hàng nút.
  Future<void> reorderTemplates(List<int> ids) async {
    await db.transaction(() async {
      for (var i = 0; i < ids.length; i++) {
        await (db.update(db.expenseTemplates)
              ..where((t) => t.id.equals(ids[i])))
            .write(ExpenseTemplatesCompanion(sortOrder: Value(i)));
      }
    });
  }

  Future<int> _nextTemplateSortOrder() async {
    final t = db.expenseTemplates;
    final maxExp = t.sortOrder.max();
    final q = db.selectOnly(t)..addColumns([maxExp]);
    return ((await q.getSingle()).read(maxExp) ?? -1) + 1;
  }

  /// Ghi một khoản chi theo mẫu, tại thời điểm [occurredAt].
  ///
  /// Đọc lại mẫu từ DB thay vì tin bản đang hiện trên màn hình, phòng khi ví
  /// vừa bị lưu trữ hay danh mục vừa bị xoá. Trả về null nếu mẫu không còn
  /// hoặc thiếu trường — khi đó nơi gọi phải mở màn ghi để người dùng điền nốt.
  Future<int?> recordFromTemplate(
    int templateId, {
    required DateTime occurredAt,
  }) async {
    final t = await getTemplate(templateId);
    if (t == null || !t.isOneTap) return null;
    final note = t.template.note?.trim();
    return addTransaction(
      kind: TxKind.expense,
      amount: t.template.amount!,
      occurredAt: occurredAt,
      walletFromId: t.template.walletId,
      categoryId: t.template.categoryId,
      note: note == null || note.isEmpty ? null : note,
    );
  }
}
