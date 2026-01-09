import 'package:intl/intl.dart';

enum PaymentType {
  cash,
  creditCard,
  transfer;

  String get label {
    switch (this) {
      case PaymentType.cash:
        return 'Nakit';
      case PaymentType.creditCard:
        return 'Kredi Kartı';
      case PaymentType.transfer:
        return 'Havale/EFT';
    }
  }
}

enum PaymentCategory {
  packageRenewal,
  singleSession,
  extra,
  other;

  String get label {
    switch (this) {
      case PaymentCategory.packageRenewal:
        return 'Paket Yenileme';
      case PaymentCategory.singleSession:
        return 'Tek Ders';
      case PaymentCategory.extra:
        return 'Ekstra';
      case PaymentCategory.other:
        return 'Diğer';
    }
  }
}

class Payment {
  final String id;
  final String memberId;
  final double amount;
  final DateTime date;
  final PaymentType type;
  final PaymentCategory category;
  final String? description;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.memberId,
    required this.amount,
    required this.date,
    required this.type,
    this.category = PaymentCategory.packageRenewal,
    this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toSupabaseMap() {
    return {
      'member_id': memberId,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type.name == 'creditCard' ? 'credit_card' : type.name, // matching sql enum
      'category': category.name == 'packageRenewal' 
          ? 'package_renewal' 
          : category.name == 'singleSession' 
              ? 'single_session' 
              : category.name,
      'description': description,
    };
  }

  factory Payment.fromSupabaseMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as String,
      memberId: map['member_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      type: _parseType(map['type'] as String),
      category: _parseCategory(map['category'] as String? ?? 'package_renewal'),
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  static PaymentType _parseType(String val) {
    if (val == 'credit_card') return PaymentType.creditCard;
    if (val == 'cash') return PaymentType.cash;
    if (val == 'transfer') return PaymentType.transfer;
    return PaymentType.cash;
  }

  static PaymentCategory _parseCategory(String val) {
    if (val == 'package_renewal') return PaymentCategory.packageRenewal;
    if (val == 'single_session') return PaymentCategory.singleSession;
    if (val == 'extra') return PaymentCategory.extra;
    return PaymentCategory.other;
  }
  
  String get formattedDate => DateFormat('dd MMM yyyy', 'tr_TR').format(date);
  String get formattedAmount => NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(amount);
}
