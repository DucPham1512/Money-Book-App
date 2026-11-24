import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/db/autotrack_repository.dart';
import '../../core/db/database.dart';
import '../../core/providers.dart';
import 'autotrack_health.dart';
import 'autotrack_platform.dart';
import 'autotrack_service.dart';

final autoTrackRepositoryProvider = Provider<AutoTrackRepository>((ref) {
  return AutoTrackRepository(ref.watch(dbProvider));
});

/// Ghi đè trong test bằng một bản giả.
final autoTrackPlatformProvider = Provider<AutoTrackPlatform>((ref) {
  return ChannelAutoTrackPlatform();
});

final autoTrackServiceProvider = Provider<AutoTrackService>((ref) {
  return AutoTrackService(
    repo: ref.watch(repositoryProvider),
    auto: ref.watch(autoTrackRepositoryProvider),
    platform: ref.watch(autoTrackPlatformProvider),
  );
});

final autoTrackEnabledProvider = StreamProvider<bool>((ref) {
  return ref.watch(autoTrackRepositoryProvider).watchEnabled();
});

final trackedAppsProvider = StreamProvider<List<TrackedApp>>((ref) {
  return ref.watch(autoTrackRepositoryProvider).watchTrackedApps();
});

final accountWalletsProvider =
    StreamProvider.family<List<AccountWallet>, String>((ref, packageName) {
      return ref
          .watch(autoTrackRepositoryProvider)
          .watchAccountWallets(packageName);
    });

/// Quyền "Truy cập thông báo". Không tự cập nhật: màn cài đặt làm mới khi
/// quay lại từ màn cài đặt hệ thống.
final listenerEnabledProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(autoTrackPlatformProvider).isListenerEnabled();
});

final autoTrackEventsProvider = StreamProvider.autoDispose
    .family<List<NotificationEvent>, Set<EventStatus>?>((ref, statuses) {
      return ref
          .watch(autoTrackRepositoryProvider)
          .watchEvents(statuses: statuses);
    });

/// Mẫu đã ghi của một app (gói), mới nhất trước.
final capturedEventsProvider = StreamProvider.autoDispose
    .family<List<NotificationEvent>, String>((ref, packageName) {
      return ref
          .watch(autoTrackRepositoryProvider)
          .watchCapturedEvents(packageName);
    });

/// Mở một URL bằng app bên ngoài (trình duyệt). App không có quyền mạng, nên
/// mọi thứ cần mạng đều đi qua trình duyệt. Test thay bằng hàm giả.
final openUrlProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => (url) => launchUrl(url, mode: LaunchMode.externalApplication),
);

final reviewCountProvider = StreamProvider<int>((ref) {
  return ref.watch(autoTrackRepositoryProvider).watchReviewCount();
});

/// Hàng chờ phân loại: giao dịch tự ghi chưa phân loại hoặc mới chỉ đoán.
final reviewItemsProvider = StreamProvider<List<ReviewItem>>((ref) {
  return ref.watch(autoTrackRepositoryProvider).watchReviewItems();
});

final receiverRulesProvider = StreamProvider.autoDispose<List<RuleView>>((ref) {
  return ref.watch(autoTrackRepositoryProvider).watchRules();
});

final categoryKeywordsProvider =
    StreamProvider.autoDispose<List<KeywordView>>((ref) {
      return ref.watch(autoTrackRepositoryProvider).watchKeywords();
    });

final autoTrackFlagProvider = StreamProvider.autoDispose.family<bool, String>((
  ref,
  key,
) {
  return ref.watch(autoTrackRepositoryProvider).watchFlag(key, fallback: true);
});

/// Tăng lên để buộc kiểm tra sức khoẻ lại (sau mỗi lần đồng bộ, khi quay lại
/// app, sau khi ẩn một cảnh báo).
final autoTrackHealthTickProvider = StateProvider<int>((ref) => 0);

/// Cảnh báo của tính năng tự động ghi. Tự tính lại khi số dư ví đổi.
final autoTrackHealthProvider = FutureProvider.autoDispose<AutoTrackHealth>((
  ref,
) {
  ref.watch(autoTrackHealthTickProvider);
  ref.watch(walletsProvider); // đổi mỗi khi có giao dịch
  ref.watch(autoTrackEnabledProvider);
  return checkAutoTrackHealth(
    repo: ref.watch(repositoryProvider),
    auto: ref.watch(autoTrackRepositoryProvider),
    platform: ref.watch(autoTrackPlatformProvider),
    now: DateTime.now(),
  );
});
