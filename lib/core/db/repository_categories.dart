part of 'repository.dart';

// ----- Danh mục -------------------------------------------------------

extension CategoryQueries on Repository {
  Stream<List<Category>> watchCategories({
    String? flow,
    bool includeArchived = false,
  }) {
    final q = db.select(db.categories);
    if (!includeArchived) q.where((c) => c.isArchived.equals(false));
    if (flow != null) q.where((c) => c.flow.equals(flow));
    q.orderBy([
      (c) => OrderingTerm(expression: c.sortOrder),
      (c) => OrderingTerm(expression: c.id),
    ]);
    return q.watch();
  }

  Future<int> insertCategory(CategoriesCompanion c) =>
      db.into(db.categories).insert(c);

  Future<bool> updateCategory(Category c) =>
      db.update(db.categories).replace(c);

  Future<int> countTransactionsOfCategory(int categoryId) async {
    final t = db.transactions;
    final countExp = t.id.count();
    final q = db.selectOnly(t)
      ..addColumns([countExp])
      ..where(t.deletedAt.isNull() & t.categoryId.equals(categoryId));
    return (await q.getSingle()).read(countExp) ?? 0;
  }

  /// Xoá danh mục. Giao dịch cũ không mất, chỉ thành "Chưa phân loại".
  ///
  /// Hạn mức ngân sách của danh mục thì mất theo, vì một hạn mức không còn
  /// danh mục thì không còn nghĩa gì.
  Future<void> deleteCategory(int id) async {
    await db.transaction(() async {
      await (db.update(db.transactions)..where((t) => t.categoryId.equals(id)))
          .write(const TransactionsCompanion(categoryId: Value(null)));
      await (db.delete(db.budgets)..where((b) => b.categoryId.equals(id))).go();
      await (db.update(db.expenseTemplates)
            ..where((t) => t.categoryId.equals(id)))
          .write(const ExpenseTemplatesCompanion(categoryId: Value(null)));
      await (db.delete(db.categories)..where((c) => c.id.equals(id))).go();
    });
  }

  Future<int> nextCategorySortOrder(String flow) async {
    final c = db.categories;
    final maxExp = c.sortOrder.max();
    final q = db.selectOnly(c)
      ..addColumns([maxExp])
      ..where(c.flow.equals(flow));
    return ((await q.getSingle()).read(maxExp) ?? -1) + 1;
  }
}
