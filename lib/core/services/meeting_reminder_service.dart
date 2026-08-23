import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../constants/firestore_paths.dart';
import '../locale/locale_service.dart';
import '../../models/notice.dart';

/// Fires a reminder notification shortly before a meeting starts.
///
/// FCM can't do this on its own: a push only arrives when something sends
/// one, and there's nothing running server-side at the scheduled moment to
/// send it (Cloud Functions and Cloud Scheduler both need the paid Blaze
/// plan). So each device schedules its own local alarm instead — no
/// server, no cost, and it still fires with the app closed.
///
/// The tradeoff: a device only learns about a meeting while the app is
/// open, since that's when this listens to the notices collection. A
/// member who never opens the app after a meeting is posted gets no
/// reminder — but they do still get the push sent at creation time.
class MeetingReminderService {
  static final MeetingReminderService instance = MeetingReminderService._();
  MeetingReminderService._();

  static const _channelId = 'meeting_reminders';

  final _plugin = FlutterLocalNotificationsPlugin();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  bool _ready = false;

  Future<void> _ensureInitialized() async {
    if (_ready) return;

    tz.initializeTimeZones();
    // The association is in Bangladesh, so pinning the zone avoids pulling
    // in a device-timezone plugin just to read one fixed offset.
    tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _ready = true;
  }

  /// Starts watching notices and keeps device-side reminders in step with
  /// them. Safe to call more than once; only the first call takes effect.
  Future<void> start() async {
    if (kIsWeb || _subscription != null) return;
    await _ensureInitialized();

    _subscription = FirebaseFirestore.instance
        .collection(FirestorePaths.notices)
        .snapshots()
        .listen((snapshot) {
      final notices = snapshot.docs.map(Notice.fromDoc).toList();
      _reschedule(notices);
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    if (_ready) await _plugin.cancelAll();
  }

  /// Cancels everything and re-schedules from the current notice list.
  /// Wholesale rather than diffing: a meeting can be edited or deleted, and
  /// at this scale (a handful of upcoming meetings) rebuilding the set is
  /// simpler than tracking which alarms are now stale.
  Future<void> _reschedule(List<Notice> notices) async {
    await _plugin.cancelAll();

    final now = DateTime.now();
    for (final notice in notices) {
      final remindAt = notice.reminderTime;
      if (remindAt == null || !remindAt.isAfter(now)) continue;

      await _schedule(notice, remindAt);
    }
  }

  Future<void> _schedule(Notice notice, DateTime remindAt) async {
    final isEn = LocaleService.isEnglish;
    final start = notice.eventDate!;
    final time = '${start.hour.toString().padLeft(2, '0')}:'
        '${start.minute.toString().padLeft(2, '0')}';

    final body = StringBuffer(
      isEn
          ? 'Starts at $time (in ${notice.reminderMinutes} minutes)'
          : '$time টায় শুরু (${notice.reminderMinutes} মিনিট পরে)',
    );
    if (notice.location.isNotEmpty) {
      body.write(isEn ? ' · ${notice.location}' : ' · ${notice.location}');
    }

    await _plugin.zonedSchedule(
      // Firestore doc IDs are strings; hashing to a stable 31-bit int keeps
      // the same meeting mapped to the same notification slot across
      // reschedules, so it can't pile up duplicates.
      id: notice.id.hashCode & 0x7fffffff,
      title: isEn ? 'Meeting: ${notice.title}' : 'সভা: ${notice.title}',
      body: body.toString(),
      scheduledDate: tz.TZDateTime.from(remindAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Meeting reminders',
          channelDescription: 'Reminds you shortly before a meeting starts',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Inexact deliberately: exact alarms need the SCHEDULE_EXACT_ALARM
      // permission, which Android 12+ makes the user grant by hand and can
      // revoke. A reminder that lands a couple of minutes either side of
      // the mark is fine; one that silently never fires is not.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
