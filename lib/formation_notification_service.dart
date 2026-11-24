import 'package:flutter/services.dart';

class FormationNotificationService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.rubberway/formation_reminders',
  );

  static Future<bool> scheduleReminder({
    required int id,
    required DateTime scheduledAt,
    required String producerName,
    required String codePhi,
  }) async {
    return await _channel.invokeMethod<bool>('scheduleReminder', {
          'id': id,
          'scheduledAt': scheduledAt.millisecondsSinceEpoch,
          'title': 'Formation RubberWay à réaliser',
          'body': 'Formation de $producerName ($codePhi) prévue aujourd’hui.',
        }) ??
        false;
  }

  static Future<void> cancelReminder(int id) =>
      _channel.invokeMethod<void>('cancelReminder', {'id': id});
}
