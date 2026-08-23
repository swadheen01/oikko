import 'package:cloud_firestore/cloud_firestore.dart';

/// Maps to the `transactions` Firestore collection (planning doc section 4.4).
enum TransactionType { duePayment, income, expense }

class AppTransaction {
  final String id;
  final String? memberId; // null for general association expense
  final TransactionType type;
  final double amount;
  final DateTime date;
  final String description;
  final String receiptUrl;
  final String createdBy;

  const AppTransaction({
    required this.id,
    this.memberId,
    required this.type,
    required this.amount,
    required this.date,
    this.description = '',
    this.receiptUrl = '',
    required this.createdBy,
  });

  factory AppTransaction.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppTransaction(
      id: doc.id,
      memberId: data['memberId'],
      type: _typeFromString(data['type'] ?? 'due_payment'),
      amount: (data['amount'] ?? 0).toDouble(),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: data['description'] ?? '',
      receiptUrl: data['receiptUrl'] ?? '',
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'type': _typeToString(type),
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'description': description,
      'receiptUrl': receiptUrl,
      'createdBy': createdBy,
    };
  }

  static TransactionType _typeFromString(String value) {
    switch (value) {
      case 'income':
        return TransactionType.income;
      case 'expense':
        return TransactionType.expense;
      default:
        return TransactionType.duePayment;
    }
  }

  static String _typeToString(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return 'income';
      case TransactionType.expense:
        return 'expense';
      case TransactionType.duePayment:
        return 'due_payment';
    }
  }
}
