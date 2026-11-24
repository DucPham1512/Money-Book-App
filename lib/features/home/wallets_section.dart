import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/repository.dart';
import '../../core/icons.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../wallets/wallet_detail_screen.dart';
import '../wallets/wallet_list_screen.dart';
import 'widgets/section_header.dart';

class WalletsSection extends ConsumerWidget {
  const WalletsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Ví của tôi',
          actionLabel: 'Quản lý',
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WalletListScreen()),
          ),
        ),
        const SizedBox(height: 8),
        wallets.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Lỗi: $e'),
          data: (list) {
            if (list.isEmpty) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.add_card),
                  title: const Text('Thêm ví đầu tiên'),
                  subtitle: const Text('Tiền mặt, MoMo, MB Bank...'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WalletListScreen(),
                    ),
                  ),
                ),
              );
            }
            return Card(
              child: Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 68),
                    _WalletRow(item: list[i]),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _WalletRow extends StatelessWidget {
  const _WalletRow({required this.item});

  final WalletWithBalance item;

  @override
  Widget build(BuildContext context) {
    final color =
        item.wallet.colorValue == null ? null : Color(item.wallet.colorValue!);
    return ListTile(
      leading: IconAvatar(
        icon: iconFor(item.wallet.iconKey, fallback: Icons.wallet),
        color: color,
      ),
      title: Text(item.name),
      trailing: MoneyText(item.balance, colored: false),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WalletDetailScreen(walletId: item.id),
        ),
      ),
    );
  }
}
