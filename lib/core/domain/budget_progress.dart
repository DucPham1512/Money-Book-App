/// Tình trạng nhịp độ tiêu tiền so với chặng đường của tháng.
enum BudgetPace {
  /// Đã tiêu hết hạn mức.
  over,

  /// Tiêu nhanh hơn nhịp đều đáng kể — cứ đà này sẽ hết sớm.
  fast,

  /// Bám sát nhịp đều.
  onTrack,

  /// Tiêu chậm hơn nhịp, đang dư dả.
  slow,
}

/// Một hạn mức kèm tiến độ chi tiêu trong tháng.
///
/// Ngoài chuyện đã tiêu bao nhiêu, lớp này còn trả lời câu hỏi quan trọng hơn:
/// *tiêu như vậy có nhanh quá so với thời điểm này của tháng không*, và
/// *những ngày còn lại được tiêu bao nhiêu mỗi ngày thì vừa đủ*.
class BudgetProgress {
  const BudgetProgress({
    required this.budgetId,
    required this.categoryId,
    required this.categoryName,
    required this.limitAmount,
    required this.spent,
    required this.isRecurring,
    required this.monthKey,
    required this.daysInMonth,
    required this.daysElapsed,
    this.colorValue,
    this.iconKey,
    this.cashCap,
    this.spentToday,
  });

  final int budgetId;
  final int categoryId;
  final String categoryName;
  final int limitAmount;
  final int spent;

  /// Hôm nay đã chi bao nhiêu vào mục này, null nếu tháng này không chứa
  /// hôm nay (tháng đã qua hoặc chưa tới).
  final int? spentToday;

  /// Hạn mức áp dụng cho mọi tháng, không riêng tháng nào.
  final bool isRecurring;

  final int monthKey;
  final int daysInMonth;

  /// Số ngày của tháng đã trôi qua, tính cả hôm nay.
  final int daysElapsed;

  final int? colorValue;
  final String? iconKey;

  /// Phần tiền THẬT trong ví dành được cho hạn mức này, null nếu không giới
  /// hạn. Xem [capBudgetsByCash].
  final int? cashCap;

  BudgetProgress withCashCap(int? cap) => BudgetProgress(
    budgetId: budgetId,
    categoryId: categoryId,
    categoryName: categoryName,
    limitAmount: limitAmount,
    spent: spent,
    isRecurring: isRecurring,
    monthKey: monthKey,
    daysInMonth: daysInMonth,
    daysElapsed: daysElapsed,
    colorValue: colorValue,
    iconKey: iconKey,
    cashCap: cap,
    spentToday: spentToday,
  );

  int get remaining => limitAmount - spent;

  /// Tiền những ngày trước tiêu không hết so với nhịp đều — đã nhả ra thành
  /// tiền tự do, không còn giữ cho hạn mức này nữa.
  ///
  /// Tính dồn cả tháng chứ không từng ngày: những ngày trước lỡ tiêu lố thì
  /// phần tiết kiệm sau đó lấp cái hụt ấy trước, lấp đủ rồi mới nhả ra.
  int get unusedBeforeToday {
    if (spentToday == null || daysElapsed == 0) return 0;
    final unused = -overspentBeforeToday(spentToday!);
    return unused > 0 ? unused : 0;
  }

  /// Phần hạn mức còn giữ lại cho hôm nay và những ngày sau.
  int get reserved => remaining - unusedBeforeToday;

  /// Số thực sự còn tiêu được: phần hạn mức còn giữ, nhưng không quá số tiền
  /// đang có. Hạn mức chỉ là lời hứa với bản thân, còn tiền hết là hết —
  /// tiêu lố ở danh mục khác thì ví vơi đi dù hạn mức này chưa hề đụng tới.
  int get spendable {
    final cap = cashCap;
    if (cap == null || cap >= reserved) return reserved;
    return cap < 0 ? 0 : cap;
  }

  /// Tiền trong ví đã ít hơn phần hạn mức còn giữ.
  bool get isLimitedByCash =>
      cashCap != null && reserved > 0 && cashCap! < reserved;
  double get ratio => limitAmount == 0 ? 0 : spent / limitAmount;
  bool get isOver => spent > limitAmount;

  /// Sắp chạm hạn mức: từ 80% trở lên nhưng chưa vượt.
  bool get isNearLimit => !isOver && ratio >= 0.8;

  // ----- Nhịp độ --------------------------------------------------------

  /// Số ngày còn lại của tháng, không tính hôm nay.
  int get daysRemaining => (daysInMonth - daysElapsed).clamp(0, 31);

  /// Tháng đã kết thúc thì không còn gì để cảnh báo nữa.
  bool get isPastMonth => daysRemaining == 0 && daysElapsed >= daysInMonth;

  /// Mức tiêu trung bình mỗi ngày nếu chia đều hạn mức cả tháng.
  ///
  /// Ngân sách ăn uống 3 triệu cho tháng 30 ngày thì đây là 100k.
  int get dailyAllowance => daysInMonth == 0 ? 0 : limitAmount ~/ daysInMonth;

  /// Thực tế đang tiêu bao nhiêu một ngày.
  int get dailyAverage => daysElapsed == 0 ? 0 : spent ~/ daysElapsed;

  /// Đáng lẽ đến giờ này mới nên tiêu tới đây.
  int get expectedByNow =>
      daysInMonth == 0 ? 0 : (limitAmount * daysElapsed) ~/ daysInMonth;

  /// Tiêu quá mức đáng lẽ bao nhiêu. Âm nghĩa là đang tiêu tiết kiệm.
  int get paceDelta => spent - expectedByNow;

  /// Mức nên tiêu trong HÔM NAY.
  ///
  /// Chia [spendable] chứ không chia [remaining]: tiền những ngày trước tiêu
  /// không hết đã sang tiền tự do ([unusedBeforeToday]), nên tiết kiệm hôm qua
  /// không đẩy mốc hôm nay lên quá nhịp đều. Ngược lại, tiêu lố thì mốc tự hạ
  /// để cả tháng vẫn đủ.
  ///
  /// Phải cộng lại phần đã tiêu hôm nay rồi mới chia, vì [remaining] đã trừ nó
  /// đi rồi còn [daysRemaining] lại không đếm hôm nay — lấy tiền của những ngày
  /// sau đem chia cho hôm nay thì sai cả tử lẫn mẫu.
  ///
  /// Tuyệt đối không cộng thêm số đã tiêu hôm nay vào kết quả này để làm mốc so
  /// sánh: làm vậy thì càng tiêu nhiều mốc càng cao và không bao giờ báo vượt.
  int budgetForToday(int spentToday) {
    final daysLeftIncludingToday = daysRemaining + 1;
    if (daysLeftIncludingToday <= 0) return 0;
    final pot = spendable + spentToday;
    if (pot <= 0) return 0;
    return pot ~/ daysLeftIncludingToday;
  }

  /// Hôm nay còn tiêu được bao nhiêu nữa.
  ///
  /// Đây là con số dùng để quyết định: đứng trước quầy nước thì cái cần biết là
  /// còn bao nhiêu, chứ không phải đã tiêu bao nhiêu. Âm nghĩa là đã lố.
  int leftForToday(int spentToday) => budgetForToday(spentToday) - spentToday;

  /// Phần đã dùng của hạn mức hôm nay, từ 0 tới 1.
  ///
  /// Dùng để vẽ thanh vơi dần: 1 là còn nguyên, 0 là hết sạch.
  double remainingRatioToday(int spentToday) {
    final target = budgetForToday(spentToday);
    if (target <= 0) return 0;
    final left = leftForToday(spentToday);
    if (left <= 0) return 0;
    return (left / target).clamp(0.0, 1.0);
  }

  /// Còn bao nhiêu tiền mỗi ngày cho những ngày CÒN LẠI, không tính hôm nay.
  ///
  /// Đây là con số hữu ích nhất: hôm nay lỡ tay thì ngày mai biết phải rút
  /// xuống bao nhiêu để cả tháng vẫn nằm trong hạn mức.
  int get remainingDailyAllowance {
    if (daysRemaining <= 0) return 0;
    final left = spendableAfterToday;
    if (left <= 0) return 0;
    return left ~/ daysRemaining;
  }

  /// Phần để dành cho những ngày sau hôm nay. Phần hôm nay chưa tiêu hết
  /// không tính vào: qua nửa đêm nó thành tiền tự do chứ không chia cho ngày
  /// sau. Không biết số đã tiêu hôm nay thì trả về [spendable] như trước.
  int get spendableAfterToday {
    final today = spentToday;
    if (today == null) return spendable;
    final leftToday = leftForToday(today);
    return leftToday > 0 ? spendable - leftToday : spendable;
  }

  /// Những ngày TRƯỚC hôm nay đã tiêu vượt nhịp đều bao nhiêu. Âm là đang dư.
  ///
  /// Không phụ thuộc vào lúc nào khoản chi được ghi: quên ghi hôm qua, sáng nay
  /// ghi bù với ngày của hôm qua thì con số này vẫn lộ ra. Nhờ vậy màn hình giải
  /// thích được vì sao mốc hôm nay thấp hơn bình thường, thay vì lặng lẽ hạ mốc
  /// mà không ai hay.
  int overspentBeforeToday(int spentToday) {
    if (daysInMonth == 0 || daysElapsed == 0) return 0;
    final before = spent - spentToday;
    final expected = (limitAmount * (daysElapsed - 1)) ~/ daysInMonth;
    return before - expected;
  }

  // ----- Gợi ý lấp chỗ hụt -----------------------------------------------
  //
  // Chỉ là lời khuyên để về lại nhịp đều sớm hơn, không phải mốc bắt buộc:
  // tiêu quá gợi ý mà vẫn dưới [budgetForToday] thì không bị coi là lố.

  /// Phần của hôm nay nếu chia đều hạn mức cả tháng, tính theo tỉ lệ để tổng
  /// các ngày khớp đúng hạn mức.
  int get normalToday {
    if (daysInMonth == 0 || daysElapsed == 0) return 0;
    return (limitAmount * daysElapsed) ~/ daysInMonth -
        (limitAmount * (daysElapsed - 1)) ~/ daysInMonth;
  }

  /// Những ngày trước tiêu quá nhịp đều bao nhiêu, chưa lấp lại được.
  int get hole {
    if (spentToday == null) return 0;
    final h = overspentBeforeToday(spentToday!);
    return h > 0 ? h : 0;
  }

  /// Gợi ý mỗi ngày bớt bao nhiêu để lấp [hole]: một phần cố định của mức
  /// thường ngày, nên chỗ hụt nhỏ vài ngày là lấp xong, chỗ hụt lớn thì lâu
  /// hơn. Không bao giờ ít hơn mức chia đều tới cuối tháng, để kịp lấp trong
  /// tháng; không bao giờ quá chính chỗ hụt.
  int get recoveryCut {
    final h = hole;
    if (h == 0) return 0;
    final daysLeft = daysRemaining + 1;
    final byPercent = (normalToday * kRecoveryCut).ceil();
    final bySpread = (h + daysLeft - 1) ~/ daysLeft;
    final cut = byPercent > bySpread ? byPercent : bySpread;
    return cut < h ? cut : h;
  }

  /// Gợi ý tiêu tối đa mỗi ngày trong lúc lấp chỗ hụt.
  int get recoveryLimit {
    final limit = normalToday - recoveryCut;
    return limit > 0 ? limit : 0;
  }

  /// Bớt đúng [recoveryCut] mỗi ngày thì sau chừng này ngày về lại mức
  /// [normalToday]. 0 nếu không hụt.
  int get daysToRecover {
    final cut = recoveryCut;
    if (cut == 0) return 0;
    return (hole + cut - 1) ~/ cut;
  }

  /// Cứ giữ nhịp này thì hết tháng sẽ tiêu hết bao nhiêu.
  int get projectedTotal =>
      daysElapsed == 0 ? 0 : (spent * daysInMonth) ~/ daysElapsed;

  /// Cứ giữ nhịp này thì còn cầm cự được thêm bao nhiêu ngày nữa.
  /// Trả về null nếu đủ tiền tới hết tháng.
  int? get daysUntilRunOut {
    if (dailyAverage <= 0 || spendable <= 0) return null;
    final days = spendable ~/ dailyAverage;
    if (days >= daysRemaining) return null;
    return days;
  }

  /// Cứ giữ nhịp này thì hạn mức cạn vào ngày thứ mấy của tháng.
  /// Trả về null nếu đủ tiền tới hết tháng.
  int? get projectedRunOutDay {
    final days = daysUntilRunOut;
    if (days == null) return null;
    final day = daysElapsed + days;
    return day > daysInMonth ? null : day;
  }

  BudgetPace get pace {
    if (isOver) return BudgetPace.over;
    if (daysElapsed == 0 || limitAmount == 0) return BudgetPace.onTrack;
    final expected = expectedByNow;
    if (expected == 0) return BudgetPace.onTrack;

    final overshoot = (spent - expected) / expected;
    // Ngưỡng 15%: đủ rộng để một bữa đắt hơn thường lệ không làm nổ cảnh báo,
    // đủ hẹp để bắt được xu hướng tiêu vượt thật sự.
    if (overshoot > 0.15) return BudgetPace.fast;
    if (overshoot < -0.15) return BudgetPace.slow;
    return BudgetPace.onTrack;
  }

  /// Có nên nhắc người dùng về hạn mức này không.
  ///
  /// Chỉ nhắc khi đã vượt, sắp chạm, hoặc đang tiêu nhanh hơn nhịp — và bỏ qua
  /// những tháng đã kết thúc vì không còn gì để điều chỉnh.
  bool get needsAttention {
    if (isPastMonth) return false;
    return isOver || isNearLimit || pace == BudgetPace.fast || isLimitedByCash;
  }
}

/// Gợi ý bớt bao nhiêu phần mức thường ngày để lấp chỗ hụt. Xem
/// [BudgetProgress.recoveryCut].
const kRecoveryCut = 0.25;

/// Chặn các hạn mức bằng số tiền thật đang có.
///
/// Hạn mức ăn uống còn 300k nhưng ví chỉ còn 190k — vì tiền đã chảy sang những
/// khoản khác — thì con số "mỗi ngày được tiêu" phải tính trên 190k. Có nhiều
/// hạn mức thì chia tiền theo tỉ lệ phần còn lại của từng cái, để tổng các
/// phần không vượt quá số tiền đang có. Đủ tiền cho tất cả thì giữ nguyên.
List<BudgetProgress> capBudgetsByCash(List<BudgetProgress> budgets, int cash) {
  final open = budgets.fold<int>(
    0,
    (sum, b) => sum + (b.reserved > 0 ? b.reserved : 0),
  );
  if (open <= cash) return budgets;

  final available = cash < 0 ? 0 : cash;
  return [
    for (final b in budgets)
      b.withCashCap(
        b.reserved <= 0 ? 0 : (available * (b.reserved / open)).floor(),
      ),
  ];
}
