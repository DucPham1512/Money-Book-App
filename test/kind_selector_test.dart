import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneybook/core/domain/tx_kind.dart';
import 'package:moneybook/features/transactions/widgets/kind_selector.dart';

/// Ba loại hay dùng luôn hiện; nhóm vay mượn nằm sau chip "Vay mượn".
void main() {
  Future<List<TxKind>> pump(WidgetTester tester, TxKind initial) async {
    final picked = <TxKind>[];
    var selected = initial;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => KindSelector(
              selected: selected,
              onChanged: (k) => setState(() {
                picked.add(k);
                selected = k;
              }),
            ),
          ),
        ),
      ),
    );
    return picked;
  }

  testWidgets('ghi mới: nhóm vay mượn đóng, bấm thì mở và chọn Cho mượn', (
    tester,
  ) async {
    final picked = await pump(tester, TxKind.expense);
    expect(find.text('Cho mượn'), findsNothing);

    await tester.tap(find.text('Vay mượn'));
    await tester.pump();
    expect(find.text('Cho mượn'), findsOneWidget);
    expect(picked, [TxKind.lend]);

    await tester.tap(find.text('Vay nợ'));
    await tester.pump();
    expect(picked.last, TxKind.borrow);

    await tester.tap(find.text('Chi tiêu'));
    await tester.pump();
    expect(picked.last, TxKind.expense);
    expect(find.text('Cho mượn'), findsNothing, reason: 'về loại thường thì đóng');
  });

  testWidgets('sửa một khoản vay mượn: nhóm tự mở', (tester) async {
    await pump(tester, TxKind.collect);
    expect(find.text('Thu nợ'), findsOneWidget);
    expect(find.text(TxKind.collect.hint), findsOneWidget);
  });
}
