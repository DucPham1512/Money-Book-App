import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/repository.dart';
import '../../core/format/money.dart';
import '../../core/icons.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';

/// Thêm hoặc sửa một mẫu.
Future<void> showTemplateEditor(BuildContext context, {TemplateView? editing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _TemplateEditor(editing: editing),
    ),
  );
}

class _TemplateEditor extends ConsumerStatefulWidget {
  const _TemplateEditor({this.editing});

  final TemplateView? editing;

  @override
  ConsumerState<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends ConsumerState<_TemplateEditor> {
  final _noteController = TextEditingController();
  final _amountController = TextEditingController();
  int? _walletId;
  int? _categoryId;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final t = widget.editing?.template;
    if (t != null) {
      _noteController.text = t.note ?? '';
      _amountController.text = t.amount == null ? '' : groupDigits(t.amount!);
      _walletId = t.walletId;
      _categoryId = t.categoryId;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final note = _noteController.text.trim();
    final amount = parseVnd(_amountController.text);
    if (note.isEmpty && _categoryId == null) {
      showSnack(context, 'Đặt ghi chú hoặc chọn danh mục để đặt tên cho mẫu');
      return;
    }

    final repo = ref.read(repositoryProvider);
    if (_isEditing) {
      await repo.updateTemplate(
        id: widget.editing!.id,
        note: note.isEmpty ? null : note,
        amount: amount > 0 ? amount : null,
        walletId: _walletId,
        categoryId: _categoryId,
      );
    } else {
      await repo.insertTemplate(
        note: note.isEmpty ? null : note,
        amount: amount > 0 ? amount : null,
        walletId: _walletId,
        categoryId: _categoryId,
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
    showSnack(context, _isEditing ? 'Đã lưu mẫu' : 'Đã thêm mẫu');
  }

  Future<void> _delete() async {
    final t = widget.editing!;
    final ok = await confirmDialog(
      context,
      title: 'Xoá mẫu?',
      message:
          'Xoá mẫu "${t.label}". Các khoản đã ghi từ mẫu này vẫn còn '
          'nguyên.',
    );
    if (!ok || !mounted) return;
    await ref.read(repositoryProvider).deleteTemplate(t.id);
    if (!mounted) return;
    Navigator.pop(context);
    showSnack(context, 'Đã xoá mẫu');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wallets = ref.watch(walletsProvider).valueOrNull ?? const [];
    final categories =
        ref.watch(expenseCategoriesProvider).valueOrNull ?? const [];

    // Ví đã lưu trữ hay danh mục đã xoá không còn trong danh sách chọn; để
    // nguyên id cũ thì DropdownButton ném lỗi, nên coi như chưa chọn.
    final walletValue = wallets.any((w) => w.id == _walletId)
        ? _walletId
        : null;
    final categoryValue = categories.any((c) => c.id == _categoryId)
        ? _categoryId
        : null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? 'Sửa mẫu chi tiêu' : 'Mẫu chi tiêu mới',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Xoá mẫu',
                    onPressed: _delete,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Ghi chú',
                hintText: 'Cà phê sáng, gửi xe, cơm trưa...',
                helperText: 'Cũng là tên của mẫu',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 16),
            AmountField(
              controller: _amountController,
              label: 'Số tiền',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            Text(
              'Để trống nếu mỗi lần một khác, bấm mẫu sẽ hỏi số tiền.',
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              // Đổi key khi danh sách ví đổi để giá trị hiển thị khớp lại.
              key: ValueKey('wallet-$walletValue-${wallets.length}'),
              initialValue: walletValue,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Trừ vào ví',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Chọn khi ghi'),
                ),
                for (final w in wallets)
                  DropdownMenuItem<int?>(
                    value: w.id,
                    child: Row(
                      children: [
                        Icon(
                          iconFor(w.wallet.iconKey, fallback: Icons.wallet),
                          size: 18,
                          color: w.wallet.colorValue == null
                              ? null
                              : Color(w.wallet.colorValue!),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(w.name, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _walletId = v),
            ),
            const SizedBox(height: 16),
            Text('Danh mục', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  selected: categoryValue == null,
                  onSelected: (_) => setState(() => _categoryId = null),
                  showCheckmark: false,
                  label: const Text('Chọn khi ghi'),
                ),
                for (final c in categories)
                  ChoiceChip(
                    selected: categoryValue == c.id,
                    onSelected: (_) => setState(() => _categoryId = c.id),
                    showCheckmark: false,
                    avatar: Icon(
                      iconFor(c.iconKey, fallback: Icons.label_outline),
                      size: 18,
                      color: c.colorValue == null ? null : Color(c.colorValue!),
                    ),
                    label: Text(c.name),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Lưu mẫu'),
            ),
          ],
        ),
      ),
    );
  }
}
