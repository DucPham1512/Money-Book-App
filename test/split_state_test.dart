import 'package:flutter_test/flutter_test.dart';
import 'package:moneybook/features/transactions/split_bill_section.dart';

/// Phép chia tiền trong màn ghi chi tiêu, chốt lại hành vi hiện tại trước khi
/// tách [SplitState] ra file riêng.
void main() {
  late SplitState s;

  setUp(() => s = SplitState()..enabled = true);
  tearDown(() => s.dispose());

  group('chia đều', () {
    test('phần lẻ dồn vào mình để tổng khớp hoá đơn', () {
      s
        ..toggle(1)
        ..toggle(2);
      expect(s.headcount, 3);
      expect(s.equalShares(100000), {1: 33333, 2: 33333});
      expect(s.myShareFor(100000), 33334);
    });

    test('chưa chọn ai hoặc tổng không dương thì không chia', () {
      expect(s.equalShares(100000), isEmpty);
      s.toggle(1);
      expect(s.equalShares(0), isEmpty);
      expect(s.myShareFor(0), 0);
    });

    test('bấm lại một người là bỏ người đó', () {
      s
        ..toggle(1)
        ..toggle(2)
        ..toggle(1);
      expect(s.personIds, [2]);
      expect(s.controllers.keys, [2]);
    });
  });

  group('chia tay', () {
    setUp(() => s.mode = SplitMode.custom);

    test('chỉ lấy những phần đã nhập số dương', () {
      s
        ..toggle(1)
        ..toggle(2);
      s.controllers[1]!.text = '30.000';
      s.controllers[2]!.text = '';
      expect(s.customShares(), {1: 30000});
      expect(s.sharesFor(100000), {1: 30000});
      expect(s.myShareFor(100000), 70000);
    });

    test('mình có thể không ăn gì: phần của mình bằng 0', () {
      s.toggle(1);
      s.controllers[1]!.text = '100.000';
      expect(s.myShareFor(100000), 0);
      expect(s.validate(100000), isNull);
    });
  });

  group('validate', () {
    test('tắt chia tiền thì luôn hợp lệ', () {
      s.enabled = false;
      expect(s.validate(100000), isNull);
    });

    test('chưa chọn người', () {
      expect(s.validate(100000), 'Hãy chọn người cùng chia tiền');
    });

    test('chia tay mà thiếu phần của ai đó', () {
      s
        ..mode = SplitMode.custom
        ..toggle(1)
        ..toggle(2);
      s.controllers[1]!.text = '10.000';
      expect(s.validate(100000), 'Hãy nhập phần của từng người');
      s.controllers[1]!.text = '';
      expect(s.validate(100000), 'Hãy nhập phần của từng người');
    });

    test('phần mọi người vượt hoá đơn', () {
      s
        ..mode = SplitMode.custom
        ..toggle(1);
      s.controllers[1]!.text = '150.000';
      expect(s.validate(100000), contains('vượt quá hoá đơn'));
    });

    test('chia đều hợp lệ', () {
      s.toggle(1);
      expect(s.validate(100000), isNull);
    });
  });
}
