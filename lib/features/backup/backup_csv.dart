part of 'backup_service.dart';

extension BackupCsv on BackupService {
  /// Xuất bảng giao dịch dạng CSV để mở bằng Excel.
  ///
  /// Ghi kèm BOM ở đầu file, nếu không Excel trên Windows sẽ đọc UTF-8 thành
  /// ký tự rác và toàn bộ tiếng Việt bị vỡ.
  Future<File> writeCsvFile() async {
    final wallets = {
      for (final w in await db.select(db.wallets).get()) w.id: w.name,
    };
    final categories = {
      for (final c in await db.select(db.categories).get()) c.id: c.name,
    };
    final people = {
      for (final p in await db.select(db.people).get()) p.id: p.name,
    };

    final query = db.select(db.transactions)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.occurredAt, mode: OrderingMode.desc),
      ]);
    final transactions = await query.get();

    final rows = <List<dynamic>>[
      [
        'Ngày',
        'Giờ',
        'Loại',
        'Số tiền',
        'Ví chi',
        'Ví nhận',
        'Danh mục',
        'Người',
        'Ảnh hưởng công nợ',
        'Ghi chú',
      ],
      for (final t in transactions)
        [
          formatDate(DateTime.fromMillisecondsSinceEpoch(t.occurredAt)),
          formatTime(DateTime.fromMillisecondsSinceEpoch(t.occurredAt)),
          t.kind.label,
          t.amount,
          t.walletFromId == null ? '' : wallets[t.walletFromId] ?? '',
          t.walletToId == null ? '' : wallets[t.walletToId] ?? '',
          t.categoryId == null ? '' : categories[t.categoryId] ?? '',
          t.personId == null ? '' : people[t.personId] ?? '',
          t.debtDelta,
          t.note ?? '',
        ],
    ];

    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(dir.path, 'moneybook_${dayKeyOf(DateTime.now())}.csv'),
    );
    const bom = '﻿';
    await file.writeAsString(
      bom + const ListToCsvConverter().convert(rows),
      encoding: utf8,
    );
    return file;
  }
}
