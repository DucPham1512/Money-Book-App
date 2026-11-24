import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/repository.dart';
import '../../core/format/money.dart';
import '../../core/icons.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';

/// Nạp tiền vào quỹ hoặc rút ngược lại.
///
/// Cả hai đều là chuyển ví thật: nạp thì tiền đi từ ví chi tiêu sang ví giữ
/// quỹ, rút thì ngược lại.
Future<void> showFundTransferSheet(
  BuildContext context, {
  required FundProgress progress,
  bool withdraw = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _FundTransferSheet(progress: progress, withdraw: withdraw),
    ),
  );
}

class _FundTransferSheet extends ConsumerStatefulWidget {
  const _FundTransferSheet({required this.progress, required this.withdraw});

  final FundProgress progress;
  final bool withdraw;

  @override
  ConsumerState<_FundTransferSheet> createState() => _FundTransferSheetState();
}

class _FundTransferSheetState extends ConsumerState<_FundTransferSheet> {
  late final TextEditingController _controller;
  int _amount = 0;
  int? _otherWalletId;

  @override
  void initState() {
    super.initState();
    // Nạp thì gợi ý sẵn phần còn thiếu, đỡ phải tính.
    final suggested =
        widget.withdraw ? widget.progress.saved : widget.progress.missing;
    _amount = suggested ?? 0;
    _controller = TextEditingController(
      text: _amount > 0 ? groupDigits(_amount) : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Chọn sẵn một ví chi tiêu để chỉ còn bấm xác nhận.
  ///
  /// Ưu tiên ví khác ví giữ quỹ như trước; chỉ có mỗi ví giữ quỹ thì chọn
  /// luôn nó — nạp / rút tại chỗ là trường hợp hợp lệ.
  void _pickDefaultWallet(List<WalletWithBalance> wallets) {
    if (_otherWalletId != null) return;
    final fundWallet = widget.progress.fund.walletId;
    final candidates = wallets.where((w) => w.id != fundWallet).toList();
    if (candidates.isEmpty) {
      if (wallets.any((w) => w.id == fundWallet)) _otherWalletId = fundWallet;
      return;
    }
    // Nạp thì lấy ví nhiều tiền nhất cho chắc đủ; rút thì trả về ví đầu.
    _otherWalletId = widget.withdraw
        ? candidates.first.id
        : candidates.reduce((a, b) => b.balance > a.balance ? b : a).id;
  }

  Future<void> _submit() async {
    if (_amount <= 0) {
      showSnack(context, 'Nhập số tiền lớn hơn 0');
      return;
    }
    if (_otherWalletId == null) {
      showSnack(context, 'Hãy chọn ví');
      return;
    }
    if (widget.withdraw && _amount > widget.progress.saved) {
      showSnack(context, 'Quỹ chỉ còn ${formatVnd(widget.progress.saved)}');
      return;
    }

    final repo = ref.read(repositoryProvider);
    final fundWallet = widget.progress.fund.walletId;

    if (widget.withdraw) {
      await repo.withdrawFromFund(
        fundId: widget.progress.id,
        walletFromId: fundWallet,
        walletToId: _otherWalletId!,
        amount: _amount,
        occurredAt: DateTime.now(),
        note: 'Rút khỏi quỹ ${widget.progress.name}',
      );
    } else {
      await repo.depositToFund(
        fundId: widget.progress.id,
        walletFromId: _otherWalletId!,
        walletToId: fundWallet,
        amount: _amount,
        occurredAt: DateTime.now(),
        note: 'Nạp quỹ ${widget.progress.name}',
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
    showSnack(
      context,
      widget.withdraw
          ? 'Đã rút ${formatVnd(_amount)} khỏi quỹ'
          : 'Đã nạp ${formatVnd(_amount)} vào quỹ',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wallets = ref.watch(walletsProvider);
    final fundWalletName = widget.progress.walletName;

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
            Text(
              widget.withdraw ? 'Rút khỏi quỹ' : 'Nạp vào quỹ',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.progress.name} · đang có '
              '${formatVnd(widget.progress.saved)}',
              style: TextStyle(color: scheme.outline),
            ),
            const SizedBox(height: 20),
            AmountField(
              controller: _controller,
              label: 'Số tiền',
              autofocus: true,
              onChanged: (v) => setState(() => _amount = v),
            ),
            const SizedBox(height: 20),
            wallets.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Lỗi: $e'),
              data: (list) {
                _pickDefaultWallet(list);
                // Có cả ví giữ quỹ: tiền đã nằm sẵn ở đó thì nạp tại chỗ, quỹ
                // đủ rồi thì rút tại chỗ để tiêu.
                final items = list;

                return DropdownButtonFormField<int>(
                  initialValue: _otherWalletId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: widget.withdraw ? 'Trả về ví' : 'Lấy từ ví',
                    prefixIcon:
                        const Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: [
                    for (final w in items)
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
                              child: Text(
                                w.id == widget.progress.fund.walletId
                                    ? '${w.name} (ví giữ quỹ)'
                                    : w.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              formatVndShort(w.balance),
                              style: TextStyle(
                                color: scheme.outline,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _otherWalletId = v),
                );
              },
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _otherWalletId == widget.progress.fund.walletId
                    // Cùng một ví: không có tiền nào di chuyển, chỉ đổi nhãn.
                    ? (widget.withdraw
                        ? '${formatVnd(_amount)} vẫn nằm ở $fundWalletName, '
                            'chỉ bỏ nhãn quỹ. Số này quay lại phần tiêu được.'
                        : '${formatVnd(_amount)} đang có sẵn ở $fundWalletName '
                            'được dành cho quỹ. Số dư ví không đổi, nhưng số '
                            'này không còn tính vào tiền tiêu được.')
                    : widget.withdraw
                        ? 'Chuyển ${formatVnd(_amount)} từ $fundWalletName về '
                            'ví chi tiêu. Tiền quay lại phần tiêu được.'
                        : 'Chuyển ${formatVnd(_amount)} sang $fundWalletName. '
                            'Số này sẽ không còn tính vào tiền tiêu được.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check),
              label: Text(widget.withdraw ? 'Rút ra' : 'Nạp vào'),
            ),
          ],
        ),
      ),
    );
  }
}
