import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:immich_mobile/services/background_sync.service.dart';
import 'package:immich_mobile/utils/bootstrap.dart';
import 'package:logging/logging.dart';
import 'package:workmanager/workmanager.dart';

const String backgroundSyncTaskName = 'background-sync-task';

final Logger _log = Logger('WorkmanagerCallbackService');

/// Workmanager callback dispatcher invoked by the OS in a background isolate.
@pragma('vm:entry-point')
void workmanagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    _log.info('Workmanager callback: received task=$task inputData=$inputData');

    if (task != backgroundSyncTaskName) {
      _log.warning('Workmanager callback: unknown task "$task", skipping');
      return true;
    }

    try {
      // Initialize database for this background isolate
      final (drift, logDB) = await Bootstrap.initDomain(shouldBufferLogs: false, listenStoreUpdates: false);

      try {
        final didSucceed = await BackgroundSyncService.checkAndDownloadNewAssets(drift);

        if (didSucceed) {
          _log.info('Workmanager callback: background sync completed successfully');
        } else {
          _log.warning('Workmanager callback: background sync reported failure');
        }

        // iOS: Reschedule the one-off task for the next execution
        // This creates a periodic-like behavior on iOS
        if (Platform.isIOS) {
          _log.info('iOS: Rescheduling one-off background sync task for next execution');
          try {
            await Workmanager().registerOneOffTask(
              'immich-background-sync-unique-id',
              backgroundSyncTaskName,
              initialDelay: const Duration(minutes: 15),
              constraints: Constraints(networkType: NetworkType.connected),
              existingWorkPolicy: ExistingWorkPolicy.replace,
            );
            _log.info('iOS: Successfully rescheduled background sync task');
          } catch (error) {
            _log.severe('iOS: Failed to reschedule background sync task: $error');
          }
        }

        return didSucceed;
      } finally {
        // Clean up database connections
        await drift.close();
        await logDB.close();
      }
    } catch (error, stackTrace) {
      _log.severe('Workmanager callback: unhandled error during background sync', error, stackTrace);

      // iOS: Even on error, try to reschedule for next attempt
      if (Platform.isIOS) {
        try {
          await Workmanager().registerOneOffTask(
            'immich-background-sync-unique-id',
            backgroundSyncTaskName,
            initialDelay: const Duration(minutes: 15),
            constraints: Constraints(networkType: NetworkType.connected),
            existingWorkPolicy: ExistingWorkPolicy.replace,
          );
        } catch (rescheduleError) {
          _log.severe('iOS: Failed to reschedule after error: $rescheduleError');
        }
      }

      return false;
    }
  });
}
