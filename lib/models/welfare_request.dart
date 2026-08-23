import 'package:cloud_firestore/cloud_firestore.dart';

/// Maps to the `welfare_requests` Firestore collection (planning doc section 4.4).
enum RequestStatus { pending, approved, rejected }

class WelfareRequest {
  final String id;
  final String memberId;
  final String reason;
  final double amountRequested;
  final RequestStatus status;
  final DateTime? submittedAt;
  final String? reviewedBy;

  const WelfareRequest({
    required this.id,
    required this.memberId,
    required this.reason,
    required this.amountRequested,
    this.status = RequestStatus.pending,
    this.submittedAt,
    this.reviewedBy,
  });

  factory WelfareRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return WelfareRequest(
      id: doc.id,
      memberId: data['memberId'] ?? '',
      reason: data['reason'] ?? '',
      amountRequested: (data['amountRequested'] ?? 0).toDouble(),
      status: _statusFromString(data['status'] ?? 'pending'),
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'reason': reason,
      'amountRequested': amountRequested,
      'status': _statusToString(status),
      'submittedAt': FieldValue.serverTimestamp(),
      'reviewedBy': reviewedBy,
    };
  }

  static RequestStatus _statusFromString(String value) {
    switch (value) {
      case 'approved':
        return RequestStatus.approved;
      case 'rejected':
        return RequestStatus.rejected;
      default:
        return RequestStatus.pending;
    }
  }

  static String _statusToString(RequestStatus status) {
    switch (status) {
      case RequestStatus.approved:
        return 'approved';
      case RequestStatus.rejected:
        return 'rejected';
      case RequestStatus.pending:
        return 'pending';
    }
  }
}
