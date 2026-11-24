import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/repository.dart';
import '../../core/format/money.dart';
import '../../core/icons.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../transactions/tx_editor_screen.dart';
import 'template_editor_sheet.dart';

/// Dùng một mẫu: đủ trường thì ghi luôn tại thời điểm bấm, thiếu thì mở màn
/// ghi đã điền sẵn phần còn lại.
///
/// [context] phải còn sống sau khi bấm — gọi từ trong bottom sheet thì truyền
/// context của Navigator chứ không phải của sheet, vì sheet đóng ngay.
Future<void> useTemplate(
  BuildContext context,
  WidgetRef ref,
  TemplateView template,
) async {
  final repo = ref.read(repositoryProvider);

  if (template.isOneTap) {
    final id = await repo.recordFromTemplate(
      template.id,
      occurredAt: DateTime.now(),
    );
    if (!context.mounted) return;
    if (id != null) {
      showSnack(
        context,
        'Đã ghi ${formatVnd(template.amount!)} · ${template.label}',
        action: SnackBarAction(
          label: 'Hoàn tác',
          onPressed: () => repo.softDeleteTransaction(id),
        ),
      );
      return;
    }
    // Mẫu vừa đổi ở nơi khác (ví bị lưu trữ, danh mục bị xoá): đọc lại rồi
    // để người dùng điền nốt.
    final fresh = await repo.getTemplate(template.id);
    if (!context.mounted || fresh == null) return;
    template = fresh;
  }

  await openTxEditor(context, fromTemplate: template);
}

/// Màn quản lý mẫu chi tiêu: thêm, sửa, xoá, kéo để đổi thứ tự.
class TemplateScreen extends ConsumerWidget {
  const TemplateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mẫu chi tiêu')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTemplateEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Thêm mẫu'),
      ),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.bolt_outlined,
              title: 'Chưa có mẫu nào',
              message:
                  'Mẫu là khoản chi hay lặp lại: cà phê sáng, gửi xe, ăn '
                  'trưa. Lưu một lần, sau đó bấm một chạm ở màn Tổng quan là '
                  'ghi xong, thời điểm lấy đúng lúc bấm.',
              action: FilledButton.icon(
                onPressed: () => showTemplateEditor(context),
                icon: const Icon(Icons.add),
                label: const Text('Thêm mẫu'),
              ),
            );
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
            itemCount: list.length,
            onReorder: (from, to) {
              final ids = list.map((t) => t.id).toList();
              if (to > from) to -= 1;
              ids.insert(to, ids.removeAt(from));
              ref.read(repositoryProvider).reorderTemplates(ids);
            },
            footer: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                'Mẫu đủ số tiền, ví và danh mục thì bấm là ghi luôn. Thiếu '
                'trường nào thì bấm vào sẽ mở màn ghi đã điền sẵn phần còn '
                'lại. Giữ và kéo để đổi thứ tự.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            itemBuilder: (context, i) {
              final t = list[i];
              return _TemplateTile(key: ValueKey(t.id), template: t);
            },
          );
        },
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({super.key, required this.template});

  final TemplateView template;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = template;
    final color = t.categoryColorValue == null
        ? null
        : Color(t.categoryColorValue!);

    final details = <String>[
      t.hasWallet ? t.walletName! : 'Chọn ví khi ghi',
      if (t.hasCategory) t.categoryName! else 'Chọn danh mục khi ghi',
    ];

    return ListTile(
      leading: IconAvatar(
        icon: iconFor(t.categoryIconKey, fallback: Icons.bolt_outlined),
        color: color,
      ),
      title: Text(t.label, overflow: TextOverflow.ellipsis),
      subtitle: Text(details.join(' · '), overflow: TextOverflow.ellipsis),
      trailing: t.hasAmount
          ? MoneyText(t.amount!, colored: false)
          : Text(
              'Nhập khi ghi',
              style: TextStyle(fontSize: 12.5, color: scheme.outline),
            ),
      onTap: () => showTemplateEditor(context, editing: t),
    );
  }
}

/// Hàng nút ghi nhanh theo mẫu. Bấm để dùng, giữ để sửa mẫu.
class TemplateChips extends StatelessWidget {
  const TemplateChips({
    super.key,
    required this.templates,
    required this.onTap,
    this.onLongPress,
  });

  final List<TemplateView> templates;
  final ValueChanged<TemplateView> onTap;
  final ValueChanged<TemplateView>? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in templates)
          _TemplateChip(
            template: t,
            onTap: () => onTap(t),
            onLongPress: onLongPress == null ? null : () => onLongPress!(t),
          ),
      ],
    );
  }
}

class _TemplateChip extends StatelessWidget {
  const _TemplateChip({
    required this.template,
    required this.onTap,
    this.onLongPress,
  });

  final TemplateView template;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = template;
    final color = t.categoryColorValue == null
        ? scheme.primary
        : Color(t.categoryColorValue!);

    return Material(
      color: scheme.surfaceContainerHigh,
      shape: StadiumBorder(
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                iconFor(t.categoryIconKey, fallback: Icons.bolt_outlined),
                size: 18,
                color: color,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  t.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 6),
              // Mẫu thiếu trường sẽ mở màn ghi thay vì ghi luôn — phải nhìn
              // ra được trước khi bấm.
              if (t.isOneTap)
                Text(
                  formatVndShort(t.amount!),
                  style: TextStyle(color: scheme.outline, fontSize: 13),
                )
              else
                Icon(Icons.edit_note, size: 18, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

// ----- Thêm / sửa mẫu ------------------------------------------------------
