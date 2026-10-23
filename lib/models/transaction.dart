import 'package:cloud_firestore/cloud_firestore.dart';

/// Maps to the `transactions` Firestore collection (planning doc section 4.4).
enum TransactionType { duePayment, income, expense, withdrawal }

class AppTransaction {
  final String id;
  final String? memberId; // null for general association expense or school-level payment
  final String? schoolName; // name of the school (for school-level transactions or tagged payments)
  final String? source; // e.g. 'member_due', 'school_fund', 'donation', 'bank_profit', 'event_fee', 'other'
  final String? category; // e.g. 'অনুদান', 'বার্ষিক চাঁদা', 'সভা', 'আপ্যায়ন', 'অফিস', ইত্যাদি
  final String? donorName; // e.g. name of the donor / organization if donation
  final TransactionType type;
  final double amount;
  final DateTime date;
  final String description;
  final String receiptUrl;
  final String createdBy;

  const AppTransaction({
    required this.id,
    this.memberId,
    this.schoolName,
    this.source,
    this.category,
    this.donorName,
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
      schoolName: data['schoolName'] as String?,
      source: data['source'] as String?,
      category: data['category'] as String?,
      donorName: (data['donorName'] ?? data['payerName']) as String?,
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
      if (schoolName != null && schoolName!.isNotEmpty) 'schoolName': schoolName,
      if (source != null && source!.isNotEmpty) 'source': source,
      if (category != null && category!.isNotEmpty) 'category': category,
      if (donorName != null && donorName!.isNotEmpty) 'donorName': donorName,
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
      case 'withdrawal':
        return TransactionType.withdrawal;
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
      case TransactionType.withdrawal:
        return 'withdrawal';
      case TransactionType.duePayment:
        return 'due_payment';
    }
  }
}
