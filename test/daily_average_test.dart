import 'package:flutter_test/flutter_test.dart';
import 'package:moneybook/features/home/month_summary_card.dart';

/// "Chi/ngày" ở màn Tổng quan phải chia theo ngày mà app đang coi là hôm nay
/// (todayProvider), không phải theo đồng hồ lúc thẻ được vẽ lần đầu.
void main() {
  test('chia cho số ngày đã qua, tính cả hôm nay', () {
    expect(dailyAverageSpend(1000000, today: DateTime(2026, 9, 10)), 100000);
    expect(dailyAverageSpend(1000000, today: DateTime(2026, 9, 11)), 90909);
  });

  test('ngày đầu tháng chia cho 1', () {
    expect(dailyAverageSpend(70000, today: DateTime(2026, 10, 1)), 70000);
  });
}
