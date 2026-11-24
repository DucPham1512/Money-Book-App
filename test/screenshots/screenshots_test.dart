// Chụp ảnh các màn hình chính để xem bố cục khi không chạy được app trên máy
// thật. Chỉ chạy khi có biến môi trường:
//
//   SCREENSHOT_DIR=/tmp/shots flutter test test/screenshots
//   SCREENSHOT_DIR=/tmp/shots SCREENSHOT_THEME=light flutter test test/screenshots
//
// Bình thường (flutter test) thì bỏ qua, không ảnh hưởng bộ test.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:moneybook/core/db/autotrack_repository.dart';
import 'package:moneybook/core/db/database.dart';
import 'package:moneybook/core/db/repository.dart';
import 'package:moneybook/core/domain/tx_kind.dart';
import 'package:moneybook/core/providers.dart';
import 'package:moneybook/core/theme.dart';
import 'package:moneybook/features/autotrack/autotrack_providers.dart';
import 'package:moneybook/features/autotrack/autotrack_settings_screen.dart';
import 'package:moneybook/features/autotrack/categorize_rules_screen.dart';
import 'package:moneybook/features/autotrack/review_screen.dart';
import 'package:moneybook/features/backup/backup_screen.dart';
import 'package:moneybook/features/budgets/budget_screen.dart';
import 'package:moneybook/features/debts/debt_book_screen.dart';
import 'package:moneybook/features/funds/fund_screen.dart';
import 'package:moneybook/features/home/dashboard_screen.dart';
import 'package:moneybook/features/settings/settings_screen.dart';
import 'package:moneybook/features/stats/stats_screen.dart';
import 'package:moneybook/features/templates/template_screen.dart';
import 'package:moneybook/features/transactions/tx_editor_screen.dart';
import 'package:moneybook/features/transactions/tx_list_screen.dart';
import 'package:moneybook/features/wallets/wallet_list_screen.dart';

import '../support/fake_autotrack_platform.dart';

final _dir = Platform.environment['SCREENSHOT_DIR'];
final _dark = Platform.environment['SCREENSHOT_THEME'] != 'light';

Future<void> _loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      '${Platform.environment['HOME']}/development/flutter';
  final fonts = '$flutterRoot/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File(f).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('Roboto', [
    for (final w in ['Regular', 'Medium', 'Bold', 'Light'])
      '$fonts/Roboto-$w.ttf',
  ]);
  await load('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
  await load('MoneyBookIcons', ['assets/fonts/MoneyBookIcons.ttf']);
}

void main() {
  late AppDatabase db;
  late FakePlatform platform;
  final now = DateTime.now();

  setUpAll(() async {
    if (_dir == null) return;
    await initializeDateFormatting('vi_VN');
    await _loadFonts();
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    platform = FakePlatform();
    final repo = Repository(db);
    final auto = AutoTrackRepository(db);
    final cash = await repo.insertWallet(
      WalletsCompanion.insert(
        name: 'Tiền mặt',
        initialBalance: const Value(1850000),
        createdAt: 0,
        updatedAt: 0,
      ),
    );
    final bidv = await repo.insertWallet(
      WalletsCompanion.insert(
        name: 'BIDV',
        type: const Value('bank'),
        initialBalance: const Value(12400000),
        createdAt: 0,
        updatedAt: 0,
      ),
    );
    final cats = {
      for (final c in await repo.watchCategories().first) c.name: c.id,
    };
    final food = cats['Ăn uống']!;
    final nam = await repo.insertPerson(
      PeopleCompanion.insert(name: 'Nguyễn Văn Nam', createdAt: 0, updatedAt: 0),
    );
    final lan = await repo.insertPerson(
      PeopleCompanion.insert(name: 'Lan', createdAt: 0, updatedAt: 0),
    );
    Future<void> tx(TxKind k, int amount, int daysAgo,
        {int? from, int? to, int? cat, int? person, String? note}) =>
        repo.addTransaction(
          kind: k,
          amount: amount,
          occurredAt: now.subtract(Duration(days: daysAgo, hours: 1)),
          walletFromId: from,
          walletToId: to,
          categoryId: cat,
          personId: person,
          note: note,
        );
    await tx(TxKind.income, 15000000, 3, to: bidv, cat: cats['Lương'], note: 'Lương tháng');
    await tx(TxKind.expense, 45000, 0, from: cash, cat: food, note: 'Phở bò');
    await tx(TxKind.expense, 120000, 1, from: bidv, cat: food,
        note: 'Bún chả Hương Liên với cả nhóm bạn đại học cuối tuần');
    await tx(TxKind.expense, 350000, 2, from: bidv, cat: cats['Đi lại'], note: 'Xăng xe');
    await tx(TxKind.lend, 200000, 2, from: cash, person: nam, note: 'Mượn tiền ăn trưa');
    await tx(TxKind.borrow, 500000, 4, to: bidv, person: lan);
    await tx(TxKind.transfer, 1000000, 1, from: bidv, to: cash);
    await repo.setBudget(categoryId: food, limitAmount: 3000000);
    await repo.setBudget(categoryId: cats['Đi lại']!, limitAmount: 800000);
    final fund = await repo.insertFund(
      FundsCompanion.insert(
        name: 'Tiền KTX',
        walletId: bidv,
        targetAmount: const Value(3000000),
        createdAt: 0,
        updatedAt: 0,
      ),
    );
    await repo.depositToFund(
      fundId: fund,
      walletFromId: bidv,
      walletToId: bidv,
      amount: 1200000,
      occurredAt: now.subtract(const Duration(days: 2)),
    );
    await repo.insertTemplate(
      note: 'Cà phê sáng',
      amount: 25000,
      walletId: cash,
      categoryId: food,
    );
    await auto.setEnabled(true);
    await auto.bindParser(parserId: 'bidv', packageName: bidvPkg);
    await auto.setDefaultWallet(bidvPkg, bidv);
    await auto.startCapture(
      packageName: 'com.mservice.momotransfer',
      label: 'MoMo',
      until: now.add(const Duration(days: 5)),
    );
  });

  tearDown(() async => db.close());

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget home, {
    double height = 915,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(412, height);
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          autoTrackPlatformProvider.overrideWithValue(platform),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(_dark ? Brightness.dark : Brightness.light),
            locale: const Locale('vi', 'VN'),
            supportedLocales: const [Locale('vi', 'VN')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: home,
          ),
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(_dir!).createSync(recursive: true);
      File('$_dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  final screens = <String, (Widget, double)>{
    '01-dashboard': (const DashboardScreen(), 2000),
    '02-tx-list': (const TxListScreen(), 915),
    '03-tx-editor': (const TxEditorScreen(), 1500),
    '04-budget': (const BudgetScreen(), 1300),
    '05-stats': (const StatsScreen(), 1800),
    '06-debts': (const DebtBookScreen(), 915),
    '07-wallets': (const WalletListScreen(), 915),
    '08-settings': (const SettingsScreen(), 1100),
    '09-autotrack': (const AutoTrackSettingsScreen(), 1800),
    '10-backup': (const BackupScreen(), 1100),
    '11-funds': (const FundScreen(), 915),
    '12-templates': (const TemplateScreen(), 915),
    '13-review': (const ReviewScreen(), 915),
    '14-rules': (const CategorizeRulesScreen(), 915),
  };
  for (final e in screens.entries) {
    testWidgets(
      e.key,
      (tester) => shoot(tester, e.key, e.value.$1, height: e.value.$2),
      skip: _dir == null,
    );
  }
}
