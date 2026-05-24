import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/enums.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/presentation/widgets/action_buttons/base_action_button.widget.dart';
import 'package:immich_mobile/providers/asset_viewer/asset_viewer.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/offline_download_state.provider.dart';
import 'package:immich_mobile/widgets/common/immich_toast.dart';

/// Action button for downloading assets for offline viewing
///
/// Shows different states:
/// - Not cached: Download icon (cloud_download)
/// - Downloading: Progress indicator with percentage
/// - Cached: Checkmark icon (offline_pin)
/// - Failed: Error icon with retry option
class DownloadOfflineActionButton extends ConsumerWidget {
  final ActionSource source;
  final bool iconOnly;
  final bool menuItem;

  const DownloadOfflineActionButton({super.key, required this.source, this.iconOnly = false, this.menuItem = false});

  void _onTap(BuildContext context, WidgetRef ref, RemoteAsset asset) async {
    if (!context.mounted) {
      return;
    }

    final downloadState = ref.read(offlineDownloadStateProvider(asset.id));

    // If already cached, show a message
    if (downloadState.isCached) {
      ImmichToast.show(
        context: context,
        msg: 'offline_download_already_cached'.tr(),
        gravity: ToastGravity.BOTTOM,
        toastType: ToastType.info,
      );
      return;
    }

    // If downloading, show a message
    if (downloadState.isDownloading) {
      ImmichToast.show(
        context: context,
        msg: 'offline_download_in_progress'.tr(),
        gravity: ToastGravity.BOTTOM,
        toastType: ToastType.info,
      );
      return;
    }

    // Start download
    try {
      final notifier = ref.read(offlineDownloadStateProvider(asset.id).notifier);
      await notifier.startDownload(asset);

      if (context.mounted) {
        ImmichToast.show(
          context: context,
          msg: 'offline_download_started'.tr(),
          gravity: ToastGravity.BOTTOM,
          toastType: ToastType.success,
        );
      }
    } catch (error) {
      if (context.mounted) {
        ImmichToast.show(
          context: context,
          msg: 'offline_download_failed'.tr(),
          gravity: ToastGravity.BOTTOM,
          toastType: ToastType.error,
        );
      }
    }
  }

  void _onRetry(BuildContext context, WidgetRef ref, RemoteAsset asset) async {
    if (!context.mounted) {
      return;
    }

    try {
      final notifier = ref.read(offlineDownloadStateProvider(asset.id).notifier);
      await notifier.retryDownload(asset);

      if (context.mounted) {
        ImmichToast.show(
          context: context,
          msg: 'offline_download_retry_started'.tr(),
          gravity: ToastGravity.BOTTOM,
          toastType: ToastType.success,
        );
      }
    } catch (error) {
      if (context.mounted) {
        ImmichToast.show(
          context: context,
          msg: 'offline_download_failed'.tr(),
          gravity: ToastGravity.BOTTOM,
          toastType: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = ref.watch(assetViewerProvider.select((s) => s.currentAsset));

    // Only show for remote-only assets
    if (asset == null || asset is! RemoteAsset || asset.storage != AssetState.remote) {
      return const SizedBox.shrink();
    }

    final downloadState = ref.watch(offlineDownloadStateProvider(asset.id));

    // Determine icon and label based on state
    IconData iconData;
    String label;
    Color? iconColor;
    VoidCallback? onPressed;

    if (downloadState.isCached) {
      iconData = Icons.offline_pin;
      label = 'offline_cached'.tr();
      iconColor = Colors.green;
      onPressed = null; // Disabled when cached
    } else if (downloadState.isDownloading) {
      iconData = Icons.downloading;
      label = 'offline_downloading'.tr();
      iconColor = Colors.blue;
      onPressed = null; // Disabled while downloading
    } else if (downloadState.isFailed) {
      iconData = Icons.error_outline;
      label = 'offline_retry'.tr();
      iconColor = Colors.red;
      onPressed = () => _onRetry(context, ref, asset);
    } else {
      iconData = Icons.cloud_download;
      label = 'offline_download'.tr();
      iconColor = null;
      onPressed = () => _onTap(context, ref, asset);
    }

    // Show progress indicator when downloading
    if (downloadState.isDownloading && !iconOnly) {
      return _DownloadProgressButton(progress: downloadState.progress, label: label, menuItem: menuItem);
    }

    return BaseActionButton(
      iconData: iconData,
      label: label,
      iconColor: iconColor,
      iconOnly: iconOnly,
      menuItem: menuItem,
      onPressed: onPressed,
    );
  }
}

/// Custom button widget that shows download progress
class _DownloadProgressButton extends StatelessWidget {
  final double progress;
  final String label;
  final bool menuItem;

  const _DownloadProgressButton({required this.progress, required this.label, required this.menuItem});

  @override
  Widget build(BuildContext context) {
    if (menuItem) {
      return MenuItemButton(
        style: MenuItemButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.all(16)),
        leadingIcon: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(value: progress > 0 ? progress : null, strokeWidth: 2),
        ),
        onPressed: null,
        child: Text('$label ${(progress * 100).toInt()}%', style: const TextStyle(fontSize: 16)),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 90),
      child: MaterialButton(
        padding: const EdgeInsets.all(10),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
        onPressed: null,
        minWidth: 75.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                value: progress > 0 ? progress : null,
                strokeWidth: 2,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w400),
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
