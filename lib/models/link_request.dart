import 'package:cloud_firestore/cloud_firestore.dart';

/// Maps to the `link_requests` Firestore collection — see planning doc
/// section 4.9, Flow B ("Find My Profile & Request Link").
enum LinkRequestStatus { pending, approved, rejected }

class LinkRequest {
  final String id;
  final String memberId;
  final String requestedByUid;
  final String requestedPhone;
  final String requestedEmail;
  final LinkRequestStatus status;
  final DateTime? requestedAt;
  final String? reviewedBy;

  const LinkRequest({
    required this.id,
    required this.memberId,
    required this.requestedByUid,
    required this.requestedPhone,
    this.requestedEmail = '',
    this.status = LinkRequestStatus.pending,
    this.requestedAt,
    this.reviewedBy,
  });

  factory LinkRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return LinkRequest(
      id: doc.id,
      memberId: data['memberId'] ?? '',
      requestedByUid: data['requestedByUid'] ?? '',
      requestedPhone: data['requestedPhone'] ?? '',
      requestedEmail: data['requestedEmail'] ?? '',
      status: _statusFromString(data['status'] ?? 'pending'),
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'requestedByUid': requestedByUid,
      'requestedPhone': requestedPhone,
      'requestedEmail': requestedEmail,
      'status': _statusToString(status),
      'requestedAt': FieldValue.serverTimestamp(),
      'reviewedBy': reviewedBy,
    };
  }

  static LinkRequestStatus _statusFromString(String value) {
    switch (value) {
      case 'approved':
        return LinkRequestStatus.approved;
      case 'rejected':
        return LinkRequestStatus.rejected;
      default:
        return LinkRequestStatus.pending;
    }
  }

  static String _statusToString(LinkRequestStatus status) {
    switch (status) {
      case LinkRequestStatus.approved:
        return 'approved';
      case LinkRequestStatus.rejected:
        return 'rejected';
      case LinkRequestStatus.pending:
        return 'pending';
    }
  }
}
