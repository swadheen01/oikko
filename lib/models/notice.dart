import 'package:cloud_firestore/cloud_firestore.dart';

/// Maps to the `notices` Firestore collection (planning doc section 4.4).
class Notice {
  final String id;
  final String title;
  final String body;
  final String postedBy;
  final DateTime? createdAt;
  /// For events this may be date-only; for meetings it carries the actual
  /// start time too, since the reminder needs to fire relative to it.
  final DateTime? eventDate;
  final String location;

  /// Marks this notice as a meeting: members get a reminder notification
  /// `reminderMinutes` before `eventDate`, scheduled on their own device.
  final bool isMeeting;

  /// How long before the meeting the reminder fires.
  final int reminderMinutes;

  const Notice({
    required this.id,
    required this.title,
    required this.body,
    required this.postedBy,
    this.createdAt,
    this.eventDate,
    this.location = '',
    this.isMeeting = false,
    this.reminderMinutes = 30,
  });

  bool get isEvent => eventDate != null;

  /// When the reminder should fire, or null if this isn't a scheduled
  /// meeting.
  DateTime? get reminderTime => (isMeeting && eventDate != null)
      ? eventDate!.subtract(Duration(minutes: reminderMinutes))
      : null;

  factory Notice.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Notice(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      postedBy: data['postedBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      eventDate: (data['eventDate'] as Timestamp?)?.toDate(),
      location: data['location'] ?? '',
      isMeeting: data['isMeeting'] ?? false,
      reminderMinutes: (data['reminderMinutes'] as num?)?.toInt() ?? 30,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'postedBy': postedBy,
      'createdAt': FieldValue.serverTimestamp(),
      'eventDate': eventDate != null ? Timestamp.fromDate(eventDate!) : null,
      'location': location,
      'isMeeting': isMeeting,
      'reminderMinutes': reminderMinutes,
    };
  }
}
