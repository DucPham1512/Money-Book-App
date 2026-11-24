import '../../core/db/repository.dart';
import '../../core/domain/bill.dart';
import '../../core/format/money.dart';
import 'tx_form_rules.dart';

/// Kết quả một thao tác trên màn ghi giao dịch: câu báo cho người dùng và,
/// nếu có, việc cần làm khi bấm Hoàn tác.
class TxActionResult {
  const TxActionResult(this.message, {this.undo});

  final String message;
  final Future<void> Function()? undo;
}

/// Những việc màn ghi giao dịch làm với dữ liệu: ghi, ghi kiểu chia tiền, xoá,
/// lưu làm mẫu. Không biết gì về widget: thông báo, đóng màn hình và hộp
/// thoại vẫn do màn hình lo, dựa trên [TxActionResult] trả về.
class TxEditorActions {
  TxEditorActions(this.repo);

  final Repository repo;

  /// Ghi mới, hoặc cập nhật khi có [editingId].
  ///
  /// [keepExistingBill]: khi sửa mà hoá đơn cũ chưa đọc xong, phải giữ nguyên
  /// hoá đơn trong DB thay vì hiểu [bill] rỗng là "bỏ hoá đơn".
  Future<TxActionResult> save(
    TxForm form, {
    required int amount,
    required DateTime occurredAt,
    required String note,
    required List<BillLine> bill,
    int? editingId,
    bool keepExistingBill = false,
  }) async {
    if (editingId != null) {
      await repo.updateTransaction(
        id: editingId,
        kind: form.kind,
        amount: amount,
        occurredAt: occurredAt,
        walletFromId: form.walletFromIdToSave,
        walletToId: form.walletToId,
        categoryId: form.categoryId,
        personId: form.personIdToSave,
        fundId: form.fundIdToSave,
        note: note.isEmpty ? null : note,
        // null là giữ nguyên hoá đơn đang có trong DB.
        bill: keepExistingBill ? null : bill,
      );
      return const TxActionResult('Đã cập nhật');
    }

    await repo.addTransaction(
      kind: form.kind,
      amount: amount,
      occurredAt: occurredAt,
      walletFromId: form.walletFromIdToSave,
      walletToId: form.walletToId,
      categoryId: form.categoryId,
      personId: form.personIdToSave,
      fundId: form.fundIdToSave,
      note: note.isEmpty ? null : note,
      bill: bill,
    );
    return TxActionResult(
      form.isPaidByOther
          ? 'Đã ghi ${formatVnd(amount)}, bạn nợ lại người trả dùm'
          : 'Đã ghi giao dịch',
    );
  }

  /// Ghi một bữa trả dùm: phần của mình là khoản chi, phần của từng người là
  /// một khoản cho mượn. Hoàn tác thì xoá mềm cả nhóm vừa ghi.
  Future<TxActionResult> saveSplit(
    TxForm form, {
    required int myShare,
    required Map<int, int> shares,
    required DateTime occurredAt,
    required String note,
  }) async {
    final ids = await repo.addSplitBill(
      walletFromId: form.walletFromId!,
      myShare: myShare,
      sharesByPerson: shares,
      occurredAt: occurredAt,
      categoryId: form.categoryId,
      note: note.isEmpty ? null : note,
    );

    final theirs = shares.values.fold<int>(0, (sum, v) => sum + v);
    return TxActionResult(
      myShare > 0
          ? 'Đã ghi ${formatVnd(myShare)} tiền của bạn và '
              '${formatVnd(theirs)} cho ${shares.length} người nợ lại'
          : 'Đã ghi ${formatVnd(theirs)} cho ${shares.length} người nợ lại',
      undo: () async {
        for (final id in ids) {
          await repo.softDeleteTransaction(id);
        }
      },
    );
  }

  /// Số giao dịch trong nhóm của [tx] (cặp trả dùm), 0 nếu không thuộc nhóm.
  /// Lớn hơn 1 thì phải hỏi trước, vì xoá lẻ một nửa sẽ để lại nợ mồ côi.
  Future<int> groupSize(TxView tx) async {
    final groupId = tx.tx.groupId;
    return groupId == null ? 0 : repo.countInGroup(groupId);
  }

  /// Xoá mềm [tx], hoặc cả nhóm của nó nếu [groupCount] > 1.
  Future<TxActionResult> delete(TxView tx, {required int groupCount}) async {
    if (groupCount > 1) {
      final ids = await repo.softDeleteGroup(tx.tx.groupId!);
      return TxActionResult(
        'Đã xoá $groupCount giao dịch',
        undo: () => repo.restoreMany(ids),
      );
    }
    await repo.softDeleteTransaction(tx.tx.id);
    return TxActionResult(
      'Đã xoá giao dịch',
      undo: () => repo.restoreTransaction(tx.tx.id),
    );
  }

  /// Lưu các trường đang nhập thành một mẫu chi tiêu. Mẫu cần ít nhất ghi chú
  /// hoặc danh mục để có tên; thiếu cả hai thì không lưu, chỉ trả lời vì sao.
  Future<TxActionResult> saveAsTemplate({
    required String note,
    required int amount,
    required int? walletId,
    required int? categoryId,
  }) async {
    if (note.isEmpty && categoryId == null) {
      return const TxActionResult(
        'Nhập ghi chú hoặc chọn danh mục để đặt tên cho mẫu',
      );
    }
    await repo.insertTemplate(
      note: note.isEmpty ? null : note,
      amount: amount > 0 ? amount : null,
      walletId: walletId,
      categoryId: categoryId,
    );
    return TxActionResult(
      amount > 0 && walletId != null && categoryId != null
          ? 'Đã lưu mẫu. Lần sau bấm ở màn Tổng quan là ghi xong'
          : 'Đã lưu mẫu. Các trường để trống sẽ được hỏi khi dùng',
    );
  }
}
