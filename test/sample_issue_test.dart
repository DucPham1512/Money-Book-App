import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneybook/core/domain/autotrack/sample_issue.dart';

/// Gói các mẫu thông báo thành một issue GitHub mở sẵn trong trình duyệt: số
/// tài khoản đã che, nội dung là JSON, vừa giới hạn độ dài URL.
void main() {
  const pkg = 'com.mservice.momotransfer';

  NotificationSample sample(DateTime at, String title, String body) =>
      NotificationSample(postedAt: at, title: title, body: body);

  final received = sample(
    DateTime(2026, 11, 24, 14, 19, 5),
    'Nhận chuyển khoản từ NGUYEN VAN A',
    'Số tiền 10.000\u00a0₫ về Túi Thần Tài. Lời nhắn: "CK 0100123456789".',
  );
  final paid = sample(
    DateTime(2026, 12, 1, 9, 2),
    'Thanh toán thành công',
    'Bạn đã thanh toán +35.000đ cho Highlands & Co',
  );

  Map<String, dynamic> jsonOf(SampleIssue issue) {
    final body = issue.body;
    expect(body, startsWith('```json\n'));
    expect(body, endsWith('\n```'));
    return jsonDecode(body.substring(8, body.length - 4))
        as Map<String, dynamic>;
  }

  test('tiêu đề theo khoảng ngày của các mẫu', () {
    final issue = buildSampleIssue(
      appName: 'MoMo',
      packageName: pkg,
      samples: [paid, received],
    );
    expect(
      issue.title,
      'Masked MoMo Notification from 24/11/2026 – 01/12/2026',
    );

    final oneDay = buildSampleIssue(
      appName: 'MoMo',
      packageName: pkg,
      samples: [received],
    );
    expect(oneDay.title, 'Masked MoMo Notification from 24/11/2026');
  });

  test('nội dung là JSON, mẫu cũ trước, số dài đã che, chữ giữ nguyên', () {
    final issue = buildSampleIssue(
      appName: 'MoMo',
      packageName: pkg,
      samples: [paid, received],
    );
    final json = jsonOf(issue);
    expect(json['app'], 'MoMo');
    expect(json['packageName'], pkg);
    final samples = (json['samples'] as List).cast<Map<String, dynamic>>();
    expect(samples.map((s) => s['title']), [
      'Nhận chuyển khoản từ NGUYEN VAN A',
      'Thanh toán thành công',
    ]);
    expect(
      samples.first['body'],
      'Số tiền 10.000\u00a0₫ về Túi Thần Tài. Lời nhắn: "CK xxxxxxxxxx789".',
    );
    expect(
      samples.first['postedAt'],
      matches(RegExp(r'^2026-11-24T14:19:05[+-]\d\d:\d\d$')),
      reason: 'giờ địa phương kèm múi giờ',
    );
  });

  test('URL mở trang tạo issue của repo, có nhãn, mã hoá đúng', () {
    final issue = buildSampleIssue(
      appName: 'MoMo',
      packageName: pkg,
      samples: [paid, received],
    );
    final url = issue.url;
    expect(url.scheme, 'https');
    expect(url.host, 'github.com');
    expect(url.path, '/DucPham1512/Money-Book-App/issues/new');
    expect(url.queryParameters['labels'], 'documentation,enhancement');
    expect(url.queryParameters['title'], issue.title);
    expect(
      url.queryParameters['body'],
      issue.body,
      reason: '₫, khoảng trắng không ngắt, dấu + và & phải đi qua nguyên vẹn',
    );
    expect(issue.fitsInUrl, isTrue);
  });

  test('quá dài cho một URL thì báo không vừa', () {
    final many = [
      for (var i = 0; i < 60; i++)
        sample(
          DateTime(2026, 11, 24, 8, i),
          'Nhận chuyển khoản từ NGUYỄN VĂN A',
          'Số tiền 10.000 ₫ về Túi Thần Tài. Lời nhắn: "Chuyển tiền ăn trưa"',
        ),
    ];
    final issue = buildSampleIssue(
      appName: 'MoMo',
      packageName: pkg,
      samples: many,
    );
    expect(issue.fitsInUrl, isFalse);
    expect(issue.url.toString().length, greaterThan(kMaxIssueUrlLength));
  });
}
