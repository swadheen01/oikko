import 'package:cloud_firestore/cloud_firestore.dart';

/// One anonymous complaint. Deliberately carries no submitter identity — see
/// firestore.rules `complaints` match.
class Complaint {
  final String id;
  final String message;
  final DateTime? createdAt;
  /// Shared "seen" flag across all admins — whichever admin opens the
  /// complaint box first marks every pending complaint read for everyone,
  /// the same as a shared mailbox. Drives the drawer/home badge.
  final bool read;

  const Complaint({
    required this.id,
    required this.message,
    this.createdAt,
    this.read = false,
  });

  factory Complaint.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Complaint(
      id: doc.id,
      message: (data['message'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      read: data['read'] == true,
    );
  }
}
