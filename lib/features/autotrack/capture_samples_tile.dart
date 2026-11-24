import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/domain/autotrack/mask.dart';
import '../../core/domain/autotrack/sample_issue.dart';
import '../../core/format/dates.dart';
import '../../core/widgets.dart';
import 'autotrack_providers.dart';

/// Một app đang (hoặc đã hết hạn) ghi mẫu, mở ra thấy các mẫu của nó.
///
/// Mẫu chỉ để viết parser: không bao giờ thành giao dịch, không nằm trong
/// nhật ký thông báo thật. Chọn mẫu rồi gửi lên GitHub thành issue — app mở
/// trang tạo issue trong trình duyệt, người dùng xoá tên người rồi tự Submit.
class CaptureAppTile extends ConsumerStatefulWidget {
  const CaptureAppTile({super.key, required this.app, required this.onChanged});

  final TrackedApp app;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<CaptureAppTile> createState() => _CaptureAppTileState();
}

class _CaptureAppTileState extends ConsumerState<CaptureAppTile> {
  /// Mẫu đã bỏ chọn. Lưu phần bỏ chọn chứ không phải phần chọn, để mẫu mới
  /// đến tự được chọn.
  final _unselected = <int>{};

  String get _name => widget.app.label ?? widget.app.packageName;

  @override
  Widget build(BuildContext context) {
    final samples =
        ref.watch(capturedEventsProvider(widget.app.packageName)).value ??
        const <NotificationEvent>[];
    final until = DateTime.fromMillisecondsSinceEpoch(
      widget.app.captureUntil ?? 0,
    );
    final active = until.isAfter(DateTime.now());
    final selected = [
      for (final s in samples)
        if (!_unselected.contains(s.id)) s,
    ];

    return ExpansionTile(
      // Mũi tên mở nằm bên trái, bên phải dành cho nút dừng ghi mẫu.
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(_name),
      subtitle: Text(
        '${active ? 'Ghi mẫu tới ${formatDateTime(until)}' : 'Đã hết hạn ghi mẫu'}'
        ' · ${samples.length} mẫu',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Dừng ghi mẫu',
        onPressed: () => _stop(samples.length),
      ),
      children: [
        if (samples.isEmpty)
          const ListTile(
            dense: true,
            title: Text('Chưa có mẫu. Thông báo của app sẽ hiện ở đây'),
          ),
        for (final s in samples)
          CheckboxListTile(
            dense: true,
            value: !_unselected.contains(s.id),
            onChanged: (v) => setState(() {
              if (v ?? false) {
                _unselected.remove(s.id);
              } else {
                _unselected.add(s.id);
              }
            }),
            title: Text(
              s.title.isEmpty ? s.body.split('\n').first : s.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${formatDateTime(DateTime.fromMillisecondsSinceEpoch(s.postedAt))}'
              ' · ${maskDigits(s.body)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (samples.isNotEmpty) _sendButton(selected),
      ],
    );
  }

  Widget _sendButton(List<NotificationEvent> selected) {
    final issue = selected.isEmpty ? null : _issueFor(selected);
    final tooLong = issue != null && !issue.fitsInUrl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.tonalIcon(
            icon: const Icon(Icons.bug_report_outlined),
            label: Text('Gửi ${selected.length} mẫu lên GitHub'),
            onPressed: issue == null || tooLong ? null : () => _send(issue),
          ),
          if (tooLong)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Quá dài cho một lần gửi. Bỏ chọn bớt',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  SampleIssue _issueFor(List<NotificationEvent> events) => buildSampleIssue(
    appName: _name,
    packageName: widget.app.packageName,
    samples: [
      for (final e in events)
        NotificationSample(
          postedAt: DateTime.fromMillisecondsSinceEpoch(e.postedAt),
          title: e.title,
          body: e.body,
        ),
    ],
  );

  Future<void> _send(SampleIssue issue) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gửi mẫu lên GitHub'),
        content: const Text(
          'Repo công khai. Số tài khoản đã được che, nhưng hãy xoá tên người trước khi bấm Submit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mở GitHub'),
          ),
        ],
      ),
    );
    if (go != true) return;
    final ok = await ref.read(openUrlProvider)(issue.url);
    if (!ok && mounted) showSnack(context, 'Không mở được trình duyệt');
  }

  Future<void> _stop(int sampleCount) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Dừng ghi mẫu $_name?'),
        content: Text(
          sampleCount == 0
              ? 'App này sẽ không được ghi mẫu nữa.'
              : '$sampleCount mẫu đã ghi cũng bị xoá.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dừng và xoá'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(autoTrackRepositoryProvider)
        .stopCapture(widget.app.packageName);
    await widget.onChanged();
  }
}
