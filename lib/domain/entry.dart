enum EntryType { income, expense }

class Entry {
  final String id;
  final DateTime date;
  final EntryType type;
  final String category;
  final String title;
  final int amount;

  Entry({
    required this.id,
    required this.date,
    required this.type,
    required this.category,
    required this.title,
    required this.amount,
  });

  Entry copyWith({
    String? id,
    DateTime? date,
    EntryType? type,
    String? category,
    String? title,
    int? amount,
  }) {
    return Entry(
      id: id ?? this.id,
      date: date ?? this.date,
      type: type ?? this.type,
      category: category ?? this.category,
      title: title ?? this.title,
      amount: amount ?? this.amount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'type': type == EntryType.income ? 'income' : 'expense',
      'category': category,
      'title': title,
      'amount': amount,
    };
  }

  factory Entry.fromMap(Map<String, dynamic> map) {
    return Entry(
      id: map['id'] as String? ?? '',
      date: DateTime.parse(map['date'] as String),
      type: (map['type'] as String) == 'income' ? EntryType.income : EntryType.expense,
      category: map['category'] as String? ?? '',
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num).toInt(),
    );
  }
}
