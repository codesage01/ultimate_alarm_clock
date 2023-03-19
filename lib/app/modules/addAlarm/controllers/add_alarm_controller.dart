import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:ultimate_alarm_clock/app/data/models/alarm_handler_model.dart';

import 'package:path/path.dart';
import 'package:ultimate_alarm_clock/app/data/models/alarm_model.dart';
import 'package:ultimate_alarm_clock/app/data/models/providers/objectbox.dart';
import 'package:ultimate_alarm_clock/app/utils/utils.dart';
import 'package:ultimate_alarm_clock/main.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(AlarmHandlerModel());
}

class AddAlarmController extends GetxController {
  final selectedTime = DateTime.now().obs;
  final isActivityenabled = false.obs;

  ReceivePort? _receivePort;

  createAlarm(AlarmModel alarmRecord) async {
    int intervaltoAlarm =
        Utils.getMillisecondsToAlarm(DateTime.now(), selectedTime.value);
    int alarmId = alarmRecord.id;
    if (await FlutterForegroundTask.isRunningService == false) {
      objectbox.insertAlarm(alarmRecord);
      // Starting service mandatorily!
      createForegroundTask(intervaltoAlarm);
      startForegroundTask(alarmId);
    } else {
      await restartForegroundTask(alarmRecord.id, intervaltoAlarm);
    }
  }

  restartForegroundTask(int alarmId, int intervalToAlarm) {
    _stopForegroundTask();
    createForegroundTask(intervalToAlarm);
    startForegroundTask(alarmId);
  }

  void createForegroundTask(int intervalForAlarm) {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'ulti_clock',
        channelName: 'Ultimate Alarm Clock',
        channelDescription: 'Ultimate Alarm Clock Channel',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
        buttons: [],
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        interval: intervalForAlarm,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<bool> startForegroundTask(int alarmId) async {
    if (!await FlutterForegroundTask.canDrawOverlays) {
      final isGranted =
          await FlutterForegroundTask.openSystemAlertWindowSettings();
      if (!isGranted) {
        print('SYSTEM_ALERT_WINDOW permission denied!');
        return false;
      }
    }

    await FlutterForegroundTask.saveData(key: 'alarmId', value: alarmId);

    final ReceivePort? receivePort = FlutterForegroundTask.receivePort;
    final bool isRegistered = _registerReceivePort(receivePort);
    if (!isRegistered) {
      print('Failed to register receivePort!');
      return false;
    }

    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    } else {
      return FlutterForegroundTask.startService(
        notificationTitle: 'UltiClock is running!',
        notificationText: 'Tap to return to the app',
        callback: startCallback,
      );
    }
  }

  Future<bool> _stopForegroundTask() {
    return FlutterForegroundTask.stopService();
  }

  void _closeReceivePort() {
    _receivePort?.close();
    _receivePort = null;
  }

  bool _registerReceivePort(ReceivePort? newReceivePort) {
    if (newReceivePort == null) {
      return false;
    }

    _closeReceivePort();

    _receivePort = newReceivePort;
    _receivePort?.listen((message) {
      if (message is int) {
        print('CONVERTING TO $message');

        // We're setting service for the next alarm and passing alarmId for that
        // TODO pass interval, not id to createForegroundTask
      }
      print('MAIN RECIEVED $message');

      if (message is String) {
        if (message == 'onNotificationPressed') {
          Get.to('/alarm-control');
        }
      }
    });

    return _receivePort != null;
  }

  T? _ambiguate<T>(T? value) => value;

  @override
  void onInit() async {
    super.onInit();
    _ambiguate(WidgetsBinding.instance)?.addPostFrameCallback((_) async {
      // You can get the previous ReceivePort without restarting the service.
      if (await FlutterForegroundTask.isRunningService) {
        final newReceivePort = FlutterForegroundTask.receivePort;
        _registerReceivePort(newReceivePort);
      }
    });
  }

  @override
  void onReady() {
    super.onReady();
  }

  @override
  void onClose() {
    super.onClose();
  }
}
