import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/repository.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/icons.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';

Future<void> showBudgetEditor(BuildContext context, {BudgetProgress? editing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _BudgetEditor(editing: editing),
    ),
  );
}

class _BudgetEditor extends ConsumerStatefulWidget {
  const _BudgetEditor({this.editing});

  final BudgetProgress? editing;

  @override
  ConsumerState<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends ConsumerState<_BudgetEditor> {
  late final TextEditingController _controller;
  int? _categoryId;
  late bool _everyMonth;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    _controller = TextEditingController(
      text: editing == null ? '' : groupDigits(editing.limitAmount),
    );
    _categoryId = editing?.categoryId;
    _everyMonth = editing?.isRecurring ?? true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseVnd(_controller.text);
    if (_categoryId == null) {
      showSnack(context, 'Hãy chọn danh mục');
      return;
    }
    if (amount <= 0) {
      showSnack(context, 'Nhập hạn mức lớn hơn 0');
      return;
    }

    final repo = ref.read(repositoryProvider);
    final monthKey = ref.read(selectedMonthProvider);

    // Đổi phạm vi áp dụng thì bản ghi cũ không còn đúng nữa, phải dọn đi.
    if (_isEditing && widget.editing!.isRecurring != _everyMonth) {
      await repo.deleteBudget(widget.editing!.budgetId);
    }

    await repo.setBudget(
      categoryId: _categoryId!,
      limitAmount: amount,
      monthKey: _everyMonth ? null : monthKey,
    );

    if (!mounted) return;
    Navigator.pop(context);
    showSnack(context, 'Đã đặt hạn mức');
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Xoá hạn mức?',
      message:
          'Giao dịch của "${widget.editing!.categoryName}" vẫn giữ nguyên.',
    );
    if (!ok || !mounted) return;

    await ref.read(repositoryProvider).deleteBudget(widget.editing!.budgetId);
    if (!mounted) return;
    Navigator.pop(context);
    showSnack(context, 'Đã xoá hạn mức');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categories = ref.watch(expenseCategoriesProvider);
    final monthKey = ref.watch(selectedMonthProvider);

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
                    _isEditing ? 'Sửa hạn mức' : 'Đặt hạn mức',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Xoá hạn mức',
                    onPressed: _delete,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AmountField(
              controller: _controller,
              label: 'Hạn mức mỗi tháng',
              autofocus: !_isEditing,
              showQuickAdd: false,
            ),
            const SizedBox(height: 20),
            Text('Danh mục', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            categories.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Lỗi: $e'),
              data: (list) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in list)
                    ChoiceChip(
                      selected: _categoryId == c.id,
                      showCheckmark: false,
                      onSelected: _isEditing
                          ? null
                          : (_) => setState(() => _categoryId = c.id),
                      avatar: Icon(
                        iconFor(c.iconKey, fallback: Icons.label_outline),
                        size: 18,
                        color: c.colorValue == null
                            ? null
                            : Color(c.colorValue!),
                      ),
                      label: Text(c.name),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _everyMonth,
              onChanged: (v) => setState(() => _everyMonth = v),
              title: const Text('Áp dụng cho mọi tháng'),
              subtitle: Text(
                _everyMonth
                    ? 'Hạn mức này lặp lại hàng tháng'
                    : 'Chỉ áp dụng cho ${monthKeyLabel(monthKey)}',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
