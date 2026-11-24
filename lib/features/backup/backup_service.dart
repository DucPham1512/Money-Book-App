import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/autotrack_repository.dart';
import '../../core/db/database.dart';
import '../../core/domain/bill.dart';
import '../../core/domain/fund_delta.dart';
import '../../core/domain/tx_kind.dart';
import '../../core/domain/tx_rules.dart';
import '../../core/format/dates.dart';
import 'backup_models.dart';

export 'backup_models.dart';

part 'backup_export.dart';
part 'backup_csv.dart';
part 'backup_import.dart';

/// Xuất và nhập toàn bộ dữ liệu dưới dạng file.
///
/// Đây là cách sao lưu duy nhất của app: không có máy chủ nào giữ hộ, nên file
/// này là thứ cứu được dữ liệu khi mất máy hoặc gỡ nhầm app.
class BackupService {
  BackupService(this.db);

  final AppDatabase db;
}
