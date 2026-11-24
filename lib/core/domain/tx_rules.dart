import 'bill.dart';
import 'tx_kind.dart';

/// Kiểm tra dùng chung cho mọi đường ghi giao dịch xuống DB (thêm, sửa, nhập
/// sao lưu), để không đường nào lách được quy tắc mà đường kia giữ.

/// Người khác trả dùm thì tiền không đi qua ví hay quỹ nào của mình. Cho
/// phép cả hai cùng lúc là vừa trừ ví vừa ghi nợ — đếm một khoản chi hai lần.
void checkPaidByOther(
  TxKind kind,
  int? personId,
  int? walletFromId,
  int? walletToId,
  int? fundId,
) {
  if (!kind.canBePaidByOther || personId == null) return;
  if (walletFromId != null || walletToId != null || fundId != null) {
    throw ArgumentError(
      'Khoản chi người khác trả dùm không được trừ vào ví hay quỹ',
    );
  }
}

/// Có hoá đơn thì số tiền phải đúng bằng tổng hoá đơn, không thì sổ sách
/// và hoá đơn mỗi bên nói một số.
void checkBill(int amount, List<BillLine> bill) {
  if (bill.isEmpty) return;
  final error = validateBill(bill);
  if (error != null) throw ArgumentError(error);
  if (billTotal(bill) != amount) {
    throw ArgumentError(
      'Số tiền $amount không khớp tổng hoá đơn ${billTotal(bill)}',
    );
  }
}
