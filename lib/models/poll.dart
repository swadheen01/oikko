import 'package:cloud_firestore/cloud_firestore.dart';

/// Maps to the `polls` Firestore collection (planning doc section 4.4).
class Poll {
  final String id;
  final String question;
  final List<String> options;
  final Map<String, int> votes; // key = option index as string
  final List<String> voterIds;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? closesAt;

  const Poll({
    required this.id,
    required this.question,
    required this.options,
    this.votes = const {},
    this.voterIds = const [],
    this.isActive = true,
    this.createdAt,
    this.closesAt,
  });

  bool hasVoted(String uid) => voterIds.contains(uid);
  int totalVotes() => votes.values.fold(0, (total, v) => total + v);

  factory Poll.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Poll(
      id: doc.id,
      question: data['question'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      votes: Map<String, int>.from(data['votes'] ?? {}),
      voterIds: List<String>.from(data['voterIds'] ?? []),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      closesAt: (data['closesAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'votes': votes,
      'voterIds': voterIds,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
      'closesAt': closesAt != null ? Timestamp.fromDate(closesAt!) : null,
    };
  }
}
