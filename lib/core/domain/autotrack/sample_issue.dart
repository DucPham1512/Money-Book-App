import 'dart:convert';

import '../../format/dates.dart';
import 'mask.dart';

/// Repo nhận mẫu thông báo để viết parser cho ngân hàng / ví mới.
const kSampleIssueRepo = (owner: 'DucPham1512', name: 'Money-Book-App');

/// URL dài hơn thế này thì GitHub (và nhiều trình duyệt) cắt hoặc từ chối.
/// Chữ tiếng Việt mã hoá vào URL dài ra khoảng ba lần, nên chừng 10–15 mẫu
/// mỗi lần gửi.
const kMaxIssueUrlLength = 8000;

/// Một thông báo đã ghi mẫu.
class NotificationSample {
  const NotificationSample({
    required this.postedAt,
    required this.title,
    required this.body,
  });

  final DateTime postedAt;
  final String title;
  final String body;
}

/// Issue GitHub mở sẵn trong trình duyệt: người dùng xem lại, xoá tên người
/// rồi tự bấm Submit. App không cần mạng, không giữ token.
class SampleIssue {
  const SampleIssue({
    required this.title,
    required this.body,
    required this.url,
  });

  final String title;

  /// JSON của các mẫu, trong khối mã.
  final String body;
  final Uri url;

  bool get fitsInUrl => url.toString().length <= kMaxIssueUrlLength;
}

/// Gói [samples] của một app thành issue. Số dài (tài khoản, mã giao dịch)
/// được che bằng [maskDigits]; tên người thì KHÔNG — người gửi tự xoá trên
/// trang GitHub trước khi bấm Submit, vì repo công khai.
SampleIssue buildSampleIssue({
  required String appName,
  required String packageName,
  required List<NotificationSample> samples,
}) {
  assert(samples.isNotEmpty);
  final sorted = [...samples]..sort((a, b) => a.postedAt.compareTo(b.postedAt));

  final first = formatDate(sorted.first.postedAt);
  final last = formatDate(sorted.last.postedAt);
  final title =
      'Masked $appName Notification from '
      '${first == last ? first : '$first – $last'}';

  final json = const JsonEncoder.withIndent('  ').convert({
    'app': appName,
    'packageName': packageName,
    'samples': [
      for (final s in sorted)
        {
          'postedAt': _isoWithOffset(s.postedAt),
          'title': maskDigits(s.title),
          'body': maskDigits(s.body),
        },
    ],
  });
  final body = '```json\n$json\n```';

  final url = Uri.https(
    'github.com',
    '/${kSampleIssueRepo.owner}/${kSampleIssueRepo.name}/issues/new',
    {'title': title, 'body': body, 'labels': 'documentation,enhancement'},
  );
  return SampleIssue(title: title, body: body, url: url);
}

/// "2026-11-24T14:19:05+07:00": giờ địa phương kèm múi giờ, để parser kiểm
/// được giờ in trong tin.
String _isoWithOffset(DateTime t) {
  final local = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
      '${two(local.day)}T${two(local.hour)}:${two(local.minute)}:'
      '${two(local.second)}$sign${two(minutes ~/ 60)}:${two(minutes % 60)}';
}
