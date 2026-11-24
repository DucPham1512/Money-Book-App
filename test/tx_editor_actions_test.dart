import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneybook/core/db/database.dart';
import 'package:moneybook/core/db/repository.dart';
import 'package:moneybook/core/domain/bill.dart';
import 'package:moneybook/core/domain/tx_kind.dart';
import 'package:moneybook/core/format/money.dart';
import 'package:moneybook/features/transactions/tx_editor_actions.dart';
import 'package:moneybook/features/transactions/tx_form_rules.dart';

/// Các thao tác của màn ghi giao dịch trên DB thật: ghi, sửa, chia tiền, xoá
/// cả nhóm, lưu mẫu — cùng câu báo và việc hoàn tác như màn hình vẫn làm.
void main() {
  late AppDatabase db;
  late Repository repo;
  late TxEditorActions actions;
  late int wallet;
  late int food;
  late int nam;
  final at = DateTime(2026, 9, 6, 12);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = Repository(db);
    actions = TxEditorActions(repo);
    wallet = await repo.insertWallet(
      WalletsCompanion.insert(
        name: 'Ví',
        initialBalance: const Value(1000000),
        createdAt: 0,
        updatedAt: 0,
      ),
    );
    food = (await repo.watchCategories(flow: CategoryFlow.expense).first).first.id;
    nam = await repo.insertPerson(
      PeopleCompanion.insert(name: 'Nam', createdAt: 0, updatedAt: 0),
    );
  });

  tearDown(() async => db.close());

  Future<List<TxView>> all() => repo.watchTransactions().first;

  test('ghi mới khoản chi thường: không mang người còn sót', () async {
    final r = await actions.save(
      TxForm(
        kind: TxKind.expense,
        walletFromId: wallet,
        categoryId: food,
        personId: nam,
      ),
      amount: 50000,
      occurredAt: at,
      note: '',
      bill: const [],
    );
    expect(r.message, 'Đã ghi giao dịch');
    expect(r.undo, isNull);
    final tx = (await all()).single.tx;
    expect(tx.personId, isNull);
    expect(tx.note, isNull);
    expect(await repo.balanceOf(wallet), 950000);
  });

  test('người khác trả dùm: không ví, có người, câu báo riêng', () async {
    final r = await actions.save(
      TxForm(
        kind: TxKind.expense,
        walletFromId: wallet,
        categoryId: food,
        personId: nam,
        paidByOther: true,
      ),
      amount: 50000,
      occurredAt: at,
      note: 'Phở',
      bill: const [],
    );
    expect(r.message, 'Đã ghi ${formatVnd(50000)}, bạn nợ lại người trả dùm');
    final tx = (await all()).single.tx;
    expect(tx.walletFromId, isNull);
    expect(tx.personId, nam);
    expect(await repo.balanceOf(wallet), 1000000);
  });

  test('sửa: giữ hoá đơn cũ khi được bảo giữ, bỏ khi gửi danh sách rỗng',
      () async {
    const lines = [BillLine(name: 'Phở', quantity: 1, unitPrice: 50000)];
    await repo.addTransaction(
      kind: TxKind.expense,
      amount: 50000,
      occurredAt: at,
      walletFromId: wallet,
      categoryId: food,
      bill: lines,
    );
    final id = (await all()).single.tx.id;
    final form =
        TxForm(kind: TxKind.expense, walletFromId: wallet, categoryId: food);

    final r = await actions.save(
      form,
      amount: 50000,
      occurredAt: at,
      note: 'Sửa',
      bill: const [],
      editingId: id,
      keepExistingBill: true,
    );
    expect(r.message, 'Đã cập nhật');
    expect(await repo.watchBill(id).first, hasLength(1));

    await actions.save(
      form,
      amount: 50000,
      occurredAt: at,
      note: 'Sửa',
      bill: const [],
      editingId: id,
    );
    expect(await repo.watchBill(id).first, isEmpty);
  });

  test('chia tiền: câu báo, và hoàn tác xoá cả nhóm', () async {
    final r = await actions.saveSplit(
      TxForm(kind: TxKind.expense, walletFromId: wallet, categoryId: food),
      myShare: 50000,
      shares: {nam: 50000},
      occurredAt: at,
      note: '',
    );
    expect(
      r.message,
      'Đã ghi ${formatVnd(50000)} tiền của bạn và '
      '${formatVnd(50000)} cho 1 người nợ lại',
    );
    expect(await all(), hasLength(2));
    await r.undo!();
    expect(await all(), isEmpty);
  });

  test('chia tiền mà mình không ăn: câu báo chỉ có phần người khác', () async {
    final r = await actions.saveSplit(
      TxForm(kind: TxKind.expense, walletFromId: wallet, categoryId: food),
      myShare: 0,
      shares: {nam: 80000},
      occurredAt: at,
      note: 'Trà sữa',
    );
    expect(r.message, 'Đã ghi ${formatVnd(80000)} cho 1 người nợ lại');
  });

  test('xoá giao dịch trong nhóm thì xoá cả nhóm, hoàn tác được', () async {
    await repo.addSplitBill(
      walletFromId: wallet,
      myShare: 50000,
      sharesByPerson: {nam: 50000},
      occurredAt: at,
      categoryId: food,
    );
    final one = (await all()).first;
    final count = await actions.groupSize(one);
    expect(count, 2);
    final r = await actions.delete(one, groupCount: count);
    expect(r.message, 'Đã xoá 2 giao dịch');
    expect(await all(), isEmpty);
    await r.undo!();
    expect(await all(), hasLength(2));
  });

  test('xoá giao dịch lẻ', () async {
    await repo.addTransaction(
      kind: TxKind.expense,
      amount: 50000,
      occurredAt: at,
      walletFromId: wallet,
      categoryId: food,
    );
    final one = (await all()).single;
    expect(await actions.groupSize(one), 0);
    final r = await actions.delete(one, groupCount: 0);
    expect(r.message, 'Đã xoá giao dịch');
    expect(await all(), isEmpty);
    await r.undo!();
    expect(await all(), hasLength(1));
  });

  group('lưu làm mẫu', () {
    test('thiếu cả ghi chú lẫn danh mục thì không lưu', () async {
      final r = await actions.saveAsTemplate(
        note: '',
        amount: 25000,
        walletId: wallet,
        categoryId: null,
      );
      expect(r.message, 'Nhập ghi chú hoặc chọn danh mục để đặt tên cho mẫu');
      expect(await repo.watchTemplates().first, isEmpty);
    });

    test('đủ số tiền, ví, danh mục: ghi một chạm được', () async {
      final r = await actions.saveAsTemplate(
        note: 'Cà phê',
        amount: 25000,
        walletId: wallet,
        categoryId: food,
      );
      expect(r.message, 'Đã lưu mẫu. Lần sau bấm ở màn Tổng quan là ghi xong');
      expect((await repo.watchTemplates().first).single.isOneTap, isTrue);
    });

    test('thiếu trường thì báo sẽ hỏi lúc dùng, số tiền 0 lưu thành trống',
        () async {
      final r = await actions.saveAsTemplate(
        note: '',
        amount: 0,
        walletId: null,
        categoryId: food,
      );
      expect(r.message, 'Đã lưu mẫu. Các trường để trống sẽ được hỏi khi dùng');
      expect((await repo.watchTemplates().first).single.amount, isNull);
    });
  });
}
