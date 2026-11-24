import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneybook/core/db/autotrack_repository.dart';
import 'package:moneybook/core/db/database.dart';
import 'package:moneybook/core/providers.dart';
import 'package:moneybook/core/theme.dart';
import 'package:moneybook/features/autotrack/autotrack_providers.dart';
import 'package:moneybook/features/autotrack/autotrack_settings_screen.dart';
import 'package:moneybook/features/autotrack/event_log_screen.dart';

import 'support/fake_autotrack_platform.dart';

/// Mẫu của app đang ghi mẫu nằm ngay dưới mục của app đó, gửi được lên GitHub
/// thành issue, và không lẫn vào nhật ký thông báo thật.
void main() {
  const momo = 'com.mservice.momotransfer';
  late AppDatabase db;
  late FakePlatform platform;
  late List<Uri> opened;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    platform = FakePlatform();
    opened = [];
    final auto = AutoTrackRepository(db);
    await auto.setEnabled(true);
    await auto.startCapture(
      packageName: momo,
      label: 'MoMo',
      until: DateTime.now().add(const Duration(days: 7)),
    );
    var n = 0;
    Future<void> sample(DateTime at, String title, String body) => db
        .into(db.notificationEvents)
        .insert(
          NotificationEventsCompanion.insert(
            packageName: momo,
            title: Value(title),
            body: body,
            postedAt: at.millisecondsSinceEpoch,
            dedupeHash: 'h${n++}',
            status: Value(EventStatus.captured.name),
            createdAt: 0,
          ),
        );
    await sample(
      DateTime(2026, 11, 24, 14, 19),
      'Nhận chuyển khoản từ A',
      'Số tiền 10.000 ₫ về Ví. Mã 0100123456789',
    );
    await sample(
      DateTime(2026, 11, 25, 9, 2),
      'Thanh toán thành công',
      'Bạn đã thanh toán 35.000đ',
    );
  });

  tearDown(() async => db.close());

  Widget app(Widget home) => ProviderScope(
    overrides: [
      dbProvider.overrideWithValue(db),
      autoTrackPlatformProvider.overrideWithValue(platform),
      openUrlProvider.overrideWithValue((url) async {
        opened.add(url);
        return true;
      }),
    ],
    child: MaterialApp(theme: buildTheme(Brightness.light), home: home),
  );

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMomo(WidgetTester tester) async {
    await tester.pumpWidget(app(const AutoTrackSettingsScreen()));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('MoMo'), 200);
    await tester.ensureVisible(find.text('MoMo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 mẫu'), findsOneWidget);
    await tester.tap(find.text('MoMo'));
    await settle(tester);
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('mở mục MoMo thấy các mẫu, gửi lên GitHub thành issue', (
    tester,
  ) async {
    await openMomo(tester);
    await tester.scrollUntilVisible(find.text('Nhận chuyển khoản từ A'), 200);
    expect(find.text('Nhận chuyển khoản từ A'), findsOneWidget);
    expect(find.text('Thanh toán thành công'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Gửi 2 mẫu lên GitHub'), 200);
    await tester.ensureVisible(find.text('Gửi 2 mẫu lên GitHub'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi 2 mẫu lên GitHub'));
    await settle(tester);
    expect(
      find.textContaining('xoá tên người'),
      findsOneWidget,
      reason: 'nhắc trước khi mở repo công khai',
    );
    await tester.tap(find.text('Mở GitHub'));
    await settle(tester);

    final url = opened.single;
    expect(url.path, '/DucPham1512/Money-Book-App/issues/new');
    expect(
      url.queryParameters['title'],
      'Masked MoMo Notification from 24/11/2026 – 25/11/2026',
    );
    expect(url.queryParameters['body'], contains('xxxxxxxxxx789'));
    expect(url.queryParameters['body'], isNot(contains('0100123456789')));
    await dispose(tester);
  });

  testWidgets('bỏ chọn một mẫu thì chỉ gửi mẫu còn lại', (tester) async {
    await openMomo(tester);
    await tester.scrollUntilVisible(find.text('Thanh toán thành công'), 200);
    await tester.ensureVisible(find.text('Thanh toán thành công'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thanh toán thành công'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Gửi 1 mẫu lên GitHub'), 200);
    await tester.ensureVisible(find.text('Gửi 1 mẫu lên GitHub'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi 1 mẫu lên GitHub'));
    await settle(tester);
    await tester.tap(find.text('Mở GitHub'));
    await settle(tester);
    expect(
      opened.single.queryParameters['title'],
      'Masked MoMo Notification from 24/11/2026',
    );
    await dispose(tester);
  });

  testWidgets('dừng ghi mẫu thì hỏi lại rồi xoá cả mẫu', (tester) async {
    await openMomo(tester);
    await tester.tap(find.byTooltip('Dừng ghi mẫu'));
    await settle(tester);
    expect(find.textContaining('2 mẫu đã ghi cũng bị xoá'), findsOneWidget);
    await tester.tap(find.text('Dừng và xoá'));
    await settle(tester);

    expect(find.text('MoMo'), findsNothing);
    final left = await tester.runAsync(
      () => db.select(db.notificationEvents).get(),
    );
    expect(left, isEmpty);
    await dispose(tester);
  });

  testWidgets('nhật ký thông báo không còn mẫu', (tester) async {
    await tester.pumpWidget(app(const EventLogScreen()));
    await settle(tester);
    expect(find.textContaining('35.000đ'), findsNothing);
    expect(find.text('Mẫu'), findsNothing, reason: 'bỏ bộ lọc Mẫu');
    await dispose(tester);
  });
}
