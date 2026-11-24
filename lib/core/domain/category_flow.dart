import 'tx_kind.dart';

/// Chiều của một danh mục: tiền ra hay tiền vào. Một danh mục chỉ thuộc một
/// chiều.
///
/// Lưu xuống DB bằng [name] (`textEnum`), nên giá trị cũ 'expense' / 'income'
/// đọc lên được mà không cần migration. Thêm chiều mới ở đây thì trình biên
/// dịch chỉ ra mọi `switch` còn thiếu nhánh.
enum CategoryFlow {
  expense,
  income;

  /// Loại giao dịch dùng danh mục chiều này. Chiều ngược lại là
  /// [TxKindX.categoryFlow].
  TxKind get txKind => switch (this) {
    CategoryFlow.expense => TxKind.expense,
    CategoryFlow.income => TxKind.income,
  };

  String get label => switch (this) {
    CategoryFlow.expense => 'Chi tiêu',
    CategoryFlow.income => 'Thu nhập',
  };
}
