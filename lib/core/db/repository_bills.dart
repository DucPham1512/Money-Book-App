part of 'repository.dart';

// ----- Hoá đơn chi tiết -----------------------------------------------

extension BillQueries on Repository {
  /// Ghi đè toàn bộ hoá đơn của một giao dịch. Danh sách rỗng là bỏ hoá đơn.
  Future<void> _writeBill(int transactionId, List<BillLine> bill) async {
    await (db.delete(
      db.billItems,
    )..where((b) => b.transactionId.equals(transactionId))).go();
    for (var i = 0; i < bill.length; i++) {
      final l = bill[i];
      await db
          .into(db.billItems)
          .insert(
            BillItemsCompanion.insert(
              transactionId: transactionId,
              name: l.name.trim(),
              quantity: Value(l.quantity),
              unitPrice: l.unitPrice,
              isDiscount: Value(l.isDiscount),
              sortOrder: Value(i),
            ),
          );
    }
  }

  /// Hoá đơn chi tiết của một giao dịch, theo thứ tự lúc nhập.
  Stream<List<BillItem>> watchBill(int transactionId) {
    return (db.select(db.billItems)
          ..where((b) => b.transactionId.equals(transactionId))
          ..orderBy([(b) => OrderingTerm.asc(b.sortOrder)]))
        .watch();
  }
}
