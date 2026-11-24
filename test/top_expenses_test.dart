import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneybook/core/db/database.dart';
import 'package:moneybook/core/db/repository.dart';
import 'package:moneybook/core/domain/tx_kind.dart';

/// Chốt hành vi của các truy vấn trả về TxView trước khi gom câu SELECT dùng
/// chung: khoản chi lớn nhất tháng và đọc lại một giao dịch theo id.
void main() {
  late AppDatabase db;
  late Repository repo;
  late int wallet;
  late int food;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = Repository(db);
    wallet = await repo.insertWallet(
      WalletsCompanion.insert(
        name: 'Ví',
        initialBalance: const Value(10000000),
        createdAt: 0,
        updatedAt: 0,
      ),
    );
    food = (await repo.watchCategories(flow: CategoryFlow.expense).first).first.id;
  });

  tearDown(() async => db.close());

  Future<int> spend(int amount, DateTime at, {TxKind kind = TxKind.expense}) =>
      repo.addTransaction(
        kind: kind,
        amount: amount,
        occurredAt: at,
        walletFromId: kind.needsWalletFrom ? wallet : null,
        walletToId: kind.needsWalletFrom ? null : wallet,
        categoryId: kind.needsCategory ? food : null,
      );

  test('khoản chi lớn nhất: chỉ chi tiêu của đúng tháng, lớn trước, có giới hạn',
      () async {
    await spend(50000, DateTime(2026, 9, 1));
    await spend(300000, DateTime(2026, 9, 2));
    await spend(120000, DateTime(2026, 9, 3));
    final gone = await spend(900000, DateTime(2026, 9, 4));
    await repo.softDeleteTransaction(gone);
    await spend(800000, DateTime(2026, 10, 1)); // tháng khác
    await spend(700000, DateTime(2026, 9, 5), kind: TxKind.income);

    final top = await repo.watchTopExpenses(202609, limit: 2).first;
    expect(top.map((v) => v.tx.amount), [300000, 120000]);
    expect(top.first.walletFrom?.name, 'Ví');
    expect(top.first.category?.id, food);
    expect(top.first.billCount, 0);
  });

  test('đọc lại một giao dịch theo id, kể cả khi đã xoá mềm', () async {
    final id = await spend(50000, DateTime(2026, 9, 1));
    expect((await repo.getTransaction(id))!.tx.amount, 50000);
    await repo.softDeleteTransaction(id);
    expect((await repo.getTransaction(id))!.tx.deletedAt, isNotNull);
    expect(await repo.getTransaction(id + 100), isNull);
  });
}
