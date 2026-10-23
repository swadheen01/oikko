import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_paths.dart';
import '../../models/member.dart';
import '../../models/transaction.dart';

/// Summary model for a school's deposits, withdrawals, and net balance.
class SchoolFinanceSummary {
  final String schoolName;
  final int memberCount;
  final double totalDeposit;
  final double totalWithdrawal;
  final double balance;
  final List<AppTransaction> transactions;

  const SchoolFinanceSummary({
    required this.schoolName,
    required this.memberCount,
    required this.totalDeposit,
    required this.totalWithdrawal,
    required this.balance,
    required this.transactions,
  });
}

/// Finance-specific Firestore queries (planning doc section 4.4 —
/// `transactions` collection). Kept separate from the generic
/// FirestoreService to keep finance logic (totals, filtering) together.
class FinanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// All transactions, newest first — used for the admin dashboard.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllTransactions() {
    return _db
        .collection(FirestorePaths.transactions)
        .orderBy('date', descending: true)
        .snapshots();
  }

  /// Transactions belonging to a single member — used for their
  /// personal statement screen.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchMemberTransactions(String memberId) {
    return _db
        .collection(FirestorePaths.transactions)
        .where('memberId', isEqualTo: memberId)
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> addTransaction(AppTransaction transaction) {
    return _db.collection(FirestorePaths.transactions).add(transaction.toMap());
  }

  /// Admin-only: remove one payment/expense record. Totals are computed by
  /// summing the collection, so deleting a row is what corrects a figure
  /// that was entered wrongly — there is no separate "adjustment" concept.
  Future<void> deleteTransaction(String transactionId) {
    return _db.collection(FirestorePaths.transactions).doc(transactionId).delete();
  }

  /// Admin-only: wipe every transaction, resetting all totals to zero.
  /// Firestore has no "delete collection" call, so this pages through in
  /// batches of 400 (the write-batch limit is 500).
  Future<int> deleteAllTransactions() async {
    var deleted = 0;
    while (true) {
      final snapshot = await _db
          .collection(FirestorePaths.transactions)
          .limit(400)
          .get();
      if (snapshot.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      deleted += snapshot.docs.length;
    }
    return deleted;
  }

  /// Simple in-memory aggregation — fine at this member-count scale.
  /// If the association grows very large, this should move to a
  /// Cloud Function that maintains running totals instead.
  static double totalIncome(List<AppTransaction> all) => all
      .where((t) => t.type == TransactionType.income || t.type == TransactionType.duePayment)
      .fold(0.0, (acc, t) => acc + t.amount);

  static double totalExpense(List<AppTransaction> all) => all
      .where((t) => t.type == TransactionType.expense || t.type == TransactionType.withdrawal)
      .fold(0.0, (acc, t) => acc + t.amount);

  static double totalWithdrawal(List<AppTransaction> all) => all
      .where((t) => t.type == TransactionType.withdrawal)
      .fold(0.0, (acc, t) => acc + t.amount);

  static double totalDeposit(List<AppTransaction> all) => all
      .where((t) => t.type == TransactionType.duePayment)
      .fold(0.0, (acc, t) => acc + t.amount);

  static double totalDonations(List<AppTransaction> all) => all
      .where((t) =>
          t.type == TransactionType.income &&
          (t.source == 'donation' || t.category == 'অনুদান' || (t.donorName != null && t.donorName!.isNotEmpty)))
      .fold(0.0, (acc, t) => acc + t.amount);

  static double balance(List<AppTransaction> all) => totalIncome(all) - totalExpense(all);

  /// Resolves the school name for any transaction.
  /// First checks the direct `tx.schoolName`. If null, looks up the member's school
  /// from [membersMap]. Backward-compatible with all pre-existing records!
  static String? effectiveSchool(AppTransaction tx, Map<String, Member> membersMap) {
    if (tx.schoolName != null && tx.schoolName!.trim().isNotEmpty) {
      return tx.schoolName!.trim();
    }
    if (tx.memberId != null) {
      final member = membersMap[tx.memberId];
      if (member != null && member.schoolName.trim().isNotEmpty) {
        return member.schoolName.trim();
      }
    }
    return null;
  }

  /// Filter all transactions belonging to a given school name.
  static List<AppTransaction> transactionsForSchool(
    String schoolName,
    List<AppTransaction> all,
    Map<String, Member> membersMap,
  ) {
    final target = schoolName.trim().toLowerCase();
    return all.where((tx) {
      final school = effectiveSchool(tx, membersMap);
      return school != null && school.toLowerCase() == target;
    }).toList();
  }

  /// Aggregates finance data for all known schools.
  static List<SchoolFinanceSummary> allSchoolSummaries(
    List<AppTransaction> all,
    Map<String, Member> membersMap,
    Iterable<String> knownSchools,
  ) {
    // Collect all unique school names from both known schools list and transactions
    final schoolSet = <String>{};
    for (final s in knownSchools) {
      final trimmed = s.trim();
      if (trimmed.isNotEmpty) schoolSet.add(trimmed);
    }
    for (final tx in all) {
      final s = effectiveSchool(tx, membersMap);
      if (s != null && s.isNotEmpty) schoolSet.add(s);
    }

    final summaries = <SchoolFinanceSummary>[];
    for (final school in schoolSet) {
      final txs = transactionsForSchool(school, all, membersMap);
      final deposit = txs
          .where((t) => t.type == TransactionType.duePayment || t.type == TransactionType.income)
          .fold(0.0, (acc, t) => acc + t.amount);
      final withdrawal = txs
          .where((t) => t.type == TransactionType.withdrawal || t.type == TransactionType.expense)
          .fold(0.0, (acc, t) => acc + t.amount);
      final memberCount = membersMap.values
          .where((m) => m.schoolName.trim().toLowerCase() == school.toLowerCase())
          .length;

      summaries.add(SchoolFinanceSummary(
        schoolName: school,
        memberCount: memberCount,
        totalDeposit: deposit,
        totalWithdrawal: withdrawal,
        balance: deposit - withdrawal,
        transactions: txs,
      ));
    }

    // Sort by largest net balance or deposit, then alphabetical
    summaries.sort((a, b) {
      final cmp = b.totalDeposit.compareTo(a.totalDeposit);
      if (cmp != 0) return cmp;
      return a.schoolName.compareTo(b.schoolName);
    });

    return summaries;
  }
}
