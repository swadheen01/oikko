import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_paths.dart';
import '../../models/transaction.dart';

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
      .fold(0.0, (sum, t) => sum + t.amount);

  static double totalExpense(List<AppTransaction> all) =>
      all.where((t) => t.type == TransactionType.expense).fold(0.0, (sum, t) => sum + t.amount);

  static double balance(List<AppTransaction> all) => totalIncome(all) - totalExpense(all);
}
