import 'package:flutter/material.dart';

import '../../core/format/money.dart';

/// Cách chia tiền một hoá đơn.
enum SplitMode {
  /// Chia đều cho mình và tất cả những người được chọn.
  equal,

  /// Tự gõ phần của từng người.
  custom,
}

/// Trạng thái chia tiền của một hoá đơn.
///
/// Sống bên trong màn ghi chi tiêu: người dùng nhập tổng hoá đơn ở ô số tiền
/// như bình thường, bật công tắc chia tiền, rồi chọn ai cùng ăn.
class SplitState {
  SplitState();

  bool enabled = false;
  SplitMode mode = SplitMode.equal;

  /// Những người cùng chia, theo thứ tự được chọn.
  final List<int> personIds = [];

  /// Phần của từng người khi chia tay (mode == custom).
  final Map<int, TextEditingController> controllers = {};

  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
  }

  void toggle(int personId) {
    if (personIds.remove(personId)) {
      controllers.remove(personId)?.dispose();
    } else {
      personIds.add(personId);
      controllers[personId] = TextEditingController();
    }
  }

  /// Số người cùng chia hoá đơn, tính cả mình.
  int get headcount => personIds.length + 1;

  /// Phần của từng người khi chia đều.
  ///
  /// Chia không hết thì phần lẻ dồn vào mình, để tổng luôn khớp hoá đơn và
  /// mình không đòi bạn bè thêm mấy đồng lẻ.
  Map<int, int> equalShares(int total) {
    if (personIds.isEmpty || total <= 0) return const {};
    final each = total ~/ headcount;
    return {for (final id in personIds) id: each};
  }

  Map<int, int> customShares() {
    final result = <int, int>{};
    for (final id in personIds) {
      final value = parseVnd(controllers[id]?.text ?? '');
      if (value > 0) result[id] = value;
    }
    return result;
  }

  Map<int, int> sharesFor(int total) =>
      mode == SplitMode.equal ? equalShares(total) : customShares();

  /// Phần còn lại là của mình.
  int myShareFor(int total) {
    final theirs =
        sharesFor(total).values.fold<int>(0, (sum, v) => sum + v);
    return total - theirs;
  }

  /// Lý do không ghi được, hoặc null nếu hợp lệ.
  String? validate(int total) {
    if (!enabled) return null;
    if (personIds.isEmpty) return 'Hãy chọn người cùng chia tiền';
    final shares = sharesFor(total);
    if (shares.isEmpty) return 'Hãy nhập phần của từng người';
    if (shares.length != personIds.length) {
      return 'Hãy nhập phần của từng người';
    }
    final theirs = shares.values.fold<int>(0, (sum, v) => sum + v);
    if (theirs > total) {
      return 'Phần của mọi người (${formatVnd(theirs)}) vượt quá hoá đơn';
    }
    return null;
  }
}
