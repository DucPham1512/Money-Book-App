import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/repository.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/icons.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

Future<void> showFundEditor(
  BuildContext context, {
  FundProgress? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _FundEditor(editing: editing),
    ),
  );
}

class _FundEditor extends ConsumerStatefulWidget {
  const _FundEditor({this.editing});

  final FundProgress? editing;

  @override
  ConsumerState<_FundEditor> createState() => _FundEditorState();
}

class _FundEditorState extends ConsumerState<_FundEditor> {
  final _nameController = TextEditingController();
  late final TextEditingController _targetController;

  int? _walletId;
  int? _colorValue;
  String? _iconKey;
  DateTime? _due;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing?.fund;
    _targetController = TextEditingController(
      text: editing?.targetAmount == null
          ? ''
          : groupDigits(editing!.targetAmount!),
    );
    if (editing != null) {
      _nameController.text = editing.name;
      _walletId = editing.walletId;
      _colorValue = editing.colorValue;
      _iconKey = editing.iconKey;
      _due = editing.dueDayKey == null
          ? null
          : dayKeyToDate(editing.dueDayKey!);
    } else {
      _colorValue = kPickerColors.first;
      _iconKey = 'savings';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: 'Khi nào cần dùng tới',
    );
    if (picked != null) setState(() => _due = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showSnack(context, 'Đặt tên cho quỹ');
      return;
    }
    if (_walletId == null) {
      showSnack(context, 'Chọn ví sẽ giữ tiền quỹ');
      return;
    }

    final repo = ref.read(repositoryProvider);
    final target = parseVnd(_targetController.text);
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_isEditing) {
      await repo.updateFund(
        widget.editing!.fund.copyWith(
          name: name,
          walletId: _walletId!,
          targetAmount: Value(target > 0 ? target : null),
          dueDayKey: Value(_due == null ? null : dayKeyOf(_due!)),
          colorValue: Value(_colorValue),
          iconKey: Value(_iconKey),
          updatedAt: now,
        ),
      );
    } else {
      await repo.insertFund(
        FundsCompanion.insert(
          name: name,
          walletId: _walletId!,
          targetAmount: Value(target > 0 ? target : null),
          dueDayKey: Value(_due == null ? null : dayKeyOf(_due!)),
          colorValue: Value(_colorValue),
          iconKey: Value(_iconKey),
          sortOrder: Value(await repo.nextFundSortOrder()),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
    showSnack(context, _isEditing ? 'Đã lưu' : 'Đã lập quỹ');
  }

  Future<void> _delete() async {
    final progress = widget.editing!;
    final repo = ref.read(repositoryProvider);

    if (progress.saved > 0) {
      final ok = await confirmDialog(
        context,
        title: 'Quỹ vẫn còn tiền',
        message: '${progress.name} đang giữ ${formatVnd(progress.saved)}.\n\n'
            'Xoá quỹ không làm mất tiền — số này sẽ quay lại phần tiêu được. '
            'Các giao dịch cũ vẫn còn nguyên, chỉ mất nhãn quỹ.',
        confirmLabel: 'Xoá quỹ',
      );
      if (!ok || !mounted) return;
    } else {
      final ok = await confirmDialog(
        context,
        title: 'Xoá quỹ?',
        message: 'Xoá "${progress.name}".',
      );
      if (!ok || !mounted) return;
    }

    await repo.deleteFund(progress.id);
    if (!mounted) return;
    Navigator.pop(context);
    showSnack(context, 'Đã xoá quỹ');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wallets = ref.watch(walletsProvider);
    final color = _colorValue == null ? null : Color(_colorValue!);

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
                    _isEditing ? 'Sửa quỹ' : 'Lập quỹ mới',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Xoá quỹ',
                    onPressed: _delete,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Tên quỹ',
                hintText: 'Tiền KTX, tiền điện, trả SPayLater...',
                prefixIcon: Icon(Icons.savings_outlined),
              ),
            ),
            const SizedBox(height: 16),
            wallets.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Lỗi: $e'),
              data: (list) => DropdownButtonFormField<int>(
                initialValue: _walletId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Ví giữ tiền quỹ',
                  helperText: 'Thường là ngân hàng ít dùng, để khỏi tiêu nhầm',
                  helperMaxLines: 2,
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
                items: [
                  for (final w in list)
                    DropdownMenuItem(
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
                            child:
                                Text(w.name, overflow: TextOverflow.ellipsis),
                          ),
                          Text(
                            formatVndShort(w.balance),
                            style:
                                TextStyle(color: scheme.outline, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _walletId = v),
              ),
            ),
            const SizedBox(height: 16),
            AmountField(
              controller: _targetController,
              label: 'Cần bao nhiêu',
              showQuickAdd: false,
            ),
            const SizedBox(height: 6),
            Text(
              'Để trống nếu chỉ để dành mà chưa có con số cụ thể.',
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Khi nào cần dùng'),
              subtitle: Text(
                _due == null ? 'Chưa đặt' : formatDate(_due!),
              ),
              trailing: _due == null
                  ? const Icon(Icons.chevron_right)
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Bỏ hạn',
                      onPressed: () => setState(() => _due = null),
                    ),
              onTap: _pickDue,
            ),
            const SizedBox(height: 12),
            Text('Màu', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            ColorPickerRow(
              selected: _colorValue,
              onSelected: (v) => setState(() => _colorValue = v),
            ),
            const SizedBox(height: 16),
            Text('Biểu tượng', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            IconPickerGrid(
              keys: kFundIconKeys,
              selected: _iconKey,
              color: color,
              onSelected: (v) => setState(() => _iconKey = v),
            ),
            const SizedBox(height: 20),
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
